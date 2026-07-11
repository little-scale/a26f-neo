# A26F NEO

An Atari 2600 MIDI and sample-playback interface driven by an RP2040 Pico.

The project is split into four parts:

- `protocol/`: the shared Pico-to-Atari wire protocol.
- `atari/`: PAL Atari 2600 ROM source and builds.
- `pico/`: class-compliant USB MIDI firmware for an RP2040 Pico board.
- `web/`: the fully offline sample-bank ROM patcher.

## Fixed hardware targets

- Original PAL50 hardware is the primary target; NTSC builds are generated too.
- UnoCart-compatible SD flashcart, configured for PAL.
- 32 KiB F4 production ROM (`.f4`).
- RP2040 Pico-compatible 40-pin board with USB-C, built as `PICO_BOARD=pico`.
- Controller port 2 carries clock, data, and ground only.

## Current milestone

The PAL and NTSC ROMs provide stable displays, background activity feedback, a
five-bank controller-port-1 sound check, a scanline-safe controller-port-2
serial receiver, two AR envelope engines, and 4-bit sample playback in the 32K
F4 builds. The Pico firmware builds as a class-compliant USB MIDI device. The
offline patcher converts WAV files and replaces all 32 ROM sample slots.

## Build the diagnostic ROMs

```sh
make -C atari
```

Outputs include 4K diagnostic ROMs and production `a26f-pal.f4` and
`a26f-ntsc.f4` images.

## Build the Pico firmware

The project uses Pico SDK 2.3.0 and the Arm GNU toolchain. With
`PICO_SDK_PATH` and the compiler available:

```sh
cmake -S pico -B pico/build -DPICO_BOARD=pico
cmake --build pico/build
```

Flash `pico/build/a26f_neo.uf2` by holding BOOTSEL while connecting the Pico,
then copying the UF2 to the mounted `RPI-RP2` drive.

## Build and use the offline patcher

```sh
node web/build.mjs
```

Open `web/a26f-rom-patcher.html` directly in a browser. Choose a production F4
ROM, choose or mass-drop up to 32 WAV files, preview their actual 4-bit
conversion, select gated or one-shot playback for each slot, and create the
patched `.bin` ROM. No web server or network connection is used.
