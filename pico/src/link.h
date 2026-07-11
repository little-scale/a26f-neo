#pragma once

#include <stdbool.h>
#include <stdint.h>

void a26f_link_init(void);
void a26f_link_task(void);
bool a26f_link_enqueue(uint8_t command);
bool a26f_link_enqueue_pair(uint8_t first, uint8_t second);
bool a26f_link_overflowed(void);

