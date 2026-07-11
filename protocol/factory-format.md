# A26F factory bank format 1.0

An `.a26factory` file is a ROM-independent, reproducible instrument preset. It
contains 32 ordered slots with names, gate flags, and prepared packed 4-bit PAL
and NTSC variants. ROM placement is deliberately omitted; the browser or build
tool packs the factory into the sample regions declared by the target ROM.

## Binary header

All integers are little-endian.

| Offset | Size | Meaning |
|---:|---:|---|
| 0 | 8 | ASCII `A26FFACT` |
| 8 | 1 | Major version (`1`) |
| 9 | 1 | Minor version (`0`) |
| 10 | 1 | Slot count (`32`) |
| 11 | 1 | Variant count (`2`) |
| 12 | 4 | UTF-8 JSON manifest length |
| 16 | 4 | Binary payload length |
| 20 | 4 | CRC-32 of manifest and payload |
| 24 | variable | JSON manifest, followed by packed payloads |

The JSON manifest records each slot's name, gated/one-shot flag, and PAL/NTSC
payload offset, byte length, exact amplitude-sample count, and rate. Payload
offsets are relative to the start of the binary payload area.

Both parser implementations reject unsupported versions, invalid lengths,
missing variants, samples over 3,840 packed bytes, and checksum failures.
