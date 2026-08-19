--[[
	pma-voice compatibility (server).

	Accepts every net event pma-voice's client sent, and re-emits the events it
	raised under their old names.

	`exports['pma-voice']:...` resolves by resource name, so it needs either the
	resource folder to be named `pma-voice` or the shim in `compat/pma-voice`.
	See COMPATIBILITY.md.
]]

--#region Legacy net events

RegisterNetEvent('pma-voice:setPlayerRadio', function(radioChannel)
	setPlayerRadio(source, radioChannel)
end)

RegisterNetEvent('pma-voice:setPlayerCall', function(callChannel)
	setPlayerCall(source, callChannel)
end)

RegisterNetEvent('pma-voice:setTalkingOnRadio', function(talking)
	-- setTalkingOnRadio reads the implicit `source` global rather than taking
	-- it as an argument, and it's already set for us here.
	setTalkingOnRadio(talking)
end)

RegisterNetEvent('pma-voice:setTalkingOnCall', function(talking)
	setTalkingOnCall(talking)
end)

--#endregion

--#region Mirrored events

--- Events I-Voice raises, re-emitted under their pma-voice names.
local mirroredEvents = {
	'playerMuted',
}

for _, name in ipairs(mirroredEvents) do
	AddEventHandler('ivoice:' .. name, function(...)
		TriggerEvent('pma-voice:' .. name, ...)
	end)
end

--#endregion

--- Reports which compatibility route is active, for the diagnostics command.
--- @return string 'native' when the resource is literally named pma-voice,
---                'shim' when the compat resource is running, or 'events-only'
function getPmaVoiceCompatMode()
	local resourceName = GetCurrentResourceName()
	if resourceName == 'pma-voice' then
		return 'native'
	end

	if GetResourceState('pma-voice') == 'started' then
		return 'shim'
	end

	return 'events-only'
end
exports('getPmaVoiceCompatMode', getPmaVoiceCompatMode)

CreateThread(function()
	Wait(2000)

	local mode = getPmaVoiceCompatMode()
	if mode == 'events-only' and GetConvarInt('voice_warnPmaVoiceCompat', 1) == 1 then
		logger.warn(
			"pma-voice event compatibility is active, but exports['pma-voice'] will not resolve "
				.. "because this resource is named '%s'. Either rename the folder to 'pma-voice' or "
				.. 'start the shim in compat/pma-voice. Set voice_warnPmaVoiceCompat 0 to silence this.',
			GetCurrentResourceName()
		)
	else
		logger.info('pma-voice compatibility mode: %s', mode)
	end
end)
