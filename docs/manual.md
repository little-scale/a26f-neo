# A26F NEO Manual

Version: development main branch  
Primary television target: PAL50  
Secondary target: NTSC

## 1. Introduction

A26F NEO is a MIDI and sample-playback system for the Atari 2600. A
Pico-compatible RP2040 board appears to a computer as a class-compliant USB
MIDI device. It translates MIDI into a compact serial stream delivered to
controller port 2. A custom Atari ROM receives that stream and controls both
TIA audio voices.

The instrument provides:

- Two monophonic TIA synth voices
- MIDI-controlled attack and release envelopes
- 32 wrapped drum-sample slots
- Four-bit ROM-resident sample playback
- Gated and one-shot samples
- Joystick-only soundcheck operation
- Audio-reactive background colour
- Offline ROM and factory-bank creation

The Pico does not act as a USB host. It must be connected to a computer or
other USB host that sends MIDI to **A26F NEO**.

## 2. Safety and electrical requirements

### Read before connecting hardware

- Power off the Atari and disconnect the Pico before changing wiring.
- Do not connect Atari controller-port 5 V to the Pico.
- Do not connect Pico GPIO directly to Atari controller-port inputs.
- Use the documented two-transistor open-collector interface.
- Confirm the pinout of the exact NPN transistors being used. A 2N3904 and a
  BC547 commonly have different lead arrangements.
- Check DB9 numbering from the connector side you are actually viewing.
- A26F NEO shares ground between the USB-powered Pico and Atari port 2.

The design is unidirectional. The Pico controls two NPN transistor bases. The
Atari's existing controller-port pull-ups create the released/high state, while
the transistors can safely pull the inputs low.

## 3. Required equipment

- Original Atari 2600 or compatible system
- PAL console and PAL ROM for the primary configuration, or matching NTSC pair
- UnoCart-compatible SD flashcart with the correct PAL/NTSC setting
- RP2040 Pico-compatible 40-pin board, configured as `PICO_BOARD=pico`
- Two small-signal NPN transistors, such as 2N3904 or BC547
- Two 4.7 kΩ base resistors
- Atari-compatible male DB9 plug or controller cable
- USB data cable
- Computer with a MIDI-capable DAW, sequencer, or test utility
- Joystick in controller port 1 for local soundcheck

Optional but recommended:

- Multimeter
- Logic analyser or oscilloscope
- Breadboard for the first prototype

## 4. Hardware connection

### Atari controller port 2

| DB9 pin | Atari function | A26F function |
|---:|---|---|
| 1 | Up, `SWCHA` bit 3 | Clock |
| 2 | Down, `SWCHA` bit 2 | Data |
| 8 | Ground | Common ground |

No other controller-port connection is required.

### Pico GPIO

| Pico signal | Default GPIO |
|---|---:|
| Data | GP2 |
| Clock | GP3 |

### Transistor stages

Build one identical stage for data and one for clock:

```text
Pico GPIO ── 4.7 kΩ ──► NPN base
                            collector ──► Atari controller input
Pico GND ───────────────── emitter
```

Connections:

1. GP2 through 4.7 kΩ to the data transistor base.
2. Data transistor collector to Atari port 2 pin 2.
3. GP3 through 4.7 kΩ to the clock transistor base.
4. Clock transistor collector to Atari port 2 pin 1.
5. Both transistor emitters to Pico GND.
6. Pico GND to Atari port 2 pin 8.

The stages invert both signals. Use `a26f_neo_npn.uf2`, which is compiled with:

```c
#define A26F_LINK_OUTPUT_INVERTED 1
```

Use `a26f_neo_noninverting.uf2` only with a suitable level-shifting interface
that preserves the Pico GPIO polarity. Both UF2 files use the same Atari ROM.

## 5. Atari ROMs

### Production ROMs

The production player is a 32 KiB F4 bankswitched image.

| Output | Purpose |
|---|---|
| `a26f-pal.f4` | Empty patchable PAL production ROM |
| `a26f-ntsc.f4` | Empty patchable NTSC production ROM |
| `a26f-pal-factory.bin` | PAL ROM populated from the selected factory bank |
| `a26f-ntsc-factory.bin` | NTSC ROM populated from the selected factory bank |

The `.f4` extension is convenient for forcing Stella's F4 mapper. UnoCart-style
flashcarts normally accept `.bin`, `.rom`, or `.a26`; the browser exports
`.bin` by default.

### Diagnostic ROMs

The 4 KiB PAL and NTSC images exercise the display, controller soundcheck,
serial receiver, and envelopes without sample bankswitching.

### Flashcart setup

1. Format the SD card as FAT or FAT32 if required by the flashcart.
2. Copy the matching ROM to the card.
3. Confirm the flashcart PAL/NTSC switch configuration.
4. Power off the Atari before inserting or removing the cartridge.
5. Select and launch the ROM from the flashcart menu.

Do not run a PAL ROM on an NTSC console, or an NTSC ROM on a PAL console, when
evaluating timing or pitch.

## 6. Flashing the Pico

Two UF2 files are produced unless another build directory was chosen:

| UF2 | Compile-time inversion | USB MIDI name |
|---|---:|---|
| `a26f_neo_npn.uf2` | `1` | `A26F NEO NPN` |
| `a26f_neo_noninverting.uf2` | `0` | `A26F NEO Non-Inverting` |

1. Disconnect the Pico.
2. Hold the BOOTSEL button.
3. Connect the Pico to the computer by USB.
4. Release BOOTSEL after the `RPI-RP2` drive appears.
5. Copy the UF2 matching the electrical interface to that drive.
6. The board reboots automatically.
7. Confirm that **A26F NEO NPN** or **A26F NEO Non-Inverting** appears as a
   MIDI device.

The firmware does not require a serial driver or MIDI driver on operating
systems that support class-compliant USB MIDI.

The Pico's onboard LED responds to incoming USB MIDI activity. This confirms
USB reception, not necessarily successful transfer to the Atari.

## 7. First tests

### Stella test

1. Load the PAL or NTSC production/factory ROM in Stella.
2. Confirm that Stella reports an F4 32K cartridge. If necessary, force
   `Cart.Type` to `F4` or use the `.f4` extension.
3. Use the emulated left joystick for controller port 1.
4. Test the four synth banks and sample bank described below.

Stella tests the ROM, bankswitching, samples, controls, and display. It does not
test the physical Pico-to-Atari link.

### Hardware test sequence

1. With the Pico disconnected, load a populated ROM and verify joystick audio.
2. Power everything off and inspect the three-wire interface.
3. Connect the Pico interface to controller port 2.
4. Power the Atari and connect the Pico to the computer by USB.
5. Select the labelled **A26F NEO** MIDI output in the DAW.
6. Send a channel 1 note and confirm voice 0 audio and colour response.
7. Send channel 2 and confirm voice 1.
8. Send channel 10 note 32 and confirm sample slot 0.
9. Test gated note-off behaviour.

## 8. MIDI operation

MIDI channel numbers below use the usual user-facing numbering from 1 to 16.

### Synth voices

| MIDI message | Result |
|---|---|
| Channel 1 | TIA voice 0 |
| Channel 2 | TIA voice 1 |
| CC1 | `AUDC = value >> 3` |
| Note number | `AUDF = note >> 2` |
| Note velocity | Peak `AUDV = velocity >> 3` |
| CC73 | Attack index `value >> 3` |
| CC72 | Release index `value >> 3` |

Each synth voice is monophonic. Note-off only releases a voice when its pitch
matches the currently active note. MIDI note-on with velocity zero is treated
as note-off.

The TIA is not chromatic in the conventional synthesizer sense. MIDI pitch is
deliberately reduced to the 5-bit TIA frequency range, and the 16 `AUDC` values
select very different tone/noise divider behaviours.

### Attack/release envelopes

The note-on velocity sets the peak amplitude. Attack moves toward that peak,
the note remains held while its MIDI gate is open, and note-off begins release.

Envelope indices select ticks per one-step amplitude change:

```text
0: instant     1: 1       2: 2       3: 3
4: 4           5: 6       6: 8       7: 12
8: 16          9: 24     10: 32     11: 48
12: 64        13: 96     14: 128    15: 192
```

An envelope tick occurs once per frame: 50 Hz PAL and approximately 60 Hz
NTSC. Total transition time also depends on how many of the 15 amplitude steps
must be crossed. Defaults are attack `0` and release `1`.

### Drum samples

- MIDI channel 10 triggers the sample player on TIA voice 1.
- `slot = MIDI note & 31`.
- Notes therefore wrap over the 32 slots four times across the MIDI range.
- Sample velocity is ignored.
- A new sample replaces the current sample.
- Exact source-note matching prevents stale note-offs from stopping a newer
  drum hit.

Examples:

| MIDI notes | Slot |
|---|---:|
| 0, 32, 64, 96 | 0 |
| 1, 33, 65, 97 | 1 |
| 31, 63, 95, 127 | 31 |

Gated samples respond to matching note-off and use a short de-click ramp.
One-shot samples ignore note-off and play to their natural end.

## 9. Controller port 1 soundcheck

Connect a joystick to controller port 1. Fire advances through five banks and
wraps from bank 4 to bank 0. Fire is edge-triggered, so press and release it for
each step.

| Bank | Directions |
|---:|---|
| 0 | `AUDC0` values 0–3 |
| 1 | `AUDC0` values 4–7 |
| 2 | `AUDC0` values 8–11 |
| 3 | `AUDC0` values 12–15 |
| 4 | Sample slots 0–3 |

In synth banks, Up, Right, Down, and Left select `AUDF0` values 4, 10, 18, and
28. In bank 4 those directions trigger slots 0, 1, 2, and 3 respectively.

Releasing a sample direction gates a gated sample off. A one-shot sample keeps
playing.

## 10. Visual feedback

The ROM uses the background colour as performance feedback:

- Each sample slot has a different hue.
- Sample amplitude controls background luminance.
- Synth voices 0 and 1 use different colour families.
- When both synth voices are active, the displayed family alternates.
- Silent incoming register changes produce a short colour indication.
- Joystick soundcheck banks retain distinct colours.

The visual system updates once per video frame so it does not disturb the
fixed two-scanline sample cadence.

## 11. Offline ROM patcher

Open `web/a26f-rom-patcher.html` directly in a modern browser. It is a
standalone local file and does not upload the ROM or audio.

### Create a custom ROM

1. Choose a matching empty or factory-populated A26F PAL or NTSC ROM.
   Existing sample slots are loaded into the editor and preserved by default.
2. Choose multiple WAVs or drag them onto the drop area.
3. Files are naturally sorted by filename into the first empty slots.
4. Choose gated or one-shot mode for each slot.
5. Use the play button to preview the actual converted 4-bit result.
6. Check the capacity meter.
7. Select **Create ROM**.

The converter accepts standard PCM or 32-bit float WAV input, mixes multiple
channels to mono, optionally trims near-silence, normalizes, filters while
downsampling, applies short fades, and packs two 4-bit amplitude samples per
byte.

Processing options apply when a WAV is loaded. Reload a WAV after changing an
option if that slot must be converted again.

### Sample limits

- Maximum individual sample: 3,840 packed bytes
- Maximum individual duration: approximately 0.98 seconds
- Total capacity: 26,880 packed bytes
- Total playback time: approximately 6.9 seconds

Samples may have different lengths. The tool assigns them to the seven payload
banks and refuses an arrangement that cannot fit.

When an existing ROM slot is imported, the ROM does not contain its original
filename or exact odd/even source-sample count, so it is labelled `ROM slot NN`
and previewed using its full packed-byte length. Its audio bytes and gate mode
are preserved. Replace that slot with a WAV if fresh PAL and NTSC factory
variants or a filename are required.

## 12. Factory banks

An `.a26factory` file is an instrument preset independent of a particular ROM
build. It stores:

- 32 ordered slots
- Sample names
- Gated/one-shot settings
- Prepared PAL and NTSC 4-bit variants
- Format version and CRC-32 checksum

### Browser workflow

After loading a compatible base ROM:

- **Export factory** saves the current instrument.
- **Import factory** restores all populated slots and selects the matching PAL
  or NTSC variants automatically.
- Imported samples remain previewable and editable.

### Source-build workflow

The repository includes `factory/default.a26factory`, populated with 16 808
samples.

```sh
make -C atari factory
```

Use a different bank:

```sh
make -C atari factory FACTORY=/path/to/instrument.a26factory
```

## 13. Building from source

### Atari toolchain

Requirements:

- DASM
- Node.js

Build and verify all base ROMs and the default-factory populated ROMs:

```sh
make -C atari clean all
```

The verifier checks exact ROM sizes, PAL/NTSC manifests, empty internal base
directories, and identical F4 common bankswitch stubs. The default build also
applies `factory/default.a26factory` to both television targets.

Build factory-populated ROMs:

```sh
make -C atari factory
```

### Pico toolchain

Requirements:

- CMake
- Ninja or Make
- Arm GNU embedded compiler with C library support
- Pico SDK 2.3.0 with TinyUSB

The repository import file expects the SDK at `pico/lib/pico-sdk` unless its
path is changed.

```sh
cmake -S pico -B pico/build -DPICO_BOARD=pico
cmake --build pico/build
```

### Rebuild the offline HTML

```sh
node web/build.mjs
```

The generated deliverable is `web/a26f-rom-patcher.html`.

### Software preflight

Before a hardware session, run:

```sh
make test
make test-pico
make test-stella
```

The first target rebuilds the Atari and browser outputs and runs deterministic
ROM/factory/converter tests. `test-pico` uses an isolated build directory and
checks both UF2 identities with picotool. `test-stella` verifies that all four
empty/populated PAL/NTSC production images are recognised as 32K F4 ROMs.

## 14. Troubleshooting

### Stella plays synth sounds but not samples

- Confirm the ROM is exactly 32,768 bytes.
- Confirm Stella reports `F4 (32K)`.
- Use a `.f4` extension or explicitly force the F4 cartridge type.
- Confirm slots 0–3 are populated before testing joystick bank 4.
- Confirm Fire was pressed and released four times from startup.

### ROM patcher rejects the ROM

- Use an A26F NEO 32K production ROM with a supported manifest version.
- Do not use the 4K diagnostic ROM as the patcher base.
- Match PAL/NTSC ROM selection to the intended console.

### Factory import fails

- Confirm the file ends in `.a26factory` and was produced by a compatible tool
  version.
- A checksum error means the factory file is incomplete or modified.
- A factory may also be rejected if its samples cannot fit the target layout.

### Pico does not appear as a MIDI device

- Try another USB data cable; many USB cables provide power only.
- Reflash the UF2 using BOOTSEL.
- Confirm the firmware was built for `PICO_BOARD=pico`.
- Check the MIDI device list for **A26F NEO NPN** or
  **A26F NEO Non-Inverting**.

### Pico LED reacts but Atari does not

- USB MIDI reception is working; focus on the physical link.
- Confirm common ground to Atari port 2 pin 8.
- Confirm GP2 is data and GP3 is clock.
- Confirm transistor collector/emitter orientation.
- Confirm both 4.7 kΩ base resistors.
- Confirm the `npn` UF2 is used with the two-NPN stages, or the `noninverting`
  UF2 with a suitable non-inverting interface.
- Confirm the Atari ROM is the current A26F build.

### Notes stick

- Confirm the DAW sends note-off on the same MIDI channel and pitch.
- MIDI note-on velocity zero is accepted as note-off.
- The synth and drum handlers intentionally ignore stale, nonmatching
  note-offs.

### Gated drum does not stop

- Confirm the slot is set to **Gated**, not **One-shot**.
- The note-off pitch must exactly match the most recent triggering MIDI note,
  even when two different pitches wrap to the same slot.

## 15. Technical reference

- [PAL hardware bring-up checklist](hardware-test-checklist.md)
- [Three-wire electrical interface](../hardware/wiring.md)
- [Wire and MIDI protocol](../protocol/protocol.md)
- [ROM format](../protocol/rom-format.md)
- [Factory format](../protocol/factory-format.md)

## 16. Current project status

Software builds and emulator testing are operational. The current engineering
priority is complete validation and tuning on original PAL hardware, followed
by NTSC hardware confirmation.
