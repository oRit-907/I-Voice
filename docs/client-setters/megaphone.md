## setMegaphoneActive | setMegaphoneAllowed | setMegaphoneVolume | isMegaphoneActive

## Description

A megaphone broadcasts the player's voice out to `voice_megaphoneRange` game units
(default 40) with a dedicated PA-style submix, well past normal shouting range.

Unlike the radio and phone, it stays positional: receiving clients open a listen channel onto
the speaker only while they're inside the range, so distance falloff still applies.

Players hold the megaphone key (`voice_defaultMegaphone`, default `CAPITAL`) to talk. The
resource does not decide *who* may use one — gate it yourself with `setMegaphoneAllowed`.

## Parameters

* **setMegaphoneActive(active)**: raise or lower the megaphone
* **setMegaphoneAllowed(allowed)**: whether the key does anything at all
* **setMegaphoneVolume(volume)**: 0-100, persisted for the player

```lua
-- only let the player use a megaphone while they're a cop on duty
exports['I-Voice']:setMegaphoneAllowed(job == 'police' and onDuty)

-- raise it from your own script instead of the key bind
exports['I-Voice']:setMegaphoneActive(true)

if exports['I-Voice']:isMegaphoneActive() then
	-- ...
end

-- react to the player raising or lowering it
AddEventHandler('ivoice:megaphoneActive', function(active)
	print('megaphone', active)
end)
```

Lowering happens automatically when the player dies or when `setMegaphoneAllowed(false)` is
called mid-broadcast.
