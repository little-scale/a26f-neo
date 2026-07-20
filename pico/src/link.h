#pragma once

#include <stdbool.h>
#include <stdint.h>

void a26f_link_init(void);
void a26f_link_task(void);
bool a26f_link_enqueue(uint8_t command);
bool a26f_link_enqueue_pair(uint8_t first, uint8_t second);
bool a26f_link_enqueue_latest(uint8_t command);
bool a26f_link_enqueue_envelope(uint8_t select, uint8_t value);
void a26f_link_discard_pending(void);
bool a26f_link_take_overflow(void);
