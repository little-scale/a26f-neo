#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef void (*a26f_midi_message_handler_t)(void *context,
                                            uint8_t status,
                                            uint8_t data1,
                                            uint8_t data2);

typedef struct {
    a26f_midi_message_handler_t handler;
    void *context;
    uint8_t running_status;
    uint8_t current_status;
    uint8_t data[2];
    uint8_t data_count;
    uint8_t data_length;
    bool in_sysex;
} a26f_midi_serial_parser_t;

void a26f_midi_serial_parser_init(a26f_midi_serial_parser_t *parser,
                                  a26f_midi_message_handler_t handler,
                                  void *context);
void a26f_midi_serial_parser_feed(a26f_midi_serial_parser_t *parser,
                                  uint8_t byte);
