import {mkdir} from "node:fs/promises";
import {spawnSync} from "node:child_process";

const cases = [
  ["atari/build/a26f-pal.bin", "PAL", "F4"],
  ["atari/build/a26f-ntsc.bin", "NTSC", "F4"],
];
const basedir = `/tmp/a26f-stella-smoke-${process.pid}`;
await mkdir(basedir, {recursive: true});

for (const [path, tv, mapper] of cases) {
  const result = spawnSync("stella", ["-basedir", basedir, "-rominfo", path], {
    encoding: "utf8",
    env: {...process.env, SDL_VIDEODRIVER: "dummy", SDL_AUDIODRIVER: "dummy"},
  });
  if (result.error) throw result.error;
  const output = `${result.stdout}\n${result.stderr}`;
  if (result.status !== 0 || !new RegExp(`Display Format:\\s+${tv}`).test(output) ||
      !new RegExp(`Bankswitch Type:\\s+${mapper}`).test(output)) {
    throw new Error(`Stella rejected ${path}:\n${output}`);
  }
  console.log(`Stella: ${path} is ${tv} ${mapper}`);
}
