// Generates the small effect sprites used by the crystal effects (src/render/GemFx.tsx). Original artwork made
// from SVG, white-on-alpha so Viro materials can tint them per crystal colour.
//   node gen-fx.mjs   ->  assets/textures/fx_shard.png, fx_glow.png, fx_star.png
import { mkdirSync } from "node:fs";
import sharp from "sharp";

const OUT = new URL("../../assets/textures/", import.meta.url).pathname;
mkdirSync(OUT, { recursive: true });
const svg = (size, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${body}</svg>`;

const sprites = {
  // a thin faceted sliver, brighter along one edge like a lit crystal fragment
  fx_shard: svg(64, `
    <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="1" stop-color="#fff" stop-opacity="0.55"/></linearGradient></defs>
    <polygon points="33,2 48,30 34,62 17,31" fill="url(#g)"/>
    <polygon points="33,2 34,62 17,31" fill="#fff" fill-opacity="0.35"/>`),
  // soft round glow for the light pooled under a crystal
  fx_glow: svg(128, `
    <defs><radialGradient id="g"><stop offset="0" stop-color="#fff" stop-opacity="0.95"/><stop offset="0.35" stop-color="#fff" stop-opacity="0.45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>
    <circle cx="64" cy="64" r="64" fill="url(#g)"/>`),
  // four-point twinkle
  fx_star: svg(64, `
    <defs><radialGradient id="g"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="1" stop-color="#fff" stop-opacity="0.85"/></radialGradient></defs>
    <polygon points="32,0 37,27 64,32 37,37 32,64 27,37 0,32 27,27" fill="url(#g)"/>
    <circle cx="32" cy="32" r="5" fill="#fff"/>`),
};
for (const [name, xml] of Object.entries(sprites)) {
  await sharp(Buffer.from(xml)).png({ compressionLevel: 9 }).toFile(`${OUT}${name}.png`);
  console.log("wrote", name);
}
