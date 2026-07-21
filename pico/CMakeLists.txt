cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(a26f_neo_pico C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

function(add_a26f_firmware target inversion txs_gpio_oe product_name)
    add_executable(${target}
        src/link.c
        src/main.c
        src/midi_serial_parser.c
        src/usb_descriptors.c
    )

    target_include_directories(${target} PRIVATE src)
    target_compile_definitions(${target} PRIVATE
        A26F_LINK_OUTPUT_INVERTED=${inversion}
        A26F_TXS0108E_GPIO_OE=${txs_gpio_oe}
        A26F_USB_PRODUCT=\"${product_name}\"
    )

    target_link_libraries(${target} PRIVATE
        pico_stdlib
        hardware_uart
        tinyusb_device
        tinyusb_board
    )

    pico_enable_stdio_uart(${target} 0)
    pico_enable_stdio_usb(${target} 0)
    pico_add_extra_outputs(${target})
endfunction()

# Recommended for the documented two-NPN open-collector interface.
add_a26f_firmware(a26f_neo_npn 1 0 "A26F NEO NPN")

# For a TXS0108E or another suitable non-inverting interface. This variant
# controls the translator's OE input from GP4 after link-pin initialization.
add_a26f_firmware(a26f_neo_noninverting 0 1 "A26F NEO Non-Inverting")

# Slow electrical test for the documented TXS0108E wiring. It cycles GP2/GP3
# through 00, 10, 01, and 11 so a meter or logic analyser can show whether each
# signal reaches the A side, B side, and console independently.
add_executable(a26f_neo_link_test
    src/link_test.c
)

target_link_libraries(a26f_neo_link_test PRIVATE
    pico_stdlib
)

pico_enable_stdio_uart(a26f_neo_link_test 0)
pico_enable_stdio_usb(a26f_neo_link_test 0)
pico_add_extra_outputs(a26f_neo_link_test)

# End-to-end protocol test for the non-inverting TXS0108E interface. This
# sends register writes and a sample trigger without requiring USB MIDI.
add_executable(a26f_neo_protocol_test
    src/link.c
    src/protocol_test.c
)

target_include_directories(a26f_neo_protocol_test PRIVATE src)
target_compile_definitions(a26f_neo_protocol_test PRIVATE
    A26F_LINK_OUTPUT_INVERTED=0
    A26F_TXS0108E_GPIO_OE=1
)
target_link_libraries(a26f_neo_protocol_test PRIVATE
    pico_stdlib
)

pico_enable_stdio_uart(a26f_neo_protocol_test 0)
pico_enable_stdio_usb(a26f_neo_protocol_test 0)
pico_add_extra_outputs(a26f_neo_protocol_test)
