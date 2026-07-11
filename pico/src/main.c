#include <stdbool.h>
#include <stdint.h>

#include "bsp/board_api.h"
#include "link.h"
#include "tusb.h"

enum {
    CMD_AUDC0 = 0x00,
    CMD_AUDF0 = 0x20,
    CMD_AUDV0 = 0x40,
    CMD_AUDC1 = 0x60,
    CMD_AUDF1 = 0x80,
    CMD_AUDV1 = 0xA0,
    CMD_SAMPLE_TRIGGER = 0xC0,
    CMD_ENV_SELECT = 0xE0,
    CMD_PARSER_RESET = 0xE4,
    CMD_ENV_VALUE = 0xF0,
    CMD_SAMPLE_GATE_OFF = 0xF0,
};

enum {
    CC_SOUND_CONTROL = 1,
    CC_RELEASE = 72,
    CC_ATTACK = 73,
};

enum {
    ENV_ATTACK = 0,
    ENV_RELEASE = 1,
};

static int16_t active_note[2] = {-1, -1};
static int16_t active_drum_note = -1;
static bool midi_activity;

static uint8_t command_base(uint8_t voice, uint8_t voice0, uint8_t voice1) {
    return voice == 0 ? voice0 : voice1;
}

static void set_envelope(uint8_t voice, uint8_t parameter, uint8_t value) {
    const uint8_t select = CMD_ENV_SELECT | ((voice & 1u) << 1u) | (parameter & 1u);
    const uint8_t data = CMD_ENV_VALUE | ((value >> 3u) & 0x0Fu);
    a26f_link_enqueue_pair(select, data);
}

static void handle_synth_note_on(uint8_t voice, uint8_t note, uint8_t velocity) {
    active_note[voice] = note;
    a26f_link_enqueue(command_base(voice, CMD_AUDF0, CMD_AUDF1) | (note >> 2u));
    a26f_link_enqueue(command_base(voice, CMD_AUDV0, CMD_AUDV1) | (velocity >> 3u));
}

static void handle_synth_note_off(uint8_t voice, uint8_t note) {
    if (active_note[voice] != note) {
        return;
    }
    active_note[voice] = -1;
    a26f_link_enqueue(command_base(voice, CMD_AUDV0, CMD_AUDV1));
}

static void handle_drum_note_on(uint8_t note) {
    active_drum_note = note;
    a26f_link_enqueue(CMD_SAMPLE_TRIGGER | (note & 0x1Fu));
}

static void handle_drum_note_off(uint8_t note) {
    if (active_drum_note != note) {
        return;
    }
    active_drum_note = -1;
    a26f_link_enqueue(CMD_SAMPLE_GATE_OFF);
}

static void handle_midi_message(uint8_t status, uint8_t data1, uint8_t data2) {
    const uint8_t type = status & 0xF0u;
    const uint8_t channel = status & 0x0Fu;

    if (type == 0x90u && data2 == 0) {
        // MIDI defines note-on with velocity zero as note-off.
        if (channel == 9) {
            handle_drum_note_off(data1);
        } else if (channel < 2) {
            handle_synth_note_off(channel, data1);
        }
        return;
    }

    if (type == 0x90u) {
        if (channel == 9) {
            handle_drum_note_on(data1);
        } else if (channel < 2) {
            handle_synth_note_on(channel, data1, data2);
        }
        return;
    }

    if (type == 0x80u) {
        if (channel == 9) {
            handle_drum_note_off(data1);
        } else if (channel < 2) {
            handle_synth_note_off(channel, data1);
        }
        return;
    }

    if (type == 0xB0u && channel < 2) {
        switch (data1) {
            case CC_SOUND_CONTROL:
                a26f_link_enqueue(command_base(channel, CMD_AUDC0, CMD_AUDC1) |
                                  ((data2 >> 3u) & 0x0Fu));
                break;
            case CC_ATTACK:
                set_envelope(channel, ENV_ATTACK, data2);
                break;
            case CC_RELEASE:
                set_envelope(channel, ENV_RELEASE, data2);
                break;
            default:
                break;
        }
    }
}

static void midi_task(void) {
    while (tud_midi_available()) {
        uint8_t packet[4];
        if (!tud_midi_packet_read(packet)) {
            break;
        }
        handle_midi_message(packet[1], packet[2], packet[3]);
        midi_activity = true;
    }
}

int main(void) {
    board_init();
    a26f_link_init();

    tusb_init();
    if (board_init_after_tusb) {
        board_init_after_tusb();
    }

    while (true) {
        tud_task();
        midi_task();
        a26f_link_task();

        if (a26f_link_take_overflow()) {
            // If this enqueue also finds the queue full, the overflow flag is
            // set again and the reset is retried on a later pass.
            a26f_link_enqueue(CMD_PARSER_RESET);
        }

        if (midi_activity) {
            board_led_write(true);
            midi_activity = false;
        } else {
            board_led_write(false);
        }
    }
}
