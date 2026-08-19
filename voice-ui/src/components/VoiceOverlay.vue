<template>
	<div class="overlay" :class="voice.uiPosition" :style="overlayStyle">
		<transition name="fade">
			<div v-if="voice.notification" class="notification" :class="voice.notification.kind">
				{{ voice.notification.text }}
			</div>
		</transition>

		<transition name="fade">
			<ul v-if="talkers.length" class="talkers">
				<li v-for="talker in talkers" :key="talker.id">
					<span class="pulse"></span>
					<span class="talker-name">{{ talker.name }}</span>
					<span class="talker-channel">{{ formatChannel(talker.channel) }}</span>
				</li>
			</ul>
		</transition>

		<div class="rows">
			<transition name="fade">
				<div v-if="voice.usingMegaphone" class="row megaphone active">
					<span class="dot"></span>
					<span class="label">Megaphone</span>
				</div>
			</transition>

			<transition name="fade">
				<div v-if="voice.callInfo !== 0" class="row call" :class="{ active: voice.talking }">
					<span class="dot"></span>
					<span class="label">Call</span>
				</div>
			</transition>

			<transition name="fade">
				<div
					v-if="voice.radioEnabled && voice.radioChannel !== 0"
					class="row radio"
					:class="{ active: voice.usingRadio }"
				>
					<span class="dot"></span>
					<span class="label">{{ formatChannel(voice.radioChannel) }}</span>
					<span v-if="monitoredChannels.length" class="badge">
						+{{ monitoredChannels.length }}
					</span>
				</div>
			</transition>

			<div v-if="voice.voiceModes.length" class="row range" :class="{ active: voice.talking }">
				<span class="meter" aria-hidden="true">
					<i v-for="step in 3" :key="step" :class="{ lit: step <= litSteps }"></i>
				</span>
				<span class="label">{{ voiceModeLabel }}</span>
			</div>
		</div>
	</div>
</template>

<script setup>
import { computed } from 'vue'
import { voice, voiceModeLabel, monitoredChannels } from '../state.js'

const overlayStyle = computed(() => ({
	transform: `scale(${(voice.uiScale || 100) / 100})`,
}))

/** How many range bars to light up — "Custom" always shows as full. */
const litSteps = computed(() => {
	if (voice.voiceMode >= voice.voiceModes.length - 1) return 3
	return voice.voiceMode + 1
})

const talkers = computed(() => (voice.showTalkerList ? voice.radioTalkers : []))

/** Renders a channel number the way a radio would: `142.5 MHz`. */
function formatChannel(channel) {
	return `${(channel / 10).toFixed(1)} MHz`
}
</script>

<style scoped>
.overlay {
	position: fixed;
	display: flex;
	flex-direction: column;
	gap: 4px;
	pointer-events: none;
	font-size: 12px;
	font-weight: 700;
	line-height: 1.35;
	color: var(--ivoice-idle);
	text-shadow: var(--ivoice-outline);
}

.overlay.bottom-right {
	right: 8px;
	bottom: 6px;
	align-items: flex-end;
	transform-origin: bottom right;
}
.overlay.bottom-left {
	left: 8px;
	bottom: 6px;
	align-items: flex-start;
	transform-origin: bottom left;
}
.overlay.top-right {
	right: 8px;
	top: 6px;
	align-items: flex-end;
	transform-origin: top right;
}
.overlay.top-left {
	left: 8px;
	top: 6px;
	align-items: flex-start;
	transform-origin: top left;
}

.rows {
	display: flex;
	flex-direction: column;
	align-items: inherit;
	gap: 1px;
}

.row {
	display: flex;
	align-items: center;
	gap: 5px;
	transition: color 120ms ease;
}

.overlay.bottom-left .row,
.overlay.top-left .row {
	flex-direction: row-reverse;
}

.row.active {
	color: var(--ivoice-active);
}

.dot {
	width: 6px;
	height: 6px;
	border-radius: 50%;
	background: currentColor;
	opacity: 0.45;
	transition: opacity 120ms ease, box-shadow 120ms ease;
}

.row.active .dot {
	opacity: 1;
}

.row.radio.active {
	color: var(--ivoice-radio);
}
.row.call.active {
	color: var(--ivoice-call);
}
.row.megaphone.active {
	color: var(--ivoice-megaphone);
}

.row.radio.active .dot,
.row.call.active .dot,
.row.megaphone.active .dot {
	box-shadow: 0 0 6px currentColor;
	animation: throb 900ms ease-in-out infinite;
}

.badge {
	padding: 0 4px;
	border-radius: 6px;
	background: rgba(255, 255, 255, 0.16);
	font-size: 10px;
	text-shadow: none;
}

.meter {
	display: inline-flex;
	align-items: flex-end;
	gap: 2px;
	height: 9px;
}

.meter i {
	display: block;
	width: 3px;
	background: currentColor;
	opacity: 0.3;
	border-radius: 1px;
	transition: opacity 120ms ease;
}

.meter i:nth-child(1) {
	height: 4px;
}
.meter i:nth-child(2) {
	height: 7px;
}
.meter i:nth-child(3) {
	height: 10px;
}

.meter i.lit {
	opacity: 0.95;
}

.talkers {
	margin: 0 0 2px;
	padding: 0;
	list-style: none;
	display: flex;
	flex-direction: column;
	align-items: inherit;
	gap: 1px;
	font-weight: 600;
	color: var(--ivoice-radio);
}

.talkers li {
	display: flex;
	align-items: center;
	gap: 5px;
}

.overlay.bottom-left .talkers li,
.overlay.top-left .talkers li {
	flex-direction: row-reverse;
}

.talker-channel {
	opacity: 0.6;
	font-weight: 500;
	font-size: 11px;
}

.pulse {
	width: 5px;
	height: 5px;
	border-radius: 50%;
	background: currentColor;
	box-shadow: 0 0 6px currentColor;
	animation: throb 900ms ease-in-out infinite;
}

.notification {
	max-width: 280px;
	padding: 5px 9px;
	border-radius: 5px;
	background: var(--ivoice-panel);
	border: 1px solid var(--ivoice-panel-border);
	color: var(--ivoice-active);
	font-weight: 600;
	text-shadow: none;
}

.notification.error {
	border-color: rgba(255, 118, 118, 0.5);
	color: var(--ivoice-danger);
}

@keyframes throb {
	0%,
	100% {
		opacity: 1;
	}
	50% {
		opacity: 0.4;
	}
}

.fade-enter-active,
.fade-leave-active {
	transition: opacity 140ms ease;
}
.fade-enter-from,
.fade-leave-to {
	opacity: 0;
}
</style>
