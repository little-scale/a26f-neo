# Traditional MIDI input

A26F NEO accepts traditional 31.25 kbit/s MIDI on an opto-isolated UART input
in addition to USB MIDI. Both transports feed the same mappings and Atari-link
queue. The production firmware uses:

| Function | Pico connection |
|---|---|
| MIDI UART receive | GP5, header pin 7 |
| Valid mapped-message LED | GP6, header pin 9 |
| 6N138 output pull-up | `3V3(OUT)`, header pin 36 |
| 6N138 supply | `VBUS`, header pin 40, nominal 5 V while USB-powered |

## 6N138 circuit

Use the following values for the initial breadboard build:

| Part | Value |
|---|---:|
| MIDI current-loop resistor | 220 ohm, 5% |
| Reverse-protection diode | 1N4148 or 1N914 |
| 6N138 output pull-up | 2.2 kohm to Pico `3V3(OUT)` |
| 6N138 pin-7 speed-up resistor | 47 kohm to Pico GND |
| 6N138 supply bypass | 100 nF ceramic between pins 8 and 5 |
| Activity LED resistor | 1 kohm |

### Isolated MIDI side

```text
DIN pin 4 / TRS ring ---- 220 ohm ---- 6N138 pin 2 (LED anode)
DIN pin 5 / TRS tip  ----------------- 6N138 pin 3 (LED cathode)

1N4148 across pins 2 and 3:
  cathode (striped end) -> pin 2
  anode                 -> pin 3
```

For a 5-pin DIN input, leave pins 1 and 3 unconnected. DIN pin 2 must have no
direct DC connection to Pico ground. For a 3.5 mm TRS input, use the official
Type A mapping: ring is DIN pin 4/current source, tip is DIN pin 5/current
sink, and sleeve is the pin-2 shield. Leave the sleeve without a direct DC
connection to Pico ground.

### Pico side

```text
6N138 pin 8 (VCC)    -> Pico VBUS / 5 V
6N138 pin 5 (GND)    -> Pico GND
6N138 pin 6 (output) -> Pico GP5 / UART1 RX
                         |
                         +-- 2.2 kohm -- Pico 3V3(OUT)
6N138 pin 7 (base)   -> 47 kohm -> Pico GND
6N138 pins 1 and 4   -> no connection
100 nF               -> directly between pins 8 and 5
```

The 6N138 requires a 5 V-class supply; do not power its pin 8 from Pico 3.3 V.
Its pin-6 output is open collector, so pulling that output up to 3.3 V gives
GP5 a safe logic level even though the optocoupler itself is powered at 5 V.
If the Pico is not USB-powered, provide a suitable regulated 5 V supply rather
than assuming VBUS is present.

This follows the MIDI Association receiver topology: a 220-ohm receiver
resistor, reverse-voltage diode, no receiver-side DC ground connection at the
MIDI connector, and opto-isolation. The Broadcom 6N138 data sheet specifies a
4.5 V minimum operating supply, recommends a 2.2-kohm pull-up for its rated
TTL load, and recommends 100 nF between pins 8 and 5. The 47-kohm base resistor
trades some excess gain for a faster turn-off without going below the data
sheet's threshold for significant gain reduction.

References:

- [MIDI 1.0 Electrical Specification Update](https://midi.org/wp-content/uploads/wpforo/default_attachments/1709416667-ca33-MIDI-10-Electrical-Specification-Update.pdf)
- [Broadcom 6N138 data sheet](https://docs.broadcom.com/doc/AV02-1359EN)
- [MIDI Association TRS adapter specification announcement](https://midi.org/specification-for-trs-adapters-adopted-and-released)

## Valid-message LED

Connect GP6 through 1 kohm to the LED anode and connect the LED cathode to Pico
GND. The firmware holds GP6 high for approximately 35 ms whenever either USB
or UART delivers a MIDI message that A26F NEO maps to a synth, envelope,
pitch-bend, or sample action. Unsupported channels and controls do not light
this indicator.

## Input behaviour

- USB MIDI and traditional MIDI remain active simultaneously.
- Running status is supported.
- System real-time bytes may be interleaved without disturbing a message.
- SysEx and unsupported channel messages are parsed or skipped safely.
- If USB and traditional MIDI control the same A26F channel, the most recent
  event wins; avoid competing note streams on one channel.
- Traditional MIDI does not power the Pico. Use USB or another appropriate
  Pico power connection.
