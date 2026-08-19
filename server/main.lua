--[[
	I-Voice server runtime.
]]

voiceData = {}
radioData = {}
callData = {}
megaphoneData = {}

--- Builds the default per-player record and seeds their state bags.
function defaultTable(source)
	handleStateBagInitilization(source)
	return {
		radio = 0,
		secondaryRadios = {},
		call = 0,
		megaphone = false,
		lastRadio = 0,
		lastCall = 0,
	}
end

--- Fetches (creating if needed) the voice record for a player.
function getVoiceData(source)
	voiceData[source] = voiceData[source] or defaultTable(source)
	return voiceData[source]
end

function handleStateBagInitilization(source)
	local plyState = Player(source).state
	if plyState.voiceInit then return end

	plyState:set('radio', GetConvarInt('voice_defaultRadioVolume', 30), true)
	plyState:set('phone', GetConvarInt('voice_defaultPhoneVolume', 60), true)
	plyState:set('megaphone', GetConvarInt('voice_defaultMegaphoneVolume', 80), true)
	plyState:set('proximity', {}, true)
	plyState:set('callChannel', 0, true)
	plyState:set('radioChannel', 0, true)
	plyState:set('secondaryRadioChannels', {}, true)
	plyState:set('megaphoneActive', false, true)
	plyState:set('voiceIntent', 'speech', true)
	-- We want to save voice inits because we'll automatically reinitialize
	-- calls and channels.
	plyState:set('voiceInit', true, false)
	-- kept for resources still reading the pma-voice flag
	plyState:set('pmaVoiceInit', true, false)
end

Citizen.CreateThread(function()
	local plyTbl = GetPlayers()
	for i = 1, #plyTbl do
		local ply = tonumber(plyTbl[i])
		voiceData[ply] = defaultTable(ply)
	end

	Wait(5000)

	local nativeAudio = GetConvar('voice_useNativeAudio', 'false')
	local _3dAudio = GetConvar('voice_use3dAudio', 'false')
	local _2dAudio = GetConvar('voice_use2dAudio', 'false')
	local sendingRangeOnly = GetConvar('voice_useSendingRangeOnly', 'false')
	local game = GetConvar('gamename', 'fivem')

	-- handle no convars being set (default drag n' drop)
	if nativeAudio == 'false' and _3dAudio == 'false' and _2dAudio == 'false' then
		if game == 'fivem' then
			SetConvarReplicated('voice_useNativeAudio', 'true')
			if sendingRangeOnly == 'false' then
				SetConvarReplicated('voice_useSendingRangeOnly', 'true')
			end
			logger.info("No convars detected for voice mode, defaulting to 'setr voice_useNativeAudio true' and 'setr voice_useSendingRangeOnly true'")
		else
			SetConvarReplicated('voice_use3dAudio', 'true')
			if sendingRangeOnly == 'false' then
				SetConvarReplicated('voice_useSendingRangeOnly', 'true')
			end
			logger.info("No convars detected for voice mode, defaulting to 'setr voice_use3dAudio true' and 'setr voice_useSendingRangeOnly true'")
		end
	elseif sendingRangeOnly == 'false' then
		logger.warn("It's recommended to have 'voice_useSendingRangeOnly' set to true, you can do that with 'setr voice_useSendingRangeOnly true'. This prevents players who directly join the mumble server from broadcasting to players.")
	end

	if game == 'rdr3' then
		if nativeAudio == 'true' then
			logger.warn("RedM doesn't currently support native audio, automatically switching to 3d audio. This also means that submixes will not work.")
			SetConvarReplicated('voice_useNativeAudio', 'false')
			SetConvarReplicated('voice_use3dAudio', 'true')
		end
	end

	local radioVolume = GetConvarInt('voice_defaultRadioVolume', 30)
	local phoneVolume = GetConvarInt('voice_defaultPhoneVolume', 60)

	-- When cast to an integer these get set to 0 or 1, so warn that a float
	-- value doesn't work.
	if radioVolume <= 1 or phoneVolume <= 1 then
		SetConvarReplicated('voice_defaultRadioVolume', '30')
		SetConvarReplicated('voice_defaultPhoneVolume', '60')
		for _ = 1, 5 do
			Wait(5000)
			logger.warn('`voice_defaultRadioVolume` or `voice_defaultPhoneVolume` have their value set as a float, this is going to automatically be fixed but please update your convars.')
		end
	end
end)

AddEventHandler('playerJoining', function()
	local source = source
	if not voiceData[source] then
		voiceData[source] = defaultTable(source)
	end
end)

AddEventHandler('playerDropped', function()
	local source = source
	local plyData = voiceData[source]
	if not plyData then return end

	if plyData.radio ~= 0 then
		removePlayerFromRadio(source, plyData.radio)
	end

	for channel in pairs(plyData.secondaryRadios) do
		removePlayerFromRadio(source, channel)
	end

	if plyData.call ~= 0 then
		removePlayerFromCall(source, plyData.call)
	end

	if plyData.megaphone then
		setMegaphoneState(source, false)
	end

	voiceData[source] = nil
end)

--- A client reconnecting to Mumble loses every listen channel, so it asks us
--- to replay whatever state it should be holding.
RegisterNetEvent('ivoice:requestSync', function()
	local source = source
	local plyData = getVoiceData(source)

	TriggerClientEvent('ivoice:syncMegaphones', source, megaphoneData)

	if plyData.radio ~= 0 and radioData[plyData.radio] then
		TriggerClientEvent('ivoice:syncRadioData', source, plyData.radio, radioData[plyData.radio], getRadioNames(plyData.radio))
	end

	for channel in pairs(plyData.secondaryRadios) do
		if radioData[channel] then
			TriggerClientEvent('ivoice:syncRadioData', source, channel, radioData[channel], getRadioNames(channel))
		end
	end

	if plyData.call ~= 0 and callData[plyData.call] then
		TriggerClientEvent('ivoice:syncCallData', source, callData[plyData.call])
	end
end)

if GetConvarInt('voice_externalDisallowJoin', 0) == 1 then
	AddEventHandler('playerConnecting', function(_, _, deferral)
		deferral.defer()
		Wait(0)
		deferral.done('This server is not accepting connections.')
	end)
end

--- Internal helper: is this a player we're tracking?
function isValidPlayer(source)
	return voiceData[source] ~= nil
end
exports('isValidPlayer', isValidPlayer)

--- Everyone on a radio channel, as `{ [serverId] = isTalking }`.
function getPlayersInRadioChannel(channel)
	return radioData[tonumber(channel) or 0] or {}
end
exports('getPlayersInRadioChannel', getPlayersInRadioChannel)
exports('GetPlayersInRadioChannel', getPlayersInRadioChannel)

--- Everyone on a call channel, as `{ [serverId] = isTalking }`.
function getPlayersInCall(channel)
	return callData[tonumber(channel) or 0] or {}
end
exports('getPlayersInCall', getPlayersInCall)

--- A summary of a channel: how many players are on it, who is transmitting and
--- who is only monitoring.
function getRadioChannelInfo(channel)
	channel = tonumber(channel) or 0
	local members = radioData[channel]
	if not members then
		return { channel = channel, count = 0, members = {}, talking = {}, monitoring = {} }
	end

	local info = { channel = channel, count = 0, members = {}, talking = {}, monitoring = {} }
	for id, isTalking in pairs(members) do
		info.count = info.count + 1
		info.members[#info.members + 1] = id
		if isTalking then
			info.talking[#info.talking + 1] = id
		end
		local plyData = voiceData[id]
		if plyData and plyData.radio ~= channel then
			info.monitoring[#info.monitoring + 1] = id
		end
	end

	table.sort(info.members)
	return info
end
exports('getRadioChannelInfo', getRadioChannelInfo)

--- Every radio channel that currently has someone on it.
exports('getActiveRadioChannels', function()
	local channels = {}
	for channel, members in pairs(radioData) do
		if next(members) then
			channels[#channels + 1] = channel
		end
	end
	table.sort(channels)
	return channels
end)
