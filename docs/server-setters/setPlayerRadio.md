## setPlayerRadio

## Description

Sets the channel a player **transmits** on. For receive-only channels see
[secondary channels](secondaryRadioChannels.md).

## Parameters

* **source**: The player to set the radio channel of
* **radioChannel**: the radio channel to set the player to, or 0 to take them off the radio

```lua
exports['I-Voice']:setPlayerRadio(source, 1)
```