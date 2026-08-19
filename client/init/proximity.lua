--[[
	Proximity: decides who can hear the local player, and keeps the UI's
	talking indicator in step with Mumble.
]]

local isListenerEnabled = false
local plyCoords = GetEntityCoords(PlayerPedId())

--- The distance the local player's voice currently carries, in game units.
--- A megaphone overrides the selected voice mode while it's raised.
function getEffectiveTalkRange()
	if isMegaphoneActive and isMegaphoneActive() then
		return Cfg.megaphoneRange
	end

	local voiceModeData = Cfg.voiceModes[mode]
	local range = customProximityRange or voiceModeData[1]
	return GetConvar('voice_useNativeAudio', 'false') == 'true' and range * 3 or range
end

function orig_addProximityCheck(ply)
	local tgtPed = GetPlayerPed(ply)
	return #(plyCoords - GetEntityCoords(tgtPed)) < getEffectiveTalkRange()
end

local addProximityCheck = orig_addProximityCheck

exports('overrideProximityCheck', function(fn)
	addProximityCheck = fn
end)

exports('resetProximityCheck', function()
	addProximityCheck = orig_addProximityCheck
end)

--- The coordinates the proximity loop last sampled. Cheaper than re-reading the
--- ped position for every candidate, and handy for the other modules.
function getCachedPlayerCoords()
	return plyCoords
end

--- Rebuilds the set of players close enough to hear us.
function addNearbyPlayers()
	-- update here so we don't have to update every call of addProximityCheck
	plyCoords = GetEntityCoords(PlayerPedId())

	MumbleClearVoiceTargetChannels(voiceTarget)
	-- We always broadcast on our own channel; anything listening to us (a
	-- megaphone receiver, a spectator) hears us through it.
	MumbleAddVoiceTargetChannel(voiceTarget, playerServerId)

	local players = GetActivePlayers()
	for i = 1, #players do
		local ply = players[i]
		local serverId = GetPlayerServerId(ply)

		if serverId ~= playerServerId and addProximityCheck(ply) then
			logger.verbose('Added %s as a voice target', serverId)
			MumbleAddVoiceTargetChannel(voiceTarget, serverId)
		end
	end
end

--- Spectators hear everyone, so bulk add/remove every player to our listen set.
function setSpectatorMode(enabled)
	logger.info('Setting spectate mode to %s', enabled)
	isListenerEnabled = enabled

	local players = GetActivePlayers()
	for i = 1, #players do
		local serverId = GetPlayerServerId(players[i])
		if serverId ~= playerServerId then
			if enabled then
				logger.verbose('Adding %s to listen table', serverId)
				MumbleAddVoiceChannelListen(serverId)
			else
				logger.verbose('Removing %s from listen table', serverId)
				MumbleRemoveVoiceChannelListen(serverId)
			end
		end
	end
end

--- True while spectator listening is on; the megaphone module checks this so it
--- doesn't tear down a listen channel spectating still needs.
function isSpectatorListening()
	return isListenerEnabled
end

RegisterNetEvent('onPlayerJoining', function(serverId)
	if isListenerEnabled then
		MumbleAddVoiceChannelListen(serverId)
		logger.verbose('Adding %s to listen table', serverId)
	end
end)

RegisterNetEvent('onPlayerDropped', function(serverId)
	if isListenerEnabled then
		MumbleRemoveVoiceChannelListen(serverId)
		logger.verbose('Removing %s from listen table', serverId)
	end
end)

-- cache talking status so we only send a nui message when it changed
local lastTalkingStatus = false
local lastRadioStatus = false
local lastMegaphoneStatus = false
local voiceState = 'proximity'

Citizen.CreateThread(function()
	while true do
		-- wait for mumble to reconnect
		while not MumbleIsConnected() do
			Wait(100)
		end

		if getSetting('uiEnabled') then
			local curTalkingStatus = isLocalPlayerTalking()
			local curMegaphoneStatus = isMegaphoneActive and isMegaphoneActive() or false

			if lastRadioStatus ~= radioPressed
				or lastTalkingStatus ~= curTalkingStatus
				or lastMegaphoneStatus ~= curMegaphoneStatus
			then
				lastRadioStatus = radioPressed
				lastTalkingStatus = curTalkingStatus
				lastMegaphoneStatus = curMegaphoneStatus
				sendUIMessage({
					usingRadio = lastRadioStatus,
					usingMegaphone = lastMegaphoneStatus,
					talking = lastTalkingStatus,
				})
			end
		end

		if voiceState == 'proximity' then
			addNearbyPlayers()

			local isSpectating = NetworkIsInSpectatorMode()
			if isSpectating and not isListenerEnabled then
				setSpectatorMode(true)
			elseif not isSpectating and isListenerEnabled then
				setSpectatorMode(false)
			end
		end

		if updateMegaphoneListeners then
			updateMegaphoneListeners(plyCoords)
		end

		Wait(GetConvarInt('voice_refreshRate', GetConvarInt('voice_uiRefreshRate', 200)))
	end
end)

--- Switches between proximity voice and a fixed, server-wide channel.
--- @param _voiceState string 'proximity' or 'channel'
--- @param channel number|nil the channel index when using 'channel'
exports('setVoiceState', function(_voiceState, channel)
	if _voiceState ~= 'proximity' and _voiceState ~= 'channel' then
		logger.error("Didn't get a proper voice state, expected proximity or channel, got %s", tostring(_voiceState))
	end

	voiceState = _voiceState

	if voiceState == 'channel' then
		type_check({ channel, 'number' })
		-- 65535 is the highest a client id can go, so we add that to the base
		-- channel so we can't collide with a player's own channel.
		channel = channel + 65535
		MumbleSetVoiceChannel(channel)
		while MumbleGetVoiceChannelFromServerId(playerServerId) ~= channel do
			Wait(250)
		end
		MumbleAddVoiceTargetChannel(voiceTarget, channel)
	else
		handleInitialState()
	end
end)

--- The current voice state, for resources that need to know before switching.
exports('getVoiceState', function()
	return voiceState
end)

AddEventHandler('onClientResourceStop', function(resource)
	if isFunctionRef(addProximityCheck) then
		local proximityCheckRef = addProximityCheck.__cfx_functionReference
		if proximityCheckRef and string.match(proximityCheckRef, resource) then
			addProximityCheck = orig_addProximityCheck
			logger.warn('Reset proximity check to default, the original resource [%s] which provided the function restarted', resource)
		end
	end
end)
