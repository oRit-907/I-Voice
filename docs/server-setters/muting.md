## setPlayerMuted | isPlayerMuted | muteply

## Description

Mutes a player at the Mumble level, so nothing they say reaches anyone. A muted player's
state bag carries `muted = true`.

Muting can be temporary: pass a duration and the player is unmuted automatically when it
elapses. Muting a player again cancels any pending automatic unmute.

## Parameters

* **target**: the player to mute
* **muted**: the state to apply
* **duration**: seconds until an automatic unmute; 0 or omitted for indefinite
* **invoker**: (optional) whoever triggered it, passed through to the event

```lua
-- mute for five minutes
exports['I-Voice']:setPlayerMuted(target, true, 300, source)

-- mute until someone lifts it
exports['I-Voice']:setPlayerMuted(target, true, 0)

-- lift it
exports['I-Voice']:setPlayerMuted(target, false)

AddEventHandler('ivoice:playerMuted', function(target, invoker, muted, duration)
	print(('%s was %s by %s'):format(target, muted and 'muted' or 'unmuted', invoker))
end)
```

The `/muteply [id] (seconds)` command toggles the same thing, defaulting to 900 seconds. It
is ace-gated — grant it with `add_ace group.superadmin command.muteply allow;`.
