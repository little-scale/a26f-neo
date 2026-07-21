# Controller-port interface

## Atari-side connections

| DB9 pin | Port 2 function | Link function |
|---:|---|---|
| 1 | Up / `SWCHA` bit 0 | Clock |
| 2 | Down / `SWCHA` bit 1 | Data |
| 8 | Ground | Common ground |

Both signals are read from the low nibble of `SWCHA`. The fire input is not
used by the serial link.

## Open-collector interface

Use one stage for data and another for clock:

```text
Pico GPIO ---- 4.7k ---- NPN base
                            collector ---- Atari input
Pico GND ------------------ emitter
```

Suitable small-signal NPN devices include 2N3904 and BC547. Check the pinout of
the actual transistor used. The two emitters and Atari pin 8 share Pico ground.

The Atari controller-port pull-ups produce the released/high state. The Pico
never receives that voltage because it only drives transistor bases.

The NPN stages invert both link signals. Build the firmware with:

```c
#define A26F_LINK_OUTPUT_INVERTED 1
```

The standard build labels this image `a26f_neo_npn.uf2`. The alternate
`a26f_neo_noninverting.uf2` sets the flag to `0` and must only be used with a
suitable interface that preserves GPIO polarity. The Atari ROM is identical
for both arrangements.

## Pico board

The current board is a Raspberry Pi Pico 2 W using the RP2350 SDK target:

```text
PICO_BOARD=pico2_w
```

The original RP2040 Pico remains supported with `PICO_BOARD=pico`; use a
separate build directory and the UF2 produced for that exact target.

Default GPIO allocation:

- GP2: data
- GP3: clock
- GP4: TXS0108E OE in the non-inverting UF2
- GP5: opto-isolated traditional MIDI UART receive
- GP6: valid mapped-MIDI activity LED output
- `3V3(OUT)`, Pico header pin 36: TXS0108E VCCA/VA

See [Traditional MIDI input](midi-input.md) for the 6N138 DIN/TRS circuit. Its
connector side remains galvanically isolated and does not share the Atari/Pico
ground.

## TXS0108E non-inverting interface

For a TXS0108E module, flash `a26f_neo_noninverting.uf2` and connect:

- Pico `3V3(OUT)` (header pin 36) to VCCA/VA.
- GP4 (Pico header pin 6) to OE. Add a 10 kOhm OE pulldown to ground if the
  module does not already provide one.
- GP2 to A1 and GP3 to A2.
- Atari pin 7 (+5 V) to VCCB/VB.
- B1 to Atari pin 2 (data) and B2 to Atari pin 1 (clock).
- Pico ground to module ground and Atari pin 8.

Add 100 nF decoupling at each supply rail if the module does not already
provide it. The non-inverting firmware holds GP4 low, establishes the GP2/GP3
idle levels, and only then raises GP4 to enable the translator. Use
`3V3(OUT)`, not the adjacent Pico `3V3_EN` pin.

The logical link still consists of clock, data, and common ground. Powering
VCCB from Atari pin 7 makes this particular translator arrangement a four-wire
controller-port connection. Never join Atari pin 7 to Pico VBUS or 3V3.
