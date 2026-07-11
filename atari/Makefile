DASM ?= dasm
PAL_ROM := build/a26f-pal-4k.bin
NTSC_ROM := build/a26f-ntsc-4k.bin
SRC := src/main.asm

.PHONY: all clean verify

all: $(PAL_ROM) $(NTSC_ROM) verify

$(PAL_ROM): $(SRC) src/vcs.inc
	@mkdir -p build
	$(DASM) $(SRC) -f3 -Isrc -o$(PAL_ROM) -lbuild/a26f-pal-4k.lst -sbuild/a26f-pal-4k.sym

$(NTSC_ROM): $(SRC) src/vcs.inc
	@mkdir -p build
	$(DASM) $(SRC) -DVIDEO_NTSC=1 -f3 -Isrc -o$(NTSC_ROM) -lbuild/a26f-ntsc-4k.lst -sbuild/a26f-ntsc-4k.sym

verify: $(PAL_ROM) $(NTSC_ROM)
	@test "$$(wc -c < $(PAL_ROM) | tr -d ' ')" = "4096"
	@test "$$(wc -c < $(NTSC_ROM) | tr -d ' ')" = "4096"
	@echo "Verified PAL and NTSC diagnostic ROMs: 4096 bytes each"

clean:
	rm -f build/a26f-*-4k.bin build/a26f-*-4k.lst build/a26f-*-4k.sym
