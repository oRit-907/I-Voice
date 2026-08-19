## setRadioVolume

## Description

Sets the local players radio channel volume

## Parameters

* **radioVolume**: the radio volume to set to between 0 - 100 percent

```lua
-- sets the radio volume to 50 percent
exports['I-Voice']:setRadioVolume(50)
```

The volume is persisted for the player and restored on their next join, so this only needs
calling when you actually want to change it. `setCallVolume` and `setMegaphoneVolume` behave
the same way, and `getRadioVolume` returns the current value as a 0-1 float.