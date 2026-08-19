## State Bag Getters/Setters

## Description

State bag getters are a little bit simpler: they just return the current value that is set in
the state bag.

#### Note: If you're on the client and only using it on the current player, you can replace Player(source) with LocalPlayer

| State Bag | Description | Type |
|---|---|---|
| `proximity` | The mode index, distance and mode name | table |
| `radioChannel` | The channel the player transmits on, or 0 | int |
| `secondaryRadioChannels` | Channels the player is monitoring | table |
| `callChannel` | The player's call channel, or 0 | int |
| `megaphoneActive` | Whether the player has a megaphone raised | boolean |
| `voiceIntent` | `'speech'` or `'music'` | string |
| `muted` | Whether the player is server-muted | boolean |
| `radio` / `phone` / `megaphone` | The player's volume for that bucket | number |

## Example for Proximity

```lua
local plyState = Player(source).state
local proximity = plyState.proximity
print(proximity.index) -- prints the index of the proximity as seen in Cfg.voiceModes
print(proximity.distance) -- prints the distance of the proximity
print(proximity.mode) -- prints the mode name of the proximity, or 'Custom' when overridden
```

## Example for radio channels

```lua
local plyState = Player(source).state
print(plyState.radioChannel) -- 1

for _, channel in ipairs(plyState.secondaryRadioChannels or {}) do
	print('also monitoring', channel)
end
```

## Setting death state

The radio and megaphone both refuse to key up while the player is dead. If your framework
tracks death itself, mirror it into the `isDead` state bag on the client:

```lua
LocalPlayer.state:set('isDead', true, false)
```
