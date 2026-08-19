## removePlayerFromRadio

## Description

Removes the player from the radio

## NOTE: This is just syntactic sugar for `setRadioChannel(0)`

It only clears the transmit channel. To drop monitored channels as well, use
`leaveAllRadioChannels` — see [secondary channels](secondaryRadioChannels.md).

```lua
-- Removes the player from the radio channel
exports['I-Voice']:removePlayerFromRadio()
```