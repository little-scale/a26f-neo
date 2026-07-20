# A26F NEO PAL Hardware Bring-up Checklist

Use this sequence for the first original-hardware test. Stop at the first
unexpected result; each stage isolates a smaller part of the system.

## Test files

- Atari ROM: `atari/build/a26f-pal.bin`
- Pico 2 W with two-NPN interface: `pico/build-pico2w/a26f_neo_npn.uf2`
- Current TXS0108E firmware:
  `pico/build-pico2w/a26f_neo_noninverting.uf2`. TXS0108E support uses GP4 for
  OE and must not be substituted with a TXB0108.

## 1. Unpowered inspection

- [ ] Atari and Pico are disconnected from power.
- [ ] Atari port 2 pin 1 connects only to the clock transistor collector.
- [ ] Atari port 2 pin 2 connects only to the data transistor collector.
- [ ] Atari port 2 pin 8 connects to Pico ground and both emitters.
- [ ] GP3 reaches the clock base through 4.7 kΩ.
- [ ] GP2 reaches the data base through 4.7 kΩ.
- [ ] The exact transistor collector/base/emitter pinout has been checked.
- [ ] Atari port 5 V is not connected.
- [ ] There are no collector-to-emitter or adjacent DB9 shorts.

For the alternate TXS0108E interface, replace the NPN-specific checks above:

- [ ] Pico `3V3(OUT)` (header pin 36) reaches VCCA/VA.
- [ ] GP4 (Pico header pin 6) reaches OE.
- [ ] OE has a 10 kOhm pulldown if the module does not already provide one.
- [ ] GP2 reaches A1 and GP3 reaches A2.
- [ ] B1 reaches Atari pin 2 and B2 reaches Atari pin 1.
- [ ] Atari pin 7 reaches VCCB/VB only.
- [ ] Atari pin 8, Pico ground, and translator ground are common.
- [ ] The module is marked TXS0108E, not TXB0108.

## 2. Atari-only ROM test

Leave the Pico interface disconnected from controller port 2.

- [ ] Set the flashcart for PAL.
- [ ] Load `a26f-pal.bin`.
- [ ] Confirm a stable display.
- [ ] Connect a joystick to port 1.
- [ ] Confirm directions produce tones in bank 0.
- [ ] Press and release Fire four times.
- [ ] Confirm directions trigger factory sample slots 0–3.
- [ ] Confirm the sixteen full-width receive-history bands remain stable.

If this stage fails, troubleshoot the ROM, flashcart, television mode, or
joystick before connecting the Pico.

## 3. Pico-only USB test

Leave the Atari disconnected.

- [ ] Flash the UF2 matching the interface: `a26f_neo_npn.uf2` or
      `a26f_neo_noninverting.uf2`.
- [ ] Confirm the corresponding `A26F NEO NPN` or
      `A26F NEO Non-Inverting` MIDI device appears.
- [ ] For TXS0108E, measure approximately 3.3 V between VCCA and ground.
- [ ] For TXS0108E, measure approximately 3.3 V between GP4/OE and ground.
- [ ] Select it as a MIDI output.
- [ ] Send channel 1 and channel 10 notes.
- [ ] Confirm the Pico LED responds to incoming MIDI.

The LED confirms USB MIDI reception only. It does not prove controller-port
transfer.

## 4. Optional signal test

With a logic analyser or oscilloscope connected on the Pico side:

- [ ] GP2 is data.
- [ ] GP3 is clock.
- [ ] A MIDI message produces eight clock transitions per protocol byte.
- [ ] Data changes before each clock transition.
- [ ] Clock transitions are approximately 1 ms apart.
- [ ] Data is established approximately 250 µs before each clock transition.
- [ ] There is an approximately 5 ms inter-byte gap.

For the NPN UF2, GPIO levels are intentionally pre-inverted before the
transistor stages.

If a staged diagnosis is required, use `a26f_neo_link_test.uf2` while measuring
the four raw GP2/GP3 states, or use `a26f_neo_protocol_test.uf2` with the
production ROM to test decoded commands without USB MIDI.

## 5. Complete system test

Power down before connecting the controller-port interface.

- [ ] Insert the flashcart and connect the interface to controller port 2.
- [ ] Power the Atari, then connect the Pico to USB.
- [ ] Load `a26f-pal.bin`.
- [ ] Send channel 1 note 60 at velocity 127.
- [ ] Confirm TIA voice 0 audio and colour response.
- [ ] Move channel 1 CC1 through several values.
- [ ] Confirm several TIA sound-control characters.
- [ ] Test channel 1 CC73 attack and CC72 release/decay.
- [ ] Send CC70 = 127, confirm attack-decay completes without note-off, then
      send CC70 = 0 and confirm note-off gates the release again.
- [ ] Confirm each MIDI note changes at least its pitch and amplitude history
      bands without disturbing audio.
- [ ] Confirm bands fill in ring order and begin wrapping after sixteen bytes.
- [ ] Confirm the visualizer contains only full-width horizontal bands, with no
      grey playfield blocks over them.
- [ ] Send a channel 2 note and confirm TIA voice 1.
- [ ] Send channel 10 note 32 and confirm sample slot 0.
- [ ] Send channel 10 notes 33–35 and confirm slots 1–3.
- [ ] Send channel 10 CC20 values 0, 64, and 127 and confirm 1×, 2×, and 4×
      sample speed and pitch.
- [ ] Release a gated drum note early and confirm de-clicked stop.
- [ ] Set a browser-patched slot to one-shot and confirm note-off is ignored.

## 6. Stress test

- [ ] Alternate channel 1 and channel 2 notes rapidly.
- [ ] Sweep CC1 while notes are held.
- [ ] Trigger channel 10 repeatedly at the intended performance rate.
- [ ] Confirm no stuck notes after deliberately sending stale note-offs.
- [ ] Confirm video remains stable during dense MIDI.
- [ ] Confirm samples maintain stable pitch during dense MIDI.
- [ ] Run continuously for at least ten minutes.

## Fault isolation

| Observation | Most likely area |
|---|---|
| No stable display | ROM TV target, flashcart setting, or ROM image |
| Joystick tones work; samples do not | Wrong/empty ROM sample bank or wrong soundcheck bank |
| Pico MIDI device absent | UF2, USB cable, USB port, or host MIDI setup |
| Pico LED inactive | DAW routing or incoming USB MIDI |
| Pico LED active; Atari unchanged | Ground, GPIO assignment, transistor pinout, or polarity firmware |
| Random Atari commands | Data polarity, missed clock edges, poor ground, or wiring noise |
| Synth works; samples fail over MIDI | Channel 10 routing or note-to-slot choice |
| Samples start but do not gate | Slot is one-shot or note-off pitch does not exactly match |
| Unstable sample pitch/video | Link timing, receiver polling, or an unexpected scanline overrun |
| Audio works but history bands do not change | Old ROM, receive-path fault, or unchanged repeated data |

## Test record

| Item | Result/notes |
|---|---|
| Console model and region | |
| Flashcart and switch settings | |
| Pico board | |
| Transistor type and pinout | |
| ROM filename | |
| UF2 filename | |
| MIDI host/software | |
| Joystick test | |
| Channel 1 | |
| Channel 2 | |
| Channel 10 samples | |
| Gate behaviour | |
| Stress test | |
