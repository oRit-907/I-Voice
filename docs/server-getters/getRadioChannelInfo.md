## getRadioChannelInfo | getActiveRadioChannels

## Description

`getRadioChannelInfo` summarises a single radio channel. `getActiveRadioChannels` lists every
channel that currently has someone on it.

## Parameters

* **channel**: the channel to describe

## Returns

```lua
{
	channel = 1,
	count = 3,             -- everyone on the channel
	members = { 1, 2, 3 }, -- sorted server ids
	talking = { 1 },       -- who is transmitting right now
	monitoring = { 3 },    -- who is receive-only (this is a secondary channel for them)
}
```

```lua
local info = exports['I-Voice']:getRadioChannelInfo(1)
print(('channel 1 has %s listeners, %s talking'):format(info.count, #info.talking))

for _, channel in ipairs(exports['I-Voice']:getActiveRadioChannels()) do
	print(channel, exports['I-Voice']:getRadioChannelInfo(channel).count)
end
```

An empty or never-used channel returns a zeroed record rather than nil, so it's always safe
to index.
