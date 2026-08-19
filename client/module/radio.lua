--[[
	Radio.

	A player has one *primary* channel — the one they transmit on — and any
	number of *secondary* channels they only monitor. Everything the client
	knows about a channel lives in `radioChannelData[channel]`.
]]

local primaryChannel = 0
local secondaryChannels = {}
local radioChannelData = {}
local radioNames = {}

--- Members of the channel we transmit on, or an empty table when we have none.
function getPrimaryRadioMembers()
	return radioChannelData[primaryChannel] or {}
end

--- The channel the player transmits on (0 when they're off the radio).
function getRadioChannel()
	return primaryChannel
end
exports('getRadioChannel', getRadioChannel)

--- Every channel the player is currently receiving, primary first.
function getRadioChannels()
	local channels = {}
	if primaryChannel ~= 0 then
		channels[#channels + 1] = primaryChannel
	end
	for channel in pairs(secondaryChannels) do
		channels[#channels + 1] = channel
	end
	table.sort(channels, function(a, b)
		if a == primaryChannel then return true end
		if b == primaryChannel then return false end
		return a < b
	end)
	return channels
end
exports('getRadioChannels', getRadioChannels)

--- True when the player is on `channel`, either as primary or secondary.
function isOnRadioChannel(channel)
	channel = tonumber(channel)
	return channel ~= nil and (channel == primaryChannel or secondaryChannels[channel] == true)
end
exports('isOnRadioChannel', isOnRadioChannel)

--- Everyone currently transmitting, as `{ { id, name, channel }, ... }`.
--- This is what the UI's talker list renders.
function getRadioTalkers()
	local talkers = {}
	for channel, members in pairs(radioChannelData) do
		for id, talking in pairs(members) do
			if talking and id ~= playerServerId then
				talkers[#talkers + 1] = {
					id = id,
					name = radioNames[id] or ('Player %s'):format(id),
					channel = channel,
				}
			end
		end
	end
	table.sort(talkers, function(a, b)
		if a.channel ~= b.channel then return a.channel < b.channel end
		return a.id < b.id
	end)
	return talkers
end
exports('getRadioTalkers', getRadioTalkers)

--- Pushes the current radio state at the UI.
function refreshRadioUI()
	sendUIMessage({
		radioChannel = primaryChannel,
		radioChannels = getRadioChannels(),
		radioEnabled = radioEnabled,
		radioTalkers = getSetting('showTalkerList') and getRadioTalkers() or {},
	})
end

--#region Networked state

--- Replaces the client's view of a channel wholesale. Sent when we join.
--- @param channel number
--- @param members table map of `[serverId] = isTalking`
--- @param names table map of `[serverId] = displayName`
local function syncRadioData(channel, members, names)
	logger.info('[radio] Syncing channel %s (%s members).', channel, tableCount(members))

	radioChannelData[channel] = members
	radioData = getPrimaryRadioMembers()

	if names then
		for id, name in pairs(names) do
			radioNames[id] = name
		end
	end

	if GetConvarInt('voice_debugMode', 0) >= 4 then
		print('-------- RADIO TABLE --------')
		tPrint(radioChannelData)
		print('-----------------------------')
	end

	for id, talking in pairs(members) do
		if id ~= playerServerId then
			toggleVoice(id, talking, 'radio')
		end
	end

	refreshRadioUI()
end
RegisterNetEvent('ivoice:syncRadioData', syncRadioData)

--- A member of one of our channels started or stopped transmitting.
local function setTalkingOnRadio(channel, plySource, enabled)
	local members = radioChannelData[channel]
	if not members then return end

	members[plySource] = enabled
	if channel == primaryChannel then
		radioData = members
	end

	toggleVoice(plySource, enabled, 'radio')
	playMicClicks(enabled)
	refreshRadioUI()
end
RegisterNetEvent('ivoice:setTalkingOnRadio', setTalkingOnRadio)

--- Someone joined a channel we're on.
local function addPlayerToRadio(channel, plySource, plyRadioName)
	radioChannelData[channel] = radioChannelData[channel] or {}
	radioChannelData[channel][plySource] = false

	if plyRadioName then
		radioNames[plySource] = plyRadioName
	end

	if channel == primaryChannel then
		radioData = radioChannelData[channel]
		if radioPressed then
			logger.info('[radio] %s joined radio %s while we were talking, adding them to targets', plySource, channel)
			refreshVoiceTargets()
		else
			logger.info('[radio] %s joined radio %s', plySource, channel)
		end
	end

	refreshRadioUI()
end
RegisterNetEvent('ivoice:addPlayerToRadio', addPlayerToRadio)

--- Someone left a channel we're on — or we left it ourselves.
local function removePlayerFromRadio(channel, plySource)
	local members = radioChannelData[channel]

	-- The server can reject a channel we already optimistically joined, in
	-- which case we never received its member table — still roll our own state
	-- back so we don't sit on a channel we aren't really on.
	if not members then
		if plySource == playerServerId then
			secondaryChannels[channel] = nil
			if channel == primaryChannel then
				primaryChannel = 0
				radioData = {}
			end
			refreshRadioUI()
		end
		return
	end

	if plySource == playerServerId then
		logger.info('[radio] Left radio %s, cleaning up.', channel)

		for id in pairs(members) do
			if id ~= playerServerId then
				-- only drop their audio if they aren't reachable on another
				-- channel we're still listening to
				local stillAudible = false
				for otherChannel, otherMembers in pairs(radioChannelData) do
					if otherChannel ~= channel and otherMembers[id] ~= nil then
						stillAudible = true
						break
					end
				end
				if not stillAudible then
					toggleVoice(id, false, 'radio')
				end
			end
		end

		radioChannelData[channel] = nil
		secondaryChannels[channel] = nil
		if channel == primaryChannel then
			primaryChannel = 0
			radioData = {}
		end

		-- names are cheap to re-sync and stale entries would leak, so rebuild
		local stillKnown = {}
		for _, otherMembers in pairs(radioChannelData) do
			for id in pairs(otherMembers) do
				stillKnown[id] = radioNames[id]
			end
		end
		radioNames = stillKnown

		refreshVoiceTargets()
	else
		members[plySource] = nil
		radioNames[plySource] = nil
		toggleVoice(plySource, false, 'radio')

		if channel == primaryChannel then
			radioData = members
			if radioPressed then
				logger.info('[radio] %s left radio %s while we were talking, updating targets.', plySource, channel)
				refreshVoiceTargets()
			else
				logger.info('[radio] %s has left radio %s', plySource, channel)
			end
		end
	end

	refreshRadioUI()
end
RegisterNetEvent('ivoice:removePlayerFromRadio', removePlayerFromRadio)

--- The server rejected or forcibly changed our channel membership.
RegisterNetEvent('ivoice:radioDenied', function(channel, reason)
	logger.warn('[radio] Channel %s refused: %s', channel, reason or 'no reason given')
	sendUIMessage({ notification = { kind = 'error', text = reason or ('Channel %s is unavailable.'):format(channel) } })
end)

--#endregion

--#region Channel control

--- Sets the channel the player transmits on.
--- @param channel number the channel to join, or 0 to leave the radio
function setRadioChannel(channel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	channel = tonumber(channel)
	type_check({ channel, 'number' })

	if channel == primaryChannel then return end

	-- moving the primary onto a channel we already monitor just promotes it
	secondaryChannels[channel] = nil

	TriggerServerEvent('ivoice:setPlayerRadio', channel)
	primaryChannel = channel
	radioData = getPrimaryRadioMembers()
	refreshRadioUI()
end
exports('setRadioChannel', setRadioChannel)
-- mumble-voip compatibility
exports('SetRadioChannel', setRadioChannel)

exports('removePlayerFromRadio', function()
	setRadioChannel(0)
end)

exports('addPlayerToRadio', function(_radio)
	local radio = tonumber(_radio)
	if radio then
		setRadioChannel(radio)
	end
end)

--- Starts monitoring an extra channel without transmitting on it.
--- @param channel number
function addSecondaryRadioChannel(channel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	channel = tonumber(channel)
	type_check({ channel, 'number' })

	if channel == 0 or channel == primaryChannel or secondaryChannels[channel] then return end

	local limit = GetConvarInt('voice_maxSecondaryChannels', 3)
	if tableCount(secondaryChannels) >= limit then
		return logger.warn('[radio] Refusing to monitor %s, already monitoring %s channels (voice_maxSecondaryChannels)', channel, limit)
	end

	secondaryChannels[channel] = true
	TriggerServerEvent('ivoice:addSecondaryRadio', channel)
	refreshRadioUI()
end
exports('addSecondaryRadioChannel', addSecondaryRadioChannel)

--- Stops monitoring an extra channel.
--- @param channel number
function removeSecondaryRadioChannel(channel)
	channel = tonumber(channel)
	type_check({ channel, 'number' })

	if not secondaryChannels[channel] then return end

	secondaryChannels[channel] = nil
	TriggerServerEvent('ivoice:removeSecondaryRadio', channel)
	refreshRadioUI()
end
exports('removeSecondaryRadioChannel', removeSecondaryRadioChannel)

--- Drops every channel, primary and secondary alike.
function leaveAllRadioChannels()
	for channel in pairs(secondaryChannels) do
		removeSecondaryRadioChannel(channel)
	end
	setRadioChannel(0)
end
exports('leaveAllRadioChannels', leaveAllRadioChannels)

--#endregion

--#region Radio animation

local disableRadioAnim = false

exports('toggleRadioAnim', function()
	disableRadioAnim = not disableRadioAnim
	TriggerEvent('ivoice:toggleRadioAnim', disableRadioAnim)
	return disableRadioAnim
end)

--- Whether the radio animation is currently suppressed.
exports('getRadioAnimState', function()
	return disableRadioAnim
end)

local function shouldPlayRadioAnim()
	if GetConvarInt('voice_enableRadioAnim', 0) ~= 1 then return false end
	if disableRadioAnim or not getSetting('radioAnim') then return false end
	if GetConvarInt('voice_disableVehicleRadioAnim', 0) == 1 and IsPedInAnyVehicle(PlayerPedId(), false) then
		return false
	end
	return true
end

local function playRadioAnim()
	RequestAnimDict('random@arrests')
	local deadline = GetGameTimer() + 2000
	while not HasAnimDictLoaded('random@arrests') do
		if GetGameTimer() > deadline then
			return logger.warn('[radio] Timed out loading the radio animation dictionary')
		end
		Citizen.Wait(10)
	end
	TaskPlayAnim(PlayerPedId(), 'random@arrests', 'generic_radio_enter', 8.0, 2.0, -1, 50, 2.0, false, false, false)
end

--#endregion

--- Checks whether the player is dead.
--- Kept separate so servers using their own death system can swap it out via
--- the `isDead` state bag: `LocalPlayer.state:set('isDead', true, false)`.
function isDead()
	if LocalPlayer.state.isDead then return true end
	return IsPlayerDead(PlayerId())
end

RegisterCommand('+radiotalk', function()
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	if radioPressed or not radioEnabled or primaryChannel <= 0 then return end
	if isDead() then return end

	logger.info('[radio] Start broadcasting, update targets and notify server.')
	radioPressed = true
	refreshVoiceTargets()
	TriggerServerEvent('ivoice:setTalkingOnRadio', true)
	playMicClicks(true)

	if shouldPlayRadioAnim() then
		playRadioAnim()
	end

	Citizen.CreateThread(function()
		TriggerEvent('ivoice:radioActive', true)
		while radioPressed do
			Wait(0)
			SetControlNormal(0, 249, 1.0)
			SetControlNormal(1, 249, 1.0)
			SetControlNormal(2, 249, 1.0)
		end
	end)
end, false)

RegisterCommand('-radiotalk', function()
	if not radioPressed then return end

	radioPressed = false
	refreshVoiceTargets()
	TriggerEvent('ivoice:radioActive', false)
	playMicClicks(false)

	if GetConvarInt('voice_enableRadioAnim', 0) == 1 then
		StopAnimTask(PlayerPedId(), 'random@arrests', 'generic_radio_enter', -4.0)
	end

	TriggerServerEvent('ivoice:setTalkingOnRadio', false)
end, false)

if gameVersion == 'fivem' then
	RegisterKeyMapping('+radiotalk', 'Talk over Radio', 'keyboard', GetConvar('voice_defaultRadio', 'LMENU'))
end

--- The server moved us; mirror it locally without echoing back.
RegisterNetEvent('ivoice:clSetPlayerRadio', function(_radioChannel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	logger.info('[radio] radio set serverside, update to radio %s', _radioChannel)
	primaryChannel = _radioChannel
	secondaryChannels[_radioChannel] = nil
	radioData = getPrimaryRadioMembers()
	refreshRadioUI()
end)

onSettingChanged('showTalkerList', refreshRadioUI)
