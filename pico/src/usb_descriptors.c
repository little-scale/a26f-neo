#include <stddef.h>
#include <string.h>

#include "bsp/board_api.h"
#include "config.h"
#include "tusb.h"

#define USB_VID 0xCAFE
#define USB_PID 0x4008
#define USB_BCD 0x0100

tusb_desc_device_t const device_descriptor = {
    .bLength = sizeof(tusb_desc_device_t),
    .bDescriptorType = TUSB_DESC_DEVICE,
    .bcdUSB = 0x0200,
    .bDeviceClass = 0x00,
    .bDeviceSubClass = 0x00,
    .bDeviceProtocol = 0x00,
    .bMaxPacketSize0 = CFG_TUD_ENDPOINT0_SIZE,
    .idVendor = USB_VID,
    .idProduct = USB_PID,
    .bcdDevice = USB_BCD,
    .iManufacturer = 0x01,
    .iProduct = 0x02,
    .iSerialNumber = 0x03,
    .bNumConfigurations = 0x01,
};

uint8_t const *tud_descriptor_device_cb(void) {
    return (uint8_t const *)&device_descriptor;
}

enum {
    ITF_NUM_MIDI = 0,
    ITF_NUM_MIDI_STREAMING,
    ITF_NUM_TOTAL,
};

#define CONFIG_TOTAL_LEN (TUD_CONFIG_DESC_LEN + TUD_MIDI_DESC_LEN)
#define EPNUM_MIDI_OUT 0x01
#define EPNUM_MIDI_IN 0x81

uint8_t const configuration_descriptor[] = {
    TUD_CONFIG_DESCRIPTOR(1, ITF_NUM_TOTAL, 0, CONFIG_TOTAL_LEN, 0x00, 100),
    TUD_MIDI_DESCRIPTOR(ITF_NUM_MIDI, 0, EPNUM_MIDI_OUT, EPNUM_MIDI_IN, 64),
};

uint8_t const *tud_descriptor_configuration_cb(uint8_t index) {
    (void)index;
    return configuration_descriptor;
}

enum {
    STRID_LANGID = 0,
    STRID_MANUFACTURER,
    STRID_PRODUCT,
    STRID_SERIAL,
};

static char const *string_descriptors[] = {
    (const char[]){0x09, 0x04},
    A26F_USB_MANUFACTURER,
    A26F_USB_PRODUCT,
    NULL,
};

static uint16_t descriptor_buffer[33];

uint16_t const *tud_descriptor_string_cb(uint8_t index, uint16_t langid) {
    (void)langid;
    size_t count;

    if (index == STRID_LANGID) {
        memcpy(&descriptor_buffer[1], string_descriptors[0], 2);
        count = 1;
    } else if (index == STRID_SERIAL) {
        count = board_usb_get_serial(descriptor_buffer + 1, 32);
    } else {
        if (index >= sizeof(string_descriptors) / sizeof(string_descriptors[0])) {
            return NULL;
        }
        const char *text = string_descriptors[index];
        count = strlen(text);
        if (count > 32) {
            count = 32;
        }
        for (size_t i = 0; i < count; ++i) {
            descriptor_buffer[i + 1] = (uint8_t)text[i];
        }
    }

    descriptor_buffer[0] = (uint16_t)((TUSB_DESC_STRING << 8u) | (2u * count + 2u));
    return descriptor_buffer;
}

