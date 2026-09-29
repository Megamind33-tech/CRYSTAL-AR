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
  // ---- living-environment creatures (white on alpha; tinted per realm by their Viro material)
  // gull seen from above, wings swept back: head points up the image
  fx_bird: svg(64, `<path d="M32 4 L37 24 L62 42 L37 37 L32 60 L27 37 L2 42 L27 24 Z" fill="#fff"/><path d="M32 4 L37 24 L32 60 Z" fill="#fff" fill-opacity="0.7"/>`),
  // butterfly: two wing pairs and a body
  fx_butterfly: svg(64, `<path d="M31 30 C12 2 0 18 6 32 C10 40 24 38 31 32 Z" fill="#fff"/><path d="M33 30 C52 2 64 18 58 32 C54 40 40 38 33 32 Z" fill="#fff"/><path d="M31 34 C14 44 12 62 26 58 C32 56 32 44 31 34 Z" fill="#fff" fill-opacity="0.85"/><path d="M33 34 C50 44 52 62 38 58 C32 56 32 44 33 34 Z" fill="#fff" fill-opacity="0.85"/><rect x="30" y="18" width="4" height="34" rx="2" fill="#fff"/>`),
  // manta ray, head up
  fx_manta: svg(64, `<path d="M32 4 C44 18 62 24 61 36 C50 32 42 40 35 46 L32 62 L29 46 C22 40 14 32 3 36 C2 24 20 18 32 4 Z" fill="#fff"/><path d="M32 4 C44 18 62 24 61 36 C50 32 42 40 35 46 L32 20 Z" fill="#fff" fill-opacity="0.65"/>`),
  // jellyfish, standing up: bell and trailing tentacles (billboarded in the scene)
  fx_jelly: svg(64, `<defs><radialGradient id="g" cx="0.5" cy="0.6"><stop offset="0" stop-color="#fff" stop-opacity="0.55"/><stop offset="1" stop-color="#fff" stop-opacity="1"/></radialGradient></defs><path d="M6 32 C6 8 58 8 58 32 C48 27 40 30 32 28 C24 30 16 27 6 32 Z" fill="url(#g)"/><g stroke="#fff" stroke-width="2.4" fill="none" stroke-linecap="round" opacity="0.85"><path d="M16 30 C12 40 20 46 15 58"/><path d="M26 30 C24 42 30 48 26 60"/><path d="M38 30 C40 42 34 48 38 60"/><path d="M48 30 C52 40 44 46 49 58"/></g>`),
};
for (const [name, xml] of Object.entries(sprites)) {
  await sharp(Buffer.from(xml)).png({ compressionLevel: 9 }).toFile(`${OUT}${name}.png`);
  console.log("wrote", name);
}
