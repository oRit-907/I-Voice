--[[
	Player facing commands and proximity cycling.
]]

local wasProximityDisabledFromOverride = false
disableProximityCycle = false

--- Set while a resource has pinned the talk range to a custom value.
customProximityRange = nil

--- The index the UI should highlight — the "Custom" entry sits one past the
--- configured modes.
function getUiVoiceModeIndex()
	if customProximityRange then
		return #Cfg.voiceModes
	end
	return mode - 1
end

RegisterCommand('setvoiceintent', function(_, args)
	if GetConvarInt('voice_allowSetIntent', 1) ~= 1 then return end

	local intent = args[1]
	if intent == 'speech' then
		MumbleSetAudioInputIntent(`speech`)
	elseif intent == 'music' then
		MumbleSetAudioInputIntent(`music`)
	else
		return logger.warn('Usage: /setvoiceintent [speech|music]')
	end

	LocalPlayer.state:set('voiceIntent', intent, true)
end)

RegisterCommand('vol', function(_, args)
	local volume = tonumber(args[1])
	if not volume then
		return logger.log('Usage: /vol [0-100] (radio|phone|megaphone)')
	end
	setVolume(volume, args[2])
end)

RegisterCommand('micclicks', function()
	local enabled = not getSetting('micClicks')
	setSetting('micClicks', enabled)
	logger.log('Mic clicks are now %s', enabled and 'on' or 'off')
end)

RegisterCommand('voiceblock', function(_, args)
	local target = tonumber(args[1])
	if not target then
		local blocked = getBlockedPlayers()
		if #blocked == 0 then
			return logger.log('You have nobody blocked. Usage: /voiceblock [player id]')
		end
		return logger.log('Blocked players: %s', table.concat(blocked, ', '))
	end

	if target == playerServerId then
		return logger.log('You cannot block yourself.')
	end

	local blocked = toggleMutePlayer(target)
	logger.log('%s player %s.', blocked and 'Blocked' or 'Unblocked', target)
	refreshUI()
end)

RegisterCommand('voiceunblockall', function()
	clearBlockedPlayers()
	logger.log('Cleared your block list.')
	refreshUI()
end)

RegisterCommand('radiomonitor', function(_, args)
	local channel = tonumber(args[1])
	if not channel then
		return logger.log('Usage: /radiomonitor [channel] — monitors a channel without transmitting on it')
	end

	if isOnRadioChannel(channel) and channel ~= getRadioChannel() then
		removeSecondaryRadioChannel(channel)
		logger.log('Stopped monitoring channel %s.', channel)
	else
		addSecondaryRadioChannel(channel)
		logger.log('Now monitoring channel %s.', channel)
	end
end)

exports('setAllowProximityCycleState', function(state)
	type_check({ state, 'boolean' })
	disableProximityCycle = state
end)

--- Applies a talk range and mirrors it into the state bag and the UI.
--- @param proximityRange number
--- @param isCustom boolean whether this came from an override
function setProximityState(proximityRange, isCustom)
	local voiceModeData = Cfg.voiceModes[mode]
	customProximityRange = isCustom and proximityRange or nil

	MumbleSetTalkerProximity(proximityRange + 0.0)
	LocalPlayer.state:set('proximity', {
		index = mode,
		distance = proximityRange,
		mode = isCustom and 'Custom' or voiceModeData[2],
	}, true)

	sendUIMessage({ voiceMode = getUiVoiceModeIndex() })
end

exports('overrideProximityRange', function(range, disableCycle)
	type_check({ range, 'number' })
	setProximityState(range, true)
	if disableCycle then
		disableProximityCycle = true
		wasProximityDisabledFromOverride = true
	end
end)

exports('clearProximityOverride', function()
	setProximityState(Cfg.voiceModes[mode][1], false)
	if wasProximityDisabledFromOverride then
		disableProximityCycle = false
		wasProximityDisabledFromOverride = false
	end
end)

RegisterCommand('cycleproximity', function()
	-- Proximity is either disabled, or manually overwritten.
	if GetConvarInt('voice_enableProximityCycle', 1) ~= 1 or disableProximityCycle then return end

	mode = mode + 1
	if mode > #Cfg.voiceModes then
		mode = 1
	end

	setProximityState(Cfg.voiceModes[mode][1], false)
	TriggerEvent('ivoice:setTalkingMode', mode)
end, false)

if gameVersion == 'fivem' then
	RegisterKeyMapping('cycleproximity', 'Cycle Proximity', 'keyboard', GetConvar('voice_defaultCycle', 'F11'))
end

CreateThread(function()
	TriggerEvent('chat:addSuggestion', '/vol', 'Sets your voice volume', {
		{ name = 'volume', help = '0-100' },
		{ name = 'type', help = '(opt) radio, phone or megaphone — all of them when omitted' },
	})
	TriggerEvent('chat:addSuggestion', '/voicesettings', 'Opens the voice settings panel')
	TriggerEvent('chat:addSuggestion', '/micclicks', 'Toggles radio mic clicks')
	TriggerEvent('chat:addSuggestion', '/voiceblock', 'Silences a player for you only', {
		{ name = 'player id', help = 'the player to block or unblock' },
	})
	TriggerEvent('chat:addSuggestion', '/voiceunblockall', 'Clears your block list')
	TriggerEvent('chat:addSuggestion', '/radiomonitor', 'Monitors an extra radio channel', {
		{ name = 'channel', help = 'the channel to start or stop monitoring' },
	})
	TriggerEvent('chat:addSuggestion', '/setvoiceintent', 'Tells Mumble whether you are speaking or playing music', {
		{ name = 'intent', help = 'speech or music' },
	})
end)
