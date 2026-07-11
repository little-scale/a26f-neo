#include "link.h"

#include <stddef.h>

#include "config.h"
#include "hardware/gpio.h"
#include "pico/time.h"

#define LINK_QUEUE_SIZE 64u
#define LINK_QUEUE_MASK (LINK_QUEUE_SIZE - 1u)
#define LINK_DATA_SETUP_US 20u

_Static_assert((LINK_QUEUE_SIZE & LINK_QUEUE_MASK) == 0,
               "link queue size must be a power of two");
_Static_assert(LINK_DATA_SETUP_US < A26F_LINK_BIT_TIME_US,
               "data setup time must be shorter than bit time");

typedef enum {
    TX_IDLE,
    TX_DATA_SETUP,
    TX_BIT_HOLD,
    TX_INTERBYTE_GAP,
} tx_state_t;

static uint8_t queue[LINK_QUEUE_SIZE];
static uint8_t queue_read;
static uint8_t queue_write;
static bool queue_overflow;

static tx_state_t tx_state;
static uint8_t tx_byte;
static int8_t tx_bit;
static bool logical_clock;
static uint64_t deadline_us;

static inline uint8_t queue_used(void) {
    return (uint8_t)(queue_write - queue_read);
}

static inline uint8_t queue_free(void) {
    return (uint8_t)(LINK_QUEUE_SIZE - 1u - queue_used());
}

static inline void put_logical(uint gpio, bool logical_level) {
    const bool physical_level = logical_level ^ !!A26F_LINK_OUTPUT_INVERTED;
    gpio_put(gpio, physical_level);
}

void a26f_link_init(void) {
    gpio_init(A26F_LINK_DATA_GPIO);
    gpio_init(A26F_LINK_CLOCK_GPIO);
    gpio_set_dir(A26F_LINK_DATA_GPIO, GPIO_OUT);
    gpio_set_dir(A26F_LINK_CLOCK_GPIO, GPIO_OUT);

    logical_clock = false;
    put_logical(A26F_LINK_DATA_GPIO, false);
    put_logical(A26F_LINK_CLOCK_GPIO, logical_clock);

    queue_read = 0;
    queue_write = 0;
    queue_overflow = false;
    tx_state = TX_INTERBYTE_GAP;
    deadline_us = time_us_64() + A26F_LINK_INTERBYTE_GAP_US;
}

bool a26f_link_enqueue(uint8_t command) {
    if (queue_free() < 1u) {
        queue_overflow = true;
        return false;
    }
    queue[queue_write & LINK_QUEUE_MASK] = command;
    queue_write++;
    return true;
}

bool a26f_link_enqueue_pair(uint8_t first, uint8_t second) {
    if (queue_free() < 2u) {
        queue_overflow = true;
        return false;
    }
    queue[queue_write & LINK_QUEUE_MASK] = first;
    queue_write++;
    queue[queue_write & LINK_QUEUE_MASK] = second;
    queue_write++;
    return true;
}

bool a26f_link_take_overflow(void) {
    const bool result = queue_overflow;
    queue_overflow = false;
    return result;
}

void a26f_link_task(void) {
    const uint64_t now = time_us_64();
    if ((int64_t)(now - deadline_us) < 0) {
        return;
    }

    switch (tx_state) {
        case TX_IDLE:
        case TX_INTERBYTE_GAP:
            if (queue_read == queue_write) {
                tx_state = TX_IDLE;
                deadline_us = now + A26F_LINK_INTERBYTE_GAP_US;
                return;
            }
            tx_byte = queue[queue_read & LINK_QUEUE_MASK];
            queue_read++;
            tx_bit = 7;
            put_logical(A26F_LINK_DATA_GPIO, (tx_byte >> tx_bit) & 1u);
            tx_state = TX_DATA_SETUP;
            deadline_us = now + LINK_DATA_SETUP_US;
            return;

        case TX_DATA_SETUP:
            logical_clock = !logical_clock;
            put_logical(A26F_LINK_CLOCK_GPIO, logical_clock);
            tx_state = TX_BIT_HOLD;
            deadline_us = now + (A26F_LINK_BIT_TIME_US - LINK_DATA_SETUP_US);
            return;

        case TX_BIT_HOLD:
            tx_bit--;
            if (tx_bit < 0) {
                tx_state = TX_INTERBYTE_GAP;
                deadline_us = now + A26F_LINK_INTERBYTE_GAP_US;
                return;
            }
            put_logical(A26F_LINK_DATA_GPIO, (tx_byte >> tx_bit) & 1u);
            tx_state = TX_DATA_SETUP;
            deadline_us = now + LINK_DATA_SETUP_US;
            return;
    }
}
