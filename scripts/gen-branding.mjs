// Original Crystals AR branding: app icon, adaptive icon layers, monochrome icon, splash, favicon.
// A faceted "Prism Heart" crystal rasterised with per-facet shading. Usage: node scripts/gen-branding.mjs
import { writeFileSync } from "node:fs";
import { deflateSync } from "node:zlib";

const OUT = new URL("../assets/images/", import.meta.url);

function png(path, w, h, px) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    px.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const table = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (b) => {
    let c = 0xffffffff;
    for (const x of b) c = table[(c ^ x) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const c = Buffer.alloc(4);
    c.writeUInt32BE(crc(td));
    return Buffer.concat([len, td, c]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr.set([8, 6, 0, 0, 0], 8);
  writeFileSync(new URL(path, OUT), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0))]));
  console.log(path);
}

class Canvas {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.px = Buffer.alloc(w * h * 4);
  }
  blend(x, y, [r, g, b], a) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h || a <= 0) return;
    const i = (y * this.w + x) * 4;
    const da = this.px[i + 3] / 255;
    const oa = a + da * (1 - a);
    for (const [k, v] of [[0, r], [1, g], [2, b]]) this.px[i + k] = Math.round((v * a + this.px[i + k] * da * (1 - a)) / (oa || 1));
    this.px[i + 3] = Math.round(oa * 255);
  }
  fill(fn) {
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const c = fn(x / this.w, y / this.h);
      if (c) this.blend(x, y, c[0], c[1]);
    }
  }
  /** Anti-aliased convex/concave polygon via 4x4 supersampling (coords in 0..1). */
  poly(pts, color, alpha = 1) {
    const P = pts.map(([x, y]) => [x * this.w, y * this.h]);
    const minX = Math.max(0, Math.floor(Math.min(...P.map((p) => p[0])))), maxX = Math.min(this.w - 1, Math.ceil(Math.max(...P.map((p) => p[0]))));
    const minY = Math.max(0, Math.floor(Math.min(...P.map((p) => p[1])))), maxY = Math.min(this.h - 1, Math.ceil(Math.max(...P.map((p) => p[1]))));
    const inside = (x, y) => {
      let c = false;
      for (let i = 0, j = P.length - 1; i < P.length; j = i++) {
        const [xi, yi] = P[i], [xj, yj] = P[j];
        if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) c = !c;
      }
      return c;
    };
    for (let y = minY; y <= maxY; y++)
      for (let x = minX; x <= maxX; x++) {
        let n = 0;
        for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) if (inside(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4)) n++;
        if (n) this.blend(x, y, color, (alpha * n) / 16);
      }
  }
}

const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
/** The Prism Heart: a brilliant-cut crystal seen from the front, facets lit from the upper left. */
function crystal(cv, cx, cy, s, mono = null) {
  const top = cy - 0.36 * s, girdle = cy - 0.08 * s, bottom = cy + 0.46 * s;
  const tableW = 0.2 * s, crownW = 0.4 * s;
  const girdlePts = [-1, -0.62, -0.2, 0.2, 0.62, 1].map((k) => [cx + k * crownW, girdle]);
  const tablePts = [-1, -0.33, 0.33, 1].map((k) => [cx + k * tableW, top]);
  const light = [-0.55, -0.8];
  const base = [[255, 200, 90], [90, 220, 255], [160, 110, 255], [255, 90, 140], [80, 230, 150]];
  const shade = (i, n, nx, ny) => {
    const l = Math.max(0, -(nx * light[0] + ny * light[1]));
    const hue = base[i % base.length];
    return mono ?? mix(mix(hue, [255, 255, 255], 0.1 + l * 0.35), [16, 20, 48], Math.max(0, 0.32 - l * 0.4));
  };
  // crown facets (table edge → girdle)
  for (let i = 0; i < 5; i++) {
    const a = girdlePts[i], b = girdlePts[i + 1];
    const t0 = tablePts[Math.min(3, Math.floor((i * 4) / 5))], t1 = tablePts[Math.min(3, Math.ceil(((i + 1) * 4) / 5))];
    const nx = ((a[0] + b[0]) / 2 - cx) / crownW;
    cv.poly([t0, t1, b, a], shade(i, 5, nx * 0.8, -0.6));
  }
  cv.poly([tablePts[0], tablePts[3], [cx + tableW * 0.7, top + 0.05 * s], [cx - tableW * 0.7, top + 0.05 * s]], mono ?? [255, 250, 230]);
  // pavilion facets (girdle → culet)
  for (let i = 0; i < 5; i++) {
    const a = girdlePts[i], b = girdlePts[i + 1];
    const nx = ((a[0] + b[0]) / 2 - cx) / crownW;
    cv.poly([a, b, [cx, bottom]], shade(i + 2, 5, nx, 0.4));
  }
  if (!mono) {
    // girdle line and table rim catch the light
    cv.poly([[girdlePts[0][0], girdle - 0.006 * s], [girdlePts[5][0], girdle - 0.006 * s], [girdlePts[5][0], girdle + 0.006 * s], [girdlePts[0][0], girdle + 0.006 * s]], [255, 244, 210], 0.8);
    // glints
    cv.poly([[cx - 0.2 * s, top + 0.02 * s], [cx - 0.08 * s, top + 0.02 * s], [cx - 0.28 * s, girdle - 0.01 * s]], [255, 255, 255], 0.55);
    cv.poly([[cx + 0.05 * s, girdle + 0.02 * s], [cx + 0.1 * s, girdle + 0.02 * s], [cx + 0.02 * s, bottom - 0.12 * s]], [255, 255, 255], 0.35);
  }
}

function sky(cv) {
  cv.fill((x, y) => {
    const d = Math.hypot(x - 0.5, y - 0.45);
    const c = mix([22, 58, 52], [9, 12, 20], Math.min(1, d * 1.6));
    return [mix(c, [60, 120, 110], Math.max(0, 0.35 - d) * 1.2), 1];
  });
  // halo + a few stars
  cv.fill((x, y) => {
    const d = Math.hypot(x - 0.5, y - 0.47);
    const a = Math.max(0, 0.42 - Math.abs(d - 0.3) * 6) * 0.35;
    return a > 0 ? [[242, 196, 107], a] : null;
  });
  for (let i = 0; i < 40; i++) {
    const x = ((i * 7919) % 997) / 997, y = ((i * 104729) % 991) / 991;
    if (Math.hypot(x - 0.5, y - 0.47) < 0.36) continue;
    cv.poly([[x, y - 0.004], [x + 0.003, y], [x, y + 0.004], [x - 0.003, y]], [255, 240, 210], 0.7);
  }
}

// full icon
{ const c = new Canvas(1024, 1024); sky(c); crystal(c, 0.5, 0.5, 0.78); png("icon.png", 1024, 1024, c.px); }
// adaptive: background layer + foreground crystal inside the 66% safe zone
{ const c = new Canvas(1024, 1024); sky(c); png("android-icon-background.png", 1024, 1024, c.px); }
{ const c = new Canvas(1024, 1024); crystal(c, 0.5, 0.5, 0.5); png("android-icon-foreground.png", 1024, 1024, c.px); }
{ const c = new Canvas(1024, 1024); crystal(c, 0.5, 0.5, 0.5, [255, 255, 255]); png("android-icon-monochrome.png", 1024, 1024, c.px); }
{ const c = new Canvas(512, 512); crystal(c, 0.5, 0.5, 0.8); png("splash-icon.png", 512, 512, c.px); }
{ const c = new Canvas(64, 64); sky(c); crystal(c, 0.5, 0.5, 0.82); png("favicon.png", 64, 64, c.px); }
