import {readFile} from "node:fs/promises";

const [pal4kPath, ntsc4kPath, palF4Path, ntscF4Path] = process.argv.slice(2);
if (!ntscF4Path) throw new Error("Pass PAL/NTSC 4K and PAL/NTSC F4 ROM paths.");

const files = await Promise.all(
  [pal4kPath, ntsc4kPath, palF4Path, ntscF4Path].map((path) => readFile(path)),
);
if (files[0].length !== 4096 || files[1].length !== 4096 ||
    files[2].length !== 32768 || files[3].length !== 32768) {
  throw new Error("Unexpected ROM byte size.");
}

for (const [index, rom] of files.slice(2).entries()) {
  if (rom.subarray(0x7e00, 0x7e08).toString("binary") !== "A26FSMP\0") {
    throw new Error("Patch manifest magic is missing.");
  }
  if (rom[0x7e08] !== 1 || rom[0x7e09] !== 0 || rom[0x7e0a] !== index) {
    throw new Error("Patch manifest version or television target is incorrect.");
  }
  const reference = rom.subarray(0x0f00, 0x1000);
  for (let bank = 1; bank < 8; bank += 1) {
    if (!reference.equals(rom.subarray(bank * 0x1000 + 0x0f00, (bank + 1) * 0x1000))) {
      throw new Error(`F4 common stub differs in bank ${bank}.`);
    }
  }
  for (let slot = 0; slot < 32; slot += 1) {
    if (rom[0x7d00 + slot * 8] !== 0xff) throw new Error("Base ROM directory is not empty.");
  }
}

console.log("Verified ROM sizes, manifests, directories, and F4 common stubs");
