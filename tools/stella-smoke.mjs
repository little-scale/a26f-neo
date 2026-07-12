import {mkdir} from "node:fs/promises";
import {spawnSync} from "node:child_process";

const cases = [
  ["atari/build/a26f-pal.f4", "PAL"],
  ["atari/build/a26f-ntsc.f4", "NTSC"],
  ["atari/build/a26f-pal-factory.bin", "PAL"],
  ["atari/build/a26f-ntsc-factory.bin", "NTSC"],
];
const basedir = `/tmp/a26f-stella-smoke-${process.pid}`;
await mkdir(basedir, {recursive: true});

for (const [path, tv] of cases) {
  const result = spawnSync("stella", ["-basedir", basedir, "-rominfo", path], {
    encoding: "utf8",
    env: {...process.env, SDL_VIDEODRIVER: "dummy", SDL_AUDIODRIVER: "dummy"},
  });
  if (result.error) throw result.error;
  const output = `${result.stdout}\n${result.stderr}`;
  if (result.status !== 0 || !new RegExp(`Display Format:\\s+${tv}`).test(output) ||
      !/Bankswitch Type:\s+F4/.test(output)) {
    throw new Error(`Stella rejected ${path}:\n${output}`);
  }
  console.log(`Stella: ${path} is ${tv} F4 (32K)`);
}
