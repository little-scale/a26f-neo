import {createFactory, decodeWav, FACTORY_RATES, parseFactory, parseManifest, patchRom, processAudio, SLOT_COUNT} from "./core.js";

const state = {
  rom: null,
  manifest: null,
  slots: Array.from({length: SLOT_COUNT}, () => null),
};

const $ = (selector) => document.querySelector(selector);
const romInput = $("#rom-input");
const batchInput = $("#sample-input");
const slotsElement = $("#slots");
const buildButton = $("#build-button");
const clearButton = $("#clear-button");
const message = $("#message");
const romSummary = $("#rom-summary");
const capacityBar = $("#capacity-bar");
const capacityText = $("#capacity-text");
const dropZone = $("#drop-zone");
const factoryInput = $("#factory-input");
const factoryExportButton = $("#factory-export");
const previewAudio = new Audio();
let activePreview = -1;

function showMessage(text, kind = "info") {
  message.textContent = text;
  message.dataset.kind = kind;
}

function refreshCapacity() {
  const used = state.slots.reduce((sum, slot) => sum + (slot?.packed.length ?? 0), 0);
  const capacity = state.manifest ? state.manifest.regions.reduce((sum, r) => sum + r.length, 0) : 26880;
  capacityBar.style.width = `${Math.min(100, used / capacity * 100)}%`;
  capacityText.textContent = `${used.toLocaleString()} / ${capacity.toLocaleString()} packed bytes`;
  factoryExportButton.disabled = !state.slots.some(Boolean);
}

function makePreviewUrl(packed, sampleCount, sampleRate) {
  const wav = new Uint8Array(44 + sampleCount);
  const view = new DataView(wav.buffer);
  const text = (offset, value) => [...value].forEach((char, i) => { wav[offset + i] = char.charCodeAt(0); });
  text(0, "RIFF");
  view.setUint32(4, 36 + sampleCount, true);
  text(8, "WAVE");
  text(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, Math.round(sampleRate), true);
  view.setUint32(28, Math.round(sampleRate), true);
  view.setUint16(32, 1, true);
  view.setUint16(34, 8, true);
  text(36, "data");
  view.setUint32(40, sampleCount, true);
  for (let i = 0; i < sampleCount; i += 1) {
    const nibble = (i & 1) ? packed[i >> 1] & 0x0f : packed[i >> 1] >> 4;
    wav[44 + i] = nibble * 17;
  }
  return URL.createObjectURL(new Blob([wav], {type: "audio/wav"}));
}

function slotMarkup(index) {
  return `<article class="slot" data-slot="${index}">
    <div class="slot-number">${String(index).padStart(2, "0")}</div>
    <div class="slot-file">
      <strong class="slot-name">Empty</strong>
      <span class="slot-detail">MIDI notes ${index}, ${index + 32}, ${index + 64}, ${index + 96}</span>
    </div>
    <label class="mode"><span>Mode</span><select aria-label="Playback mode for slot ${index}">
      <option value="gated">Gated</option><option value="one-shot">One-shot</option>
    </select></label>
    <label class="choose"><input type="file" accept="audio/wav,.wav"><span>Choose WAV</span></label>
    <button class="preview" type="button" aria-label="Preview slot ${index}" disabled>▶</button>
    <button class="remove" type="button" aria-label="Clear slot ${index}">×</button>
  </article>`;
}

slotsElement.innerHTML = Array.from({length: SLOT_COUNT}, (_, index) => slotMarkup(index)).join("");

function installSlot(index, slot) {
  const row = slotsElement.querySelector(`[data-slot="${index}"]`);
  if (state.slots[index]?.previewUrl) URL.revokeObjectURL(state.slots[index].previewUrl);
  const selected = slot.variants[state.manifest.tv];
  state.slots[index] = {
    ...slot,
    packed: selected.packed,
    duration: selected.duration,
    sampleCount: selected.sampleCount,
    previewUrl: makePreviewUrl(selected.packed, selected.sampleCount, state.manifest.sampleRate),
  };
  row.querySelector(".slot-name").textContent = slot.name;
  row.querySelector(".slot-detail").textContent = `${selected.duration.toFixed(3)} s · ${selected.sampleCount.toLocaleString()} × 4-bit samples`;
  row.querySelector("select").value = slot.gated === false ? "one-shot" : "gated";
  row.classList.add("filled");
  row.querySelector(".preview").disabled = false;
  refreshCapacity();
}

async function loadSample(index, file) {
  if (!state.manifest) throw new Error("Choose an A26F ROM before adding samples.");
  const decoded = decodeWav(await file.arrayBuffer());
  const options = {autoTrim: $("#auto-trim").checked, normalize: $("#normalize").checked};
  const variants = {
    PAL: processAudio(decoded, FACTORY_RATES.PAL, options),
    NTSC: processAudio(decoded, FACTORY_RATES.NTSC, options),
  };
  const processed = variants[state.manifest.tv];
  const max = state.manifest.regions[0].length;
  if (Object.values(variants).some((variant) => variant.packed.length > max)) {
    throw new Error(`${file.name} is ${processed.duration.toFixed(2)} s after conversion; the limit is ${(max * 2 / state.manifest.sampleRate).toFixed(2)} s.`);
  }
  const row = slotsElement.querySelector(`[data-slot="${index}"]`);
  installSlot(index, {
    name: file.name,
    gated: row.querySelector("select").value === "gated",
    variants,
  });
}

slotsElement.addEventListener("change", async (event) => {
  const row = event.target.closest(".slot");
  const index = Number(row.dataset.slot);
  if (event.target.matches('input[type="file"]') && event.target.files[0]) {
    try {
      await loadSample(index, event.target.files[0]);
      showMessage(`Loaded ${event.target.files[0].name} into slot ${index}.`, "success");
    } catch (error) {
      event.target.value = "";
      showMessage(error.message, "error");
    }
  }
  if (event.target.matches("select") && state.slots[index]) {
    state.slots[index].gated = event.target.value === "gated";
  }
});

slotsElement.addEventListener("click", (event) => {
  const preview = event.target.closest(".preview");
  if (preview) {
    const row = preview.closest(".slot");
    const index = Number(row.dataset.slot);
    if (activePreview === index && !previewAudio.paused) {
      previewAudio.pause();
      preview.textContent = "▶";
      activePreview = -1;
      return;
    }
    for (const button of slotsElement.querySelectorAll(".preview")) button.textContent = "▶";
    previewAudio.src = state.slots[index].previewUrl;
    previewAudio.play();
    preview.textContent = "■";
    activePreview = index;
    return;
  }
  const button = event.target.closest(".remove");
  if (!button) return;
  const row = button.closest(".slot");
  const index = Number(row.dataset.slot);
  if (activePreview === index) {
    previewAudio.pause();
    activePreview = -1;
  }
  if (state.slots[index]?.previewUrl) URL.revokeObjectURL(state.slots[index].previewUrl);
  state.slots[index] = null;
  row.querySelector(".slot-name").textContent = "Empty";
  row.querySelector(".slot-detail").textContent = `MIDI notes ${index}, ${index + 32}, ${index + 64}, ${index + 96}`;
  row.querySelector('input[type="file"]').value = "";
  row.classList.remove("filled");
  row.querySelector(".preview").disabled = true;
  refreshCapacity();
});

previewAudio.addEventListener("ended", () => {
  const row = slotsElement.querySelector(`[data-slot="${activePreview}"]`);
  if (row) row.querySelector(".preview").textContent = "▶";
  activePreview = -1;
});

romInput.addEventListener("change", async () => {
  try {
    const file = romInput.files[0];
    if (!file) return;
    state.rom = new Uint8Array(await file.arrayBuffer());
    state.manifest = parseManifest(state.rom);
    state.slots.forEach((slot, index) => { if (slot?.variants) installSlot(index, slot); });
    romSummary.innerHTML = `<strong>${file.name}</strong><span>${state.manifest.tv} · ${state.manifest.sampleRate.toFixed(1)} Hz · 32K F4 · format ${state.manifest.major}.${state.manifest.minor}</span>`;
    batchInput.disabled = false;
    factoryInput.disabled = false;
    buildButton.disabled = false;
    refreshCapacity();
    showMessage("ROM recognised. Add WAV files to any sample slots.", "success");
  } catch (error) {
    state.rom = null;
    state.manifest = null;
    batchInput.disabled = true;
    factoryInput.disabled = true;
    buildButton.disabled = true;
    romSummary.innerHTML = "<strong>No compatible ROM loaded</strong><span>Choose an unmodified A26F NEO 32K ROM.</span>";
    showMessage(error.message, "error");
  }
});

async function loadFiles(fileList) {
  if (!state.manifest) {
    showMessage("Choose an A26F ROM before adding samples.", "error");
    return;
  }
  const files = [...fileList]
    .filter((file) => /\.wav$/i.test(file.name) || /^(audio\/wav|audio\/wave|audio\/x-wav)$/i.test(file.type))
    .sort((a, b) => a.name.localeCompare(b.name, undefined, {numeric: true, sensitivity: "base"}));
  if (!files.length) {
    showMessage("No WAV files were found in that selection.", "error");
    return;
  }
  const empty = state.slots.map((slot, index) => slot ? -1 : index).filter((index) => index >= 0);
  if (files.length > empty.length) {
    showMessage(`Only ${empty.length} sample slots are empty.`, "error");
    return;
  }
  for (let i = 0; i < files.length; i += 1) {
    try {
      await loadSample(empty[i], files[i]);
    } catch (error) {
      showMessage(error.message, "error");
      return;
    }
  }
  showMessage(`Loaded ${files.length} sample${files.length === 1 ? "" : "s"} into the first empty slots.`, "success");
}

batchInput.addEventListener("change", async () => {
  await loadFiles(batchInput.files);
  batchInput.value = "";
});

factoryInput.addEventListener("change", async () => {
  try {
    const file = factoryInput.files[0];
    if (!file) return;
    const factory = parseFactory(await file.arrayBuffer());
    for (const button of slotsElement.querySelectorAll(".remove")) button.click();
    factory.slots.forEach((slot, index) => { if (slot) installSlot(index, slot); });
    showMessage(`Imported ${file.name} with ${factory.slots.filter(Boolean).length} populated slots.`, "success");
  } catch (error) {
    showMessage(error.message, "error");
  } finally {
    factoryInput.value = "";
  }
});

factoryExportButton.addEventListener("click", () => {
  try {
    const factory = createFactory(state.slots);
    const link = document.createElement("a");
    link.href = URL.createObjectURL(new Blob([factory], {type: "application/octet-stream"}));
    link.download = "a26f-factory.a26factory";
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 1000);
    showMessage("Factory bank exported with PAL and NTSC sample variants.", "success");
  } catch (error) {
    showMessage(error.message, "error");
  }
});

for (const eventName of ["dragenter", "dragover"]) {
  dropZone.addEventListener(eventName, (event) => {
    event.preventDefault();
    if (state.manifest) dropZone.classList.add("dragging");
  });
}
for (const eventName of ["dragleave", "dragend"]) {
  dropZone.addEventListener(eventName, () => dropZone.classList.remove("dragging"));
}
dropZone.addEventListener("drop", async (event) => {
  event.preventDefault();
  dropZone.classList.remove("dragging");
  await loadFiles(event.dataTransfer.files);
});

clearButton.addEventListener("click", () => {
  for (const button of slotsElement.querySelectorAll(".remove")) button.click();
  showMessage("All sample slots cleared. The source ROM is unchanged.");
});

buildButton.addEventListener("click", () => {
  try {
    const result = patchRom(state.rom, state.manifest, state.slots);
    const blob = new Blob([result.rom], {type: "application/octet-stream"});
    const link = document.createElement("a");
    const base = romInput.files[0].name.replace(/\.(bin|rom|f4)$/i, "");
    link.href = URL.createObjectURL(blob);
    link.download = `${base}-samples.bin`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 1000);
    showMessage(`Patched ROM created using ${result.used.toLocaleString()} of ${result.capacity.toLocaleString()} sample bytes.`, "success");
  } catch (error) {
    showMessage(error.message, "error");
  }
});

refreshCapacity();
