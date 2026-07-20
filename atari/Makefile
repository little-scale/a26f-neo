DASM ?= dasm
PAL_ROM := build/a26f-pal.bin
NTSC_ROM := build/a26f-ntsc.bin
FACTORY ?= ../factory/default.a26factory
SOURCES := src/f4.asm src/main.asm src/f4_stub.inc src/vcs.inc

.PHONY: all clean verify

all: $(PAL_ROM) $(NTSC_ROM) verify

$(PAL_ROM): $(SOURCES) $(FACTORY) ../tools/apply-factory.mjs ../web/src/core.js
	@mkdir -p build
	$(DASM) src/f4.asm -f3 -Isrc -obuild/.a26f-pal-base -lbuild/a26f-pal.lst -sbuild/a26f-pal.sym
	@node ../tools/apply-factory.mjs build/.a26f-pal-base $(FACTORY) $@
	@rm -f build/.a26f-pal-base

$(NTSC_ROM): $(SOURCES) $(FACTORY) ../tools/apply-factory.mjs ../web/src/core.js
	@mkdir -p build
	$(DASM) src/f4.asm -DVIDEO_NTSC=1 -f3 -Isrc -obuild/.a26f-ntsc-base -lbuild/a26f-ntsc.lst -sbuild/a26f-ntsc.sym
	@node ../tools/apply-factory.mjs build/.a26f-ntsc-base $(FACTORY) $@
	@rm -f build/.a26f-ntsc-base

verify: $(PAL_ROM) $(NTSC_ROM)
	@node ../tools/verify-rom.mjs $(PAL_ROM) $(NTSC_ROM)

clean:
	rm -f build/a26f-* build/.a26f-*
