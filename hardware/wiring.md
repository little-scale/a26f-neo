# Three-wire controller-port interface

## Atari-side connections

| DB9 pin | Port 2 function | Link function |
|---:|---|---|
| 1 | Up / `SWCHA` bit 3 | Clock |
| 2 | Down / `SWCHA` bit 2 | Data |
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

The selected board is an RP2040 Pico-compatible 40-pin module with USB-C. It
uses the normal Raspberry Pi Pico SDK board target:

```text
PICO_BOARD=pico
```

Default GPIO allocation:

- GP2: data
- GP3: clock
