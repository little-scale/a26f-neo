cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(a26f_neo_pico C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

function(add_a26f_firmware target inversion product_name)
    add_executable(${target}
        src/link.c
        src/main.c
        src/usb_descriptors.c
    )

    target_include_directories(${target} PRIVATE src)
    target_compile_definitions(${target} PRIVATE
        A26F_LINK_OUTPUT_INVERTED=${inversion}
        A26F_USB_PRODUCT=\"${product_name}\"
    )

    target_link_libraries(${target} PRIVATE
        pico_stdlib
        tinyusb_device
        tinyusb_board
    )

    pico_enable_stdio_uart(${target} 0)
    pico_enable_stdio_usb(${target} 0)
    pico_add_extra_outputs(${target})
endfunction()

# Recommended for the documented two-NPN open-collector interface.
add_a26f_firmware(a26f_neo_npn 1 "A26F NEO NPN")

# For a suitable interface which does not invert the Pico GPIO levels.
add_a26f_firmware(a26f_neo_noninverting 0 "A26F NEO Non-Inverting")
