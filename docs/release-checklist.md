# Release checklist

## Version policy

- Current release: `v0.11`
- Development/next release: `v0.12`
- Continue in `v0.01` increments: `v0.13`, `v0.14`, and so on
- Update `VERSION` and add a new `CHANGELOG.md` section before each release
- Do not change the wire, ROM, or factory format version unless compatibility
  actually changes

## Build candidate

From the repository root:

```sh
make release
```

This rebuilds and tests the Atari ROMs and browser tool, runs Stella checks,
builds and verifies the original Pico and Pico 2 W firmware, and creates:

```text
dist/a26f-neo-v0.12/
dist/a26f-neo-v0.12.zip
```

## Release contents

- `a26f-pal.bin`
- `a26f-ntsc.bin`
- `a26f-pico-noninverting.uf2`
- `a26f-pico-npn.uf2`
- `a26f-pico2w-noninverting.uf2`
- `a26f-pico2w-npn.uf2`
- `a26f-rom-patcher.html`
- `default.a26factory`
- `README.md`
- `manual.md`
- `wiring.md`
- `CHANGELOG.md`
- `LICENSE`
- `SHA256SUMS`

## Final checks

- Confirm `git status` contains only intended source and documentation changes.
- Confirm both ROMs are exactly 32,768 bytes and Stella identifies them as F4.
- Confirm the PAL ROM boots on original hardware and joystick soundcheck works.
- Confirm GP5/UART1 accepts opto-isolated DIN or TRS Type A MIDI and GP6 holds
  the external valid-message LED visibly high for mapped USB and UART events.
- Flash `a26f-pico2w-noninverting.uf2` to the tested Pico 2 W and confirm MIDI,
  synthesis, sample triggering, gate-off, CC20 rates at 1×/2×/4×, and
  receive-history bands.
- Open the bundled patcher offline, load each bundled ROM, audition a sample,
  and export a patched copy.
- Verify the archive against `SHA256SUMS` after extracting it.
- Commit the release preparation, create the matching annotated tag, push the
  commit and tag, then attach the matching versioned zip to the GitHub release.
