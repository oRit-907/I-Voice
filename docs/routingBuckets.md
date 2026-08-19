## Routing Buckets

I-Voice natively supports routing buckets — a player only ever hears people in their own
bucket, with no configuration required.

If you need a group of players to share a voice channel regardless of where they are in the
world (an interior instance, a minigame lobby), use `setVoiceState` instead of a bucket:

```lua
-- everyone on channel 4 hears each other, distance is ignored
exports['I-Voice']:setVoiceState('channel', 4)

-- back to normal proximity voice
exports['I-Voice']:setVoiceState('proximity')
```
