export const MAGIC = "A26FSMP\0";
export const FORMAT_MAJOR = 1;
export const FORMAT_MINOR = 0;
export const SLOT_COUNT = 32;
export const FLAG_GATED = 1;

const readU16 = (data, offset) => data[offset] | (data[offset + 1] << 8);
const readU32 = (data, offset) =>
  (data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) |
    (data[offset + 3] << 24)) >>> 0;

const writeU16 = (data, offset, value) => {
  data[offset] = value & 0xff;
  data[offset + 1] = (value >>> 8) & 0xff;
};

export function parseManifest(input) {
  const rom = input instanceof Uint8Array ? input : new Uint8Array(input);
  if (rom.length !== 32768) throw new Error("This tool requires a 32K F4 ROM.");

  const offset = 0x7e00;
  const magic = String.fromCharCode(...rom.slice(offset, offset + 8));
  if (magic !== MAGIC) throw new Error("A26F sample manifest not found.");

  const major = rom[offset + 8];
  const minor = rom[offset + 9];
  if (major !== FORMAT_MAJOR || minor !== FORMAT_MINOR) {
    throw new Error(`ROM format ${major}.${minor} is not supported by this tool.`);
  }

  const manifest = {
    offset,
    major,
    minor,
    tv: rom[offset + 10] === 0 ? "PAL" : "NTSC",
    mapper: rom[offset + 11],
    bankCount: rom[offset + 12],
    slotCount: rom[offset + 13],
    encoding: rom[offset + 14],
    defaultFlags: rom[offset + 15],
    sampleRate: readU32(rom, offset + 16) / 1000,
    romSize: readU32(rom, offset + 20),
    directoryOffset: readU32(rom, offset + 24),
    directoryLength: readU32(rom, offset + 28),
    directoryBank: rom[offset + 32],
    entrySize: rom[offset + 33],
    regions: [],
  };

  if (manifest.mapper !== 4 || manifest.bankCount !== 8 ||
      manifest.slotCount !== SLOT_COUNT || manifest.encoding !== 1 ||
      manifest.romSize !== rom.length || manifest.directoryOffset !== 0x7d00 ||
      manifest.directoryLength !== 0x100 || manifest.entrySize !== 8) {
    throw new Error("The ROM manifest is valid but its layout is not supported.");
  }

  for (let i = 0; i < 7; i += 1) {
    manifest.regions.push({
      offset: readU16(rom, offset + 36 + i * 4),
      length: readU16(rom, offset + 38 + i * 4),
    });
  }
  if (manifest.regions.some((r, i) => r.offset !== i * 0x1000 || r.length !== 0x0f00)) {
    throw new Error("The ROM sample regions do not match format 1.0.");
  }
  return manifest;
}

export function decodeWav(arrayBuffer) {
  const view = new DataView(arrayBuffer);
  const text = (offset, length) =>
    String.fromCharCode(...new Uint8Array(arrayBuffer, offset, length));
  if (text(0, 4) !== "RIFF" || text(8, 4) !== "WAVE") {
    throw new Error("Not a RIFF/WAVE file.");
  }

  let format;
  let dataOffset;
  let dataLength;
  for (let offset = 12; offset + 8 <= view.byteLength;) {
    const id = text(offset, 4);
    const length = view.getUint32(offset + 4, true);
    const body = offset + 8;
    if (body + length > view.byteLength) throw new Error("Truncated WAV chunk.");
    if (id === "fmt ") {
      format = {
        code: view.getUint16(body, true),
        channels: view.getUint16(body + 2, true),
        sampleRate: view.getUint32(body + 4, true),
        blockAlign: view.getUint16(body + 12, true),
        bits: view.getUint16(body + 14, true),
      };
    } else if (id === "data") {
      dataOffset = body;
      dataLength = length;
    }
    offset = body + length + (length & 1);
  }
  if (!format || dataOffset === undefined) throw new Error("WAV format or data is missing.");
  if (![1, 3].includes(format.code) || format.channels < 1 || format.channels > 8) {
    throw new Error("Use PCM or IEEE-float WAV audio with 1–8 channels.");
  }
  if (format.code === 1 && ![8, 16, 24, 32].includes(format.bits)) {
    throw new Error("Supported PCM depths are 8, 16, 24, and 32-bit.");
  }
  if (format.code === 3 && format.bits !== 32) throw new Error("Only 32-bit float WAV is supported.");

  const frameCount = Math.floor(dataLength / format.blockAlign);
  const mono = new Float32Array(frameCount);
  const bytesPerSample = format.bits / 8;
  const readSample = (offset) => {
    if (format.code === 3) return view.getFloat32(offset, true);
    if (format.bits === 8) return (view.getUint8(offset) - 128) / 128;
    if (format.bits === 16) return view.getInt16(offset, true) / 32768;
    if (format.bits === 24) {
      let value = view.getUint8(offset) | (view.getUint8(offset + 1) << 8) |
        (view.getUint8(offset + 2) << 16);
      if (value & 0x800000) value |= 0xff000000;
      return value / 8388608;
    }
    return view.getInt32(offset, true) / 2147483648;
  };
  for (let frame = 0; frame < frameCount; frame += 1) {
    let sum = 0;
    const base = dataOffset + frame * format.blockAlign;
    for (let channel = 0; channel < format.channels; channel += 1) {
      sum += readSample(base + channel * bytesPerSample);
    }
    mono[frame] = Math.max(-1, Math.min(1, sum / format.channels));
  }
  return {samples: mono, sampleRate: format.sampleRate};
}

function trimAudio(samples, sampleRate, thresholdDb = -48, marginMs = 4) {
  let peak = 0;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  if (peak === 0) return new Float32Array([0, 0]);
  const threshold = peak * (10 ** (thresholdDb / 20));
  let start = 0;
  let end = samples.length - 1;
  while (start < samples.length && Math.abs(samples[start]) < threshold) start += 1;
  while (end > start && Math.abs(samples[end]) < threshold) end -= 1;
  const margin = Math.round(sampleRate * marginMs / 1000);
  start = Math.max(0, start - margin);
  end = Math.min(samples.length - 1, end + margin);
  return samples.slice(start, end + 1);
}

function resampleLinear(samples, sourceRate, targetRate) {
  const length = Math.max(2, Math.round(samples.length * targetRate / sourceRate));
  const output = new Float32Array(length);
  const scale = sourceRate / targetRate;
  if (scale > 1) {
    // A weighted box filter reduces the worst fold-down aliasing before the
    // deliberately low-rate 4-bit quantisation.
    for (let i = 0; i < length; i += 1) {
      const start = i * scale;
      const end = Math.min(samples.length, (i + 1) * scale);
      let sum = 0;
      let weight = 0;
      for (let source = Math.floor(start); source < Math.ceil(end); source += 1) {
        if (source < 0 || source >= samples.length) continue;
        const overlap = Math.max(0, Math.min(end, source + 1) - Math.max(start, source));
        sum += samples[source] * overlap;
        weight += overlap;
      }
      output[i] = weight ? sum / weight : 0;
    }
    return output;
  }
  for (let i = 0; i < length; i += 1) {
    const position = Math.min(samples.length - 1, i * scale);
    const left = Math.floor(position);
    const right = Math.min(samples.length - 1, left + 1);
    const fraction = position - left;
    output[i] = samples[left] * (1 - fraction) + samples[right] * fraction;
  }
  return output;
}

export function processAudio(decoded, targetRate, options = {}) {
  let samples = options.autoTrim === false
    ? decoded.samples.slice()
    : trimAudio(decoded.samples, decoded.sampleRate, options.thresholdDb ?? -48);
  samples = resampleLinear(samples, decoded.sampleRate, targetRate);

  let peak = 0;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  const gain = options.normalize === false || peak === 0 ? 1 : 0.98 / peak;
  const fadeSamples = Math.min(Math.floor(samples.length / 2), Math.round(targetRate * 0.003));
  const packed = new Uint8Array(Math.ceil(samples.length / 2));
  for (let i = 0; i < samples.length; i += 1) {
    let envelope = 1;
    if (fadeSamples > 0 && i < fadeSamples) envelope = i / fadeSamples;
    if (fadeSamples > 0 && i >= samples.length - fadeSamples) {
      envelope = Math.min(envelope, (samples.length - 1 - i) / fadeSamples);
    }
    const signed = Math.max(-1, Math.min(1, samples[i] * gain * envelope));
    const nibble = Math.max(0, Math.min(15, Math.round((signed + 1) * 7.5)));
    if ((i & 1) === 0) packed[i >> 1] = nibble << 4;
    else packed[i >> 1] |= nibble;
  }
  if (samples.length & 1) packed[packed.length - 1] |= 8;
  return {packed, sampleCount: samples.length, duration: samples.length / targetRate};
}

function packSlots(slots, regionLength) {
  const placements = new Array(SLOT_COUNT).fill(null);
  const bins = Array.from({length: 7}, () => ({used: 0}));
  const ordered = slots.map((slot, index) => ({slot, index}))
    .filter(({slot}) => slot?.packed?.length)
    .sort((a, b) => b.slot.packed.length - a.slot.packed.length);

  for (const item of ordered) {
    if (item.slot.packed.length > regionLength) {
      throw new Error(`Slot ${item.index}: sample exceeds ${regionLength} packed bytes.`);
    }
    let selected = -1;
    let leastRemaining = Infinity;
    for (let bank = 0; bank < bins.length; bank += 1) {
      const remaining = regionLength - bins[bank].used;
      if (item.slot.packed.length <= remaining && remaining < leastRemaining) {
        selected = bank;
        leastRemaining = remaining;
      }
    }
    if (selected < 0) throw new Error("The samples do not fit in the seven ROM payload banks.");
    placements[item.index] = {bank: selected, offset: bins[selected].used};
    bins[selected].used += item.slot.packed.length;
  }
  return {placements, used: bins.reduce((sum, bin) => sum + bin.used, 0)};
}

export function patchRom(input, manifest, slots) {
  const source = input instanceof Uint8Array ? input : new Uint8Array(input);
  const rom = source.slice();
  const regionLength = manifest.regions[0].length;
  const {placements, used} = packSlots(slots, regionLength);

  for (const region of manifest.regions) rom.fill(0, region.offset, region.offset + region.length);
  rom.fill(0, manifest.directoryOffset, manifest.directoryOffset + manifest.directoryLength);

  for (let index = 0; index < SLOT_COUNT; index += 1) {
    const entry = manifest.directoryOffset + index * manifest.entrySize;
    const slot = slots[index];
    const placement = placements[index];
    if (!slot?.packed?.length || !placement) {
      rom[entry] = 0xff;
      rom[entry + 5] = slot?.gated === false ? 0 : FLAG_GATED;
      continue;
    }
    const region = manifest.regions[placement.bank];
    rom.set(slot.packed, region.offset + placement.offset);
    rom[entry] = placement.bank;
    writeU16(rom, entry + 1, 0xf000 + placement.offset);
    writeU16(rom, entry + 3, slot.packed.length);
    rom[entry + 5] = slot.gated === false ? 0 : FLAG_GATED;
  }
  return {rom, used, capacity: regionLength * manifest.regions.length};
}
