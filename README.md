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

The first milestone is a 4 KiB PAL diagnostic ROM. It provides a stable PAL
display, background-colour activity feedback, and a controller-port-1 TIA
sound check. The serial receiver and F4 sample ROM build on this kernel.

## Build the diagnostic ROMs

```sh
make -C atari
```

The outputs are `atari/build/a26f-pal-4k.bin` and
`atari/build/a26f-ntsc-4k.bin`.
