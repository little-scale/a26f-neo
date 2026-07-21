# A26F NEO

A26F NEO is a MIDI interface for the Atari 2600. 

You'll need: An Atari 2600 console with a flashcart or EEPROM cart, a Raspberry Pi Pico 2W, wires, a two channel level shifter or two NPN transistors, 

In the [release bundle](https://github.com/little-scale/a26f-neo/releases) you'll find: 
- The ROM images for the Atari 2600 (a26f-ntsc.bin and a26f-pal.bin, both will fit into a 32KB of space) - tested and working with a Unocart clone
- The Pico 2 files (a26f-pico2w-noninverting.uf2 for use with a level shifter and a26f-pico2w-npn.uf2 for use with two NPN transistors) - tested with a stock Pico2W
- The browser-based sample patcher (a26f-rom-patcher.html - load up the ROM and add your own samples!)

<img width="1280" height="720" alt="atari_2600_setup_a26f-neo2" src="https://github.com/user-attachments/assets/14db985f-b0d5-4d41-8832-381d56d987e6" />
Note that connecting the Pico 2W can be connected to the Atari 2600 directly: 
- Pico ground -> Atari 2600 port 2 pin 8 (black wire)
- Pico GP 2 (data) --> Atari 2600 port 2 pin 2 (grey wire)
- Pico GP3 (clock) --> Atari 2600 port 2 pin 1 (white wire)

This will work (even without NPN or level shifter) and I have tried it extensively however the safety of the Pico GPIO pins cannot be guaranteed as they may be exposed to 5V. But it works fine for me for now. 

The process is as follow: 
- Upload the ROM to the flashcart or EEPROM cart
- Connect the Pico 2W to a computer, this will show up as a USB MIDI device in a DAW
- Connect the Pico 2W to the Atari 2600 controller port 2
- Run the ROM on the Atari 2600
- Send MIDI data from the DAW to the Pico 2W
- Monitor the audio from the Atari 2600 to hear the notes being played

The MIDI mapping is as follows: 

- MIDI channels 1 and 2 are mapped to TIA sound channels 0 and 1
- Pitches wrap around every 32 notes; pitchbend will change the pitch as well
- Velocity controls amplitude and is scalled to one of 16 levels
- CC1 will set the sound of the TIA channel to one of 16 choices
- CC73 will set the attack time of the TIA channel to one of 16 choices
- CC72 will set the release rate of the TIA channel to one of 16 choices
- CC70 will set envelope behaviour of the envelope; <= 63 and note offs are respected, > 63 and notes offs are ignores, the release begins immediately after the attack
- Sending MIDI notes on channel 10 will trigger one shot drum samples. The samples are stored in the Atari 2600 ROM and can be added to or replaced by using the browser patcher tool in releases. Note that playing a sample will consume TIA channel 1 for the duration of that sample playback.
- CC20 on MIDI channel 10 will set the drum sample playback rate to 1x, 2x or 4x


Tested on PAL50 hardware (Atari 2600 Jr). ROM image supplied for NTSC as well, untested on hardware but appears to be running fine under emulation (Stella). 

Current public release: **v0.1**

> A26F NEO is an experimental hardware project. Use the documented
> level-shifting interface; do not connect Pico GPIO directly to Atari inputs

## What is implemented

- USB MIDI device firmware for RP2040 and RP2350 Pico-family boards
- Three-signal unidirectional link: clock, data, and common ground
- MIDI channels 1 and 2 mapped to the two TIA audio voices
- Switchable attack-hold-release and attack-decay envelopes controlled by MIDI CC
- 32 wrapped MIDI drum slots on channel 10
- Packed 4-bit PCM playback at approximately 7.8 kHz
- Per-sample gated or one-shot operation
- Global 1×, 2×, and 4× sample playback-rate control via channel 10 CC20
- 32K Atari F4 bankswitching with PAL and NTSC targets
- Five-bank joystick soundcheck, including sample slots 0–3
- Sixteen-band receive-history visualization with no black rows
- Offline WAV conversion, preview, ROM patching, and mass drag-and-drop
- Portable `.a26factory` banks containing ordered PAL and NTSC sample variants
- Included prepared PAL/NTSC factory sample bank

## System overview

```text
Computer / DAW
    │ USB MIDI
    ▼
Pico 2 W ── clock + data + ground ──► Atari controller port 2
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
- [PAL hardware bring-up checklist](docs/hardware-test-checklist.md)
- [Safe controller-port interface](hardware/wiring.md)
- [MIDI and wire protocol](protocol/protocol.md)
- [Patchable ROM format](protocol/rom-format.md)
- [Factory-bank format](protocol/factory-format.md)
- [Release checklist](docs/release-checklist.md)
- [Changelog](CHANGELOG.md)

## Repository layout

| Path | Purpose |
|---|---|
| `atari/` | 6507/TIA source and the PAL/NTSC 32K F4 ROMs |
| `pico/` | Pico/Pico 2 class-compliant USB MIDI firmware |
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

The build creates exactly two production ROMs:

- `atari/build/a26f-pal.bin`
- `atari/build/a26f-ntsc.bin`

Both are 32 KiB F4 images, include the sixteen-band receive-history display,
and are populated from `factory/default.a26factory`.

Use another exported factory bank with:

```sh
make -C atari FACTORY=/path/to/instrument.a26factory
```

The display maps the receiver's 16-byte ring to sixteen horizontal colour
bands while retaining MIDI synthesis, envelopes, joystick soundcheck, and
sample playback. Each byte remains visible until its ring position is reused.
Minimum luminance is forced on, so no band is black. Both ROMs can be loaded,
edited, and exported by the offline browser tool.

## Build Pico firmware

The current hardware target is Raspberry Pi Pico 2 W (`pico2_w`, RP2350) with
Pico SDK 2.3.0.

```sh
cmake -S pico -B pico/build-pico2w -DPICO_BOARD=pico2_w
cmake --build pico/build-pico2w
```

The original RP2040 Pico remains supported by selecting `PICO_BOARD=pico` and
using a separate build directory.

The build creates two explicitly labelled firmware images:

| UF2 | Interface | USB MIDI name |
|---|---|---|
| `a26f_neo_npn.uf2` | Recommended two-NPN open-collector stages | `A26F NEO NPN` |
| `a26f_neo_noninverting.uf2` | TXS0108E or suitable non-inverting level shifter; GP4 controls OE | `A26F NEO Non-Inverting` |

Hold BOOTSEL while connecting the board, then copy the appropriate UF2 onto
the mounted boot drive.

### Hardware diagnostic firmware

The Pico build also creates:

| UF2 | Purpose |
|---|---|
| `a26f_neo_link_test.uf2` | Cycles raw GP2/GP3 states for wiring checks |
| `a26f_neo_protocol_test.uf2` | Autonomous normal-speed register/sample sequence |

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
- Apply global 0 dB to +60 dB gain and optional tanh shaping
- Preview the actual converted 4-bit result
- Set gated or one-shot mode per slot
- Create a flashcart-compatible `.bin` ROM
- Load and preserve samples already present in a populated A26F ROM
- Import or export a checksummed `.a26factory` instrument bank

## Hardware summary

The logical link uses these three signals:

| Signal | Pico | Atari port 2 |
|---|---:|---:|
| Data | GP2 | DB9 pin 2 |
| Clock | GP3 | DB9 pin 1 |
| Ground | GND | DB9 pin 8 |

The NPN option inverts both signals and uses the `npn` UF2. The currently
tested Pico 2 W hardware uses a TXS0108E and the `noninverting` UF2, with GP4
providing sequenced OE, VCCA from Pico `3V3(OUT)`, and VCCB from Atari pin 7.
That power connection makes the TXS arrangement four physical controller-port
wires even though the protocol itself has three signals. See the
[manual](docs/manual.md) before wiring. Never connect Pico GPIO directly to
the Atari inputs.

## MIDI summary

| Input | Action |
|---|---|
| Channel 1 | TIA voice 0 |
| Channel 2 | TIA voice 1 |
| CC1 | TIA sound control (`value >> 3`) |
| Note pitch | Inverted TIA divider (`31 - (note & 31)`, wrapping every 32 notes) |
| Velocity | Peak amplitude (`velocity >> 3`) |
| Pitch bend | Moves only AUDF across the full 0-31 range; clamps without wrapping |
| CC70 | Envelope mode (`0-63` attack-hold-release, `64-127` attack-decay) |
| CC73 | Attack index |
| CC72 | Release/decay index |
| Channel 10 notes | Sample slot `note & 31` |
| Channel 10 CC20, 0–42 | Sample playback at 1× |
| Channel 10 CC20, 43–84 | Sample playback at 2× |
| Channel 10 CC20, 85–127 | Sample playback at 4× |

The drum mapping always wraps across all 32 physical slots. Empty slots emit
no sample audio; if one replaces an active sample, the normal de-click stop
runs before the latest channel 2 synthesizer state is restored.

Both synth voices boot with sound control 4. CC1 replaces that default for its
channel.

The Pico keeps quantized shadow state for both voices. Duplicate register
writes are suppressed, and a newer unsent value replaces an older queued value
for the same TIA register. Sample triggers remain ordered events.

Samples ignore velocity. Note-on with velocity zero is treated as note-off.

## Status and testing

The PAL and NTSC Atari images, F4 stubs, manifests, directories, factory checksums,
browser conversion, and Pico firmware builds are verified automatically.
Original PAL hardware now passes controller soundcheck, USB MIDI synth,
pitch-bend, and factory-sample playback tests through the Pico 2 W and
non-inverting TXS0108E interface. The receive-history visualizer also performs
well on PAL hardware; NTSC hardware validation remains pending.

Run the software preflight checks with:

```sh
make test          # ROM, factory, patcher, WAV and corruption tests
make test-pico     # clean dual-UF2 build plus picotool/USB-name checks
make test-stella   # PAL/NTSC and F4 mapper smoke matrix
```

Prepare the complete versioned release bundle with:

```sh
make release
```

This uses `VERSION` for the output name, currently creating
`dist/a26f-neo-v0.11/` and `dist/a26f-neo-v0.11.zip`, including the
two production ROMs, two Pico 2 W interface UF2s, offline patcher, default
factory, documentation, and SHA-256 checksums.

## Author

little-scale — seb.tomczak@gmail.com

## License

[MIT](LICENSE) — Copyright (c) 2026 little-scale.
