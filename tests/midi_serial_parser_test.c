#include <assert.h>
#include <stddef.h>
#include <stdint.h>

#include "midi_serial_parser.h"

typedef struct {
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
} message_t;

static message_t messages[16];
static size_t message_count;

static void collect(void *context,
                    uint8_t status,
                    uint8_t data1,
                    uint8_t data2) {
    (void)context;
    assert(message_count < sizeof(messages) / sizeof(messages[0]));
    messages[message_count++] = (message_t){status, data1, data2};
}

static void feed(a26f_midi_serial_parser_t *parser,
                 const uint8_t *bytes,
                 size_t count) {
    for (size_t index = 0; index < count; index++) {
        a26f_midi_serial_parser_feed(parser, bytes[index]);
    }
}

int main(void) {
    a26f_midi_serial_parser_t parser;
    a26f_midi_serial_parser_init(&parser, collect, NULL);

    const uint8_t notes[] = {
        0x90, 60, 100,
        61, 101,       // Running status.
        62, 0xF8, 102, // Real-time clock inside a message.
    };
    feed(&parser, notes, sizeof(notes));
    assert(message_count == 3);
    assert(messages[0].status == 0x90 && messages[0].data1 == 60 &&
           messages[0].data2 == 100);
    assert(messages[1].status == 0x90 && messages[1].data1 == 61 &&
           messages[1].data2 == 101);
    assert(messages[2].status == 0x90 && messages[2].data1 == 62 &&
           messages[2].data2 == 102);

    const uint8_t system_common[] = {
        0xF2, 1, 2, // Consumed and cancels running status.
        63, 103,    // Ignored without a new channel status.
        0xE1, 0, 64,
    };
    feed(&parser, system_common, sizeof(system_common));
    assert(message_count == 4);
    assert(messages[3].status == 0xE1 && messages[3].data1 == 0 &&
           messages[3].data2 == 64);

    const uint8_t sysex[] = {
        0xF0, 0x01, 0x02, 0xF8, 0x03, 0xF7,
        0xB0, 73, 127,
    };
    feed(&parser, sysex, sizeof(sysex));
    assert(message_count == 5);
    assert(messages[4].status == 0xB0 && messages[4].data1 == 73 &&
           messages[4].data2 == 127);

    const uint8_t short_messages[] = {
        0xC0, 10,
        11, // Program-change running status.
        0xD0, 55,
    };
    feed(&parser, short_messages, sizeof(short_messages));
    assert(message_count == 8);
    assert(messages[5].status == 0xC0 && messages[5].data1 == 10);
    assert(messages[6].status == 0xC0 && messages[6].data1 == 11);
    assert(messages[7].status == 0xD0 && messages[7].data1 == 55);

    return 0;
}
