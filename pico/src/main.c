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
    CC_ENVELOPE_MODE = 70,
    CC_RELEASE = 72,
    CC_ATTACK = 73,
};

enum {
    ENV_ATTACK = 0,
    ENV_RELEASE = 1,
    ENV_MODE = 2,
};

enum {
    REGISTER_STATE_COUNT = 6,
    ENVELOPE_STATE_COUNT = 6,
    MIDI_BEND_CENTER = 8192,
    MIDI_BEND_MAX = 16383,
};

typedef struct {
    uint8_t desired;
    uint8_t scheduled;
    bool desired_valid;
    bool scheduled_valid;
} shadow_state_t;

static int16_t active_note[2] = {-1, -1};
static int16_t active_drum_note = -1;
static uint8_t base_audf[2];
static bool base_audf_valid[2];
static uint16_t pitch_bend[2] = {MIDI_BEND_CENTER, MIDI_BEND_CENTER};
static bool attack_decay_mode[2];
static shadow_state_t register_state[REGISTER_STATE_COUNT];
static shadow_state_t envelope_state[ENVELOPE_STATE_COUNT];
static bool midi_activity;

static uint8_t command_base(uint8_t voice, uint8_t voice0, uint8_t voice1) {
    return voice == 0 ? voice0 : voice1;
}

static void request_register(uint8_t command) {
    const uint8_t slot = command >> 5u;
    if (slot >= REGISTER_STATE_COUNT) {
        return;
    }
    register_state[slot].desired = command;
    register_state[slot].desired_valid = true;
}

static void force_next_volume_write(uint8_t voice) {
    const uint8_t command = command_base(voice, CMD_AUDV0, CMD_AUDV1);
    register_state[command >> 5u].scheduled_valid = false;
}

static void set_envelope(uint8_t voice, uint8_t parameter, uint8_t value) {
    const uint8_t slot = parameter == ENV_MODE
                             ? (uint8_t)(4u + (voice & 1u))
                             : (uint8_t)(((voice & 1u) << 1u) |
                                         (parameter & 1u));
    envelope_state[slot].desired = parameter == ENV_MODE
                                       ? (uint8_t)(value > 63u)
                                       : (uint8_t)((value >> 3u) & 0x0Fu);
    envelope_state[slot].desired_valid = true;
}

static uint8_t bent_audf(uint8_t voice) {
    int32_t result = base_audf[voice];
    const uint16_t bend = pitch_bend[voice];

    if (bend > MIDI_BEND_CENTER) {
        const uint32_t distance = bend - MIDI_BEND_CENTER;
        const int32_t steps = (int32_t)((distance * 32u) /
                                        (MIDI_BEND_MAX - MIDI_BEND_CENTER));
        result -= steps;
    } else if (bend < MIDI_BEND_CENTER) {
        const uint32_t distance = MIDI_BEND_CENTER - bend;
        const int32_t steps = (int32_t)((distance * 32u) / MIDI_BEND_CENTER);
        result += steps;
    }

    if (result < 0) {
        return 0;
    }
    if (result > 31) {
        return 31;
    }
    return (uint8_t)result;
}

static void request_bent_pitch(uint8_t voice) {
    if (!base_audf_valid[voice]) {
        return;
    }
    request_register(command_base(voice, CMD_AUDF0, CMD_AUDF1) |
                     bent_audf(voice));
}

static void handle_synth_note_on(uint8_t voice, uint8_t note, uint8_t velocity) {
    active_note[voice] = note;
    // The TIA exposes 32 AUDF values and a larger divider produces a lower
    // oscillator frequency. Invert the wrapped divider so ascending MIDI
    // notes generally produce ascending audible frequency.
    base_audf[voice] = 31u - (note & 0x1Fu);
    base_audf_valid[voice] = true;
    request_bent_pitch(voice);
    // Attack-decay changes the Atari's target back to zero internally. Force
    // every new AD gate onto the wire even when its velocity matches the last
    // one remembered by the Pico shadow.
    if (attack_decay_mode[voice]) {
        force_next_volume_write(voice);
    }
    request_register(command_base(voice, CMD_AUDV0, CMD_AUDV1) |
                     (velocity >> 3u));
}

static void handle_synth_note_off(uint8_t voice, uint8_t note) {
    if (active_note[voice] != note) {
        return;
    }
    active_note[voice] = -1;
    if (attack_decay_mode[voice]) {
        return;
    }
    request_register(command_base(voice, CMD_AUDV0, CMD_AUDV1));
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
                request_register(command_base(channel, CMD_AUDC0, CMD_AUDC1) |
                                 ((data2 >> 3u) & 0x0Fu));
                break;
            case CC_ENVELOPE_MODE:
                if (attack_decay_mode[channel] != (data2 > 63u)) {
                    // The Atari may have autonomously decayed while the Pico's
                    // last scheduled volume still names the old peak.
                    force_next_volume_write(channel);
                }
                attack_decay_mode[channel] = data2 > 63u;
                set_envelope(channel, ENV_MODE, data2);
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

    if (type == 0xE0u && channel < 2) {
        pitch_bend[channel] = ((uint16_t)data2 << 7u) | data1;
        request_bent_pitch(channel);
    }
}

static void flush_shadow_state(void) {
    // Envelope configuration is sent first so a mode or rate change received
    // immediately before a note takes effect before that note's volume gate.
    for (uint8_t slot = 0; slot < ENVELOPE_STATE_COUNT; slot++) {
        shadow_state_t *state = &envelope_state[slot];
        if (!state->desired_valid ||
            (state->scheduled_valid && state->scheduled == state->desired)) {
            continue;
        }
        const uint8_t select = CMD_ENV_SELECT | (slot < 4u ? slot : slot + 1u);
        const uint8_t value = CMD_ENV_VALUE | state->desired;
        if (a26f_link_enqueue_envelope(select, value)) {
            state->scheduled = state->desired;
            state->scheduled_valid = true;
        }
    }

    for (uint8_t slot = 0; slot < REGISTER_STATE_COUNT; slot++) {
        shadow_state_t *state = &register_state[slot];
        if (!state->desired_valid ||
            (state->scheduled_valid && state->scheduled == state->desired)) {
            continue;
        }
        if (a26f_link_enqueue_latest(state->desired)) {
            state->scheduled = state->desired;
            state->scheduled_valid = true;
        }
    }
}

static void invalidate_scheduled_state(void) {
    for (uint8_t slot = 0; slot < REGISTER_STATE_COUNT; slot++) {
        register_state[slot].scheduled_valid = false;
    }
    for (uint8_t slot = 0; slot < ENVELOPE_STATE_COUNT; slot++) {
        envelope_state[slot].scheduled_valid = false;
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

        if (a26f_link_take_overflow()) {
            a26f_link_discard_pending();
            invalidate_scheduled_state();
            a26f_link_enqueue(CMD_PARSER_RESET);
        }

        flush_shadow_state();
        a26f_link_task();

        if (midi_activity) {
            board_led_write(true);
            midi_activity = false;
        } else {
            board_led_write(false);
        }
    }
}
