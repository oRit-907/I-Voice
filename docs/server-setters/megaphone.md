## setMegaphoneState | getMegaphoneUsers | isPlayerUsingMegaphone

## Description

Raises or lowers a player's megaphone from the server, and tells every client so they can
open a listen channel onto them when they're in range.

The server only tracks *who* has one raised; the range check happens on each receiving
client, which is the only place that knows the distance between two players cheaply.

## Parameters

* **source**: the player whose megaphone to change
* **active**: whether the megaphone is raised

```lua
-- cut someone off
exports['I-Voice']:setMegaphoneState(source, false)

if exports['I-Voice']:isPlayerUsingMegaphone(source) then
	-- ...
end

-- { 3, 17 }
local users = exports['I-Voice']:getMegaphoneUsers()

AddEventHandler('ivoice:playerMegaphone', function(source, active)
	print(('%s %s their megaphone'):format(source, active and 'raised' or 'lowered'))
end)
```

Megaphones are dropped automatically when a player disconnects. Set
`voice_enableMegaphone 0` to disable the module entirely.
