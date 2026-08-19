--[[
	Mumble connection lifecycle.
]]

--- Puts the client into its baseline proximity state: own channel, own target,
--- talker proximity matching the selected voice mode.
function handleInitialState()
	local voiceModeData = Cfg.voiceModes[mode]

	MumbleSetTalkerProximity((customProximityRange or voiceModeData[1]) + 0.0)
	MumbleClearVoiceTarget(voiceTarget)
	MumbleSetVoiceTarget(voiceTarget)
	MumbleSetVoiceChannel(playerServerId)

	local deadline = GetGameTimer() + 30000
	while MumbleGetVoiceChannelFromServerId(playerServerId) ~= playerServerId do
		if GetGameTimer() > deadline then
			logger.warn('Timed out waiting to be moved onto our own Mumble channel; retrying.')
			MumbleSetVoiceChannel(playerServerId)
			deadline = GetGameTimer() + 30000
		end
		Wait(250)
	end

	MumbleAddVoiceTargetChannel(voiceTarget, playerServerId)

	addNearbyPlayers()
end

AddEventHandler('mumbleConnected', function(address, isReconnecting)
	local shown = GetConvarInt('voice_hideEndpoints', 1) == 1 and 'HIDDEN' or address
	logger.info('Connected to mumble server with address of %s, is this a reconnect %s', shown, isReconnecting)
	logger.log('Connecting to mumble, setting targets.')

	-- don't try to set the channel instantly, we're still getting data.
	local voiceModeData = Cfg.voiceModes[mode]
	LocalPlayer.state:set('proximity', {
		index = mode,
		distance = customProximityRange or voiceModeData[1],
		mode = customProximityRange and 'Custom' or voiceModeData[2],
	}, true)

	handleInitialState()

	-- a reconnect drops every listen channel, so ask the server for the state
	-- we're meant to be holding
	TriggerServerEvent('ivoice:requestSync')

	logger.log('Finished connection logic')
end)

AddEventHandler('mumbleDisconnected', function(address)
	local shown = GetConvarInt('voice_hideEndpoints', 1) == 1 and 'HIDDEN' or address
	logger.info('Disconnected from mumble server with address of %s', shown)
end)

-- TODO: Convert the last Cfg to a Convar, while still keeping it simple.
AddEventHandler('ivoice:settingsCallback', function(cb)
	cb(Cfg)
end)