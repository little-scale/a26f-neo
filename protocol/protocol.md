# A26F wire and MIDI protocol

Protocol version: `1.1`

## Physical link

The link is unidirectional. The Pico drives two controller-port-2 inputs and
the Atari only polls them.

| Signal | Atari controller port 2 | Pico default |
|---|---:|---:|
| Clock | pin 1 (up), `SWCHA` bit 0 | GP3 |
| Data | pin 2 (down), `SWCHA` bit 1 | GP2 |
| Ground | pin 8 | GND |

Supported safe interfaces include two NPN open-collector stages and the
documented TXS0108E arrangement. The NPN stages invert their input. The Pico
firmware has one compile-time flag,
`A26F_LINK_OUTPUT_INVERTED`, which applies to both clock and data:

```c
#define A26F_LINK_OUTPUT_INVERTED 1
```

Set it to `1` for the NPN interface and `0` only for a suitable non-inverting
3.3 V-to-5 V interface. The TXS0108E build also drives OE from GP4 after
initializing the link pins. Direct connection to the Atari inputs is not the
recommended electrical implementation.

Standard builds are labelled `a26f_neo_npn.uf2` (`1`) and
`a26f_neo_noninverting.uf2` (`0`). Both produce the same logical wire protocol
and use the same Atari ROM.

## Bit transfer

- Bytes are sent most-significant bit first.
- The Pico sets data before changing clock.
- Every clock transition transfers one bit; there is no preferred edge.
- Clock remains at its new level until the next bit.
- Conservative hardware target: 1,000 microseconds between clock changes
  (1 kbit/s), with data stable for 250 microseconds before each transition.
- A 5,000-microsecond inter-byte gap permits the Atari to discard a partial
  byte and restore alignment before every command.
- The Pico must never produce two clock changes inside the Atari's maximum
  polling interval.

The Pico owns pacing and queues complete commands. Replaceable register writes
may be coalesced so that only their newest queued value is transmitted.

### Diagnostic timing profile

The optional ultra-slow profile uses 100,000 microseconds per clock transition,
25,000 microseconds of data setup, and a 500,000-microsecond inter-byte gap.
Its Atari ROM uses a correspondingly longer RIOT idle timeout. It exists only
for electrical diagnosis and must not be mixed with a normal-speed endpoint.

The Atari restarts a RIOT timer on every observed clock transition. A long idle
period resets only partial-byte shift state; complete commands already in its
16-byte receive ring remain queued. Pending extended-envelope selection is
preserved across the normal byte gap so its value byte remains valid.

## One-byte commands

Most commands use the upper three bits as an operation and the lower five bits
as its value.

| Range | Operation | Value |
|---|---|---|
| `00-1F` | Set `AUDC0` | low 4 bits |
| `20-3F` | Set `AUDF0` | 5 bits |
| `40-5F` | Set voice 0 target amplitude/gate | low 4 bits |
| `60-7F` | Set `AUDC1` | low 4 bits |
| `80-9F` | Set `AUDF1` | 5 bits |
| `A0-BF` | Set voice 1 target amplitude/gate | low 4 bits |
| `C0-DF` | Trigger sample slot | 5 bits |
| `E0-E3`, `E5-E6` | Select extended envelope parameter | see below |
| `E4` | Reset/resynchronise command parser | no value |
| `F0-FF` | Envelope value when a selection is pending | low 4 bits |
| `F0` | Gate off the current gated sample |

Amplitude commands are envelope gates: a nonzero value begins attack toward
that peak; zero begins release. In attack-decay mode the ROM changes the target
to zero after reaching the peak. The Pico filters stale MIDI note-off events
and omits matching note-off amplitude commands in attack-decay mode.

### Envelope parameter pair

An envelope change is a validated two-byte pair:

```text
1110PPPP  select parameter
1111VVVV  set value
```

- `E0`: voice 0 attack.
- `E1`: voice 0 release/decay.
- `E2`: voice 1 attack.
- `E3`: voice 1 release/decay.
- `E5`: voice 0 mode (`0` attack-hold-release, `1` attack-decay).
- `E6`: voice 1 mode (`0` attack-hold-release, `1` attack-decay).
- `VVVV`: time-table index 0-15 for a time parameter, or 0/1 for mode.

`E4` remains reserved for parser reset.

The normal inter-byte idle gap does not cancel a pending parameter selection.
The Pico queues each selector/value pair atomically. A value completes the
pair, while `E4` explicitly resets pending parser state.

## MIDI mapping

### Synth voices

| MIDI input | Result |
|---|---|
| Channel 1 | TIA voice 0 |
| Channel 2 | TIA voice 1 |
| CC1 | `AUDC = value >> 3` |
| Note number | `AUDF = 31 - (note & 31)`; adjacent notes rise and wrap every 32 notes |
| Velocity | peak amplitude `velocity >> 3` |
| Pitch bend | Offset current note AUDF by the full 32-step range and clamp to 0-31 |
| CC70 | envelope mode: 0-63 attack-hold-release, 64-127 attack-decay |
| CC73 | attack index `value >> 3` |
| CC72 | release/decay index `value >> 3` |

Note-on velocity zero is note-off. A note-off only closes the gate if its note
matches the currently active monophonic note on that MIDI channel. In
attack-decay mode the amplitude starts decaying as soon as attack reaches the
velocity peak, and note-off clears note tracking without changing amplitude.

Both ROM voices boot with `AUDC = 4`, so notes are audible without first
sending CC1. CC1 replaces that default independently for each voice.

Pitch bend is channel-local and changes only AUDF. MIDI centre 8192 applies no
offset. Upward bend subtracts from AUDF (raising audible frequency); downward
bend adds to AUDF. Both extremes span 32 divider steps, with the result clamped
at 0 or 31 rather than wrapped. The wheel position is retained for the next
note.

The Pico shadows the quantized TIA state. Equal values are not transmitted.
For direct AUDC/AUDF/AUDV writes, a new value replaces an older unsent value
for that same register. Envelope select/value pairs are similarly coalesced.
Sample trigger and gate-off messages remain ordered events and are never
deduplicated. Queue-overflow recovery discards stale pending bytes, sends a
parser reset, invalidates scheduled shadows, and replays desired synth state.
Attack-decay note-ons force a new amplitude command even when their quantized
velocity matches the previous peak, because the Atari autonomously returns its
target to zero after each decay.

Default envelope mode is attack-hold-release. Default indices are attack `0`
(instant) and release/decay `1`. Envelopes
run once per frame: 50 Hz on PAL and approximately 60 Hz on NTSC.

Indices select ticks per one-step amplitude change:

```text
0: instant     1: 1       2: 2       3: 3
4: 4           5: 6       6: 8       7: 12
8: 16          9: 24     10: 32     11: 48
12: 64        13: 96     14: 128    15: 192
```

### Drum samples

- MIDI channel 10 triggers ROM-resident samples on TIA voice 1.
- `slot = MIDI note & 31`, wrapping all 128 notes over 32 slots.
- Empty slots produce no sample audio. If a sample is already active, selecting
  an empty slot follows the normal short de-click stop before voice 1 returns
  to its latest synthesizer state.
- Sample velocity is ignored, except velocity zero is note-off.
- The Pico records the exact triggering MIDI note for gate matching.
- A new sample replaces the currently playing sample.
- Gated is the default per-sample mode; one-shot is optional.
- A gated sample stops only for note-off of its exact triggering note.
- Gate-off uses a maximum 15-sample de-click ramp before restoring voice 1.

## Television timing

- PAL: 312 scanlines, 50 Hz frames, 50 Hz envelope ticks, and approximately
  7,812.5 four-bit PCM samples/second.
- NTSC: 262 scanlines, approximately 60 Hz frames, approximately 60 Hz
  envelope ticks, and approximately 7,867.1 four-bit PCM samples/second.
- Four-bit PCM updates occur every two scanlines on both targets.
- Samples are unsigned 4-bit amplitude values, packed two per ROM byte.
- The ROM patch manifest identifies PAL or NTSC; the browser resamples to the
  rate declared by the loaded ROM.

## Controller port 1 sound check

Fire advances through five local banks and wraps to bank 0:

- Banks 0-3 cover `AUDC0` values 0-15 in numeric order.
- Up, right, down, and left use `AUDF0` values 4, 10, 18, and 28.
- Bank 4 maps those directions to sample slots 0, 1, 2, and 3.
- Direction press is a local note/sample gate-on; release is gate-off.
- The sample bank uses the same gated/one-shot flags as MIDI triggering.
- Local control temporarily owns the affected TIA voice while preserving its
  latest MIDI state for restoration.

## Receive-history visualization

The production ROM's sixteen horizontal bands read the existing sixteen-byte
receive ring directly. This presentation does not alter the wire protocol. A
byte becomes visible after successful assembly and ring insertion, remains in
that physical slot after command execution, and is replaced when the writer
wraps to the same slot sixteen bytes later.

Writing the same value into a slot again produces the same colour. The byte is
still represented, but that rewrite is not visually distinguishable from the
slot's previous identical value.

The raw byte is written to `COLUBK`, so the TIA displays bits 7-1 as hue and
luminance while ignoring bit 0. It is therefore a command fingerprint rather
than an injective 256-colour encoding. The playfield, players, and missiles
remain disabled so the result is sixteen unobstructed full-width bands. PCM
tick cadence and PAL/NTSC frame length are unchanged; one visible-area
serial-poll line per band is used for the colour update.
