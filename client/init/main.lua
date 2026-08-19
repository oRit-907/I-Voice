--[[
	Core client runtime: volume handling, audio submixes, voice targets and the
	local block list.
]]

--- Players the local client has silenced. Keyed by server id.
local mutedPlayers = {}

--- Live volume table, seeded from the persisted settings. Values are 0-1
--- floats because that's what Mumble's volume override expects.
local volumes = {
	radio = clamp(getSetting('radioVolume'), 0, 100) / 100,
	phone = clamp(getSetting('callVolume'), 0, 100) / 100,
	megaphone = clamp(getSetting('megaphoneVolume'), 0, 100) / 100,
}

--- Maps a volume bucket back onto the setting that persists it.
local volumeSettingKeys = {
	radio = 'radioVolume',
	phone = 'callVolume',
	megaphone = 'megaphoneVolume',
}

radioEnabled, radioPressed, mode = true, false, GetConvarInt('voice_defaultVoiceMode', 2)
radioData = {}
callData = {}

--- Clamp the configured starting mode so a bad convar can't crash proximity.
if mode < 1 or mode > #Cfg.voiceModes then
	logger.warn('voice_defaultVoiceMode was out of range (%s), falling back to %s', mode, 2)
	mode = 2
end

--#region Volume

--- Sets the volume of one (or every) voice bucket.
--- @param volume number between 0 and 100
--- @param volumeType string|nil 'radio', 'phone' or 'megaphone'; all buckets when omitted
function setVolume(volume, volumeType)
	type_check({ volume, 'number' })
	volume = clamp(volume, 0, 100)
	local normalised = volume / 100

	-- The state bag carries the 0-100 value the convars and the UI use; the
	-- local table keeps the 0-1 float Mumble's volume override expects.
	if volumeType then
		if volumes[volumeType] == nil then
			return logger.warn('setVolume got an invalid volume type "%s"', tostring(volumeType))
		end
		volumes[volumeType] = normalised
		LocalPlayer.state:set(volumeType, volume, true)
		setSetting(volumeSettingKeys[volumeType], volume)
	else
		for bucket in pairs(volumes) do
			volumes[bucket] = normalised
			LocalPlayer.state:set(bucket, volume, true)
			setSetting(volumeSettingKeys[bucket], volume)
		end
	end

	refreshUI()
end

--- Returns the 0-1 volume of a bucket.
function getVolume(volumeType)
	return volumes[volumeType]
end

exports('setRadioVolume', function(vol) setVolume(tonumber(vol) or 0, 'radio') end)
exports('getRadioVolume', function() return volumes.radio end)
exports('setCallVolume', function(vol) setVolume(tonumber(vol) or 0, 'phone') end)
exports('getCallVolume', function() return volumes.phone end)
exports('setMegaphoneVolume', function(vol) setVolume(tonumber(vol) or 0, 'megaphone') end)
exports('getMegaphoneVolume', function() return volumes.megaphone end)

--#endregion

--#region Submixes

-- default submix incase people want to fiddle with it.
-- freq_low = 389.0
-- freq_hi = 3248.0
-- fudge = 0.0
-- rm_mod_freq = 0.0
-- rm_mix = 0.16
-- o_freq_lo = 348.0
-- o_freq_hi = 4900.0

if gameVersion == 'fivem' then
	radioEffectId = CreateAudioSubmix('Radio')
	SetAudioSubmixEffectRadioFx(radioEffectId, 0)
	SetAudioSubmixEffectParamInt(radioEffectId, 0, `default`, 1)
	AddAudioSubmixOutput(radioEffectId, 0)

	phoneEffectId = CreateAudioSubmix('Phone')
	SetAudioSubmixEffectRadioFx(phoneEffectId, 1)
	SetAudioSubmixEffectParamInt(phoneEffectId, 1, `default`, 1)
	SetAudioSubmixEffectParamFloat(phoneEffectId, 1, `freq_low`, 300.0)
	SetAudioSubmixEffectParamFloat(phoneEffectId, 1, `freq_hi`, 6000.0)
	AddAudioSubmixOutput(phoneEffectId, 1)

	-- Megaphones get a narrow, slightly distorted band so they cut through
	-- ambient noise the way a real PA horn does.
	megaphoneEffectId = CreateAudioSubmix('Megaphone')
	SetAudioSubmixEffectRadioFx(megaphoneEffectId, 2)
	SetAudioSubmixEffectParamInt(megaphoneEffectId, 2, `default`, 1)
	SetAudioSubmixEffectParamFloat(megaphoneEffectId, 2, `freq_low`, 450.0)
	SetAudioSubmixEffectParamFloat(megaphoneEffectId, 2, `freq_hi`, 3500.0)
	SetAudioSubmixEffectParamFloat(megaphoneEffectId, 2, `rm_mix`, 0.24)
	AddAudioSubmixOutput(megaphoneEffectId, 2)
end

local submixFunctions = {
	radio = function(plySource) MumbleSetSubmixForServerId(plySource, radioEffectId) end,
	phone = function(plySource) MumbleSetSubmixForServerId(plySource, phoneEffectId) end,
	megaphone = function(plySource) MumbleSetSubmixForServerId(plySource, megaphoneEffectId) end,
}

local function submixesEnabled()
	return GetConvarInt('voice_enableSubmix', 1) == 1 and gameVersion == 'fivem'
end

--#endregion

--#region Voice routing

-- used to prevent a race condition if they talk again afterwards, which would
-- lead to their voice going back to default mid sentence.
local disableSubmixReset = {}

--- Toggles a remote player's voice between the proximity default and one of the
--- dedicated buckets (radio / phone / megaphone).
--- @param plySource number the player's server id
--- @param enabled boolean whether the player is starting or stopping
--- @param moduleType string|nil which volume & submix to apply
function toggleVoice(plySource, enabled, moduleType)
	if mutedPlayers[plySource] then return end
	logger.verbose('[main] Updating %s to talking: %s with submix %s', plySource, enabled, moduleType)

	if enabled then
		MumbleSetVolumeOverrideByServerId(plySource, volumes[moduleType] or -1.0)
		if submixesEnabled() then
			if moduleType and submixFunctions[moduleType] then
				disableSubmixReset[plySource] = true
				submixFunctions[moduleType](plySource)
			else
				MumbleSetSubmixForServerId(plySource, -1)
			end
		end
	else
		if submixesEnabled() then
			disableSubmixReset[plySource] = nil
			SetTimeout(250, function()
				if not disableSubmixReset[plySource] then
					MumbleSetSubmixForServerId(plySource, -1)
				end
			end)
		end
		MumbleSetVolumeOverrideByServerId(plySource, -1.0)
	end
end

--- Adds players' voices to the local player's target list, letting them
--- communicate at long range and ignoring proximity entirely.
--- @vararg table maps of `[serverId] = any` to add as targets
function playerTargets(...)
	local targets = { ... }
	local addedPlayers = { [playerServerId] = true }

	for i = 1, #targets do
		local target = targets[i]
		if target then
			for id in pairs(target) do
				if not addedPlayers[id] then
					logger.verbose('[main] Adding %s as a voice target', id)
					addedPlayers[id] = true
					MumbleAddVoiceTargetPlayerByServerId(voiceTarget, id)
				end
			end
		end
	end
end

--- True while the local player's mic is open.
--- `MumbleIsPlayerTalking` returns an int on some game builds and a boolean on
--- others, and `0` is truthy in Lua, so normalise both shapes here.
function isLocalPlayerTalking()
	local talking = MumbleIsPlayerTalking(PlayerId())
	return talking == true or talking == 1
end

--- Rebuilds the target list from whatever the player is currently using.
--- Called any time membership of a channel the player transmits on changes.
function refreshVoiceTargets()
	MumbleClearVoiceTargetPlayers(voiceTarget)
	playerTargets(
		radioPressed and getPrimaryRadioMembers() or nil,
		isLocalPlayerTalking() and callData or nil
	)
end

--#endregion

--#region Mic clicks

--- Plays the radio click if the player has them enabled.
--- @param clickType boolean true for the 'on' click, false for 'off'
function playMicClicks(clickType)
	if not getSetting('micClicks') then
		return logger.verbose('Not playing mic clicks because the client has them disabled')
	end
	sendUIMessage({
		sound = clickType and 'audio_on' or 'audio_off',
		volume = clickType and volumes.radio or 0.05,
	})
end

--#endregion

--#region Blocking

--- Silences (or unsilences) a single player for the local client only.
--- @param source number the player's server id
--- @return boolean whether the player is now blocked
function toggleMutePlayer(source)
	source = tonumber(source)
	if not source then return false end

	if mutedPlayers[source] then
		mutedPlayers[source] = nil
		MumbleSetVolumeOverrideByServerId(source, -1.0)
		logger.info('[block] Unblocked %s', source)
		return false
	end

	mutedPlayers[source] = true
	MumbleSetVolumeOverrideByServerId(source, 0.0)
	logger.info('[block] Blocked %s', source)
	return true
end
exports('toggleMutePlayer', toggleMutePlayer)

--- True when the local client has the given player blocked.
function isPlayerBlocked(source)
	return mutedPlayers[tonumber(source)] == true
end
exports('isPlayerBlocked', isPlayerBlocked)

--- Every player the local client has blocked, as a list of server ids.
function getBlockedPlayers()
	local blocked = {}
	for id in pairs(mutedPlayers) do
		blocked[#blocked + 1] = id
	end
	table.sort(blocked)
	return blocked
end
exports('getBlockedPlayers', getBlockedPlayers)

--- Lifts every block at once.
function clearBlockedPlayers()
	for id in pairs(mutedPlayers) do
		MumbleSetVolumeOverrideByServerId(id, -1.0)
	end
	mutedPlayers = {}
end
exports('clearBlockedPlayers', clearBlockedPlayers)

-- A blocked player who leaves is no longer interesting; drop them so the id
-- can't leak onto whoever reuses it.
RegisterNetEvent('onPlayerDropped', function(serverId)
	mutedPlayers[tonumber(serverId)] = nil
end)

--#endregion

--#region Voice properties

--- Sets a voice property.
--- @param type string 'radioEnabled' or 'micClicks'
--- @param value any the value to set the property to
function setVoiceProperty(type, value)
	if type == 'radioEnabled' then
		radioEnabled = value == true
		refreshUI()
	elseif type == 'micClicks' then
		setSetting('micClicks', value)
	else
		logger.warn('setVoiceProperty got an unknown property "%s"', tostring(type))
	end
end
exports('setVoiceProperty', setVoiceProperty)
-- compatibility with mumble-voip / TokoVOIP
exports('SetMumbleProperty', setVoiceProperty)
exports('SetTokoProperty', setVoiceProperty)

--#endregion

-- cache their external servers so if it changes at runtime we can reconnect the client.
local externalAddress = ''
local externalPort = 0
CreateThread(function()
	while true do
		Wait(500)
		local address = GetConvar('voice_externalAddress', '')
		local port = GetConvarInt('voice_externalPort', 0)
		if address ~= externalAddress or port ~= externalPort then
			externalAddress = address
			externalPort = port
			MumbleSetServerAddress(address, port)
		end
	end
end)

if gameVersion == 'redm' then
	CreateThread(function()
		while true do
			if IsControlJustPressed(0, 0xA5BDCD3C --[[ Right Bracket ]]) then
				ExecuteCommand('cycleproximity')
			end
			if IsControlJustPressed(0, 0x430593AA --[[ Left Bracket ]]) then
				ExecuteCommand('+radiotalk')
			elseif IsControlJustReleased(0, 0x430593AA --[[ Left Bracket ]]) then
				ExecuteCommand('-radiotalk')
			end
			Wait(0)
		end
	end)
end

-- Keep the live volume table in step with settings changed from the UI.
onSettingChanged('radioVolume', function(value) volumes.radio = value / 100 end)
onSettingChanged('callVolume', function(value) volumes.phone = value / 100 end)
onSettingChanged('megaphoneVolume', function(value) volumes.megaphone = value / 100 end)
