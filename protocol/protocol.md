# A26F wire and MIDI protocol

Protocol version: `1.0-draft`

## Physical link

The link is unidirectional. The Pico drives two controller-port-2 inputs and
the Atari only polls them.

| Signal | Atari controller port 2 | Pico default |
|---|---:|---:|
| Clock | pin 1 (up) | GP3 |
| Data | pin 2 (down) | GP2 |
| Ground | pin 8 | GND |

The intended safe interface uses two NPN open-collector stages. Both stages
invert their input. The Pico firmware has one compile-time flag,
`A26F_LINK_OUTPUT_INVERTED`, which applies to both clock and data:

```c
#define A26F_LINK_OUTPUT_INVERTED 1
```

Set it to `1` for the NPN interface and `0` only for a suitable non-inverting
3.3 V-to-5 V interface. Direct connection to the Atari inputs is not the
recommended electrical implementation.

Standard builds are labelled `a26f_neo_npn.uf2` (`1`) and
`a26f_neo_noninverting.uf2` (`0`). Both produce the same logical wire protocol
and use the same Atari ROM.

## Bit transfer

- Bytes are sent most-significant bit first.
- The Pico sets data before changing clock.
- Every clock transition transfers one bit; there is no preferred edge.
- Clock remains at its new level until the next bit.
- Initial target: 400 microseconds between clock changes (2.5 kbit/s).
- A deliberate idle gap permits the Atari to discard a partial byte.
- The Pico must never produce two clock changes inside the Atari's maximum
  polling interval.

The Pico owns pacing and queues complete commands. Replaceable register writes
may be coalesced so that only their newest queued value is transmitted.

The Atari restarts a RIOT timer on every observed clock transition. A long idle
period resets only partial-byte and pending-extended-command state; complete
commands already in its 16-byte receive ring remain queued.

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
| `E0-E3` | Select extended envelope parameter | see below |
| `E4` | Reset/resynchronise command parser | no value |
| `F0-FF` | Envelope value when a selection is pending | low 4 bits |
| `F0` | Gate off the current gated sample |

Amplitude commands are envelope gates: a nonzero value begins attack toward
that peak; zero begins release. The Pico filters stale MIDI note-off events.

### Envelope parameter pair

An envelope change is a validated two-byte pair:

```text
111000CS  select parameter
1111VVVV  set value
```

- `C`: voice 0 or 1.
- `S=0`: attack.
- `S=1`: release.
- `VVVV`: time-table index 0-15.

An idle timeout or unexpected byte cancels a pending parameter selection.

## MIDI mapping

### Synth voices

| MIDI input | Result |
|---|---|
| Channel 1 | TIA voice 0 |
| Channel 2 | TIA voice 1 |
| CC1 | `AUDC = value >> 3` |
| Note number | `AUDF = note >> 2` |
| Velocity | peak amplitude `velocity >> 3` |
| CC73 | attack index `value >> 3` |
| CC72 | release index `value >> 3` |

Note-on velocity zero is note-off. A note-off only closes the gate if its note
matches the currently active monophonic note on that MIDI channel.

Default envelope indices are attack `0` (instant) and release `1`. Envelopes
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
