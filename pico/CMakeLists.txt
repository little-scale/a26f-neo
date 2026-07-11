cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(a26f_neo_pico C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(a26f_neo
    src/link.c
    src/main.c
    src/usb_descriptors.c
)

target_include_directories(a26f_neo PRIVATE src)

target_link_libraries(a26f_neo PRIVATE
    pico_stdlib
    tinyusb_device
    tinyusb_board
)

pico_enable_stdio_uart(a26f_neo 0)
pico_enable_stdio_usb(a26f_neo 0)
pico_add_extra_outputs(a26f_neo)

