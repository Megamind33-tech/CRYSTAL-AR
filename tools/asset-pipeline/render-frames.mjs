// Card frames for the Armory: a lit rarity-coloured backdrop (gradient, sunburst, lattice, glow, coloured vignette) inside
// a gold bezel. Baked to images so they draw instantly, unlike a GPU canvas that mounts late.
//   node render-frames.mjs   -> assets/ui/armory/frame_<rarity>.webp
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const out = join(fileURLToPath(new URL("../../", import.meta.url)), "assets/ui/armory");
mkdirSync(out, { recursive: true });
const PAL = {
  common: { top: "#2bb596", bottom: "#0a4038", glow: "#5cf0a0", deep: "#06281f", mid: "#3fbf7a", hi: "#c6fbd6", rays: 0.09 },
  uncommon: { top: "#3f86ff", bottom: "#102a72", glow: "#6cc8ff", deep: "#08154a", mid: "#4aa3ff", hi: "#cfe9ff", rays: 0.11 },
  rare: { top: "#f0aa40", bottom: "#5a220e", glow: "#ffc25c", deep: "#2c0e06", mid: "#f0a83a", hi: "#fff0c4", rays: 0.17 },
};
const rays = (n, o) => Array.from({ length: n }, (_, i) => {
  const a = (i / n) * Math.PI * 2, w = 0.13, r = 95;
  return `<polygon points="50,60 ${50 + Math.cos(a - w) * r},${60 + Math.sin(a - w) * r} ${50 + Math.cos(a + w) * r},${60 + Math.sin(a + w) * r}" fill="#fff" opacity="${o}"/>`;
}).join("");
const lattice = Array.from({ length: 34 }, (_, i) => { const x = -100 + i * 9; return `<path d="M${x} 0L${x + 100} 100M${x} 0L${x - 100} 100" />`; }).join("");
const stud = ([x, y], c) => `<polygon points="${x},${y - 4} ${x + 3},${y} ${x},${y + 4} ${x - 3},${y}" fill="${c}"/>`;

for (const [name, p] of Object.entries(PAL)) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="512" height="512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${p.top}"/><stop offset="1" stop-color="${p.bottom}"/></linearGradient>
    <radialGradient id="glow" cx="50" cy="50" r="56" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="${p.glow}" stop-opacity=".85"/><stop offset=".45" stop-color="${p.glow}" stop-opacity=".28"/><stop offset="1" stop-color="${p.glow}" stop-opacity="0"/></radialGradient>
    <radialGradient id="vig" cx="50" cy="50" r="76" gradientUnits="userSpaceOnUse"><stop offset=".6" stop-color="${p.deep}" stop-opacity="0"/><stop offset="1" stop-color="${p.deep}" stop-opacity=".8"/></radialGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff1b8"/><stop offset=".3" stop-color="${p.mid}"/><stop offset=".55" stop-color="#b87a28"/><stop offset=".8" stop-color="${p.hi}"/><stop offset="1" stop-color="#8a5518"/></linearGradient>
    <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".16"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <clipPath id="c"><rect x="2" y="2" width="96" height="96" rx="12"/></clipPath>
  </defs>
  <g clip-path="url(#c)">
    <rect width="100" height="100" fill="url(#bg)"/>
    ${rays(14, p.rays)}
    <g stroke="#fff" stroke-width=".35" opacity=".07" fill="none">${lattice}</g>
    <rect width="100" height="100" fill="url(#glow)"/>
    <rect width="100" height="100" fill="url(#vig)"/>
    <rect width="100" height="42" fill="url(#sheen)"/>
  </g>
  <rect x="1.5" y="1.5" width="97" height="97" rx="13" fill="none" stroke="url(#gold)" stroke-width="3"/>
  <rect x="4.6" y="4.6" width="90.8" height="90.8" rx="10.4" fill="none" stroke="#fff" stroke-opacity=".22" stroke-width=".8"/>
  ${[[8, 8], [92, 8], [8, 92], [92, 92]].map((c) => stud(c, p.hi)).join("")}
</svg>`;
  await sharp(Buffer.from(svg)).webp({ quality: 92, alphaQuality: 95 }).toFile(join(out, `frame_${name}.webp`));
  console.log("frame", name);
}
