--[[
	UI state bridge.

	Every module calls `refreshUI()` after it changes something; this file is
	the single place that decides what the NUI frame actually gets told.
]]

local settingsOpen = false

--- Collects the full voice state and hands it to the UI.
function refreshUI()
	if not uiIsReady() then return end

	sendUIMessage({
		uiEnabled = getSetting('uiEnabled'),
		uiScale = getSetting('uiScale'),
		uiPosition = getSetting('uiPosition'),
		showTalkerList = getSetting('showTalkerList'),
		micClicks = getSetting('micClicks'),
		radioAnim = getSetting('radioAnim'),

		voiceMode = getUiVoiceModeIndex and getUiVoiceModeIndex() or (mode - 1),
		voiceModes = json.encode(Cfg.voiceModes),

		radioChannel = getRadioChannel and getRadioChannel() or 0,
		radioChannels = getRadioChannels and getRadioChannels() or {},
		radioEnabled = radioEnabled,
		radioTalkers = (getSetting('showTalkerList') and getRadioTalkers) and getRadioTalkers() or {},

		callInfo = getCallChannel and getCallChannel() or 0,

		usingMegaphone = isMegaphoneActive and isMegaphoneActive() or false,
		megaphoneEnabled = GetConvarInt('voice_enableMegaphone', 1) == 1,

		volumes = {
			radio = getSetting('radioVolume'),
			phone = getSetting('callVolume'),
			megaphone = getSetting('megaphoneVolume'),
		},

		blocked = getBlockedPlayers and getBlockedPlayers() or {},
	})
end

--- Opens or closes the settings panel, taking NUI focus with it.
--- @param open boolean
function setSettingsOpen(open)
	open = open == true
	if settingsOpen == open then return end

	settingsOpen = open
	setNuiFocus(open)

	if open then
		refreshUI()
	end

	sendUIMessage({ settingsOpen = open })
end
exports('setSettingsOpen', setSettingsOpen)

exports('isSettingsOpen', function()
	return settingsOpen
end)

RegisterCommand('voicesettings', function()
	setSettingsOpen(not settingsOpen)
end, false)

if gameVersion == 'fivem' then
	RegisterKeyMapping('voicesettings', 'Open Voice Settings', 'keyboard', GetConvar('voice_defaultSettingsKey', ''))
end

--#region NUI callbacks

RegisterNUICallback('closeSettings', function(_, cb)
	setSettingsOpen(false)
	cb('ok')
end)

RegisterNUICallback('setSetting', function(data, cb)
	local key, value = data.key, data.value

	if key == 'radioVolume' then
		setVolume(tonumber(value) or 0, 'radio')
	elseif key == 'callVolume' then
		setVolume(tonumber(value) or 0, 'phone')
	elseif key == 'megaphoneVolume' then
		setVolume(tonumber(value) or 0, 'megaphone')
	else
		setSetting(key, value)
	end

	refreshUI()
	cb('ok')
end)

RegisterNUICallback('resetSettings', function(_, cb)
	resetSettings()
	setVolume(getSetting('radioVolume'), 'radio')
	setVolume(getSetting('callVolume'), 'phone')
	setVolume(getSetting('megaphoneVolume'), 'megaphone')
	refreshUI()
	cb('ok')
end)

RegisterNUICallback('unblockPlayer', function(data, cb)
	local id = tonumber(data.id)
	if id and isPlayerBlocked(id) then
		toggleMutePlayer(id)
	end
	refreshUI()
	cb('ok')
end)

RegisterNUICallback('clearBlocked', function(_, cb)
	clearBlockedPlayers()
	refreshUI()
	cb('ok')
end)

RegisterNUICallback('leaveRadioChannel', function(data, cb)
	local channel = tonumber(data.channel)
	if channel then
		if channel == getRadioChannel() then
			setRadioChannel(0)
		else
			removeSecondaryRadioChannel(channel)
		end
	end
	cb('ok')
end)

--#endregion

-- Anything that changes how the overlay looks should push a fresh snapshot.
for _, key in ipairs({ 'uiEnabled', 'uiScale', 'uiPosition', 'showTalkerList', 'micClicks' }) do
	onSettingChanged(key, refreshUI)
end
