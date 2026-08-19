--[[
	Megaphone.

	Unlike the radio and the phone, a megaphone stays positional: the speaker is
	broadcast on their own Mumble channel and every client within
	`voice_megaphoneRange` opens a listen channel onto them. That keeps the
	distance falloff intact while reaching far past normal shouting range.
]]

local megaphoneActive = false
local megaphoneAllowed = true

--- Server ids currently holding a megaphone open, and whether we're listening.
local activeMegaphones = {}
local listening = {}

--- True while the local player is broadcasting through a megaphone.
function isMegaphoneActive()
	return megaphoneActive
end
exports('isMegaphoneActive', isMegaphoneActive)

--- Gates the megaphone behind whatever the server's job/inventory logic wants.
--- @param allowed boolean
exports('setMegaphoneAllowed', function(allowed)
	megaphoneAllowed = allowed == true
	if not megaphoneAllowed and megaphoneActive then
		ExecuteCommand('-megaphone')
	end
end)

exports('isMegaphoneAllowed', function()
	return megaphoneAllowed
end)

local function stopListeningTo(serverId)
	if not listening[serverId] then return end
	listening[serverId] = nil
	toggleVoice(serverId, false, 'megaphone')
	-- spectating already owns this listen channel; leave it alone
	if not (isSpectatorListening and isSpectatorListening()) then
		MumbleRemoveVoiceChannelListen(serverId)
	end
	logger.verbose('[megaphone] Stopped listening to %s', serverId)
end

local function startListeningTo(serverId)
	if listening[serverId] then return end
	listening[serverId] = true
	MumbleAddVoiceChannelListen(serverId)
	toggleVoice(serverId, true, 'megaphone')
	logger.verbose('[megaphone] Started listening to %s', serverId)
end

--- Called from the proximity loop: opens or closes a listen channel onto every
--- active megaphone based on how far away its holder is.
--- @param plyCoords vector3 the local player's cached position
function updateMegaphoneListeners(plyCoords)
	if next(activeMegaphones) == nil and next(listening) == nil then return end

	local range = Cfg.megaphoneRange

	for serverId in pairs(activeMegaphones) do
		local ply = GetPlayerFromServerId(serverId)
		local inRange = false

		if ply ~= -1 and serverId ~= playerServerId then
			local ped = GetPlayerPed(ply)
			if ped ~= 0 then
				inRange = #(plyCoords - GetEntityCoords(ped)) < range
			end
		end

		if inRange then
			startListeningTo(serverId)
		else
			stopListeningTo(serverId)
		end
	end

	-- clean up anyone who dropped their megaphone (or the server) while we
	-- were still listening
	for serverId in pairs(listening) do
		if not activeMegaphones[serverId] then
			stopListeningTo(serverId)
		end
	end
end

--- A remote player raised or lowered their megaphone.
RegisterNetEvent('ivoice:setMegaphoneState', function(serverId, active)
	if serverId == playerServerId then return end

	if active then
		activeMegaphones[serverId] = true
		logger.info('[megaphone] %s raised a megaphone', serverId)
	else
		activeMegaphones[serverId] = nil
		stopListeningTo(serverId)
		logger.info('[megaphone] %s lowered their megaphone', serverId)
	end
end)

--- Full state resync, sent when we connect so we don't miss megaphones that
--- were already up.
RegisterNetEvent('ivoice:syncMegaphones', function(active)
	for serverId in pairs(activeMegaphones) do
		if not active[serverId] then
			stopListeningTo(serverId)
		end
	end

	activeMegaphones = {}
	for serverId in pairs(active) do
		if serverId ~= playerServerId then
			activeMegaphones[serverId] = true
		end
	end
end)

RegisterNetEvent('onPlayerDropped', function(serverId)
	serverId = tonumber(serverId)
	if serverId and activeMegaphones[serverId] then
		activeMegaphones[serverId] = nil
		stopListeningTo(serverId)
	end
end)

--#region Local control

--- Raises or lowers the local player's megaphone.
--- @param active boolean
function setMegaphoneActive(active)
	active = active == true

	if active then
		if GetConvarInt('voice_enableMegaphone', 1) ~= 1 then return end
		if not megaphoneAllowed or megaphoneActive then return end
		if isDead and isDead() then return end
	elseif not megaphoneActive then
		return
	end

	megaphoneActive = active
	TriggerServerEvent('ivoice:setMegaphoneState', active)
	TriggerEvent('ivoice:megaphoneActive', active)
	logger.info('[megaphone] Local megaphone %s', active and 'raised' or 'lowered')

	-- widen (or restore) our own sending range immediately rather than waiting
	-- for the next proximity tick
	addNearbyPlayers()
	refreshUI()
end
exports('setMegaphoneActive', setMegaphoneActive)

RegisterCommand('+megaphone', function()
	setMegaphoneActive(true)
end, false)

RegisterCommand('-megaphone', function()
	setMegaphoneActive(false)
end, false)

if gameVersion == 'fivem' then
	RegisterKeyMapping('+megaphone', 'Talk over Megaphone', 'keyboard', GetConvar('voice_defaultMegaphone', 'CAPITAL'))
end

--#endregion

-- Dying mid-broadcast should cut the megaphone, not leave it stuck open.
CreateThread(function()
	while true do
		Wait(500)
		if megaphoneActive and isDead and isDead() then
			setMegaphoneActive(false)
		end
	end
end)
