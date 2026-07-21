#include "midi_serial_parser.h"

#include <stddef.h>

static uint8_t data_length_for_status(uint8_t status) {
    if (status < 0x80u) {
        return 0u;
    }
    if (status < 0xF0u) {
        const uint8_t type = status & 0xF0u;
        return type == 0xC0u || type == 0xD0u ? 1u : 2u;
    }

    switch (status) {
        case 0xF1u:
        case 0xF3u:
            return 1u;
        case 0xF2u:
            return 2u;
        default:
            return 0u;
    }
}

static void begin_status(a26f_midi_serial_parser_t *parser, uint8_t status) {
    parser->current_status = status;
    parser->data_count = 0;
    parser->data_length = data_length_for_status(status);
}

void a26f_midi_serial_parser_init(a26f_midi_serial_parser_t *parser,
                                  a26f_midi_message_handler_t handler,
                                  void *context) {
    *parser = (a26f_midi_serial_parser_t){
        .handler = handler,
        .context = context,
    };
}

void a26f_midi_serial_parser_feed(a26f_midi_serial_parser_t *parser,
                                  uint8_t byte) {
    // System real-time bytes may appear between any two bytes and do not
    // disturb running status or an in-progress message.
    if (byte >= 0xF8u) {
        return;
    }

    if (byte & 0x80u) {
        if (byte == 0xF0u) {
            parser->in_sysex = true;
            parser->running_status = 0;
            begin_status(parser, 0);
            return;
        }

        if (byte == 0xF7u) {
            parser->in_sysex = false;
            parser->running_status = 0;
            begin_status(parser, 0);
            return;
        }

        parser->in_sysex = false;
        if (byte < 0xF0u) {
            parser->running_status = byte;
            begin_status(parser, byte);
        } else {
            // System common cancels channel running status. Its data is
            // consumed so it cannot be mistaken for a channel message.
            parser->running_status = 0;
            begin_status(parser, byte);
            if (parser->data_length == 0) {
                begin_status(parser, 0);
            }
        }
        return;
    }

    if (parser->in_sysex) {
        return;
    }

    if (parser->current_status == 0) {
        if (parser->running_status == 0) {
            return;
        }
        begin_status(parser, parser->running_status);
    }

    if (parser->data_count < sizeof(parser->data)) {
        parser->data[parser->data_count++] = byte;
    }
    if (parser->data_count < parser->data_length) {
        return;
    }

    if (parser->current_status < 0xF0u && parser->handler != NULL) {
        parser->handler(parser->context,
                        parser->current_status,
                        parser->data[0],
                        parser->data_length == 2u ? parser->data[1] : 0u);
    }

    if (parser->current_status < 0xF0u) {
        begin_status(parser, parser->running_status);
    } else {
        begin_status(parser, 0);
    }
}
