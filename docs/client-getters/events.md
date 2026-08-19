## setTalkingMode | settingsCallback | radioActive | megaphoneActive

## Description

These events let third-party resources (a HUD, for example) follow the player's current voice
mode, radio state and megaphone state. They are emitted only to the local client.

```lua
-- default voice mode is 2
local voiceMode = 2
local voiceModes = {}
local usingRadio = false
local usingMegaphone = false

-- sets the current radio state boolean
AddEventHandler('ivoice:radioActive', function(radioTalking) usingRadio = radioTalking end)

-- sets the current megaphone state boolean
AddEventHandler('ivoice:megaphoneActive', function(active) usingMegaphone = active end)

-- changes the current voice range index
AddEventHandler('ivoice:setTalkingMode', function(newTalkingRange) voiceMode = newTalkingRange end)

-- fired when the player toggles the radio animation off or on
AddEventHandler('ivoice:toggleRadioAnim', function(disabled) print('radio anim disabled:', disabled) end)

-- returns registered voice modes from shared.lua's `Cfg.voiceModes`
TriggerEvent('ivoice:settingsCallback', function(voiceSettings)
	local voiceTable = voiceSettings.voiceModes

	-- loop through all voice modes and add them to the table
	-- the percentage is used for the voice mode slider if this was an actual UI
	for i = 1, #voiceTable do
		local distance = math.ceil(((i / #voiceTable) * 100))
		voiceModes[i] = ('%s'):format(distance)
	end

	-- how far a megaphone carries, in the same units
	print(voiceSettings.megaphoneRange)
end)
```

`pma-voice:settingsCallback` is still accepted as an alias, so existing resources keep
working. The other events were renamed to the `ivoice:` prefix.
