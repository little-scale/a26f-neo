# Factory sample bank

Place the browser-exported factory bank at `factory/default.a26factory`, or
provide another path when building:

```sh
make -C atari factory
make -C atari factory FACTORY=/path/to/instrument.a26factory
```

The normal `make -C atari` build also applies `default.a26factory`; the
dedicated `factory` target is useful when rebuilding only populated outputs.

This creates `atari/build/a26f-pal-factory.bin` and
`atari/build/a26f-ntsc-factory.bin`. Factory files contain ordered slots,
gated/one-shot flags, names, and prepared PAL and NTSC 4-bit sample variants.
