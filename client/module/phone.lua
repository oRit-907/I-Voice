--[[
	Phone calls.

	A call is a flat group: everyone on the channel hears everyone else,
	ignoring distance entirely.
]]

local callChannel = 0
local phoneThreadRunning = false

--- Watches the push-to-talk state while a call is live and mirrors it to the
--- rest of the call. Guarded so repeated channel changes can't stack threads.
local function createPhoneThread()
	if phoneThreadRunning or callChannel == 0 then return end
	phoneThreadRunning = true

	Citizen.CreateThread(function()
		local wasTalking = false

		while callChannel ~= 0 do
			local talking = isLocalPlayerTalking()

			if talking ~= wasTalking then
				wasTalking = talking
				refreshVoiceTargets()
				TriggerServerEvent('ivoice:setTalkingOnCall', talking)
			end

			Wait(0)
		end

		-- make sure we don't leave the call thinking we're mid sentence
		if wasTalking then
			TriggerServerEvent('ivoice:setTalkingOnCall', false)
		end

		phoneThreadRunning = false
	end)
end

--- The call channel the player is on (0 when not in a call).
function getCallChannel()
	return callChannel
end
exports('getCallChannel', getCallChannel)

--- Everyone on the call, as a list of server ids.
exports('getCallMembers', function()
	local members = {}
	for id in pairs(callData) do
		members[#members + 1] = id
	end
	table.sort(members)
	return members
end)

RegisterNetEvent('ivoice:syncCallData', function(callTable)
	callData = callTable

	for tgt, enabled in pairs(callTable) do
		if tgt ~= playerServerId then
			toggleVoice(tgt, enabled, 'phone')
		end
	end

	refreshUI()
end)

RegisterNetEvent('ivoice:setTalkingOnCall', function(tgt, enabled)
	if tgt == playerServerId then return end
	callData[tgt] = enabled
	toggleVoice(tgt, enabled, 'phone')
end)

RegisterNetEvent('ivoice:addPlayerToCall', function(plySource)
	callData[plySource] = false
	if isLocalPlayerTalking() then
		refreshVoiceTargets()
	end
	refreshUI()
end)

RegisterNetEvent('ivoice:removePlayerFromCall', function(plySource)
	if plySource == playerServerId then
		for tgt in pairs(callData) do
			if tgt ~= playerServerId then
				toggleVoice(tgt, false, 'phone')
			end
		end
		callData = {}
	else
		callData[plySource] = nil
		toggleVoice(plySource, false, 'phone')
	end

	refreshVoiceTargets()
	refreshUI()
end)

--- Puts the player on a call channel.
--- @param channel number the channel to join, or 0 to hang up
function setCallChannel(channel)
	if GetConvarInt('voice_enablePhones', 1) ~= 1 then return end
	channel = tonumber(channel)
	type_check({ channel, 'number' })

	if channel == callChannel then return end

	TriggerServerEvent('ivoice:setPlayerCall', channel)
	callChannel = channel

	if channel == 0 then
		callData = {}
	end

	refreshUI()
	createPhoneThread()
end

exports('setCallChannel', setCallChannel)
exports('SetCallChannel', setCallChannel)

exports('addPlayerToCall', function(_call)
	local call = tonumber(_call)
	if call then
		setCallChannel(call)
	end
end)

exports('removePlayerFromCall', function()
	setCallChannel(0)
end)

RegisterNetEvent('ivoice:clSetPlayerCall', function(_callChannel)
	if GetConvarInt('voice_enablePhones', 1) ~= 1 then return end
	callChannel = _callChannel
	if callChannel == 0 then
		callData = {}
	end
	refreshUI()
	createPhoneThread()
end)
