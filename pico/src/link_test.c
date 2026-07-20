#include "hardware/gpio.h"
#include "pico/stdlib.h"

enum {
    DATA_GPIO = 2,
    CLOCK_GPIO = 3,
    TXS_OE_GPIO = 4,
    STATE_TIME_MS = 1500,
};

static void set_link_state(bool data, bool clock) {
    gpio_put(DATA_GPIO, data);
    gpio_put(CLOCK_GPIO, clock);
}

int main(void) {
    // Keep the translator disabled until both signal pins are outputs at 0 V.
    gpio_init(TXS_OE_GPIO);
    gpio_put(TXS_OE_GPIO, false);
    gpio_set_dir(TXS_OE_GPIO, GPIO_OUT);

    gpio_init(DATA_GPIO);
    gpio_init(CLOCK_GPIO);
    set_link_state(false, false);
    gpio_set_dir(DATA_GPIO, GPIO_OUT);
    gpio_set_dir(CLOCK_GPIO, GPIO_OUT);

    sleep_ms(10);
    gpio_put(TXS_OE_GPIO, true);

    while (true) {
        // 00: both Atari indicators dark.
        set_link_state(false, false);
        sleep_ms(STATE_TIME_MS);

        // 10: data (GP2 / Atari pin 2) bright, clock dark.
        set_link_state(true, false);
        sleep_ms(STATE_TIME_MS);

        // 01: data dark, clock (GP3 / Atari pin 1) bright.
        set_link_state(false, true);
        sleep_ms(STATE_TIME_MS);

        // 11: both Atari indicators bright.
        set_link_state(true, true);
        sleep_ms(STATE_TIME_MS);
    }
}
