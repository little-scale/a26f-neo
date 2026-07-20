import {readFile} from "node:fs/promises";

import {extractRomSlots, parseManifest} from "../web/src/core.js";

const paths = process.argv.slice(2);
if (paths.length !== 2) {
  throw new Error("Pass the PAL and NTSC production ROM paths.");
}

for (const [index, path] of paths.entries()) {
  const rom = new Uint8Array(await readFile(path));
  if (rom.length !== 32768) {
    throw new Error(`${path} is not a 32 KiB F4 ROM.`);
  }

  const manifest = parseManifest(rom);
  const expectedTv = index === 0 ? "PAL" : "NTSC";
  if (manifest.tv !== expectedTv) {
    throw new Error(`${path} identifies as ${manifest.tv}, expected ${expectedTv}.`);
  }

  const reference = rom.subarray(0x0f00, 0x1000);
  for (let bank = 1; bank < 8; bank += 1) {
    const stub = rom.subarray(bank * 0x1000 + 0x0f00, (bank + 1) * 0x1000);
    if (stub.some((byte, offset) => byte !== reference[offset])) {
      throw new Error(`F4 common stub differs in bank ${bank} of ${path}.`);
    }
  }

  const sampleCount = extractRomSlots(rom, manifest).filter(Boolean).length;
  console.log(`Verified ${path}: ${expectedTv} F4, ${sampleCount} populated sample slots`);
}
