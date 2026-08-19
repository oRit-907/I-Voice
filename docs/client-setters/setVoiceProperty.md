## setVoiceProperty | SetMumbleProperty | SetTokoProperty

## Description

Sets the voice property, currently the only use is to enable/disable radios and radio clicks.

## Parameters

* **property**: The property to set
* **value**: The value to set the property to

```lua
-- Enable the radio
exports['I-Voice']:setVoiceProperty('radioEnabled', true)
-- Disable radio clicks
exports['I-Voice']:setVoiceProperty('micClicks', false)
```