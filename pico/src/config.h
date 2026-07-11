#pragma once

// One flag controls the physical polarity of both outgoing link signals.
// 1: NPN open-collector interface (recommended wiring).
// 0: suitable non-inverting level-shifting interface.
#define A26F_LINK_OUTPUT_INVERTED 1

#define A26F_LINK_DATA_GPIO 2
#define A26F_LINK_CLOCK_GPIO 3
#define A26F_LINK_BIT_TIME_US 400
#define A26F_LINK_INTERBYTE_GAP_US 1000

#define A26F_USB_MANUFACTURER "A26F"
#define A26F_USB_PRODUCT "A26F NEO"
