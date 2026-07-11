# A26F NEO

An Atari 2600 MIDI and sample-playback interface driven by an RP2040 Pico.

The project is split into four parts:

- `protocol/`: the shared Pico-to-Atari wire protocol.
- `atari/`: PAL Atari 2600 ROM source and builds.
- `pico/`: class-compliant USB MIDI firmware for an RP2040 Pico board.
- `browser/`: the fully offline sample-bank ROM patcher.

## Fixed hardware targets

- Original PAL50 hardware is the primary target; NTSC builds are generated too.
- UnoCart-compatible SD flashcart, configured for PAL.
- 32 KiB F4 production ROM (`.f4`).
- RP2040 Pico-compatible 40-pin board with USB-C, built as `PICO_BOARD=pico`.
- Controller port 2 carries clock, data, and ground only.

## Current milestone

The 4 KiB diagnostic ROM provides stable PAL and NTSC displays, background
activity feedback, a five-bank controller-port-1 sound check, a scanline-safe
controller-port-2 serial receiver, and two AR envelope engines. The production
F4 sample ROM builds on this kernel.

## Build the diagnostic ROMs

```sh
make -C atari
```

The outputs are `atari/build/a26f-pal-4k.bin` and
`atari/build/a26f-ntsc-4k.bin`.
