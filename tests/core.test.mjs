import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

import {
  createFactory,
  decodeWav,
  extractRomSlots,
  parseFactory,
  parseManifest,
  patchRom,
  processAudio,
} from "../web/src/core.js";

const readBytes = async (path) => new Uint8Array(await readFile(path));

test("PAL and NTSC manifests identify exact production targets", async () => {
  const pal = parseManifest(await readBytes("atari/build/a26f-pal.f4"));
  const ntsc = parseManifest(await readBytes("atari/build/a26f-ntsc.f4"));
  assert.equal(pal.tv, "PAL");
  assert.equal(pal.sampleRate, 7812.5);
  assert.equal(ntsc.tv, "NTSC");
  assert.equal(ntsc.sampleRate, 7867.132);
  assert.equal(pal.slotCount, 32);
  assert.equal(ntsc.slotCount, 32);
});

test("empty production ROMs contain no sample slots", async () => {
  for (const tv of ["pal", "ntsc"]) {
    const rom = await readBytes(`atari/build/a26f-${tv}.f4`);
    assert.equal(extractRomSlots(rom, parseManifest(rom)).filter(Boolean).length, 0);
  }
});

test("default factory is deterministic and checksummed", async () => {
  const bytes = await readBytes("factory/default.a26factory");
  const factory = parseFactory(bytes);
  assert.equal(factory.slots.filter(Boolean).length, 16);
  assert.deepEqual(createFactory(factory.slots), bytes);

  const corrupt = bytes.slice();
  corrupt[corrupt.length - 1] ^= 1;
  assert.throws(() => parseFactory(corrupt), /checksum/i);
});

test("populated ROM samples survive browser extraction and patching byte-for-byte", async () => {
  for (const tv of ["pal", "ntsc"]) {
    const rom = await readBytes(`atari/build/a26f-${tv}-factory.bin`);
    const manifest = parseManifest(rom);
    const extracted = extractRomSlots(rom, manifest);
    assert.equal(extracted.filter(Boolean).length, 16);
    const editable = extracted.map((slot) => slot
      ? {...slot, packed: slot.variants[manifest.tv].packed}
      : null);
    assert.deepEqual(patchRom(rom, manifest, editable).rom, rom);
  }
});

test("editing a populated ROM gate flag preserves its audio", async () => {
  const rom = await readBytes("atari/build/a26f-pal-factory.bin");
  const manifest = parseManifest(rom);
  const slots = extractRomSlots(rom, manifest).map((slot) => slot
    ? {...slot, packed: slot.variants.PAL.packed}
    : null);
  const original = slots[0].packed.slice();
  slots[0].gated = false;
  const patched = patchRom(rom, manifest, slots).rom;
  const reparsed = extractRomSlots(patched, parseManifest(patched));
  assert.equal(reparsed[0].gated, false);
  assert.deepEqual(reparsed[0].variants.PAL.packed, original);
});

test("patcher rejects a sample larger than one payload bank", async () => {
  const rom = await readBytes("atari/build/a26f-pal.f4");
  const manifest = parseManifest(rom);
  const slots = Array(32).fill(null);
  slots[0] = {packed: new Uint8Array(3841), gated: true};
  assert.throws(() => patchRom(rom, manifest, slots), /exceeds 3840/i);
});

test("WAV decoder and 4-bit converter handle silence deterministically", () => {
  const wav = new Uint8Array(44 + 8);
  const view = new DataView(wav.buffer);
  const putText = (offset, text) => [...text].forEach((char, index) => {
    wav[offset + index] = char.charCodeAt(0);
  });
  putText(0, "RIFF");
  view.setUint32(4, 44, true);
  putText(8, "WAVE");
  putText(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, 8000, true);
  view.setUint32(28, 16000, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  putText(36, "data");
  view.setUint32(40, 8, true);

  const decoded = decodeWav(wav.buffer);
  assert.equal(decoded.sampleRate, 8000);
  assert.equal(decoded.samples.length, 4);
  const converted = processAudio(decoded, 7812.5, {});
  assert.equal(converted.sampleCount, 2);
  assert.deepEqual(converted.packed, new Uint8Array([0x88]));
});

test("manifest parser rejects damaged ROM identity", async () => {
  const rom = await readBytes("atari/build/a26f-pal.f4");
  rom[0x7e00] ^= 1;
  assert.throws(() => parseManifest(rom), /manifest not found/i);
});
