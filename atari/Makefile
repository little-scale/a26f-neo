DASM ?= dasm
PAL_ROM := build/a26f-pal-4k.bin
NTSC_ROM := build/a26f-ntsc-4k.bin
PAL_F4 := build/a26f-pal.f4
NTSC_F4 := build/a26f-ntsc.f4
PAL_FACTORY_ROM := build/a26f-pal-factory.bin
NTSC_FACTORY_ROM := build/a26f-ntsc-factory.bin
FACTORY ?= ../factory/default.a26factory
SRC := src/main.asm

.PHONY: all clean verify factory

all: $(PAL_ROM) $(NTSC_ROM) $(PAL_F4) $(NTSC_F4) verify

$(PAL_ROM): $(SRC) src/vcs.inc
	@mkdir -p build
	$(DASM) $(SRC) -f3 -Isrc -o$(PAL_ROM) -lbuild/a26f-pal-4k.lst -sbuild/a26f-pal-4k.sym

$(NTSC_ROM): $(SRC) src/vcs.inc
	@mkdir -p build
	$(DASM) $(SRC) -DVIDEO_NTSC=1 -f3 -Isrc -o$(NTSC_ROM) -lbuild/a26f-ntsc-4k.lst -sbuild/a26f-ntsc-4k.sym

$(PAL_F4): src/f4.asm $(SRC) src/f4_stub.inc src/vcs.inc
	@mkdir -p build
	$(DASM) src/f4.asm -f3 -Isrc -o$(PAL_F4) -lbuild/a26f-pal-f4.lst -sbuild/a26f-pal-f4.sym

$(NTSC_F4): src/f4.asm $(SRC) src/f4_stub.inc src/vcs.inc
	@mkdir -p build
	$(DASM) src/f4.asm -DVIDEO_NTSC=1 -f3 -Isrc -o$(NTSC_F4) -lbuild/a26f-ntsc-f4.lst -sbuild/a26f-ntsc-f4.sym

verify: $(PAL_ROM) $(NTSC_ROM) $(PAL_F4) $(NTSC_F4)
	@node ../tools/verify-rom.mjs $(PAL_ROM) $(NTSC_ROM) $(PAL_F4) $(NTSC_F4)

factory: $(PAL_FACTORY_ROM) $(NTSC_FACTORY_ROM)

$(PAL_FACTORY_ROM): $(PAL_F4) $(FACTORY) ../tools/apply-factory.mjs ../web/src/core.js
	@node ../tools/apply-factory.mjs $(PAL_F4) $(FACTORY) $@

$(NTSC_FACTORY_ROM): $(NTSC_F4) $(FACTORY) ../tools/apply-factory.mjs ../web/src/core.js
	@node ../tools/apply-factory.mjs $(NTSC_F4) $(FACTORY) $@

clean:
	rm -f build/a26f-*.bin build/a26f-*.f4 build/a26f-*.lst build/a26f-*.sym
