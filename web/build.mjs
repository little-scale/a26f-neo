import {readFile, writeFile} from "node:fs/promises";

const root = new URL("./", import.meta.url);
const [template, style, rawCore, rawApp] = await Promise.all([
  readFile(new URL("src/template.html", root), "utf8"),
  readFile(new URL("src/style.css", root), "utf8"),
  readFile(new URL("src/core.js", root), "utf8"),
  readFile(new URL("src/app.js", root), "utf8"),
]);
const core = rawCore.replaceAll(/\bexport\s+/g, "");
const app = rawApp.replace(/^import .*?;\s*/m, "");
const output = template.replace("/*__STYLE__*/", style).replace("/*__SCRIPT__*/", `${core}\n${app}`);
await writeFile(new URL("a26f-rom-patcher.html", root), output);
console.log(`Built web/a26f-rom-patcher.html (${output.length.toLocaleString()} characters)`);
