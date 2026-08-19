--[[
	Server side phone calls.
]]

--- Removes a player from a call and tells everyone else on it.
--- @param source number
--- @param callChannel number
function removePlayerFromCall(source, callChannel)
	if callChannel == 0 then return end

	logger.verbose('[phone] Removed %s from call %s', source, callChannel)

	local members = callData[callChannel]
	if members then
		for player in pairs(members) do
			TriggerClientEvent('ivoice:removePlayerFromCall', player, source)
		end
		members[source] = nil

		if next(members) == nil then
			callData[callChannel] = nil
		end
	else
		TriggerClientEvent('ivoice:removePlayerFromCall', source, source)
	end

	local plyData = getVoiceData(source)
	if plyData.call == callChannel then
		plyData.call = 0
	end

	TriggerEvent('ivoice:playerLeftCall', source, callChannel)
end

--- Adds a player to a call.
--- @param source number
--- @param callChannel number
function addPlayerToCall(source, callChannel)
	logger.verbose('[phone] Added %s to call %s', source, callChannel)

	callData[callChannel] = callData[callChannel] or {}

	for player in pairs(callData[callChannel]) do
		-- the source is about to get a full sync, so skip them
		if player ~= source then
			TriggerClientEvent('ivoice:addPlayerToCall', player, source)
		end
	end

	callData[callChannel][source] = false

	local plyData = getVoiceData(source)
	plyData.call = callChannel
	plyData.lastCall = callChannel

	TriggerClientEvent('ivoice:syncCallData', source, callData[callChannel])
	TriggerEvent('ivoice:playerJoinedCall', source, callChannel)
end

--- Sets a player's call channel.
--- @param source number
--- @param _callChannel number the channel, or 0 to hang up
function setPlayerCall(source, _callChannel)
	if GetConvarInt('voice_enablePhones', 1) ~= 1 then return end

	local plyData = getVoiceData(source)
	local isResource = GetInvokingResource()
	local callChannel = tonumber(_callChannel)

	if not callChannel then
		if isResource then
			error(("'callChannel' expected 'number', got: %s"):format(type(_callChannel)))
		end
		return logger.warn("%s sent an invalid call, 'callChannel' expected 'number', got: %s", source, type(_callChannel))
	end

	if isResource then
		TriggerClientEvent('ivoice:clSetPlayerCall', source, callChannel)
	end

	local previous = plyData.call
	if previous == callChannel then return end

	if previous ~= 0 then
		removePlayerFromCall(source, previous)
	end

	if callChannel ~= 0 then
		addPlayerToCall(source, callChannel)
	end

	Player(source).state.callChannel = plyData.call
end
exports('setPlayerCall', setPlayerCall)

RegisterNetEvent('ivoice:setPlayerCall', function(callChannel)
	setPlayerCall(source, callChannel)
end)


--- Broadcasts a player's transmit state to the rest of their call.
function setTalkingOnCall(talking)
	if GetConvarInt('voice_enablePhones', 1) ~= 1 then return end

	local source = source
	local plyData = getVoiceData(source)
	local callTbl = callData[plyData.call]

	if not callTbl then
		return logger.verbose('[phone] %s tried to talk in call %s, but it doesnt exist.', source, plyData.call)
	end

	talking = talking == true
	callTbl[source] = talking
	logger.verbose('[phone] %s %s talking in call %s', source, talking and 'started' or 'stopped', plyData.call)

	for player in pairs(callTbl) do
		if player ~= source then
			TriggerClientEvent('ivoice:setTalkingOnCall', player, source, talking)
		end
	end
end
RegisterNetEvent('ivoice:setTalkingOnCall', setTalkingOnCall)
