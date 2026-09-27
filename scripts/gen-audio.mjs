// Synthesises every Crystals AR sound effect and the Forest Ruins ambient loop.
// Original work generated from code – no third-party audio. Output: assets/audio/*.wav
// Usage: node scripts/gen-audio.mjs
import { mkdirSync, writeFileSync } from "node:fs";

const SR = 22050;
const OUT = new URL("../assets/audio/", import.meta.url);
mkdirSync(OUT, { recursive: true });

let seed = 12345;
const rand = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296) * 2 - 1;

const buf = (sec) => new Float32Array(Math.ceil(sec * SR));
const midi = (n) => 440 * 2 ** ((n - 69) / 12);

/** Glassy crystal bell: inharmonic partials with exponential decay. */
function bell(out, t0, freq, amp, decay = 1.2, bright = 1) {
  const partials = [
    [1, 1],
    [2.0, 0.45 * bright],
    [2.76, 0.3 * bright],
    [5.4, 0.12 * bright],
    [8.93, 0.05 * bright],
  ];
  const start = Math.floor(t0 * SR);
  const len = Math.min(out.length - start, Math.floor(decay * 4 * SR));
  for (const [ratio, a] of partials) {
    const f = freq * ratio;
    if (f > SR / 2.2) continue;
    const d = decay / Math.sqrt(ratio);
    for (let i = 0; i < len; i++) {
      const t = i / SR;
      const attack = Math.min(1, t / 0.003);
      out[start + i] += amp * a * attack * Math.exp(-t / d) * Math.sin(2 * Math.PI * f * t);
    }
  }
}

function tone(out, t0, dur, f0, f1, amp, shape = "sine") {
  const start = Math.floor(t0 * SR);
  const n = Math.floor(dur * SR);
  let ph = 0;
  for (let i = 0; i < n && start + i < out.length; i++) {
    const k = i / n;
    const f = f0 * (f1 / f0) ** k;
    ph += (2 * Math.PI * f) / SR;
    const env = Math.min(1, i / (0.005 * SR)) * (1 - k) ** 2;
    const s = shape === "tri" ? (2 / Math.PI) * Math.asin(Math.sin(ph)) : Math.sin(ph);
    out[start + i] += amp * env * s;
  }
}

/** Band-limited noise sweep (one-pole filters) for whooshes and bursts. */
function noise(out, t0, dur, amp, cut0, cut1, attack = 0.2) {
  const start = Math.floor(t0 * SR);
  const n = Math.floor(dur * SR);
  let lp = 0, lp2 = 0;
  for (let i = 0; i < n && start + i < out.length; i++) {
    const k = i / n;
    const cut = cut0 * (cut1 / cut0) ** k;
    const a = 1 - Math.exp((-2 * Math.PI * cut) / SR);
    lp += a * (rand() - lp);
    lp2 += a * (lp - lp2);
    const env = k < attack ? k / attack : ((1 - k) / (1 - attack)) ** 1.5;
    out[start + i] += amp * env * (lp - lp2 * 0.6) * 3;
  }
}

function reverb(x, mix = 0.25, room = 0.5) {
  const delays = [1116, 1188, 1277, 1356].map((d) => Math.floor((d * SR) / 44100));
  const y = new Float32Array(x.length);
  for (const d of delays) {
    const line = new Float32Array(d);
    let p = 0, lp = 0;
    for (let i = 0; i < x.length; i++) {
      const o = line[p];
      lp = o * 0.6 + lp * 0.4;
      line[p] = x[i] + lp * (0.72 + room * 0.2);
      p = (p + 1) % d;
      y[i] += o / delays.length;
    }
  }
  for (let i = 0; i < x.length; i++) x[i] = x[i] * (1 - mix) + y[i] * mix * 2;
  return x;
}

function write(name, x, peak = 0.8) {
  let m = 0;
  for (const v of x) m = Math.max(m, Math.abs(v));
  const g = m > 0 ? peak / m : 1;
  const data = Buffer.alloc(44 + x.length * 2);
  data.write("RIFF", 0);
  data.writeUInt32LE(36 + x.length * 2, 4);
  data.write("WAVEfmt ", 8);
  data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20);
  data.writeUInt16LE(1, 22);
  data.writeUInt32LE(SR, 24);
  data.writeUInt32LE(SR * 2, 28);
  data.writeUInt16LE(2, 32);
  data.writeUInt16LE(16, 34);
  data.write("data", 36);
  data.writeUInt32LE(x.length * 2, 40);
  // short fade-out to avoid clicks
  const fade = Math.min(x.length, Math.floor(0.01 * SR));
  for (let i = 0; i < fade; i++) x[x.length - 1 - i] *= i / fade;
  for (let i = 0; i < x.length; i++) data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, x[i] * g)) * 32767), 44 + i * 2);
  writeFileSync(new URL(name + ".wav", OUT), data);
  console.log(name.padEnd(18), (data.length / 1024).toFixed(0) + " KB");
}

// --- one-shots -------------------------------------------------------------
{ const x = buf(0.35); bell(x, 0, midi(96), 0.5, 0.08); bell(x, 0.005, midi(103), 0.25, 0.06); write("select", reverb(x, 0.2), 0.45); }
{ const x = buf(0.3); noise(x, 0, 0.22, 0.6, 600, 4000, 0.4); bell(x, 0.14, midi(91), 0.25, 0.06); write("swap", reverb(x, 0.15), 0.5); }
{ const x = buf(0.4); tone(x, 0, 0.12, 330, 250, 0.6, "tri"); tone(x, 0.13, 0.16, 262, 196, 0.6, "tri"); write("invalid", reverb(x, 0.15), 0.45); }

// Match chimes escalate with cascade depth: pentatonic triads climbing and thickening.
const cascadeChords = [
  [84, 88, 91], // match / cascade 1
  [86, 91, 95, 98], // cascade 2 – richer
  [88, 93, 96, 100, 103], // cascade 3 – rising
  [91, 96, 100, 103, 108, 112], // cascade 4+ – peak
];
cascadeChords.forEach((chord, level) => {
  const x = buf(1.4 + level * 0.2);
  chord.forEach((n, i) => bell(x, i * (0.045 - level * 0.006), midi(n), 0.35, 0.35 + level * 0.12, 0.8 + level * 0.1));
  if (level >= 2) noise(x, 0, 0.5, 0.08 * level, 3000, 9000, 0.1);
  write(`match${level + 1}`, reverb(x, 0.3 + level * 0.05), 0.55 + level * 0.08);
});

{ // special crystal forged: upward shimmering arpeggio
  const x = buf(1.3);
  [79, 84, 88, 91, 96, 100].forEach((n, i) => bell(x, i * 0.06, midi(n), 0.3, 0.4));
  noise(x, 0, 0.6, 0.12, 2000, 8000, 0.5);
  write("special_create", reverb(x, 0.35), 0.65);
}
{ // special released: energy sweep with a soft low impact
  const x = buf(1.4);
  tone(x, 0, 0.5, 120, 45, 0.9);
  noise(x, 0, 0.7, 0.5, 400, 7000, 0.08);
  [96, 91, 88, 84].forEach((n, i) => bell(x, 0.05 + i * 0.05, midi(n), 0.25, 0.5));
  write("special_activate", reverb(x, 0.35), 0.75);
}
{ // world placement: rising swell, earthy thump, bloom
  const x = buf(2.2);
  noise(x, 0, 1.0, 0.35, 200, 5000, 0.85);
  tone(x, 0.95, 0.6, 90, 50, 0.9);
  [72, 79, 84, 88, 91].forEach((n, i) => bell(x, 1.0 + i * 0.07, midi(n), 0.3, 0.8, 0.7));
  write("place", reverb(x, 0.4, 0.8), 0.8);
}
{ // level complete: bell fanfare resolving to a bright major chord
  const x = buf(3.6);
  [72, 76, 79, 84].forEach((n, i) => bell(x, i * 0.14, midi(n), 0.35, 0.6));
  [84, 88, 91, 96, 100].forEach((n) => bell(x, 0.65, midi(n), 0.28, 1.1));
  noise(x, 0.6, 1.4, 0.1, 3000, 10000, 0.05);
  write("complete", reverb(x, 0.45, 0.9), 0.8);
}
{ // portal pulse when the world advances a stage
  const x = buf(1.6);
  tone(x, 0, 1.2, 55, 110, 0.5);
  [67, 74, 79].forEach((n, i) => bell(x, 0.2 + i * 0.12, midi(n), 0.3, 0.7, 0.6));
  write("portal", reverb(x, 0.4, 0.8), 0.6);
}

// --- ambient Forest Ruins loop (seamless) ------------------------------------
{
  const L = 16;
  const x = buf(L + 2);
  // stream murmur: brown-ish noise with slow amplitude drift
  let b1 = 0, b2 = 0;
  for (let i = 0; i < x.length; i++) {
    b1 += 0.02 * (rand() - b1);
    b2 += 0.2 * (rand() - b2);
    const drift = 0.75 + 0.25 * Math.sin((2 * Math.PI * i) / (SR * 8));
    x[i] += (b1 * 1.6 + b2 * 0.05) * 0.25 * drift;
  }
  // warm pad: two gentle chords, slow attack/decay
  const chords = [[48, 55, 62, 64, 71], [45, 52, 60, 64, 67]];
  chords.forEach((ch, ci) => {
    const t0 = ci * 8;
    for (const n of ch) {
      const f = midi(n);
      for (let i = 0; i < 9 * SR; i++) {
        const t = i / SR;
        const env = Math.sin(Math.PI * Math.min(1, t / 9)) ** 2;
        const k = Math.floor((t0 + t) * SR) % (L * SR);
        x[k] += 0.035 * env * (Math.sin(2 * Math.PI * f * t) + 0.3 * Math.sin(2 * Math.PI * f * 2.003 * t));
      }
    }
  });
  // sparse bird chirps and distant crystal chimes
  const chirp = (t0, f, n) => {
    for (let c = 0; c < n; c++) tone(x, t0 + c * 0.11, 0.08, f * 1.3, f, 0.12);
  };
  chirp(2.1, 3200, 3); chirp(6.7, 2800, 2); chirp(11.3, 3500, 4); chirp(14.2, 3000, 2);
  bell(x, 4.4, midi(96), 0.05, 1.5); bell(x, 9.8, midi(91), 0.05, 1.5); bell(x, 13.1, midi(100), 0.04, 1.5);
  const y = reverb(x, 0.35, 0.9);
  // fold tail into head for a seamless loop
  const out = new Float32Array(L * SR);
  const xf = 2 * SR;
  for (let i = 0; i < out.length; i++) out[i] = y[i];
  for (let i = 0; i < xf; i++) {
    const w = i / xf;
    out[i] = y[i] * w + y[L * SR + i] * (1 - w);
  }
  write("ambient_forest", out, 0.5);
}
