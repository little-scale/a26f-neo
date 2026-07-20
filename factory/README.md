# Factory sample bank

Place the browser-exported factory bank at `factory/default.a26factory`, or
provide another path when building:

```sh
make -C atari
make -C atari FACTORY=/path/to/instrument.a26factory
```

This creates the only two production images: `atari/build/a26f-pal.bin` and
`atari/build/a26f-ntsc.bin`. Both contain the receive-history display and the
selected factory's ordered slots, gated/one-shot flags, and television-specific
4-bit sample data. Both remain compatible with browser ROM patching.
