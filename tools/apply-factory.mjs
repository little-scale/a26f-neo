import {readFile, writeFile} from "node:fs/promises";
import {parseFactory, parseManifest, patchRom} from "../web/src/core.js";

const [basePath, factoryPath, outputPath] = process.argv.slice(2);
if (!outputPath) {
  throw new Error("Usage: node tools/apply-factory.mjs BASE_ROM FACTORY OUTPUT_ROM");
}

const base = new Uint8Array(await readFile(basePath));
const manifest = parseManifest(base);
const factory = parseFactory(await readFile(factoryPath));
const slots = factory.slots.map((slot) => {
  if (!slot) return null;
  const variant = slot.variants[manifest.tv];
  return {...slot, packed: variant.packed};
});
const result = patchRom(base, manifest, slots);
await writeFile(outputPath, result.rom);
console.log(`Built ${manifest.tv} factory ROM: ${outputPath} (${result.used}/${result.capacity} sample bytes)`);
