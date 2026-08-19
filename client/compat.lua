--[[
	pma-voice compatibility (client).

	I-Voice's own events use the `ivoice:` prefix. Everything a third-party
	resource could reasonably have bound against pma-voice is mirrored here, so
	scripts written for it keep working unchanged.

	Note this only covers *events* and globals — `exports['pma-voice']:...`
	resolves by resource name, so it needs either the resource folder to be
	named `pma-voice` or the shim in `compat/pma-voice`. See COMPATIBILITY.md.
]]

--#region Mirrored events

--- Events I-Voice emits locally, re-emitted under their pma-voice names.
local mirroredEvents = {
	'radioActive',
	'setTalkingMode',
	'toggleRadioAnim',
	'megaphoneActive',
}

for _, name in ipairs(mirroredEvents) do
	AddEventHandler('ivoice:' .. name, function(...)
		TriggerEvent('pma-voice:' .. name, ...)
	end)
end

--- pma-voice's settings callback. `Cfg` gained `megaphoneRange`, which is
--- additive, so the same table serves both names.
AddEventHandler('pma-voice:settingsCallback', function(cb)
	cb(Cfg)
end)

--#endregion

--#region Legacy net events

--- The server telling us our radio changed. Same signature as pma-voice, so a
--- resource still firing the old name lands in the right place.
RegisterNetEvent('pma-voice:clSetPlayerRadio', function(radioChannel)
	TriggerEvent('ivoice:clSetPlayerRadio', radioChannel)
end)

RegisterNetEvent('pma-voice:clSetPlayerCall', function(callChannel)
	TriggerEvent('ivoice:clSetPlayerCall', callChannel)
end)

--[[
	The remaining pma-voice client net events (syncRadioData, addPlayerToRadio,
	removePlayerFromRadio, setTalkingOnRadio and the call equivalents) are
	internal chatter between I-Voice's own client and server. They now carry the
	channel as their first argument because a player can be on several at once,
	so the old signatures can't be mapped across without guessing which channel
	was meant. They are deliberately not aliased: a resource firing them
	directly was reaching into pma-voice's internals, and should use the
	exports instead.
]]

--#endregion

--#region Legacy globals

--- pma-voice exposed the mic click preference as a global string. Some forks
--- and HUDs read it directly, so keep it in step with the real setting.
micClicks = tostring(getSetting('micClicks'))

onSettingChanged('micClicks', function(value)
	micClicks = tostring(value)
	-- Mirror it back into pma-voice's KVP too, so a player who switches back
	-- doesn't lose their preference.
	SetResourceKvp('pma-voice_enableMicClicks', micClicks)
end)

--#endregion
