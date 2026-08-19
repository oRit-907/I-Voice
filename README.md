# I-Voice

A voice system for FiveM and RedM built on the game's internal Mumble server.

I-Voice is a rebuild of [pma-voice](https://github.com/AvarianKnight/pma-voice): the same
proximity/radio/phone core, with a modern NUI build, a player-facing settings panel, a
megaphone module, multi-channel radios, and a test suite.

---

## What's new in 2.0

| Feature | Summary |
|---|---|
| **Multi-channel radio** | Transmit on one channel while monitoring up to `voice_maxSecondaryChannels` others. |
| **Megaphone** | A ranged PA broadcast with its own submix, key bind and volume, heard well past shouting range. |
| **Live talker list** | The overlay names whoever is transmitting on your channels (needs `voice_syncPlayerNames`). |
| **Settings panel** | `/voicesettings` — volume sliders, mic clicks, overlay corner and scale, block list. |
| **Persisted preferences** | Every setting is saved to KVP and restored on reconnect. Existing pma-voice mic-click preferences are migrated automatically. |
| **Per-player blocking** | `/voiceblock [id]` silences someone for you only, with an unblock list in the panel. |
| **Channel limits & richer checks** | `setChannelLimit`, channel checks that receive the channel and can't crash the resource when they error. |
| **Reconnect resync** | A Mumble reconnect replays your channels instead of leaving you silently deaf. |
| **Rebuilt UI toolchain** | Vue 3 on Vite instead of Vue CLI 4 — builds on current Node, and ships one 88 kB bundle instead of ~700 kB of chunks and source maps. |
| **pma-voice compatibility** | Legacy events, net events, globals and KVP kept in step, plus an export shim so `exports['pma-voice']` keeps resolving. See [COMPATIBILITY.md](COMPATIBILITY.md). |
| **Tests** | Lua syntax checks, stubbed server-logic and compat-shim suites, and a headless-Chromium smoke test of the built UI. |

Bugs fixed along the way are listed in [Fixed from pma-voice](#fixed-from-pma-voice).

---

## Support

Please report any issues you have in the GitHub [Issues](https://github.com/oRit-907/I-Voice/issues).

### NOTE: It is expected for servers to be on the latest recommended version, which you can find [here for Windows](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/) and [here for Linux](https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/).

## Compatibility notice

This script is not compatible with other voice systems (duh), that means if you have vMenu's
voice chat you will **have** to [disable](https://docs.vespura.com/vmenu/faq/#q-how-do-i-disable-voice-chat) it.

Please do not override `NetworkSetTalkerProximity`, `MumbleSetAudioInputDistance`,
`MumbleSetAudioOutputDistance` or `NetworkSetVoiceActive` in any of your other scripts, as
there have been cases where it breaks the voice system.

## Running scripts written for pma-voice

I-Voice is a drop-in replacement. Every pma-voice export exists under the same name and
signature, every event it raised is still raised under its old name, and every net event it
listened for is still accepted.

The one thing that isn't automatic is the **export namespace**: `exports['pma-voice']:...`
resolves by resource name, so either name this folder `pma-voice`, or copy the shim in
[`compat/pma-voice`](compat/pma-voice) into your resources directory alongside it:

```cfg
ensure I-Voice
ensure pma-voice   # the shim, forwards exports/ to I-Voice
```

**[COMPATIBILITY.md](COMPATIBILITY.md) has the full matrix**, including the two signature
quirks that are handled for you and the one internal event set that is deliberately not
aliased.

## Credits

- @AvarianKnight for pma-voice, which this is built on
- @Frazzle for mumble-voip (for which the concept came from)
- @pichotm for pVoice (where the grid concept came from)

---

## Building the UI

The resource runs as-is — `ui/` is committed pre-built. You only need Node to change the UI.

```bash
npm run install:ui   # installs voice-ui dependencies
npm run build:ui     # rebuilds ui/ from voice-ui/
npm test             # lua syntax + server logic + headless UI smoke test
```

`npm test` needs `lua5.4` on `PATH` and a Chromium for Playwright; point
`CHROMIUM_PATH` at your own binary if the default location doesn't exist.

---

## FiveM/RedM audio config

### NOTE: Only use one of the audio options (don't enable 3D audio and native audio at the same time). It's also recommended to always use `voice_useSendingRangeOnly`.

You only need to add a convar **if** you're changing the value. All of these are set with
`setr [voice_configOption] [boolean]`. Native audio will not work on RedM — use 3D audio.

| ConVar | Default | Description | Parameter(s) |
|---|---|---|---|
| voice_useNativeAudio | false | **This will not work for RedM.** Uses the game's native audio: 3D sound, echo, reverb and more. **Required for submixes.** | boolean |
| voice_use2dAudio | false | Uses 2D audio — the same volume no matter where a player is, until they leave proximity. | boolean |
| voice_use3dAudio | false | Uses 3D audio. | boolean |
| voice_useSendingRangeOnly | false | Only lets you hear people within your hear/send range. Prevents people connecting directly to your Mumble server and trolling. | boolean |

## Config

### PLEASE NOTE: Keybind changes only affect new players. To change your own bind go to Key Bindings → FiveM → look for the binds under 'I-Voice'.

All config is done via ConVars. The ints are used as booleans, so 0 is false and 1 is true.
Set them with `setr [voice_configOption] [int]` or `setr [voice_configOption] "[string]"`.

#### Note: if a convar defaults to 1 (true) you don't have to set it again unless you want to disable it.

### General voice settings

| ConVar | Default | Description | Parameter(s) |
|---|---|---|---|
| voice_enableUi | 1 | Enables the built in user interface. Players can also toggle it in `/voicesettings`. | int |
| voice_enableProximityCycle | 1 | Enables the proximity cycle key; if disabled players are stuck on the first proximity. | int |
| voice_defaultCycle | F11 | The key to cycle proximity. Valid keys are [in the Cfx docs](https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/). | string |
| voice_defaultVoiceMode | 2 | Proximity mode a player starts on (1: Whisper, 2: Normal, 3: Shouting). | int |
| voice_defaultRadioVolume | 30 | Starting radio volume, 1-100. Players who have set their own volume keep it. | int |
| voice_defaultPhoneVolume | 60 | Starting phone volume, 1-100. | int |
| voice_defaultMegaphoneVolume | 80 | Starting megaphone volume, 1-100. | int |
| voice_defaultSettingsKey | *(unbound)* | Optional key bind for `/voicesettings`. | string |

### Phone, radio & megaphone

| ConVar | Default | Description | Parameter(s) |
|---|---|---|---|
| voice_enableRadios | 1 | Enables the radio sub-modules. | int |
| voice_enablePhones | 1 | Enables the phone sub-modules. | int |
| voice_enableMegaphone | 1 | Enables the megaphone module. | int |
| voice_megaphoneRange | 40 | How far a megaphone carries, in game units. | int |
| voice_defaultMegaphone | CAPITAL | The key to hold to talk over a megaphone. | string |
| voice_maxSecondaryChannels | 3 | How many extra radio channels a player may monitor at once. | int |
| voice_syncPlayerNames | 0 | Sends player names to everyone on a channel so the overlay can name whoever is transmitting. | int |
| voice_enableSubmix | 1 | Applies the radio/phone/megaphone submix to voices. **Submixes require native audio.** | int |
| voice_enableRadioAnim | 0 | Plays the grab-shoulder-mic animation while talking on the radio. | int |
| voice_disableVehicleRadioAnim | 0 | Suppresses that animation while the player is in a vehicle. | int |
| voice_defaultRadio | LMENU | The key to hold to talk on the radio. | string |

### Sync

| ConVar | Default | Description | Parameter(s) |
|---|---|---|---|
| voice_refreshRate | 200 | How often the UI/proximity loop runs, in ms. Falls back to `voice_uiRefreshRate`. | int |

### External server & misc.

| ConVar | Default | Description | Parameter(s) |
|---|---|---|---|
| voice_allowSetIntent | 1 | Whether players may set their audio intent (see [the native docs](https://docs.fivem.net/natives/?_0x6383526B)). | int |
| voice_externalAddress | none | External address used to connect to the Mumble server. | string |
| voice_externalPort | 0 | External port to use. | int |
| voice_debugMode | 0 | 1 for basic logs, 4 for verbose logs. | int |
| voice_externalDisallowJoin | 0 | Blocks players joining the server. Only use this if the server is acting as an external Mumble server. | int |
| voice_hideEndpoints | 1 | Hides the Mumble address in logs. *You should only care to hide this for an external server.* | int |
| voice_warnPmaVoiceCompat | 1 | Warns at startup when `exports['pma-voice']` won't resolve. See [COMPATIBILITY.md](COMPATIBILITY.md). | int |
| voice_resourceName | *(auto)* | Read by the pma-voice shim to locate I-Voice. Only needed if auto-detection fails. | string |

---

## Commands

| Command | Description |
|---|---|
| `/voicesettings` | Opens the settings panel. |
| `/vol [0-100] (radio\|phone\|megaphone)` | Sets a volume. Omit the type to set all of them. |
| `/micclicks` | Toggles radio mic clicks. |
| `/voiceblock [id]` | Silences a player for you only. Run it again to unblock; run it with no id to list. |
| `/voiceunblockall` | Clears your block list. |
| `/radiomonitor [channel]` | Starts or stops monitoring an extra radio channel. |
| `/cycleproximity` | Cycles whisper → normal → shout. |
| `/setvoiceintent [speech\|music]` | Tells Mumble what you're transmitting. |
| `/muteply [id] (seconds)` | **Server, ace-gated.** Mutes a player, by default for 900 seconds. |

### Aces

`/muteply` is ace-gated so only your staff can use it:

```
add_ace group.superadmin command.muteply allow;
```

---

## Exports

Examples assume the resource folder is named `I-Voice`.

### Client — setters

| Export | Description | Parameter(s) |
|---|---|---|
| [setVoiceProperty](docs/client-setters/setVoiceProperty.md) | Set config options | string, any |
| [setRadioChannel](docs/client-setters/setRadioChannel.md) | Set the transmit radio channel | int |
| [addSecondaryRadioChannel](docs/client-setters/secondaryRadioChannels.md) | Monitor an extra channel | int |
| [removeSecondaryRadioChannel](docs/client-setters/secondaryRadioChannels.md) | Stop monitoring a channel | int |
| [leaveAllRadioChannels](docs/client-setters/secondaryRadioChannels.md) | Drop every channel | |
| [setCallChannel](docs/client-setters/setCallChannel.md) | Set call channel | int |
| [setRadioVolume](docs/client-setters/setRadioVolume.md) | Set radio volume for the player | int |
| [setCallVolume](docs/client-setters/setCallVolume.md) | Set call volume for the player | int |
| [setMegaphoneVolume](docs/client-setters/megaphone.md) | Set megaphone volume for the player | int |
| [setMegaphoneActive](docs/client-setters/megaphone.md) | Raise or lower the megaphone | boolean |
| [setMegaphoneAllowed](docs/client-setters/megaphone.md) | Gate the megaphone behind your own job/inventory logic | boolean |
| [setSettingsOpen](docs/client-setters/settings.md) | Open or close the settings panel | boolean |
| [setVoiceSetting](docs/client-setters/settings.md) | Change a persisted setting | string, any |
| [addPlayerToRadio](docs/client-setters/setRadioChannel.md) | Set radio channel | int |
| [addPlayerToCall](docs/client-setters/setCallChannel.md) | Set call channel | int |
| [removePlayerFromRadio](docs/client-setters/removePlayerFromRadio.md) | Remove the player from the radio | |
| [removePlayerFromCall](docs/client-setters/removePlayerFromCall.md) | Remove the player from the call | |
| [overrideProximityRange](docs/client-setters/setVoiceProperty.md) | Pin the talk range to a custom value | number, boolean |
| [clearProximityOverride](docs/client-setters/setVoiceProperty.md) | Undo the above | |
| [setVoiceState](docs/routingBuckets.md) | Switch between proximity and a fixed channel | string, int |

### Client — getters

| Export | Description | Return |
|---|---|---|
| getRadioChannel | The channel the player transmits on | int |
| [getRadioChannels](docs/client-setters/secondaryRadioChannels.md) | Every channel the player receives, primary first | table |
| [getRadioTalkers](docs/client-getters/radioTalkers.md) | Everyone transmitting, as `{ id, name, channel }` | table |
| isOnRadioChannel | Whether the player is on a channel | boolean |
| getCallChannel / getCallMembers | Current call and its members | int / table |
| getRadioVolume / getCallVolume / getMegaphoneVolume | Current volumes, 0-1 | number |
| [isMegaphoneActive](docs/client-setters/megaphone.md) | Whether the player's megaphone is up | boolean |
| [getVoiceSettings](docs/client-setters/settings.md) | Every persisted setting | table |
| getBlockedPlayers / isPlayerBlocked | The local block list | table / boolean |
| getVoiceState | `'proximity'` or `'channel'` | string |

### Client — toggles

| Export | Description | Parameter(s) |
|---|---|---|
| toggleMutePlayer | Toggles a player silenced for the local client. Returns the new state. | int |
| clearBlockedPlayers | Lifts every block. | |
| toggleRadioAnim | Toggles the radio animation. Returns the new state. | |

Supported from mumble-voip / toko-voip:

| Export | Description | Parameter(s) |
|---|---|---|
| [SetMumbleProperty](docs/client-setters/setVoiceProperty.md) | Set config options | string, any |
| [SetTokoProperty](docs/client-setters/setVoiceProperty.md) | Set config options | string, any |
| [SetRadioChannel](docs/client-setters/setRadioChannel.md) | Set radio channel | int |
| [SetCallChannel](docs/client-setters/setCallChannel.md) | Set call channel | int |

### Client — state bags

| State Bag | Description | Return Type |
|---|---|---|
| [proximity](docs/state-getters/stateBagGetters.md) | The mode index, distance, and mode name | table |
| [radioChannel](docs/state-getters/stateBagGetters.md) | The player's transmit channel, or 0 | int |
| [secondaryRadioChannels](docs/state-getters/stateBagGetters.md) | Channels the player is monitoring | table |
| [callChannel](docs/state-getters/stateBagGetters.md) | The player's call channel, or 0 | int |
| [megaphoneActive](docs/state-getters/stateBagGetters.md) | Whether the player has a megaphone up | boolean |
| [voiceIntent](docs/state-getters/stateBagGetters.md) | `'speech'` or `'music'` | string |

### Client — events

Designed for third-party integration; emitted only to the local client.

| Event | Description | Event Params |
|---|---|---|
| [ivoice:settingsCallback](docs/client-getters/events.md) | Returns the current settings when emitted. | cb(voiceSettings) |
| [ivoice:radioActive](docs/client-getters/events.md) | The radio was keyed up or released. | boolean |
| [ivoice:megaphoneActive](docs/client-getters/events.md) | The megaphone was raised or lowered. | boolean |
| [ivoice:setTalkingMode](docs/client-getters/events.md) | Proximity mode changed. | int |
| [ivoice:toggleRadioAnim](docs/client-getters/events.md) | The radio animation was toggled. | boolean |
| [ivoice:settingChanged](docs/client-setters/settings.md) | A persisted setting changed. | string, any |

### Server — setters

| Export | Description | Parameter(s) |
|---|---|---|
| [setPlayerRadio](docs/server-setters/setPlayerRadio.md) | Sets a player's transmit channel | int, int |
| [addPlayerSecondaryRadio](docs/server-setters/secondaryRadioChannels.md) | Adds a monitored channel | int, int |
| [removePlayerSecondaryRadio](docs/server-setters/secondaryRadioChannels.md) | Removes a monitored channel | int, int |
| [setPlayerCall](docs/server-setters/setPlayerCall.md) | Sets a player's call channel | int, int |
| [setMegaphoneState](docs/server-setters/megaphone.md) | Raises or lowers a player's megaphone | int, boolean |
| [setPlayerMuted](docs/server-setters/muting.md) | Mutes a player, optionally for a duration | int, boolean, int |
| [addChannelCheck](docs/server-setters/addChannelCheck.md) | Gates a radio channel behind a callback | int, function |
| [removeChannelCheck](docs/server-setters/addChannelCheck.md) | Removes that gate | int |
| [setChannelLimit](docs/server-setters/addChannelCheck.md) | Caps how many players fit on a channel | int, int |
| [overrideRadioNameGetter](docs/server-setters/addChannelCheck.md) | Changes how radio display names are resolved | function |

### Server — getters

| Export | Description | Parameter(s) |
|---|---|---|
| [getPlayersInRadioChannel](docs/server-getters/getPlayersInRadioChannel.md) | Everyone on a radio channel | int |
| [getRadioChannelInfo](docs/server-getters/getRadioChannelInfo.md) | Member count, talkers and monitors for a channel | int |
| [getActiveRadioChannels](docs/server-getters/getRadioChannelInfo.md) | Every channel with someone on it | |
| getPlayersInCall | Everyone on a call channel | int |
| [getMegaphoneUsers](docs/server-setters/megaphone.md) | Everyone with a megaphone raised | |
| isPlayerUsingMegaphone | Whether a player has a megaphone raised | int |
| isPlayerMuted | Whether a player is muted | int |

### Server — events

| Event | Description | Event Params |
|---|---|---|
| ivoice:playerJoinedRadio | A player joined a channel | source, channel, isMonitorOnly |
| ivoice:playerLeftRadio | A player left a channel | source, channel |
| ivoice:playerRadioTalking | A player keyed up or released | source, channel, talking |
| ivoice:playerJoinedCall / ivoice:playerLeftCall | Call membership changed | source, channel |
| ivoice:playerMegaphone | A player raised or lowered a megaphone | source, active |
| [ivoice:playerMuted](docs/server-setters/muting.md) | A player was muted or unmuted | target, invoker, muted, duration |

---

## Fixed from pma-voice

- `getRadioAnimState` returned an undefined global rather than the animation state.
- The `onResourceStop` handler in the server radio module referenced an out-of-scope
  variable, throwing whenever any resource stopped.
- `overrideRadioNameGetter` took a spurious `channel` argument and its type check accepted
  anything that wasn't a function reference. The old two-argument form is still accepted.
- The proximity loop read `voice_refreshRate`, but the manifest only declared
  `voice_uiRefreshRate`; both are honoured now.
- Dead `isTarget` branch in the proximity loop, and the local player was distance-checked
  against themselves every tick.
- `-radiotalk` mixed `and`/`or` precedence, so it could fire with no channel set.
- Changing call channel repeatedly stacked one push-to-talk thread per change.
- Volume state bags were seeded with 0-100 ints server side but overwritten with 0-1 floats
  client side, so the same bag meant different things depending on whether the player had
  touched their volume. They are 0-100 everywhere now; `getRadioVolume` / `getCallVolume`
  still return a 0-1 float as before.
- A channel check that threw took the join with it; checks are now sandboxed.
- Empty radio and call channels were never reclaimed.
- The radio animation dictionary could spin forever if it failed to load.
- The mute timer applied its state twice and never cleared on disconnect.

## Licence

Inherits pma-voice's licensing; see the upstream project for details.
