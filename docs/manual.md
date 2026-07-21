# A26F NEO Manual

Current public release: v0.11

Next development version: v0.12

Primary television target: PAL50

Secondary target: NTSC

Product numbering is independent of the protocol and file-format versions.
The next planned releases are v0.12, v0.13, and so on.

## 1. Introduction

A26F NEO is a MIDI and sample-playback system for the Atari 2600. A
Pico-family board appears to a computer as a class-compliant USB
MIDI device. It translates MIDI into a compact serial stream delivered to
controller port 2. A custom Atari ROM receives that stream and controls both
TIA audio voices.

The instrument provides:

- Two monophonic TIA synth voices
- Switchable attack-hold-release and attack-decay envelopes
- 32 wrapped drum-sample slots
- Four-bit ROM-resident sample playback
- Gated and one-shot samples
- Global 1×, 2×, and 4× sample playback rates
- Joystick-only soundcheck operation
- Sixteen-band receive-history visualization with no black rows
- Offline ROM and factory-bank creation

The Pico does not act as a USB host. It must be connected to a computer or
other USB host that sends MIDI to **A26F NEO**.

## 2. Safety and electrical requirements

### Read before connecting hardware

- Power off the Atari and disconnect the Pico before changing wiring.
- Do not connect Atari controller-port 5 V to the Pico.
- Do not connect Pico GPIO directly to Atari controller-port inputs.
- Use one of the documented NPN or TXS0108E level-shifting interfaces.
- Confirm the pinout of the exact NPN transistors being used. A 2N3904 and a
  BC547 commonly have different lead arrangements.
- Check DB9 numbering from the connector side you are actually viewing.
- A26F NEO shares ground between the USB-powered Pico and Atari port 2.

The design is unidirectional. With the NPN interface, the Pico controls two
transistor bases and the Atari's controller-port pull-ups create the
released/high state. With the TXS0108E interface, the translator provides the
3.3 V-to-5 V boundary and GP4 keeps it disabled until data and clock are
initialized. The Atari ROM only reads these pins in either arrangement.

## 3. Required equipment

- Original Atari 2600 or compatible system
- PAL console and PAL ROM for the primary configuration, or matching NTSC pair
- F4-capable SD flashcart with the correct PAL/NTSC setting; current testing
  uses a Superior 4 Bit Flashcard V2
- Raspberry Pi Pico-family board; the current hardware is a Pico 2 W built as
  `PICO_BOARD=pico2_w`
- Either two small-signal NPN transistors plus two 4.7 kΩ base resistors, or a
  TXS0108E module with suitable decoupling and OE pulldown
- Atari-compatible male DB9 plug or controller cable
- USB data cable
- Computer with a MIDI-capable DAW, sequencer, or test utility
- Joystick in controller port 1 for local soundcheck

For optional traditional MIDI input:

- Female 5-pin 180-degree DIN socket or 3.5 mm TRS socket wired as Type A
- 6N138 optocoupler
- 220 ohm, 2.2 kohm, 47 kohm, and 1 kohm resistors
- 1N4148 or 1N914 diode
- 100 nF ceramic capacitor
- LED for valid mapped-message indication

Optional but recommended:

- Multimeter
- Logic analyser or oscilloscope
- Breadboard for the first prototype

## 4. Hardware connection

### Atari controller port 2

| DB9 pin | Atari function | A26F function |
|---:|---|---|
| 1 | Up, `SWCHA` bit 0 | Clock |
| 2 | Down, `SWCHA` bit 1 | Data |
| 8 | Ground | Common ground |

No other controller-port connection is required for the NPN interface. The
TXS0108E interface also uses controller-port pin 7 for its 5 V-side supply.

### Pico GPIO

| Pico signal | GPIO | Pico header pin |
|---|---:|---:|
| Data | GP2 | 4 |
| Clock | GP3 | 5 |
| TXS0108E output enable | GP4 | 6 |
| Traditional MIDI UART receive | GP5 | 7 |
| Valid mapped-MIDI LED | GP6 | 9 |
| TXS0108E VCCA supply | `3V3(OUT)` | 36 |

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

### TXS0108E non-inverting interface

The non-inverting UF2 controls the TXS0108E output-enable input from GP4. Power
the translator's low-voltage rail from the Pico's regulated `3V3(OUT)` pin.

| TXS0108E connection | Connect to |
|---|---|
| `VCCA` / `VA` | Pico `3V3(OUT)`, header pin 36 |
| `OE` | Pico GP4, header pin 6; add 10 kOhm to ground if the module has no OE pulldown |
| `A1` | Pico GP2 data |
| `A2` | Pico GP3 clock |
| `VCCB` / `VB` | Atari controller port pin 7, +5 V |
| `B1` | Atari controller port 2 pin 2, data |
| `B2` | Atari controller port 2 pin 1, clock |
| `GND` | Pico ground and Atari controller port 2 pin 8 |

GP4 holds the translator disabled while GP2 and GP3 are initialized, then goes
high to enable it. The NPN UF2 does not configure GP4. The TXS0108E module
should include local supply decoupling; otherwise add 100 nF from VCCA to
ground and 100 nF from VCCB to ground close to the IC. Use Pico header pin 36,
labelled `3V3(OUT)`; do not use the adjacent `3V3_EN` pin.

This arrangement uses Atari pin 7 for the translator's 5 V side, so it is a
four-wire controller-port interface. Do not substitute a TXB0108 module and do
not connect Pico GPIO directly to the Atari inputs.

### Traditional MIDI input

The same production UF2 accepts opto-isolated 31.25 kbit/s MIDI on GP5/UART1
while USB MIDI remains active. Use the complete circuit and connector mapping
in [Traditional MIDI input](../hardware/midi-input.md).

For a 6N138 breadboard circuit, use a 220-ohm MIDI-loop resistor and 1N4148
reverse diode on the isolated input side. Power 6N138 pin 8 from Pico VBUS/5 V,
connect pin 5 to Pico ground, bypass pins 8 and 5 with 100 nF, connect pin 7 to
ground through 47 kohm, and connect pin 6 to GP5 with a 2.2-kohm pull-up from
pin 6 to Pico `3V3(OUT)`. Do not pull the GP5 signal up to 5 V.

For the activity indicator, connect GP6 through 1 kohm to the LED anode and
connect the cathode to Pico ground. It lights for approximately 35 ms when a
mapped A26F message is accepted from USB or traditional MIDI.

DIN pin 2 or the TRS sleeve must not have a direct DC connection to Pico
ground. For TRS, use Type A: ring is DIN pin 4/current source and tip is DIN
pin 5/current sink.

## 5. Atari ROMs

### Production ROMs

The production player is a 32 KiB F4 bankswitched image. There are exactly two
ROM outputs:

| Output | Purpose |
|---|---|
| `a26f-pal.bin` | PAL ROM, default factory samples, and receive-history display |
| `a26f-ntsc.bin` | NTSC ROM, default factory samples, and receive-history display |

Both images always contain the sixteen-band receive-history visualization and
are populated from `factory/default.a26factory`. The offline browser can replace
their samples and export another `.bin` without changing the player code.

### Flashcart setup

1. Format the SD card as FAT or FAT32 if required by the flashcart.
2. Copy the matching ROM to the card.
3. Confirm the flashcart PAL/NTSC switch configuration.
4. Power off the Atari before inserting or removing the cartridge.
5. Select and launch the ROM from the flashcart menu.

Do not run a PAL ROM on an NTSC console, or an NTSC ROM on a PAL console, when
evaluating timing or pitch.

## 6. Flashing the Pico

Each board build produces two USB MIDI UF2 files. The release bundle contains
both interface variants for the original Pico and Pico 2 W:

| Board | Bundled UF2 | Compile-time inversion | USB MIDI name |
|---|---|---:|---|
| Pico | `a26f-pico-npn.uf2` | `1` | `A26F NEO NPN` |
| Pico | `a26f-pico-noninverting.uf2` | `0` | `A26F NEO Non-Inverting` |
| Pico 2 W | `a26f-pico2w-npn.uf2` | `1` | `A26F NEO NPN` |
| Pico 2 W | `a26f-pico2w-noninverting.uf2` | `0` | `A26F NEO Non-Inverting` |

Local build outputs use the shorter `a26f_neo_*.uf2` names inside
`pico/build-pico/` and `pico/build-pico2w/`.

1. Disconnect the Pico.
2. Hold the BOOTSEL button.
3. Connect the Pico to the computer by USB.
4. Release BOOTSEL after the board's USB mass-storage boot drive appears.
5. Copy the UF2 matching the electrical interface to that drive.
6. The board reboots automatically.
7. Confirm that **A26F NEO NPN** or **A26F NEO Non-Inverting** appears as a
   MIDI device.

The firmware does not require a serial driver or MIDI driver on operating
systems that support class-compliant USB MIDI.

The GP6 activity LED, and the onboard LED where supported by the board,
respond to mapped MIDI received over USB or the traditional UART input. This
confirms Pico reception, not necessarily successful transfer to the Atari.

### Diagnostic UF2 files

The same Pico build includes two hardware-test images:

| UF2 | Behaviour |
|---|---|
| `a26f_neo_link_test.uf2` | No USB MIDI; cycles GP2/GP3 through `00`, `10`, `01`, and `11` every 1.5 seconds |
| `a26f_neo_protocol_test.uf2` | No USB MIDI; runs a six-second raw-pin preflight, then sends a repeating normal-speed tone/sample command sequence |

The autonomous images can be powered from an isolated USB power bank when
separating host-computer grounding from link problems. They target the
non-inverting TXS0108E wiring and drive OE from GP4.

## 7. First tests

### Stella test

1. Load `a26f-pal.bin` or `a26f-ntsc.bin` in Stella.
2. Confirm that Stella reports an F4 32K cartridge. If necessary, force
   `Cart.Type` to `F4`.
3. Use the emulated left joystick for controller port 1.
4. Test the four synth banks and sample bank described below.

Stella tests the ROM, bankswitching, samples, controls, and display. It does not
test the physical Pico-to-Atari link.

### Hardware test sequence

1. With the Pico disconnected, load a populated ROM and verify joystick audio.
2. Power everything off and inspect the selected controller-port interface.
3. Connect the Pico interface to controller port 2.
4. Power the Atari and connect the Pico to the computer by USB.
5. Select the labelled **A26F NEO** MIDI output in the DAW.
6. Send a channel 1 note and confirm voice 0 audio and colour response.
7. Send channel 2 and confirm voice 1.
8. Send channel 10 note 32 and confirm sample slot 0.
9. Test gated note-off behaviour.
10. Confirm pitch and amplitude commands occupy separate history bands.
11. If traditional MIDI is fitted, disconnect the DAW's USB MIDI route, send
    the same messages through DIN/TRS, and confirm identical audio, colour,
    and GP6 LED response.

## 8. MIDI operation

MIDI channel numbers below use the usual user-facing numbering from 1 to 16.
USB MIDI and opto-isolated GP5 UART MIDI use the same mapping and may remain
active simultaneously. If both sources control one A26F channel, the most
recent event wins.

### Synth voices

| MIDI message | Result |
|---|---|
| Channel 1 | TIA voice 0 |
| Channel 2 | TIA voice 1 |
| CC1 | `AUDC = value >> 3` |
| Note number | `AUDF = 31 - (note & 31)`; adjacent notes rise and wrap every 32 notes |
| Note velocity | Peak `AUDV = velocity >> 3` |
| Pitch bend | Changes only AUDF over its full range and clamps at 0 or 31 |
| CC70 | Envelope mode: 0-63 attack-hold-release, 64-127 attack-decay |
| CC73 | Attack index `value >> 3` |
| CC72 | Release/decay index `value >> 3` |

Each synth voice is monophonic. Note-off only releases a voice when its pitch
matches the currently active note. MIDI note-on with velocity zero is treated
as note-off. Both voices default to `AUDC = 4`, so a note is audible before any
CC1 message is sent; CC1 replaces the default for its MIDI channel.

The TIA is not chromatic in the conventional synthesizer sense. MIDI pitch is
deliberately reduced to the 5-bit TIA frequency range, and the 16 `AUDC` values
select very different tone/noise divider behaviours.

Pitch bend centre is 8192. Upward bend lowers the divider and raises the
audible pitch; downward bend raises the divider. The full wheel covers 32
steps, clamps at the register limits, and never wraps. Bend changes only the
pitch register and is retained when the next note is played.

The Pico suppresses repeated quantized values and replaces stale unsent
AUDC/AUDF/AUDV or envelope updates with the newest value. Drum triggers and
gate-off events retain their original order and are not deduplicated.

### Envelope modes

The note-on velocity sets the peak amplitude. Each voice independently defaults
to attack-hold-release: attack moves toward the peak, the note remains held
while its MIDI gate is open, and a matching note-off begins release.

CC70 values 64-127 select attack-decay. The voice attacks to the velocity peak
and immediately decays toward zero using the CC72 rate. Note-off is ignored for
amplitude in this mode, although it still clears the Pico's active-note
tracking. Values 0-63 restore attack-hold-release. A mode change applies to new
notes; it does not reshape a note already in progress.

Envelope indices select ticks per one-step amplitude change:

```text
0: instant     1: 1       2: 2       3: 3
4: 4           5: 6       6: 8       7: 12
8: 16          9: 24     10: 32     11: 48
12: 64        13: 96     14: 128    15: 192
```

An envelope tick occurs once per frame: 50 Hz PAL and approximately 60 Hz
NTSC. Total transition time also depends on how many of the 15 amplitude steps
must be crossed. Defaults are attack `0`, release/decay `1`, and
attack-hold-release mode.

### Drum samples

- MIDI channel 10 triggers the sample player on TIA voice 1.
- `slot = MIDI note & 31`.
- Notes therefore wrap over the 32 slots four times across the MIDI range.
- Empty slots produce no sample audio. If one replaces an active sample, the
  normal short de-click stop runs before the latest channel 2 synthesizer state
  is restored.
- Sample velocity is ignored.
- A new sample replaces the current sample.
- Exact source-note matching prevents stale note-offs from stopping a newer
  drum hit.
- Channel 10 CC20 selects the global playback rate: 0–42 is 1×, 43–84 is 2×,
  and 85–127 is 4×. The default is 1×.
- Rate changes take effect during playback at the next packed sample-pair
  boundary. The TIA amplitude-update cadence remains approximately 7.8 kHz;
  faster modes skip source pairs and intentionally sound more aliased.

Examples:

| MIDI notes | Slot |
|---|---:|
| 0, 32, 64, 96 | 0 |
| 1, 33, 65, 97 | 1 |
| 31, 63, 95, 127 | 31 |

Gated samples respond to matching note-off and use a short de-click ramp.
One-shot samples ignore note-off and play to their natural end.

## 9. Receive-history visualization

Both production ROMs retain the complete synthesizer, envelope, sample-player,
and controller-port soundcheck while displaying raw receive history.

- The sixteen horizontal bands correspond to the sixteen physical slots in
  the Atari receive ring.
- A completed link byte changes its ring slot's band and remains there until
  that slot is reused sixteen bytes later.
- The command byte is written directly to the TIA background-colour register,
  with the lowest visible luminance bit forced on. Its command group therefore
  strongly affects hue while every row remains visible, including empty slots
  and values whose raw TIA luminance would be zero. This is a fingerprint, not
  a hexadecimal display, because TIA colour ignores the byte's lowest bit and
  the visualizer deliberately adjusts one luminance bit.
- The bands fill the complete picture width; the RX visualizer draws no
  playfield blocks, sprites, or text over them.
- PAL uses fourteen scanlines per band and extends the final band by four
  remaining scanlines; NTSC uses twelve scanlines per band exactly.

If a slot is later overwritten with the identical raw byte, its correct new
representation is the same colour, so that particular rewrite may not appear
to change visually.

The visualizer reuses the live receive ring rather than copying bytes into a
second log. Sixteen visible-area serial polls are traded for colour-update
lines each frame, but PCM sample ticks and the total PAL/NTSC scanline counts
remain unchanged. Polling during the rest of the frame is still substantially
faster than the Pico link clock.

## 10. Controller port 1 soundcheck

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

## 11. Visual feedback

The sixteen receive-history bands described in section 9 are the sole
production display. PAL and NTSC use the same visual design with their own
scanline counts; no separate static or alternate visualizer ROM is required.

## 12. Offline ROM patcher

Open `web/a26f-rom-patcher.html` directly in a modern browser. It is a
standalone local file and does not upload the ROM or audio.

### Create a custom ROM

1. Choose the matching A26F PAL or NTSC production ROM.
   Existing sample slots are loaded into the editor and preserved by default.
2. Choose multiple WAVs or drag them onto the drop area.
3. Files are naturally sorted by filename into the first empty slots.
4. Choose gated or one-shot mode for each slot.
5. Set global gain and optional tanh shaping, then use the play button to
   preview the actual converted 4-bit result.
6. Check the capacity meter.
7. Select **Create ROM**.

The converter accepts standard PCM or 32-bit float WAV input, mixes multiple
channels to mono, optionally trims near-silence, normalizes, filters while
downsampling, applies global gain, optionally applies tanh shaping, adds short
fades, and packs two 4-bit amplitude samples per byte.

Global gain ranges from 0 dB to +60 dB and defaults to 0 dB. It follows the
optional normalization stage and feeds the tanh stage directly:

```text
WAV → trim → resample → optional normalize → gain → optional tanh → fades → clamp → 4-bit
```

Changing Auto-trim, Normalize, Gain, or Tanh immediately reconverts every
WAV-backed slot into both PAL and NTSC variants. The audition button, ROM
export, and factory export then use the updated packed data. Samples imported
from an existing ROM or `.a26factory` file have no source WAV and remain
unchanged until replaced; their audition still represents their exact packed
4-bit data.

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

## 13. Factory banks

An `.a26factory` file is an instrument preset independent of a particular ROM
build. It stores:

- 32 ordered slots
- Sample names
- Gated/one-shot settings
- Prepared PAL and NTSC 4-bit variants
- Format version and CRC-32 checksum

### Browser workflow

After loading the matching production ROM:

- **Export factory** saves the current instrument.
- **Import factory** restores all populated slots and selects the matching PAL
  or NTSC variants automatically.
- Imported samples remain previewable and editable.

### Source-build workflow

The repository includes the current prepared sample bank at
`factory/default.a26factory`.

```sh
make -C atari
```

Use a different bank:

```sh
make -C atari FACTORY=/path/to/instrument.a26factory
```

## 14. Building from source

### Atari toolchain

Requirements:

- DASM
- Node.js

Build and verify both default-factory production ROMs:

```sh
make -C atari clean all
```

The verifier checks exact ROM sizes, PAL/NTSC manifests, factory-populated
sample directories, and identical F4 common bankswitch stubs. The only ROM
outputs are `atari/build/a26f-pal.bin` and `atari/build/a26f-ntsc.bin`.

### Pico toolchain

Requirements:

- CMake
- Ninja or Make
- Arm GNU embedded compiler with C library support
- Pico SDK 2.3.0 with TinyUSB

The repository import file expects the SDK at `pico/lib/pico-sdk` unless its
path is changed.

```sh
cmake -S pico -B pico/build-pico2w -DPICO_BOARD=pico2_w
cmake --build pico/build-pico2w
```

For an original RP2040 Pico, use `PICO_BOARD=pico` and a different build
directory so the two architectures cannot be confused.

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
ROM/factory/converter tests. `test-pico` uses an isolated original-Pico
RP2040 build directory and checks both production UF2 identities with picotool;
the Pico 2 W build is made separately with `PICO_BOARD=pico2_w`. `test-stella`
checks the two PAL/NTSC production images and their F4 mapper identification.

### Prepare a release bundle

```sh
make release
```

This runs the Atari, browser, Stella, original Pico, and Pico 2 W checks,
including the host serial-MIDI parser tests, then
creates a versioned directory and zip archive under `dist/`. See
`docs/release-checklist.md` for bundle contents and the final hardware checks.

## 15. Troubleshooting

### Stella plays synth sounds but not samples

- Confirm the ROM is exactly 32,768 bytes.
- Confirm Stella reports `F4 (32K)`.
- Explicitly force the F4 cartridge type if Stella does not detect it.
- Confirm slots 0–3 are populated before testing joystick bank 4.
- Confirm Fire was pressed and released four times from startup.

### ROM patcher rejects the ROM

- Use an A26F NEO 32K production ROM with a supported manifest version.
- Match PAL/NTSC ROM selection to the intended console.

### Factory import fails

- Confirm the file ends in `.a26factory` and was produced by a compatible tool
  version.
- A checksum error means the factory file is incomplete or modified.
- A factory may also be rejected if its samples cannot fit the target layout.

### Pico does not appear as a MIDI device

- Try another USB data cable; many USB cables provide power only.
- Reflash the UF2 using BOOTSEL.
- Confirm the firmware matches the board: `pico2_w` for Pico 2 W or `pico` for
  the original Pico.
- Check the MIDI device list for **A26F NEO NPN** or
  **A26F NEO Non-Inverting**.

### MIDI activity LED reacts but Atari does not

- Mapped MIDI reception is working; focus on the physical Atari link.
- Confirm common ground to Atari port 2 pin 8.
- Confirm GP2 is data and GP3 is clock.
- Confirm transistor collector/emitter orientation.
- Confirm both 4.7 kΩ base resistors.
- Confirm the `npn` UF2 is used with the two-NPN stages, or the `noninverting`
  UF2 with a suitable non-inverting interface.
- Confirm the Atari ROM is the current A26F build.

### Traditional MIDI does not light GP6

- Confirm the source sends 31.25 kbit/s MIDI, not analogue sync or audio.
- Confirm GP5 idles near 3.3 V and falls toward 0 V during incoming data.
- Confirm the 6N138 has 5 V between pins 8 and 5.
- Confirm the pin-6 pull-up goes to 3V3(OUT), not 5 V.
- Confirm the DIN or TRS Type A source/sink orientation and reverse diode.
- Confirm the message uses an A26F mapped channel and control.

### Notes stick

- Confirm the DAW sends note-off on the same MIDI channel and pitch.
- MIDI note-on velocity zero is accepted as note-off.
- The synth and drum handlers intentionally ignore stale, nonmatching
  note-offs.

### Gated drum does not stop

- Confirm the slot is set to **Gated**, not **One-shot**.
- The note-off pitch must exactly match the most recent triggering MIDI note,
  even when two different pitches wrap to the same slot.

### Receive-history bands do not change

- Confirm the current `a26f-pal.bin` or `a26f-ntsc.bin` is running.
- A MIDI note normally produces separate pitch and amplitude command bytes.
- If the MIDI activity LED reacts but no bands change, verify GP2 data and GP3 clock at
  controller port 2 with a meter, logic analyser, or oscilloscope.
- Very dark bands are valid, but the RX visualizer forces a minimum luminance
  and should not create black rows. A black row therefore suggests an older
  visualizer ROM or a display/capture issue.

## 16. Technical reference

- [PAL hardware bring-up checklist](hardware-test-checklist.md)
- [Controller-port electrical interface](../hardware/wiring.md)
- [Wire and MIDI protocol](../protocol/protocol.md)
- [ROM format](../protocol/rom-format.md)
- [Factory format](../protocol/factory-format.md)

## 17. Current project status

Software builds and emulator testing are operational. Original PAL hardware
has passed joystick, USB MIDI synth, pitch-bend, sample-playback, and
receive-history visualization tests using the Pico 2 W and TXS0108E interface.
NTSC hardware confirmation remains to be completed.
