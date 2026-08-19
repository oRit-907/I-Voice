## setRadioChannel | addPlayerToRadio | SetRadioChannel

## Description

Sets the channel the local player **transmits** on. To also listen in on other
channels without transmitting on them, see
[secondary channels](secondaryRadioChannels.md).

## Parameters

* **radioChannel**: the radio channel to join

## NOTE: If the player fails the server side radio channel check they will be reset to no channel. 

```lua
-- Joins radio channel 1
exports['I-Voice']:setRadioChannel(1)

-- This will remove the player from all radio channels
exports['I-Voice']:setRadioChannel(0)
```

Setting the primary to a channel the player is already monitoring promotes it rather than
rejoining, so nobody sees them leave and re-enter.

addPlayerToRadio is provided as a 'easier to read' alternative to setRadioChannel.

```lua
-- Joins radio channel 1
exports['I-Voice']:addPlayerToRadio(1)
```