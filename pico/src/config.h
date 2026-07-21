#pragma once

// One flag controls the physical polarity of both outgoing link signals.
// 1: NPN open-collector interface (recommended wiring).
// 0: suitable non-inverting level-shifting interface.
#ifndef A26F_LINK_OUTPUT_INVERTED
#define A26F_LINK_OUTPUT_INVERTED 1
#endif

// The non-inverting build can control a TXS0108E output-enable input from GP4.
// VCCA is powered from the Pico's 3V3(OUT) rail, not from a GPIO.
#ifndef A26F_TXS0108E_GPIO_OE
#define A26F_TXS0108E_GPIO_OE 0
#endif

#define A26F_TXS0108E_OE_GPIO 4

#define A26F_LINK_DATA_GPIO 2
#define A26F_LINK_CLOCK_GPIO 3

// Opto-isolated DIN/TRS MIDI input and external valid-message indicator.
// GP5 is UART1 RX on both supported Pico board targets. GP6 drives an LED
// through an external current-limiting resistor.
#define A26F_MIDI_RX_GPIO 5
#define A26F_MIDI_ACTIVITY_GPIO 6
#define A26F_MIDI_ACTIVITY_HOLD_MS 35

// Conservative hardware-test timing. At 1 ms per clock transition the Atari
// polls each bit several times, while the 5 ms byte gap lets its idle detector
// restore byte alignment before every command.
#ifndef A26F_LINK_BIT_TIME_US
#define A26F_LINK_BIT_TIME_US 1000
#endif
#ifndef A26F_LINK_INTERBYTE_GAP_US
#define A26F_LINK_INTERBYTE_GAP_US 5000
#endif
#ifndef A26F_LINK_DATA_SETUP_US
#define A26F_LINK_DATA_SETUP_US 250
#endif

#define A26F_USB_MANUFACTURER "A26F"
#ifndef A26F_USB_PRODUCT
#define A26F_USB_PRODUCT "A26F NEO"
#endif
