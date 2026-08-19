--[[
	Server side radio.

	Membership of a channel is stored once, in `radioData[channel]`. Whether a
	player *transmits* on that channel is decided by `voiceData[src].radio`;
	everything else in `voiceData[src].secondaryRadios` is receive only.
]]

local radioChecks = {}
local channelLimits = {}

--#region Access control

--- Checks whether a player is allowed onto a channel.
--- @param source number
--- @param radioChannel number
--- @return boolean allowed
--- @return string|nil reason
function canJoinChannel(source, radioChannel)
	local limit = channelLimits[radioChannel]
	if limit and tableCount(radioData[radioChannel] or {}) >= limit then
		return false, ('Channel %s is full.'):format(radioChannel)
	end

	local check = radioChecks[radioChannel]
	if check then
		local ok, result = pcall(check, source, radioChannel)
		if not ok then
			logger.warn('Channel check for %s errored, denying access: %s', radioChannel, result)
			return false, 'Channel check failed.'
		end
		if not result then
			return false, ('You do not have access to channel %s.'):format(radioChannel)
		end
	end

	return true
end

--- Adds a check to a channel. The callback receives `(source, channel)` and is
--- expected to return a boolean.
--- @param channel number
--- @param cb function
function addChannelCheck(channel, cb)
	type_check({ channel, 'number' })
	if not isFunctionRef(cb) and type(cb) ~= 'function' then
		error(("'cb' expected 'function' got '%s'"):format(type(cb)))
	end

	radioChecks[channel] = cb
	logger.info('%s added a check to channel %s', GetInvokingResource() or 'I-Voice', channel)
end
exports('addChannelCheck', addChannelCheck)

--- Removes a previously registered channel check.
--- @param channel number
exports('removeChannelCheck', function(channel)
	radioChecks[tonumber(channel) or 0] = nil
end)

--- Caps how many players may sit on a channel at once.
--- @param channel number
--- @param limit number|nil the cap, or nil to remove it
exports('setChannelLimit', function(channel, limit)
	channel = tonumber(channel)
	type_check({ channel, 'number' })
	channelLimits[channel] = tonumber(limit)
	logger.info('%s set the member limit of channel %s to %s', GetInvokingResource() or 'I-Voice', channel, tostring(limit))
end)

--#endregion

--#region Display names

local function radioNameGetter_orig(source)
	return GetPlayerName(source)
end

local radioNameGetter = radioNameGetter_orig

--- Overrides how a player's radio display name is resolved.
--- @param cb function receives `(source)` and returns a string
function overrideRadioNameGetter(cb)
	if not isFunctionRef(cb) and type(cb) ~= 'function' then
		error(("'cb' expected 'function' got '%s'"):format(type(cb)))
	end
	radioNameGetter = cb
	logger.info('%s overrode the radio name getter', GetInvokingResource() or 'I-Voice')
end
exports('overrideRadioNameGetter', overrideRadioNameGetter)

exports('resetRadioNameGetter', function()
	radioNameGetter = radioNameGetter_orig
end)

local function getRadioName(source)
	local ok, name = pcall(radioNameGetter, source)
	if not ok or type(name) ~= 'string' then
		return GetPlayerName(source) or ('Player %s'):format(source)
	end
	return name
end

--- Display names for everyone on a channel, keyed by server id.
--- Returns an empty table when name syncing is switched off.
function getRadioNames(channel)
	if GetConvarInt('voice_syncPlayerNames', 0) ~= 1 then return {} end

	local names = {}
	for id in pairs(radioData[channel] or {}) do
		names[id] = getRadioName(id)
	end
	return names
end

--#endregion

--#region Membership

--- Puts a player onto a channel and tells everyone already on it.
--- @param source number
--- @param radioChannel number
--- @param isSecondary boolean whether this is a monitor-only channel
--- @return boolean whether the player was added
function addPlayerToRadio(source, radioChannel, isSecondary)
	local allowed, reason = canJoinChannel(source, radioChannel)
	if not allowed then
		logger.info('[radio] Denied %s access to radio %s (%s)', source, radioChannel, reason)
		TriggerClientEvent('ivoice:radioDenied', source, radioChannel, reason)
		TriggerClientEvent('ivoice:removePlayerFromRadio', source, radioChannel, source)
		return false
	end

	logger.verbose('[radio] Added %s to radio %s (%s)', source, radioChannel, isSecondary and 'monitor' or 'primary')

	radioData[radioChannel] = radioData[radioChannel] or {}

	local plyName = GetConvarInt('voice_syncPlayerNames', 0) == 1 and getRadioName(source) or nil
	for player in pairs(radioData[radioChannel]) do
		if player ~= source then
			TriggerClientEvent('ivoice:addPlayerToRadio', player, radioChannel, source, plyName)
		end
	end

	local plyData = getVoiceData(source)
	radioData[radioChannel][source] = false

	if isSecondary then
		plyData.secondaryRadios[radioChannel] = true
		Player(source).state:set('secondaryRadioChannels', getSecondaryChannelList(plyData), true)
	else
		plyData.radio = radioChannel
		plyData.lastRadio = radioChannel
	end

	TriggerClientEvent('ivoice:syncRadioData', source, radioChannel, radioData[radioChannel], getRadioNames(radioChannel))
	TriggerEvent('ivoice:playerJoinedRadio', source, radioChannel, isSecondary == true)

	return true
end

--- Removes a player from a channel and tells everyone who was on it.
--- @param source number
--- @param radioChannel number
function removePlayerFromRadio(source, radioChannel)
	if radioChannel == 0 then return end

	logger.verbose('[radio] Removed %s from radio %s', source, radioChannel)

	local members = radioData[radioChannel]
	if members then
		for player in pairs(members) do
			TriggerClientEvent('ivoice:removePlayerFromRadio', player, radioChannel, source)
		end
		members[source] = nil

		-- don't keep empty channels around forever
		if next(members) == nil then
			radioData[radioChannel] = nil
		end
	else
		TriggerClientEvent('ivoice:removePlayerFromRadio', source, radioChannel, source)
	end

	local plyData = getVoiceData(source)
	if plyData.radio == radioChannel then
		plyData.radio = 0
	end
	if plyData.secondaryRadios[radioChannel] then
		plyData.secondaryRadios[radioChannel] = nil
		Player(source).state:set('secondaryRadioChannels', getSecondaryChannelList(plyData), true)
	end

	TriggerEvent('ivoice:playerLeftRadio', source, radioChannel)
end

--- The monitor-only channels of a player, as a sorted list.
function getSecondaryChannelList(plyData)
	local channels = {}
	for channel in pairs(plyData.secondaryRadios) do
		channels[#channels + 1] = channel
	end
	table.sort(channels)
	return channels
end

--#endregion

--#region Channel control

--- Sets the channel a player transmits on.
--- @param source number
--- @param _radioChannel number the channel, or 0 to take them off the radio
function setPlayerRadio(source, _radioChannel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end

	local plyData = getVoiceData(source)
	local isResource = GetInvokingResource()
	local radioChannel = tonumber(_radioChannel)

	if not radioChannel then
		if isResource then
			error(("'radioChannel' expected 'number', got: %s"):format(type(_radioChannel)))
		end
		return logger.warn("%s sent an invalid radio, 'radioChannel' expected 'number', got: %s", source, type(_radioChannel))
	end

	if isResource then
		-- set through an export, so the client needs telling that its radio
		-- changed underneath it
		TriggerClientEvent('ivoice:clSetPlayerRadio', source, radioChannel)
	end

	-- promoting a monitored channel to primary shouldn't re-join it
	if plyData.secondaryRadios[radioChannel] then
		plyData.secondaryRadios[radioChannel] = nil
		Player(source).state:set('secondaryRadioChannels', getSecondaryChannelList(plyData), true)
	end

	local previous = plyData.radio
	if previous == radioChannel then return end

	if previous ~= 0 then
		removePlayerFromRadio(source, previous)
	end

	if radioChannel ~= 0 then
		if not addPlayerToRadio(source, radioChannel, false) then
			Player(source).state.radioChannel = 0
			return
		end
	end

	Player(source).state.radioChannel = plyData.radio
end
exports('setPlayerRadio', setPlayerRadio)

--- Adds a monitor-only channel for a player.
function addPlayerSecondaryRadio(source, _channel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end

	local channel = tonumber(_channel)
	if not channel or channel == 0 then return end

	local plyData = getVoiceData(source)
	if plyData.radio == channel or plyData.secondaryRadios[channel] then return end

	local limit = GetConvarInt('voice_maxSecondaryChannels', 3)
	if tableCount(plyData.secondaryRadios) >= limit then
		return TriggerClientEvent('ivoice:radioDenied', source, channel, ('You can only monitor %s extra channels.'):format(limit))
	end

	addPlayerToRadio(source, channel, true)
end
exports('addPlayerSecondaryRadio', addPlayerSecondaryRadio)

--- Removes a monitor-only channel for a player.
function removePlayerSecondaryRadio(source, _channel)
	local channel = tonumber(_channel)
	if not channel then return end

	local plyData = getVoiceData(source)
	if not plyData.secondaryRadios[channel] then return end

	removePlayerFromRadio(source, channel)
end
exports('removePlayerSecondaryRadio', removePlayerSecondaryRadio)

RegisterNetEvent('ivoice:setPlayerRadio', function(radioChannel)
	setPlayerRadio(source, radioChannel)
end)

RegisterNetEvent('ivoice:addSecondaryRadio', function(channel)
	addPlayerSecondaryRadio(source, channel)
end)

RegisterNetEvent('ivoice:removeSecondaryRadio', function(channel)
	removePlayerSecondaryRadio(source, channel)
end)

-- pma-voice compatibility for resources still triggering the old net events
RegisterNetEvent('pma-voice:setPlayerRadio', function(radioChannel)
	setPlayerRadio(source, radioChannel)
end)

--#endregion

--- Broadcasts a player's transmit state to their channel.
--- Only the primary channel carries voice, so monitors never key up.
--- @param talking boolean
function setTalkingOnRadio(talking)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end

	local source = source
	local plyData = getVoiceData(source)
	local channel = plyData.radio
	local radioTbl = radioData[channel]
	if not radioTbl then return end

	talking = talking == true
	radioTbl[source] = talking
	logger.verbose('[radio] Set %s to talking: %s on radio %s', source, talking, channel)

	for player in pairs(radioTbl) do
		if player ~= source then
			TriggerClientEvent('ivoice:setTalkingOnRadio', player, channel, source, talking)
			logger.verbose('[radio] Sync %s to let them know %s is %s', player, source, talking and 'talking' or 'not talking')
		end
	end

	TriggerEvent('ivoice:playerRadioTalking', source, channel, talking)
end
RegisterNetEvent('ivoice:setTalkingOnRadio', setTalkingOnRadio)

AddEventHandler('onResourceStop', function(resource)
	for channel, cfxFunctionRef in pairs(radioChecks) do
		if isFunctionRef(cfxFunctionRef) and string.match(cfxFunctionRef.__cfx_functionReference, resource) then
			radioChecks[channel] = nil
			logger.warn('Channel %s had its radio check removed because the resource that provided it stopped', channel)
		end
	end

	if isFunctionRef(radioNameGetter) and string.match(radioNameGetter.__cfx_functionReference, resource) then
		radioNameGetter = radioNameGetter_orig
		logger.warn('Radio name getter reset to default because the resource that provided it stopped')
	end
end)
