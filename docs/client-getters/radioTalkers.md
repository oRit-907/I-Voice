## getRadioTalkers

## Description

Returns everyone currently transmitting on any channel the local player is receiving,
primary and monitored alike. This is what the overlay's talker list renders.

Names are only populated when the server has `voice_syncPlayerNames` set to 1; otherwise
each entry falls back to `Player <id>`. Use `overrideRadioNameGetter` on the server to
return a character name, callsign or badge number instead of the Steam/Discord name.

## Returns

A list of `{ id = number, name = string, channel = number }`, sorted by channel then id.

```lua
for _, talker in ipairs(exports['I-Voice']:getRadioTalkers()) do
	print(('%s is talking on %s'):format(talker.name, talker.channel))
end
```

If you're drawing your own HUD, hide the built-in list with
`exports['I-Voice']:setVoiceSetting('showTalkerList', false)`.
