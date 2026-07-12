LOCAL_PICO_TOOLCHAIN := $(if $(wildcard pico/toolchain/bin/arm-none-eabi-gcc),-DPICO_TOOLCHAIN_PATH=$(CURDIR)/pico/toolchain,)
PICO_CMAKE_ARGS ?= $(LOCAL_PICO_TOOLCHAIN)
PICO_TEST_BUILD ?= pico/build-test

.PHONY: all test test-pico test-stella clean

all:
	$(MAKE) -C atari all
	@node web/build.mjs

test:
	$(MAKE) -C atari clean all
	@node web/build.mjs
	@node --test tests/*.test.mjs

test-pico:
	@cmake -S pico -B $(PICO_TEST_BUILD) -DPICO_BOARD=pico $(PICO_CMAKE_ARGS)
	@cmake --build $(PICO_TEST_BUILD)
	@node tools/verify-pico-build.mjs $(PICO_TEST_BUILD)

test-stella:
	@node tools/stella-smoke.mjs

clean:
	$(MAKE) -C atari clean
