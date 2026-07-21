LOCAL_PICO_TOOLCHAIN := $(if $(wildcard pico/toolchain/bin/arm-none-eabi-gcc),-DPICO_TOOLCHAIN_PATH=$(CURDIR)/pico/toolchain,)
PICO_CMAKE_ARGS ?= $(LOCAL_PICO_TOOLCHAIN)
PICO_TEST_BUILD ?= pico/build-test

VERSION := $(shell tr -d '\r\n' < VERSION)

.PHONY: all test test-pico test-stella release clean

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
	@$(MAKE) -C atari all
	@node tools/stella-smoke.mjs

release: test test-stella
	@cmake -S pico -B pico/build-pico -DPICO_BOARD=pico $(PICO_CMAKE_ARGS)
	@cmake --build pico/build-pico
	@node tools/verify-pico-build.mjs pico/build-pico
	@cmake -S pico -B pico/build-pico2w -DPICO_BOARD=pico2_w $(PICO_CMAKE_ARGS)
	@cmake --build pico/build-pico2w
	@node tools/verify-pico-build.mjs pico/build-pico2w pico2_w
	@node tools/build-release.mjs $(VERSION)

clean:
	$(MAKE) -C atari clean
