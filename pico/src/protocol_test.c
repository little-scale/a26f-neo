#include <stdbool.h>
#include <stdint.h>

#include "config.h"
#include "hardware/gpio.h"
#include "link.h"
#include "pico/time.h"

#define A26F_PROTOCOL_TEST_STEP_TIME_US 1000000

enum {
    CMD_AUDC0 = 0x00,
    CMD_AUDF0 = 0x20,
    CMD_AUDV0 = 0x40,
    CMD_SAMPLE_TRIGGER = 0xC0,
    CMD_PARSER_RESET = 0xE4,
    CMD_SAMPLE_GATE_OFF = 0xF0,
    PREFLIGHT_STATE_MS = 750,
};

static void preflight_pin_test(void) {
    // Begin with the already-proven electrical pattern so GP2/GP3 can be
    // checked with a meter, logic analyser, or oscilloscope.
    gpio_init(A26F_TXS0108E_OE_GPIO);
    gpio_put(A26F_TXS0108E_OE_GPIO, false);
    gpio_set_dir(A26F_TXS0108E_OE_GPIO, GPIO_OUT);

    gpio_init(A26F_LINK_DATA_GPIO);
    gpio_init(A26F_LINK_CLOCK_GPIO);
    gpio_put(A26F_LINK_DATA_GPIO, false);
    gpio_put(A26F_LINK_CLOCK_GPIO, false);
    gpio_set_dir(A26F_LINK_DATA_GPIO, GPIO_OUT);
    gpio_set_dir(A26F_LINK_CLOCK_GPIO, GPIO_OUT);
    sleep_ms(10);
    gpio_put(A26F_TXS0108E_OE_GPIO, true);

    for (uint8_t pass = 0; pass < 2; pass++) {
        gpio_put(A26F_LINK_DATA_GPIO, false);
        gpio_put(A26F_LINK_CLOCK_GPIO, false);
        sleep_ms(PREFLIGHT_STATE_MS);
        gpio_put(A26F_LINK_DATA_GPIO, true);
        sleep_ms(PREFLIGHT_STATE_MS);
        gpio_put(A26F_LINK_DATA_GPIO, false);
        gpio_put(A26F_LINK_CLOCK_GPIO, true);
        sleep_ms(PREFLIGHT_STATE_MS);
        gpio_put(A26F_LINK_DATA_GPIO, true);
        sleep_ms(PREFLIGHT_STATE_MS);
    }

    gpio_put(A26F_TXS0108E_OE_GPIO, false);
}

static void run_step(uint8_t step) {
    switch (step) {
        case 0:
            // A strong voice-0 tone and maximum target amplitude.
            a26f_link_enqueue(CMD_AUDC0 | 4u);
            a26f_link_enqueue(CMD_AUDF0 | 4u);
            a26f_link_enqueue(CMD_AUDV0 | 15u);
            break;
        case 1:
            a26f_link_enqueue(CMD_AUDF0 | 10u);
            break;
        case 2:
            a26f_link_enqueue(CMD_AUDF0 | 18u);
            break;
        case 3:
            a26f_link_enqueue(CMD_AUDF0 | 28u);
            break;
        case 4:
            a26f_link_enqueue(CMD_AUDV0);
            break;
        case 5:
            // Factory sample slot zero. Velocity is intentionally irrelevant.
            a26f_link_enqueue(CMD_SAMPLE_TRIGGER);
            break;
        case 6:
            a26f_link_enqueue(CMD_SAMPLE_GATE_OFF);
            break;
    }
}

int main(void) {
    preflight_pin_test();
    a26f_link_init();

    // Give the Atari time to boot and establish its initial clock state.
    uint64_t deadline = time_us_64() + A26F_PROTOCOL_TEST_STEP_TIME_US;
    uint8_t step = 0;
    bool reset_sent = false;

    while (true) {
        a26f_link_task();

        const uint64_t now = time_us_64();
        if ((int64_t)(now - deadline) < 0) {
            continue;
        }

        if (!reset_sent) {
            a26f_link_enqueue(CMD_PARSER_RESET);
            reset_sent = true;
        } else {
            run_step(step);
            step = (uint8_t)((step + 1u) % 7u);
        }
        deadline = now + A26F_PROTOCOL_TEST_STEP_TIME_US;
    }
}
