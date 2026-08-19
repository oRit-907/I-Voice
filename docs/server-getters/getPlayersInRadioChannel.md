## getPlayersInRadioChannel

## Description

Gets a list of all of the players in the specified radio channel.

## Parameters

* **radioChannel**: The channel to get all the members of

## Returns

Returns a table of all of the players in the specified radio channel, keyed by server id,
with the value being whether they're transmitting right now.

This includes players who are only *monitoring* the channel — they'll always read as not
talking, since a monitor keys up on their own primary channel.
[getRadioChannelInfo](getRadioChannelInfo.md) tells the two apart.

```lua
-- this will return all of the current players in radio channel 1
local players = exports['I-Voice']:getPlayersInRadioChannel(1)
for source, isTalking in pairs(players) do
	print(('%s is in radio channel 1, isTalking: %s'):format(GetPlayerName(source), isTalking))
end
```
