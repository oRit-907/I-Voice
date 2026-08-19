/*
 * Server side mute handling.
 *
 * Implemented in JS because Lua has no way to cancel a scheduled timer, and a
 * temporary mute has to be cancellable when an admin toggles it back off.
 *
 * The command is `muteply` rather than `mute` because `mute` collides with
 * rp-radio.
 */

/** @type {Record<number, NodeJS.Timeout>} */
const muteTimers = {};

const resourceName = GetCurrentResourceName();

/**
 * Applies a mute state to a player and mirrors it into their state bag.
 * @param {number} target the player's server id
 * @param {boolean} muted
 */
function applyMute(target, muted) {
	MumbleSetPlayerMuted(target, muted);
	Player(target).state.set('muted', muted, true);
}

/**
 * Clears any pending automatic unmute for a player.
 * @param {number} target
 */
function clearMuteTimer(target) {
	if (muteTimers[target]) {
		clearTimeout(muteTimers[target]);
		delete muteTimers[target];
	}
}

/**
 * Mutes or unmutes a player, optionally for a fixed duration.
 * @param {number} target the player to mute
 * @param {boolean} muted the state to apply
 * @param {number} duration seconds before an automatic unmute (mutes only)
 * @param {number|string} [invoker] whoever triggered it, for the event payload
 */
function setPlayerMuted(target, muted, duration, invoker) {
	target = parseInt(target, 10);
	if (Number.isNaN(target) || !exports[resourceName].isValidPlayer(target)) {
		return false;
	}

	clearMuteTimer(target);
	applyMute(target, muted);
	emit('ivoice:playerMuted', target, invoker, muted, duration);

	if (muted && duration > 0) {
		muteTimers[target] = setTimeout(() => {
			delete muteTimers[target];
			applyMute(target, false);
			emit('ivoice:playerMuted', target, invoker, false, 0);
		}, duration * 1000);
	}

	return true;
}

exports('setPlayerMuted', setPlayerMuted);

exports('isPlayerMuted', (target) => MumbleIsPlayerMuted(parseInt(target, 10)));

RegisterCommand(
	'muteply',
	(source, args) => {
		const target = parseInt(args[0], 10);
		if (Number.isNaN(target)) {
			console.log('Usage: muteply [player id] (duration in seconds, default 900)');
			return;
		}

		const parsedDuration = parseInt(args[1], 10);
		const duration = Number.isNaN(parsedDuration) ? 900 : parsedDuration;

		// toggle: if they're muted right now, this call lifts it
		const muted = !MumbleIsPlayerMuted(target);

		if (!setPlayerMuted(target, muted, duration, source)) {
			console.log(`[I-Voice] ${target} is not a player we're tracking.`);
			return;
		}

		console.log(
			muted
				? `[I-Voice] Muted ${target}${duration > 0 ? ` for ${duration} seconds` : ''}.`
				: `[I-Voice] Unmuted ${target}.`
		);
	},
	true
);

on('playerDropped', () => {
	clearMuteTimer(parseInt(global.source, 10));
});
