# pma-voice compatibility

I-Voice is a drop-in replacement for [pma-voice](https://github.com/AvarianKnight/pma-voice).
Scripts written against it keep working — but **exports resolve by resource name**, so how
you install I-Voice decides whether `exports['pma-voice']:setRadioChannel(1)` finds anything.

## Pick an install mode

### Mode A — name the folder `pma-voice` (simplest)

```
resources/pma-voice/     <- this repository
```

```cfg
ensure pma-voice
```

Everything works with no extra steps: exports, events, and any script with
`dependencies { 'pma-voice' }`.

### Mode B — any other folder name, plus the shim

```
resources/I-Voice/           <- this repository
resources/pma-voice/         <- copy of I-Voice/compat/pma-voice
```

```cfg
ensure I-Voice
ensure pma-voice
```

The shim claims the `pma-voice` name and forwards every export through to I-Voice. It finds
I-Voice by looking for the started resource whose manifest declares `name 'I-Voice'`, so the
folder name doesn't matter. To be explicit instead:

```cfg
set voice_resourceName "I-Voice"
```

> The shim ships inside `compat/pma-voice` so it's versioned with the resource. **Copy it out**
> into your resources directory — it does nothing where it sits.

### Mode C — any folder name, no shim

Events work; `exports['pma-voice']` does not, and neither does
`dependencies { 'pma-voice' }`. I-Voice prints a warning at startup saying so. If that's what
you want (nothing on your server calls pma-voice exports), silence it with:

```cfg
set voice_warnPmaVoiceCompat 0
```

You can check which mode is live at runtime:

```lua
print(exports['I-Voice']:getPmaVoiceCompatMode()) -- 'native' | 'shim' | 'events-only'
```

---

## What works, by mode

| Surface | Mode A | Mode B | Mode C |
|---|:--:|:--:|:--:|
| `exports['pma-voice']:...` (client & server) | yes | yes | **no** |
| `dependencies { 'pma-voice' }` | yes | yes | **no** |
| `AddEventHandler('pma-voice:radioActive', …)` and friends | yes | yes | yes |
| `TriggerServerEvent('pma-voice:setPlayerRadio', …)` and friends | yes | yes | yes |
| `AddEventHandler('pma-voice:playerMuted', …)` | yes | yes | yes |
| `Player(src).state.radioChannel` and the other state bags | yes | yes | yes |

Do **not** run the real pma-voice alongside either mode — two resources can't share a name,
and two voice systems can't share a Mumble connection.

---

## Exports

Every export pma-voice had exists in I-Voice under the same name and signature:

**Client** — `setVoiceProperty`, `SetMumbleProperty`, `SetTokoProperty`, `setRadioChannel`,
`SetRadioChannel`, `addPlayerToRadio`, `removePlayerFromRadio`, `setCallChannel`,
`SetCallChannel`, `addPlayerToCall`, `removePlayerFromCall`, `setRadioVolume`,
`getRadioVolume`, `setCallVolume`, `getCallVolume`, `toggleMutePlayer`, `toggleRadioAnim`,
`getRadioAnimState`, `setAllowProximityCycleState`, `overrideProximityRange`,
`clearProximityOverride`, `overrideProximityCheck`, `resetProximityCheck`, `setVoiceState`

**Server** — `setPlayerRadio`, `setPlayerCall`, `addChannelCheck`, `overrideRadioNameGetter`,
`getPlayersInRadioChannel`, `GetPlayersInRadioChannel`, `isValidPlayer`

Two behaved differently in pma-voice and are handled:

- **`getRadioAnimState`** returned an undefined global in pma-voice (always `nil`). It now
  returns the real state. A script relying on the `nil` is relying on a bug.
- **`overrideRadioNameGetter`** took `(channel, cb)`, where the channel was never used.
  I-Voice takes `(cb)` but still accepts the old two-argument form, so both work.

---

## Events

Everything pma-voice raised is still raised under its old name, alongside the `ivoice:` one:

| pma-voice event | Still emitted | Notes |
|---|:--:|---|
| `pma-voice:radioActive` | yes | Also `ivoice:radioActive` |
| `pma-voice:setTalkingMode` | yes | Also `ivoice:setTalkingMode` |
| `pma-voice:toggleRadioAnim` | yes | Also `ivoice:toggleRadioAnim` |
| `pma-voice:settingsCallback` | yes | The `Cfg` table gained `megaphoneRange`; nothing was removed |
| `pma-voice:playerMuted` | yes | Server side. Also `ivoice:playerMuted` |

Everything pma-voice listened for is still accepted:

| pma-voice net event | Accepted | Side |
|---|:--:|---|
| `pma-voice:setPlayerRadio` | yes | server |
| `pma-voice:setPlayerCall` | yes | server |
| `pma-voice:setTalkingOnRadio` | yes | server |
| `pma-voice:setTalkingOnCall` | yes | server |
| `pma-voice:clSetPlayerRadio` | yes | client |
| `pma-voice:clSetPlayerCall` | yes | client |

### The one deliberate gap

pma-voice's remaining **client** net events — `syncRadioData`, `addPlayerToRadio`,
`removePlayerFromRadio`, `setTalkingOnRadio`, and the call equivalents — are *not* aliased.

They were internal chatter between pma-voice's own client and server. I-Voice's versions now
carry the channel as their first argument, because a player can be on several channels at
once, and the old single-channel signatures can't be mapped onto them without guessing which
channel was meant.

A resource firing these directly was reaching into pma-voice's internals. Use the exports
instead — `setRadioChannel`, `addSecondaryRadioChannel`, `setPlayerRadio` — which are stable
and do the right thing.

---

## State bags

All of pma-voice's state bags are present, with the same names and meanings: `proximity`,
`radioChannel`, `callChannel`, `voiceIntent`, `muted`, `radio`, `phone`, and the internal
`pmaVoiceInit` flag. I-Voice adds `secondaryRadioChannels`, `megaphoneActive`, `megaphone`
and `voiceInit`.

**One deliberate change.** pma-voice seeded the `radio` and `phone` volume bags server side
with the 0-100 convar value, then overwrote them client side with a 0-1 float — so the same
bag meant different things depending on whether the player had touched their volume yet.
I-Voice uses **0-100 everywhere**, matching the convars and the settings panel. The
`getRadioVolume` / `getCallVolume` exports still return a 0-1 float, exactly as before.

If you read the bag directly and divided by 100 to normalise, that now works consistently
rather than only before the player's first volume change.

---

## Player preferences

pma-voice stored the mic-click preference in the `pma-voice_enableMicClicks` KVP and exposed
it as a global `micClicks` string. I-Voice keeps both in step:

- On first run it adopts the existing pma-voice preference rather than resetting it.
- The old KVP is kept updated, so a player who joins a pma-voice server later keeps their choice.
- The `micClicks` global still exists and still holds `'true'` / `'false'`.

New preferences live under the `ivoice:` KVP prefix and don't collide with anything.
