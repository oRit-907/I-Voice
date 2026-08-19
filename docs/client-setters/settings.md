## setVoiceSetting | getVoiceSetting | getVoiceSettings | setSettingsOpen

## Description

Every player-facing preference is persisted to the game's KVP store, so it survives a
reconnect. Players change them in the panel (`/voicesettings`); resources can read and write
them through these exports.

| Key | Type | Default |
|---|---|---|
| `micClicks` | boolean | `true` |
| `radioVolume` | number, 0-100 | `voice_defaultRadioVolume` |
| `callVolume` | number, 0-100 | `voice_defaultPhoneVolume` |
| `megaphoneVolume` | number, 0-100 | `voice_defaultMegaphoneVolume` |
| `uiEnabled` | boolean | `voice_enableUi` |
| `uiScale` | number, 75-150 | `100` |
| `uiPosition` | `'bottom-right'` \| `'bottom-left'` \| `'top-right'` \| `'top-left'` | `'bottom-right'` |
| `showTalkerList` | boolean | `true` |
| `radioAnim` | boolean | `true` |

```lua
-- read one, or all of them
local scale = exports['I-Voice']:getVoiceSetting('uiScale')
local all = exports['I-Voice']:getVoiceSettings()

-- move the overlay out of the way of your own HUD
exports['I-Voice']:setVoiceSetting('uiPosition', 'top-left')

-- open the panel from your own menu
exports['I-Voice']:setSettingsOpen(true)

-- react to a player changing something
AddEventHandler('ivoice:settingChanged', function(key, value)
	print(key, value)
end)
```

Volumes are also reachable through `setRadioVolume`, `setCallVolume` and
`setMegaphoneVolume`, which apply the change immediately as well as persisting it.
