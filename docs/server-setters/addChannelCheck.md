## addChannelCheck | removeChannelCheck | setChannelLimit | overrideRadioNameGetter

## Description

Controls who may join a radio channel, and how many of them fit.

A check receives `(source, channel)` and must return a boolean. A check that throws is
treated as a refusal rather than taking the join down with it.

## Parameters

* **channel**: the channel to gate
* **cb**: the function to run; returns whether the player may join

```lua
-- Example for addChannelCheck
-- this always has to return true/false
exports['I-Voice']:addChannelCheck(1, function(source)
	if IsPlayerAceAllowed(source, 'radio.police') then
		return true
	end
	return false
end)

-- the channel is passed too, so one function can gate a range of channels
for channel = 10, 20 do
	exports['I-Voice']:addChannelCheck(channel, function(source, chan)
		return hasRadioFrequency(source, chan)
	end)
end

exports['I-Voice']:removeChannelCheck(1)
```

Checks apply to monitored (secondary) channels as well as the transmit channel.

## Channel limits

```lua
-- at most eight people on the dispatch channel
exports['I-Voice']:setChannelLimit(1, 8)

-- remove the cap
exports['I-Voice']:setChannelLimit(1, nil)
```

A player refused for either reason gets an `ivoice:radioDenied` event carrying the reason,
which the built-in UI surfaces as a notification.

## Display names

With `voice_syncPlayerNames` set to 1, everyone on a channel is told the names of the others
so the overlay can show who is transmitting. By default that's `GetPlayerName`; override it
to use a character name or callsign instead.

```lua
exports['I-Voice']:overrideRadioNameGetter(function(source)
	return getCharacter(source).callsign
end)

-- back to GetPlayerName
exports['I-Voice']:resetRadioNameGetter()
```

Both the check table and the name getter are cleaned up automatically if the resource that
provided them stops.
