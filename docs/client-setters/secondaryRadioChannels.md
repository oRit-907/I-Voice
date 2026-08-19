## addSecondaryRadioChannel | removeSecondaryRadioChannel | leaveAllRadioChannels | getRadioChannels

## Description

A player transmits on exactly one channel — their *primary*, set with
[setRadioChannel](setRadioChannel.md). Secondary channels are receive-only: the player hears
everything on them but keying up still goes out on the primary.

How many secondary channels a player may hold is capped by `voice_maxSecondaryChannels`
(default 3). Going over the cap is refused by the server, and the player is told why.

## Parameters

* **channel**: the radio channel to start or stop monitoring

```lua
-- transmit on dispatch
exports['I-Voice']:setRadioChannel(1)

-- while also listening in on the fire and EMS channels
exports['I-Voice']:addSecondaryRadioChannel(2)
exports['I-Voice']:addSecondaryRadioChannel(3)

-- { 1, 2, 3 } — the primary always comes first
local channels = exports['I-Voice']:getRadioChannels()

-- stop monitoring EMS
exports['I-Voice']:removeSecondaryRadioChannel(3)

-- drop everything, primary included
exports['I-Voice']:leaveAllRadioChannels()
```

Promoting a monitored channel to primary is just `setRadioChannel` — the player won't rejoin
or be announced twice.

```lua
exports['I-Voice']:setRadioChannel(2) -- 2 stops being a monitor, becomes the primary
```
