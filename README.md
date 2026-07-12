# A26F NEO

A26F NEO turns an RP2040 Pico and a custom Atari 2600 ROM into a
class-compliant USB MIDI instrument with two TIA synth voices, 4-bit drum
sample playback, audio-reactive colour, and a fully offline sample-bank tool.

PAL50 hardware is the primary target. Matching NTSC firmware-independent ROMs
and sample variants are built from the same source.

> A26F NEO is currently an experimental hardware project. Use the documented
> open-collector interface; do not connect Pico GPIO directly to Atari inputs.

## What is implemented

- USB MIDI device firmware for a Pico-compatible RP2040 board
- Three-wire unidirectional controller-port link: clock, data, and ground
- MIDI channels 1 and 2 mapped to the two TIA audio voices
- Attack/release amplitude envelopes controlled by MIDI CC
- 32 wrapped MIDI drum slots on channel 10
- Packed 4-bit PCM playback at approximately 7.8 kHz
- Per-sample gated or one-shot operation
- 32K Atari F4 bankswitching with PAL and NTSC targets
- Five-bank joystick soundcheck, including sample slots 0–3
- Audio-reactive background colour feedback
- Offline WAV conversion, preview, ROM patching, and mass drag-and-drop
- Portable `.a26factory` banks containing ordered PAL and NTSC sample variants
- Included 16-slot 808 factory bank

## System overview

```text
Computer / DAW
    │ USB MIDI
    ▼
RP2040 Pico ── clock + data + ground ──► Atari controller port 2
                                              │
                                              ▼
                                      A26F NEO F4 ROM
                                              │
                                   TIA audio + colour output
```

The Pico is a USB MIDI **device**, not a USB host. The Atari only reads port 2;
it never changes the link pins to outputs.

## Start here

- [User and builder manual](docs/manual.md)
- [Safe three-wire interface](hardware/wiring.md)
- [MIDI and wire protocol](protocol/protocol.md)
- [Patchable ROM format](protocol/rom-format.md)
- [Factory-bank format](protocol/factory-format.md)

## Repository layout

| Path | Purpose |
|---|---|
| `atari/` | 6507/TIA source, PAL/NTSC 4K diagnostics, and 32K F4 ROMs |
| `pico/` | RP2040 class-compliant USB MIDI firmware |
| `web/` | Single-file offline ROM and factory-bank tool |
| `factory/` | Default prepared sample bank and build instructions |
| `hardware/` | Electrical interface documentation |
| `protocol/` | Wire, ROM, and factory format specifications |
| `tools/` | ROM verification and factory application utilities |

## Build Atari ROMs

Requirements: DASM and Node.js.

```sh
make -C atari
```

Important outputs:

- `atari/build/a26f-pal.f4`
- `atari/build/a26f-ntsc.f4`
- `atari/build/a26f-pal-4k.bin`
- `atari/build/a26f-ntsc-4k.bin`
- `atari/build/a26f-pal-factory.bin`
- `atari/build/a26f-ntsc-factory.bin`

The normal build always creates populated PAL and NTSC ROMs from
`factory/default.a26factory`. To rebuild only the factory outputs, use:

```sh
make -C atari factory
```

This creates:

- `atari/build/a26f-pal-factory.bin`
- `atari/build/a26f-ntsc-factory.bin`

Use another exported factory bank with:

```sh
make -C atari factory FACTORY=/path/to/instrument.a26factory
```

## Build Pico firmware

The current target is `PICO_BOARD=pico` with Pico SDK 2.3.0.

```sh
cmake -S pico -B pico/build -DPICO_BOARD=pico
cmake --build pico/build
```

The build creates two explicitly labelled firmware images:

| UF2 | Interface | USB MIDI name |
|---|---|---|
| `a26f_neo_npn.uf2` | Recommended two-NPN open-collector stages | `A26F NEO NPN` |
| `a26f_neo_noninverting.uf2` | Suitable non-inverting level shifter | `A26F NEO Non-Inverting` |

Hold BOOTSEL while connecting the board, then copy the appropriate UF2 onto
the mounted `RPI-RP2` drive.

## Offline sample and factory tool

Rebuild the standalone HTML file with:

```sh
node web/build.mjs
```

Open `web/a26f-rom-patcher.html` directly—no server or internet connection is
required. It can:

- Validate PAL/NTSC A26F ROM versions
- Choose or mass-drop up to 32 WAV files
- Auto-trim, normalize, filter, resample, and quantize audio
- Preview the actual converted 4-bit result
- Set gated or one-shot mode per slot
- Create a flashcart-compatible `.bin` ROM
- Load and preserve samples already present in a populated A26F ROM
- Import or export a checksummed `.a26factory` instrument bank

## Hardware summary

The recommended link uses two NPN open-collector stages:

| Signal | Pico | Atari port 2 |
|---|---:|---:|
| Data | GP2 | DB9 pin 2 |
| Clock | GP3 | DB9 pin 1 |
| Ground | GND | DB9 pin 8 |

The two transistor stages invert the signals, so use the `npn` UF2. The
`noninverting` UF2 is only for a suitable interface which preserves GPIO
polarity. See the [manual](docs/manual.md) before wiring.

## MIDI summary

| Input | Action |
|---|---|
| Channel 1 | TIA voice 0 |
| Channel 2 | TIA voice 1 |
| CC1 | TIA sound control (`value >> 3`) |
| Note pitch | TIA frequency (`note >> 2`) |
| Velocity | Peak amplitude (`velocity >> 3`) |
| CC73 | Attack index |
| CC72 | Release index |
| Channel 10 notes | Sample slot `note & 31` |

Samples ignore velocity. Note-on with velocity zero is treated as note-off.

## Status and testing

PAL/NTSC Atari images, F4 stubs, manifests, directories, factory checksums,
browser conversion, and Pico firmware builds are verified automatically. The
next project milestone is end-to-end validation on original PAL hardware.

## Author

little-scale — seb.tomczak@gmail.com
