import {createHash} from "node:crypto";
import {copyFile, mkdir, readFile, readdir, rm, writeFile} from "node:fs/promises";
import {spawnSync} from "node:child_process";
import path from "node:path";

const version = (process.argv[2] ?? "").trim();
if (!/^v0\.\d+$/.test(version)) {
  throw new Error("Usage: node tools/build-release.mjs v0.N");
}

const declaredVersion = (await readFile("VERSION", "utf8")).trim();
if (version !== declaredVersion) {
  throw new Error(`Requested ${version}, but VERSION declares ${declaredVersion}.`);
}

const romFiles = (await readdir("atari/build"))
  .filter((name) => name.endsWith(".bin"))
  .sort();
if (romFiles.join("\n") !== "a26f-ntsc.bin\na26f-pal.bin") {
  throw new Error(`Expected exactly the PAL and NTSC ROMs; found: ${romFiles.join(", ")}`);
}

const bundleName = `a26f-neo-${version}`;
const bundleDir = path.join("dist", bundleName);
const archivePath = path.join("dist", `${bundleName}.zip`);
await rm(bundleDir, {recursive: true, force: true});
await rm(archivePath, {force: true});
await mkdir(bundleDir, {recursive: true});

const payloads = [
  ["atari/build/a26f-pal.bin", "a26f-pal.bin"],
  ["atari/build/a26f-ntsc.bin", "a26f-ntsc.bin"],
  ["pico/build-pico2w/a26f_neo_noninverting.uf2", "a26f-pico2w-noninverting.uf2"],
  ["pico/build-pico2w/a26f_neo_npn.uf2", "a26f-pico2w-npn.uf2"],
  ["web/a26f-rom-patcher.html", "a26f-rom-patcher.html"],
  ["factory/default.a26factory", "default.a26factory"],
];
const documents = [
  ["README.md", "README.md"],
  ["docs/manual.md", "manual.md"],
  ["hardware/wiring.md", "wiring.md"],
  ["CHANGELOG.md", "CHANGELOG.md"],
  ["LICENSE", "LICENSE"],
];

for (const [source, destination] of [...payloads, ...documents]) {
  await copyFile(source, path.join(bundleDir, destination));
}

const checksumLines = [];
for (const [, destination] of payloads) {
  const bytes = await readFile(path.join(bundleDir, destination));
  const digest = createHash("sha256").update(bytes).digest("hex");
  checksumLines.push(`${digest}  ${destination}`);
}
await writeFile(path.join(bundleDir, "SHA256SUMS"), `${checksumLines.join("\n")}\n`);

const zip = spawnSync("zip", ["-q", "-r", `${bundleName}.zip`, bundleName], {
  cwd: "dist",
  encoding: "utf8",
});
if (zip.error) throw zip.error;
if (zip.status !== 0) throw new Error(`zip failed: ${zip.stderr}`);

console.log(`Prepared ${bundleDir}`);
console.log(`Prepared ${archivePath}`);
