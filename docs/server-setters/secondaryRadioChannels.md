## addPlayerSecondaryRadio | removePlayerSecondaryRadio

## Description

Server-side control of a player's monitored (receive-only) radio channels. The player keeps
transmitting on whatever [setPlayerRadio](setPlayerRadio.md) gave them.

Channel checks and limits apply exactly as they do for a primary channel — a player who
fails `addChannelCheck` is refused and told why.

## Parameters

* **source**: the player to change
* **channel**: the radio channel to start or stop monitoring

```lua
-- put a dispatcher on their own channel, listening to all three services
exports['I-Voice']:setPlayerRadio(source, 1)
exports['I-Voice']:addPlayerSecondaryRadio(source, 2)
exports['I-Voice']:addPlayerSecondaryRadio(source, 3)

exports['I-Voice']:removePlayerSecondaryRadio(source, 3)
```

The player's monitored channels are replicated in the `secondaryRadioChannels` state bag.
