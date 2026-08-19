--[[
	NUI bridge — every message to the UI funnels through here so nothing is
	dispatched before the UI has told us it is mounted and listening.
]]

local uiReady = promise.new()
local isUiReady = false

--- Sends a message to the NUI frame, waiting for it to become ready first.
--- @param message table the payload handed to the UI
function sendUIMessage(message)
	if not isUiReady then
		Citizen.Await(uiReady)
	end
	SendNUIMessage(message)
end

--- True once the UI has signalled that it is mounted.
function uiIsReady()
	return isUiReady
end

RegisterNUICallback('uiReady', function(_, cb)
	if not isUiReady then
		isUiReady = true
		uiReady:resolve(true)
	end
	cb('ok')
end)

--- Focus state is centralised so two menus can never fight over the cursor.
local nuiFocused = false

--- Toggles NUI focus, keeping our own bookkeeping in sync.
--- @param focused boolean
function setNuiFocus(focused)
	if nuiFocused == focused then return end
	nuiFocused = focused
	SetNuiFocus(focused, focused)
	SetNuiFocusKeepInput(false)
end

--- True while the voice UI owns the cursor.
function isNuiFocused()
	return nuiFocused
end

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and nuiFocused then
		SetNuiFocus(false, false)
	end
end)
