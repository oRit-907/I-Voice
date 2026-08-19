--[[
	Server side megaphone.

	The server only tracks *who* has one raised — the range check happens on
	each receiving client, which is the only place that knows the distance
	between two players cheaply.
]]

--- Raises or lowers a player's megaphone and tells every client about it.
--- @param source number
--- @param active boolean
function setMegaphoneState(source, active)
	if GetConvarInt('voice_enableMegaphone', 1) ~= 1 then return end

	active = active == true
	local plyData = getVoiceData(source)
	if plyData.megaphone == active then return end

	plyData.megaphone = active

	if active then
		megaphoneData[source] = true
	else
		megaphoneData[source] = nil
	end

	Player(source).state:set('megaphoneActive', active, true)
	TriggerClientEvent('ivoice:setMegaphoneState', -1, source, active)
	TriggerEvent('ivoice:playerMegaphone', source, active)

	logger.verbose('[megaphone] %s %s their megaphone', source, active and 'raised' or 'lowered')
end
exports('setMegaphoneState', setMegaphoneState)

--- Whether a player currently has a megaphone raised.
exports('isPlayerUsingMegaphone', function(source)
	local plyData = voiceData[source]
	return plyData ~= nil and plyData.megaphone
end)

--- Every player currently broadcasting through a megaphone.
exports('getMegaphoneUsers', function()
	local users = {}
	for id in pairs(megaphoneData) do
		users[#users + 1] = id
	end
	table.sort(users)
	return users
end)

RegisterNetEvent('ivoice:setMegaphoneState', function(active)
	setMegaphoneState(source, active)
end)
