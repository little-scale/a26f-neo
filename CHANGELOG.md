# Changelog

Product releases use decimal-style pre-1.0 numbering. The initial release is
`v0.1`; subsequent releases increment by `v0.01` (`v0.11`, `v0.12`, `v0.13`,
and so on). Product release numbers are independent of the wire protocol, ROM
sample format, and factory-bank format versions.

## v0.1 — 2026-07-20

Initial hardware-tested release candidate.

### Included

- PAL and NTSC 32 KiB F4 ROMs with a single shared feature set
- Sixteen-band receive-history visualization with minimum visible luminance
- Two TIA synth voices driven by MIDI channels 1 and 2
- Sound control, attack/release, envelope-mode, and pitch-bend MIDI control
- Thirty-two wrapped channel 10 sample slots with gated and one-shot playback
- Voice 1 synthesizer-state restoration after sample playback
- Raspberry Pi Pico 2 W class-compliant USB MIDI firmware for NPN-inverting and
  TXS0108E/non-inverting interfaces
- Offline ROM and factory-bank editor with WAV mass-drop, 4-bit audition,
  auto-trim, normalization, 0 to +60 dB gain, and optional tanh shaping
- Default factory bank with prepared PAL and NTSC sample variants
- Joystick soundcheck covering all TIA sound-control values and sample slots
  0–3
- MIT-licensed source and release bundle

### Validation

- PAL original hardware: synth, envelopes, pitch bend, samples, gating,
  receive visualization, and Pico 2 W/TXS0108E link tested
- PAL and NTSC: automated ROM, manifest, factory, patcher, and Stella F4 checks
- NTSC original hardware remains unverified
