import {readFile} from "node:fs/promises";
import {spawnSync} from "node:child_process";

const buildDir = process.argv[2] ?? "pico/build";
const expectedBoard = process.argv[3] ?? "pico";
const variants = [
  ["a26f_neo_npn", "A26F NEO NPN"],
  ["a26f_neo_noninverting", "A26F NEO Non-Inverting"],
];
const uf2Files = [];

for (const [target, usbName] of variants) {
  const uf2Path = `${buildDir}/${target}.uf2`;
  const elfPath = `${buildDir}/${target}.elf`;
  const [uf2, elf] = await Promise.all([readFile(uf2Path), readFile(elfPath)]);
  if (uf2.length < 1024) throw new Error(`${uf2Path} is unexpectedly small.`);
  if (!elf.includes(Buffer.from(usbName))) throw new Error(`${elfPath} lacks USB name ${usbName}.`);

  const info = spawnSync("picotool", ["info", "-a", uf2Path], {encoding: "utf8"});
  if (info.error) throw info.error;
  const hasField = (name, value) => new RegExp(`^\\s*${name}:\\s+${value}\\s*$`, "m")
    .test(info.stdout);
  if (info.status !== 0 || !hasField("name", target) ||
      !hasField("sdk version", "2\\.3\\.0") ||
      !hasField("pico_board", expectedBoard)) {
    throw new Error(`picotool validation failed for ${uf2Path}.`);
  }
  uf2Files.push(uf2);
  console.log(`Pico: ${target}.uf2 is ${expectedBoard} / SDK 2.3.0 with USB name ${usbName}`);
}

if (uf2Files[0].equals(uf2Files[1])) throw new Error("Pico polarity UF2 files are identical.");
