# A26F sample ROM format 1.0

The patchable production image is a 32 KiB Atari F4 bankswitched ROM. Banks
0–6 hold sample payloads; bank 7 holds the player, directory, manifest, common
bankswitch stub, and vectors.

## Sample encoding and limits

- Unsigned 4-bit amplitude, high nibble first.
- Two amplitude samples per packed byte.
- The playback rate is declared by the ROM: 7,812.5 Hz PAL or approximately
  7,867.1 Hz NTSC.
- Each of banks 0–6 exposes 3,840 patchable bytes at logical `$F000–$FEFF`.
- One sample cannot cross a payload-bank boundary in format 1.0, so its maximum
  packed length is 3,840 bytes (7,680 samples, about 0.98 seconds).
- Total payload capacity is 26,880 bytes (53,760 samples, about 6.9 seconds).

Samples may have different lengths. The patcher may place slots in any payload
bank; the directory preserves the MIDI slot mapping.

## Directory

The 256-byte directory begins at raw file offset `$7D00`. It contains 32
eight-byte entries:

| Byte | Meaning |
|---:|---|
| 0 | F4 bank 0–6, or `$FF` for an empty slot |
| 1–2 | Little-endian logical start address (`$F000–$FEFF`) |
| 3–4 | Little-endian packed-byte length |
| 5 | Flags: bit 0 set = gated; clear = one-shot |
| 6–7 | Reserved, zero |

## Patch manifest

The 128-byte manifest begins at raw offset `$7E00`. Multi-byte integers are
little-endian.

| Offset | Size | Meaning |
|---:|---:|---|
| 0 | 8 | `A26FSMP` followed by zero |
| 8 | 2 | Format major, minor (`1, 0`) |
| 10 | 1 | TV: 0 PAL, 1 NTSC |
| 11 | 1 | Mapper ID: 4 = F4 |
| 12 | 1 | Bank count: 8 |
| 13 | 1 | Slot count: 32 |
| 14 | 1 | Encoding: 1 = packed unsigned 4-bit PCM |
| 15 | 1 | Default sample flags |
| 16 | 4 | Sample rate in millihertz |
| 20 | 4 | ROM byte size |
| 24 | 4 | Directory raw file offset |
| 28 | 4 | Directory byte length |
| 32 | 1 | Directory bank |
| 33 | 1 | Directory entry size |
| 34 | 2 | Reserved |
| 36 | 28 | Seven pairs of payload offset and length (16-bit each) |
| 64 | 64 | Reserved |

The offline patcher requires an exact supported major/minor version and checks
the mapper, ROM size, directory, slot count, encoding, and payload regions
before changing a copy of the source ROM.
