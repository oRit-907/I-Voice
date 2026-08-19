# pma-voice compatibility shim

A tiny resource that claims the `pma-voice` name and forwards every export to
I-Voice, so scripts calling `exports['pma-voice']:setRadioChannel(1)` keep working
when the I-Voice folder is named something else.

**You only need this if your I-Voice folder is *not* named `pma-voice`.** Naming the
folder `pma-voice` is the simpler option and needs no shim at all.

## Install

1. Copy this `pma-voice` folder into your resources directory. The folder **must** be
   named `pma-voice` — that name is the whole point.
2. Start it after I-Voice:

   ```cfg
   ensure I-Voice
   ensure pma-voice
   ```

The shim finds I-Voice by looking for the started resource whose manifest declares
`name 'I-Voice'`, so the folder name doesn't matter. If you'd rather be explicit:

```cfg
set voice_resourceName "my-voice-folder"
```

## What it does and doesn't do

It forwards **exports** only. Event compatibility (`pma-voice:radioActive`,
`pma-voice:setPlayerRadio` and friends) is built into I-Voice itself and works whether
or not this shim is installed.

Do **not** run this alongside the real pma-voice — two resources cannot share a name.

See [COMPATIBILITY.md](../../COMPATIBILITY.md) for the full compatibility matrix.
