--[[
	Startup: hand the UI its initial state and restore any channels the server
	still thinks we're on.
]]

AddEventHandler('onClientResourceStart', function(resource)
	if resource ~= GetCurrentResourceName() then return end

	logger.log('[I-Voice] Starting script initialization')

	setVolume(getSetting('radioVolume'), 'radio')
	setVolume(getSetting('callVolume'), 'phone')
	setVolume(getSetting('megaphoneVolume'), 'megaphone')

	refreshUI()

	-- Reinitialize channels if the server still has us on them (a resource
	-- restart doesn't drop server side membership).
	local radioChannel = LocalPlayer.state.radioChannel
	if radioChannel and radioChannel ~= 0 then
		setRadioChannel(radioChannel)
	end

	local callChannel = LocalPlayer.state.callChannel
	if callChannel and callChannel ~= 0 then
		setCallChannel(callChannel)
	end

	TriggerServerEvent('ivoice:requestSync')

	logger.log('[I-Voice] Script initialization finished.')
end)
