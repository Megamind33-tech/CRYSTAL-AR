// Generates all Crystals AR 3D assets (original, procedural, flat-shaded low-poly).
// Output: assets/models/*.glb and assets/textures/*.png
// World units are metres. World-local frame: origin = island centre on the table,
// +Y up, +Z toward the player.  Usage: node scripts/gen-models.mjs
import { mkdirSync, writeFileSync } from "node:fs";
import { deflateSync } from "node:zlib";
import { Model, blob, box, cone, cylinder, loft, pillowGem, rng, slab, xf } from "./lib/glb.mjs";

const MODELS = new URL("../assets/models/", import.meta.url);
const TEX = new URL("../assets/textures/", import.meta.url);
mkdirSync(MODELS, { recursive: true });
mkdirSync(TEX, { recursive: true });
// Crystal meshes are also exported as TypeScript for ViroGeometry: creating them needs no file load,
// which avoids Viro background-task races when crystals spawn mid-game (seen on a Tecno Camon 19).
const MESHES = {};
const out = (name, model) => {
  if (name.startsWith("gem_") || name.startsWith("socket") || name.startsWith("ob_") || ["surge_aura", "bloom", "glow_cluster", "vines", "portal_core"].includes(name)) {
    MESHES[name] = [...model.buckets].filter(([, b]) => b.pos.length).map(([mat, b]) => {
      const def = model.materials.find((x) => x.name === mat);
      const r = (v) => Math.round(v * 1e4) / 1e4;
      return { material: mat, color: def.color, alpha: def.alpha, emissive: def.emissive, doubleSided: !!def.doubleSided, v: b.pos.map(r), n: b.nrm.map(r) };
    });
  }
  const r = model.write(new URL(name + ".glb", MODELS));
  console.log(name.padEnd(16), String(r.triangles).padStart(6), "tris", (r.bytes / 1024).toFixed(0).padStart(5), "KB");
};

// Shared layout constants – keep in sync with src/render/layout.ts
const SURFACE_Y = 0.04;
const CELL = 0.052;

// ---------------------------------------------------------------- crystals --
const GEM_COLORS = {
  red: [0.95, 0.22, 0.06], // Ember Core
  blue: [0.06, 0.42, 0.98], // Tide Sapphire
  green: [0.04, 0.72, 0.36], // Leaf Emerald
  purple: [0.5, 0.14, 0.9], // Void Amethyst
  gold: [1.0, 0.78, 0.12], // Solar Shard
};
const gemMaterial = (m, name, c) =>
  m.material(name, { color: c, metallic: 0.35, roughness: 0.07, emissive: c.map((v) => v * 0.22), alpha: 0.82 });
const coreMaterial = (m, name, c) =>
  m.material(name + "_core", { color: c.map((v) => Math.min(1, v * 0.6 + 0.4)), roughness: 0.3, emissive: c.map((v) => Math.min(1, v * 0.9 + 0.25)) });

// Five crystal families, each with its own silhouette so they read without colour
// (no hearts, stars or generic diamonds):
//   Ember Core    (red)    – squat hexagonal ember with a banded girdle
//   Tide Sapphire (blue)   – droplet cut, rounded belly, drawn-up tip
//   Leaf Emerald  (green)  – tall step-cut emerald (octagonal table)
//   Void Amethyst (purple) – natural quartz cluster: one tall point, two leaning buds
//   Solar Shard   (gold)   – thin four-sided shard, tilted like a splinter of light
const emeraldCut = [[-0.2, -0.52], [0.2, -0.52], [0.32, -0.38], [0.32, 0.38], [0.2, 0.52], [-0.2, 0.52], [-0.32, 0.38], [-0.32, -0.38]];
const point = (h, r, lean, x, rot = 0) => loft([
  { n: 6, r: r * 0.8, y: -0.5, rot },
  { n: 6, r, y: -0.5 + h * 0.62, rot },
  { n: 6, r: 0, y: -0.5 + h },
]).map((tri) => tri.map(xf({ r: [0, 0, lean], t: [x, 0, 0] })));

const gems = {
  gem_red: (m, mat) =>
    m.tris(mat, loft([
      { n: 6, r: 0, y: -0.42 },
      { n: 6, r: 0.46, y: -0.08, rot: 0 },
      { n: 6, r: 0.5, y: 0.02, rot: Math.PI / 6 },
      { n: 6, r: 0.46, y: 0.12, rot: 0 },
      { n: 6, r: 0.26, y: 0.36, rot: Math.PI / 6 },
      { n: 6, r: 0, y: 0.42 },
    ])),
  gem_blue: (m, mat) =>
    m.tris(mat, loft([
      { n: 14, r: 0, y: -0.52 },
      { n: 14, r: 0.3, y: -0.44, rot: 0 },
      { n: 14, r: 0.42, y: -0.24, rot: Math.PI / 14 },
      { n: 14, r: 0.38, y: 0.02, rot: 0 },
      { n: 14, r: 0.26, y: 0.22, rot: Math.PI / 14 },
      { n: 14, r: 0.12, y: 0.42, rot: 0 },
      { n: 14, r: 0, y: 0.6 },
    ])),
  gem_green: (m, mat) => m.tris(mat, pillowGem(emeraldCut, 0.26, 0.1, 0.62)),
  gem_purple: (m, mat) => {
    m.tris(mat, point(1.08, 0.2, 0, 0, 0.3));
    m.tris(mat, point(0.66, 0.14, 0.42, -0.2, 0.9));
    m.tris(mat, point(0.54, 0.12, -0.46, 0.22, 0.1));
  },
  gem_gold: (m, mat) => {
    // a twisted six-sided splinter of light with a smaller companion shard
    const shard = (h, r) => loft([
      { n: 6, r: 0, y: -h * 0.5 },
      { n: 6, r, y: -h * 0.12, rot: 0, jitter: (i) => (i % 2 ? 0.62 : 1) },
      { n: 6, r: r * 0.86, y: h * 0.12, rot: Math.PI / 6, jitter: (i) => (i % 2 ? 1 : 0.62) },
      { n: 6, r: 0, y: h * 0.52 },
    ]);
    m.tris(mat, shard(1.18, 0.24), xf({ r: [0, 0.25, -0.22] }));
    m.tris(mat, shard(0.62, 0.13), xf({ r: [0.2, 0.9, 0.55], t: [0.2, -0.22, 0.05] }));
  },
};
const colorOf = { gem_red: "red", gem_blue: "blue", gem_green: "green", gem_purple: "purple", gem_gold: "gold" };
for (const [name, build] of Object.entries(gems)) {
  const m = new Model();
  const c = GEM_COLORS[colorOf[name]];
  // inner core first: a shrunken copy of the same cut, glowing through the translucent shell
  const core = coreMaterial(m, name, c);
  const shell = gemMaterial(m, name, c);
  const tris = m.tris.bind(m);
  m.tris = (mat, t, f) => tris(core, t, (p) => { const q = f ? f(p) : p; return [q[0] * 0.55, q[1] * 0.55, q[2] * 0.55]; });
  build(m, shell);
  m.tris = tris;
  build(m, shell);
  out(name, m);
}

{ // PRISM: rainbow star-crystal, facets alternate through all five crystal hues
  const m = new Model();
  const mats = Object.entries(GEM_COLORS).map(([k, c]) =>
    m.material("prism_" + k, { color: c.map((v) => 0.55 + v * 0.45), metallic: 0.3, roughness: 0.1, emissive: c.map((v) => 0.25 + v * 0.35) }));
  const tris = loft([
    { n: 10, r: 0, y: -0.55 },
    { n: 10, r: 0.42, y: 0, jitter: (i) => (i % 2 ? 0.62 : 1) },
    { n: 10, r: 0, y: 0.55 },
  ]);
  tris.forEach((t, i) => m.tris(mats[i % mats.length], [t]));
  out("gem_prism", m);
}
{ // SURGE aura: energy ring + twin arrowheads along +/-X (rotate 90deg about Y for vertical surges)
  const m = new Model();
  const glow = m.material("surge", { color: [1, 0.95, 0.75], metallic: 0.6, roughness: 0.2, emissive: [0.9, 0.75, 0.35] });
  const ring = [];
  const N = 16, R = 0.62, r = 0.05;
  for (let i = 0; i < N; i++) {
    const a0 = (i / N) * Math.PI * 2, a1 = ((i + 1) / N) * Math.PI * 2;
    ring.push(...cylinder(4, r, 1).map((tri) => tri.map(xf({ s: [1, (a1 - a0) * R, 1], r: [0, 0, 0], t: [0, 0, 0] }))).map((tri) =>
      tri.map(([x, y, z]) => {
        const a = a0 + (y / R);
        return [x * 0 + Math.cos(a) * (R + x), z, Math.sin(a) * (R + x)];
      })));
  }
  m.tris(glow, ring, xf({ r: [Math.PI / 2, 0, Math.PI / 2] }));
  m.tris(glow, cone(4, 0.14, 0.3), xf({ r: [0, 0, -Math.PI / 2], t: [0.62, 0, 0] }));
  m.tris(glow, cone(4, 0.14, 0.3), xf({ r: [0, 0, Math.PI / 2], t: [-0.62, 0, 0] }));
  out("surge_aura", m);
}

// ---------------------------------------------------------------- platform --
{ // Stone puzzle platform in board-local space: origin at board centre, top of tiles at y = 0.
  const m = new Model();
  const R = rng(7);
  const stoneA = m.material("stoneA", { color: [0.62, 0.6, 0.55], roughness: 0.95 });
  const stoneB = m.material("stoneB", { color: [0.52, 0.51, 0.47], roughness: 0.95 });
  const trim = m.material("trim", { color: [0.42, 0.4, 0.36], roughness: 0.9 });
  const moss = m.material("moss", { color: [0.28, 0.46, 0.18], roughness: 1 });
  const rune = m.material("rune", { color: [0.55, 0.85, 1.0], emissive: [0.25, 0.55, 0.8], roughness: 0.5 });
  const half = (CELL * 6) / 2;
  // base plinth
  m.tris(trim, slab(half * 2 + 0.05, 0.03, half * 2 + 0.05, 0.008), xf({ t: [0, -0.034, 0] }));
  // tiles
  for (let y = 0; y < 6; y++)
    for (let x = 0; x < 6; x++) {
      const cx = -half + CELL * (x + 0.5), cz = -half + CELL * (y + 0.5);
      m.tris((x + y) % 2 ? stoneA : stoneB, slab(CELL - 0.004, 0.006, CELL - 0.004, 0.0018), xf({ t: [cx, -0.006 + (R() - 0.5) * 0.0012, cz], r: [0, (R() - 0.5) * 0.03, 0] }));
    }
  // border blocks with rune inlays at the corners
  for (let i = 0; i < 4; i++) {
    const side = [[0, -1], [0, 1], [-1, 0], [1, 0]][i];
    for (let k = 0; k < 7; k++) {
      const along = -half + (k / 6) * half * 2;
      const [bx, bz] = side[0] === 0 ? [along, side[1] * (half + 0.012)] : [side[0] * (half + 0.012), along];
      m.tris(trim, blob(0.012, R, 0.2), xf({ s: [1.4, 0.8, 1.4], t: [bx, -0.004, bz] }));
    }
  }
  for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    m.tris(trim, slab(0.034, 0.02, 0.034, 0.005), xf({ t: [sx * (half + 0.012), -0.012, sz * (half + 0.012)] }));
    m.tris(rune, blob(0.008, R, 0), xf({ s: [1, 0.5, 1], t: [sx * (half + 0.012), 0.009, sz * (half + 0.012)] }));
  }
  // moss creeping on the plinth edges
  for (let i = 0; i < 16; i++) {
    const a = R() * Math.PI * 2;
    const px = Math.max(-1, Math.min(1, Math.cos(a) * 1.4)) * (half + 0.022), pz = Math.max(-1, Math.min(1, Math.sin(a) * 1.4)) * (half + 0.022);
    m.tris(moss, blob(0.008 + R() * 0.006, R, 0.3), xf({ s: [1.3, 0.5, 1.3], t: [px, -0.01, pz] }));
  }
  out("platform", m);
}

// ------------------------------------------------------- board stone sockets --
// Each playable cell is its own carved stone column (top at y = 0, reaching down into the terrain),
// so irregular board shapes read as ruins rather than a panel laid on the scenery.
for (const [name, top, side] of [["socket_a", [0.64, 0.62, 0.57], [0.44, 0.42, 0.38]], ["socket_b", [0.56, 0.55, 0.5], [0.4, 0.38, 0.35]]]) {
  const m = new Model();
  const R2 = rng(name.length * 31);
  const topM = m.material(name + "_top", { color: top, roughness: 0.95 });
  const sideM = m.material(name + "_side", { color: side, roughness: 1 });
  const grooveM = m.material(name + "_groove", { color: side.map((c) => c * 0.7), roughness: 1 });
  const w = CELL - 0.005;
  m.tris(sideM, box(w * 0.94, 0.07, w * 0.94), xf({ t: [0, -0.041, 0] }));          // column into the ground
  m.tris(topM, slab(w, 0.008, w, 0.0022), xf({ t: [0, -0.008, 0] }));                  // dressed top
  m.tris(grooveM, slab(w * 0.72, 0.0012, w * 0.72, 0.0004), xf({ t: [0, 0.0001, 0] })); // carved socket ring
  m.tris(topM, slab(w * 0.6, 0.0012, w * 0.6, 0.0004), xf({ t: [0, 0.0004, 0] }));
  for (let k = 0; k < 3; k++) m.tris(sideM, blob(0.004, R2, 0.3, 0), xf({ s: [1.2, 0.6, 1], t: [(R2() - 0.5) * w, -0.012 - R2() * 0.02, (R2() > 0.5 ? 1 : -1) * w * 0.47] }));
  out(name, m);
}

// --------------------------------------------------------------- obstacles --
// Covers are built in crystal units (scaled by GEM_SCALE at runtime, centred on the crystal);
// stones and runes are in board-local metres like the sockets.
const sub3 = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross3 = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm3 = (a) => { const l = Math.hypot(...a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
/** A round tube along a polyline (vines, chain links). */
function tube(pts, r, sides = 5, closed = false) {
  const P = closed ? [...pts, pts[0], pts[1]] : pts;
  const rings = P.map((p, i) => {
    const q = P[Math.min(i + 1, P.length - 1)], o = P[Math.max(i - 1, 0)];
    const d = norm3(sub3(q, o));
    const a = norm3(cross3(d, Math.abs(d[1]) < 0.9 ? [0, 1, 0] : [1, 0, 0]));
    const b = cross3(d, a);
    return Array.from({ length: sides }, (_, k) => {
      const th = (k / sides) * Math.PI * 2;
      return [0, 1, 2].map((j) => p[j] + (a[j] * Math.cos(th) + b[j] * Math.sin(th)) * r);
    });
  });
  const t = [];
  for (let i = 0; i < rings.length - (closed ? 2 : 1); i++)
    for (let k = 0; k < sides; k++) {
      const k2 = (k + 1) % sides;
      const A = rings[i][k], B = rings[i + 1][k], C = rings[i + 1][k2], D = rings[i][k2];
      t.push([A, C, B], [A, D, C]);
    }
  return t;
}

for (const hp of [1, 2]) { // ICE: a clear faceted shell locking the crystal, frosted when thick
  const m = new Model();
  const shell = m.material(`ob_ice${hp}_shell`, { color: [0.78, 0.93, 1], metallic: 0.1, roughness: 0.05, emissive: [0.1, 0.18, 0.24], alpha: hp === 2 ? 0.58 : 0.4 });
  const frost = m.material(`ob_ice${hp}_frost`, { color: [0.92, 0.97, 1], roughness: 0.55, emissive: [0.18, 0.22, 0.26] });
  const k = hp === 2 ? 1.12 : 1;
  m.tris(shell, loft([
    { n: 6, r: 0.6 * k, y: -0.62 },
    { n: 6, r: 0.7 * k, y: -0.18, rot: 0.26 },
    { n: 6, r: 0.64 * k, y: 0.38, rot: 0.52 },
    { n: 6, r: 0.34 * k, y: 0.74, rot: 0.8 },
  ]));
  const R2 = rng(hp * 17);
  for (let i = 0; i < (hp === 2 ? 8 : 4); i++) {
    const a = R2() * Math.PI * 2;
    m.tris(frost, blob(0.08 + R2() * 0.06, R2, 0.35, 0), xf({ t: [Math.cos(a) * 0.5 * k, 0.3 + R2() * 0.4, Math.sin(a) * 0.5 * k] }));
  }
  out(`ob_ice${hp}`, m);
}

for (const hp of [1, 2]) { // VINES: stems spiralling round the crystal, with leaves
  const m = new Model();
  const stem = m.material(`ob_vine${hp}_stem`, { color: [0.19, 0.4, 0.13], roughness: 0.9, doubleSided: true });
  const leaf = m.material(`ob_vine${hp}_leaf`, { color: [0.33, 0.68, 0.22], roughness: 0.75, doubleSided: true });
  const R2 = rng(70 + hp);
  for (let s = 0; s < hp + 1; s++) {
    const phase = (s / (hp + 1)) * Math.PI * 2;
    const pts = Array.from({ length: 15 }, (_, i) => {
      const t = i / 14, a = phase + t * Math.PI * 3.2;
      const r = 0.52 + 0.05 * Math.sin(t * 9);
      return [Math.cos(a) * r, -0.6 + t * 1.25, Math.sin(a) * r];
    });
    m.tris(stem, tube(pts, 0.045, 4));
    for (let i = 2; i < pts.length; i += 3) {
      const p = pts[i];
      m.tris(leaf, blob(0.075, R2, 0.2, 0), xf({ s: [1.6, 0.35, 0.9], r: [0, R2() * 3, R2() - 0.5], t: [p[0] * 1.12, p[1], p[2] * 1.12] }));
    }
  }
  out(`ob_vine${hp}`, m);
}

for (const hp of [1, 2]) { // CHAINS: iron links strapped diagonally across the crystal
  const m = new Model();
  const iron = m.material(`ob_chain${hp}_iron`, { color: [0.5, 0.5, 0.53], metallic: 0.85, roughness: 0.35, doubleSided: true });
  const lock = m.material(`ob_chain${hp}_lock`, { color: [0.72, 0.56, 0.28], metallic: 0.8, roughness: 0.3 });
  const straps = hp === 2 ? [0.6, -0.6] : [0.6];
  for (const tilt of straps) {
    const N = 10, R0 = 0.6;
    for (let i = 0; i < N; i++) {
      const a = (i / N) * Math.PI * 2;
      const c = [Math.cos(a) * R0, 0, Math.sin(a) * R0];
      const tan = [-Math.sin(a), 0, Math.cos(a)];
      const side = i % 2 ? [0, 1, 0] : [Math.cos(a), 0, Math.sin(a)];
      const link = Array.from({ length: 7 }, (_, j) => {
        const th = (j / 7) * Math.PI * 2;
        return [0, 1, 2].map((q) => c[q] + tan[q] * Math.cos(th) * 0.15 + side[q] * Math.sin(th) * 0.08);
      });
      m.tris(iron, tube(link, 0.03, 3, true), xf({ r: [0, 0, tilt] }));
    }
    m.tris(lock, box(0.2, 0.22, 0.1), xf({ r: [0, 0, tilt], t: [0, 0, 0.6] }));
  }
  out(`ob_chain${hp}`, m);
}

for (const hp of [1, 2]) { // EMBERS: charred crust with glowing cracks
  const m = new Model();
  const crust = m.material(`ob_ember${hp}_crust`, { color: [0.13, 0.09, 0.08], roughness: 0.95 });
  const glow = m.material(`ob_ember${hp}_glow`, { color: [1, 0.46, 0.12], emissive: [1, 0.45, 0.1] });
  const R2 = rng(90 + hp);
  const chunks = hp === 2 ? 16 : 10;
  for (let i = 0; i < chunks; i++) {
    const a = R2() * Math.PI * 2, e = (R2() - 0.35) * 1.3;
    const p = [Math.cos(a) * Math.cos(e) * 0.55, Math.sin(e) * 0.6, Math.sin(a) * Math.cos(e) * 0.55];
    m.tris(crust, blob(0.12 + R2() * 0.07, R2, 0.4, 0), xf({ s: [1, 0.7, 1], t: p }));
    if (i % 2 === 0) m.tris(glow, cone(3, 0.05, 0.22), xf({ r: [R2() * 3, R2() * 3, R2() * 3], t: p.map((v) => v * 0.92) }));
  }
  out(`ob_ember${hp}`, m);
}

for (const hp of [1, 2, 3]) { // CRACKED STONE: fills the cell; more fractured as it takes hits
  const m = new Model();
  const R2 = rng(40 + hp);
  const stone = m.material(`ob_stone${hp}_rock`, { color: [0.6, 0.57, 0.52], roughness: 0.95 });
  const dark = m.material(`ob_stone${hp}_crack`, { color: [0.16, 0.14, 0.13], roughness: 1 });
  const moss = m.material(`ob_stone${hp}_moss`, { color: [0.33, 0.45, 0.2], roughness: 1 });
  const w = CELL * 0.86, h = 0.05;
  if (hp === 3) {
    m.tris(stone, slab(w, h, w, 0.004), xf({ t: [0, -0.004, 0] }));
  } else {
    // split into blocks that drift apart as the stone weakens
    const parts = hp === 2 ? 2 : 4;
    const gap = hp === 2 ? 0.0025 : 0.004;
    for (let i = 0; i < parts; i++) {
      const px = parts === 2 ? (i - 0.5) * (w / 2 + gap) : ((i % 2) - 0.5) * (w / 2 + gap);
      const pz = parts === 2 ? 0 : (Math.floor(i / 2) - 0.5) * (w / 2 + gap);
      const sw = parts === 2 ? w / 2 - gap : w / 2 - gap;
      const sd = parts === 2 ? w : w / 2 - gap;
      const hh = h * (0.8 + R2() * 0.2);
      m.tris(stone, slab(sw, hh, sd, 0.003), xf({ r: [0, (R2() - 0.5) * 0.12, 0], t: [px, -0.004, pz] }));
    }
    m.tris(dark, box(hp === 2 ? 0.0025 : w, 0.0015, hp === 2 ? w : 0.0025), xf({ t: [0, h - 0.004, 0] }));
  }
  for (let k = 0; k < 3; k++) m.tris(moss, blob(0.006, R2, 0.3, 0), xf({ s: [1.4, 0.5, 1.2], t: [(R2() - 0.5) * w * 0.8, h - 0.003, (R2() - 0.5) * w * 0.8] }));
  out(`ob_stone${hp}`, m);
}

for (const hp of [1, 2]) { // BURIED RUNES: a glowing carved plate on the socket top
  const m = new Model();
  const glowC = hp === 2 ? [0.55, 0.97, 1] : [0.3, 0.72, 0.8];
  const rune = m.material(`ob_rune${hp}_glow`, { color: glowC, emissive: glowC });
  const plate = m.material(`ob_rune${hp}_plate`, { color: [0.3, 0.29, 0.28], roughness: 0.9 });
  const w = CELL * 0.8;
  m.tris(plate, slab(w, 0.0016, w, 0.0006), xf({ t: [0, 0.0005, 0] }));
  const ring = Array.from({ length: 24 }, (_, i) => { const a = (i / 24) * Math.PI * 2; return [Math.cos(a) * w * 0.4, 0.0024, Math.sin(a) * w * 0.4]; });
  m.tris(rune, tube(ring, 0.0011, 3, true));
  for (let g = 0; g < 4; g++) {
    const a = (g / 4) * Math.PI * 2 + 0.4;
    m.tris(rune, box(w * 0.22, 0.0012, 0.0016), xf({ r: [0, a, 0], t: [Math.cos(a) * w * 0.27, 0.0024, -Math.sin(a) * w * 0.27] }));
    m.tris(rune, box(0.0016, 0.0012, w * 0.1), xf({ r: [0, a, 0], t: [Math.cos(a) * w * 0.33, 0.0024, -Math.sin(a) * w * 0.33] }));
  }
  out(`ob_rune${hp}`, m);
}

{ // SOLAR RELIC: a golden sun-disc idol that must be carried to the island's edge
  const m = new Model();
  const gold = m.material("gem_relic_gold", { color: [1, 0.76, 0.3], metallic: 0.85, roughness: 0.22 });
  const core = m.material("gem_relic_core", { color: [1, 0.93, 0.6], emissive: [1, 0.9, 0.55] });
  m.tris(gold, cylinder(14, 0.36, 0.14), xf({ r: [Math.PI / 2, 0, 0], t: [0, 0, -0.07] }));
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2;
    m.tris(gold, cone(4, 0.07, i % 2 ? 0.2 : 0.3), xf({ r: [0, 0, a - Math.PI / 2], t: [Math.cos(a) * 0.36, Math.sin(a) * 0.36, 0] }));
  }
  m.tris(core, loft([{ n: 8, r: 0, y: -0.2 }, { n: 8, r: 0.18, y: 0 }, { n: 8, r: 0, y: 0.2 }]), xf({ r: [Math.PI / 2, 0, 0], t: [0, 0, 0.1] }));
  out("gem_relic", m);
}

// ------------------------------------------------------------------ island --
const R = rng(2024);
const ISLAND_RX = 0.37, ISLAND_RZ = 0.33;
const edgeNoise = (a) => 1 + 0.06 * Math.sin(a * 3 + 1.3) + 0.04 * Math.sin(a * 7 + 0.4) + 0.02 * Math.sin(a * 13);
const inStream = (x, z) => x < -0.19 && x > -0.3 && z > -0.1;
{
  // Split into terrain + prop clusters: Viro hit-tests bounding boxes, so no decorative mesh may
  // have an AABB that encloses the board (it would swallow taps meant for crystals).
  const models = { terrain: new Model(), back: new Model(), left: new Model(), right: new Model() };
  let route = "terrain";
  const m = {
    material: (name, opts) => {
      for (const mm of Object.values(models)) mm.material(name, opts);
      return name;
    },
    tris: (mat, t, f) => models[route].tris(mat, t, f),
  };
  const grass = m.material("grass", { color: [0.33, 0.55, 0.2], roughness: 1 });
  const grassDark = m.material("grassDark", { color: [0.24, 0.44, 0.16], roughness: 1 });
  const soil = m.material("soil", { color: [0.42, 0.29, 0.18], roughness: 1 });
  const soilDeep = m.material("soilDeep", { color: [0.3, 0.2, 0.13], roughness: 1 });
  const rock = m.material("rock", { color: [0.5, 0.49, 0.46], roughness: 0.95 });
  const rockDark = m.material("rockDark", { color: [0.37, 0.36, 0.34], roughness: 0.95 });
  const ruin = m.material("ruin", { color: [0.7, 0.66, 0.58], roughness: 0.95 });
  const bark = m.material("bark", { color: [0.36, 0.24, 0.15], roughness: 1 });
  const pine = m.material("pine", { color: [0.13, 0.36, 0.2], roughness: 1 });
  const pineLight = m.material("pineLight", { color: [0.2, 0.46, 0.24], roughness: 1 });
  const leafy = m.material("leafy", { color: [0.36, 0.58, 0.2], roughness: 1 });
  const leafyWarm = m.material("leafyWarm", { color: [0.55, 0.62, 0.22], roughness: 1 });
  const water = m.material("water", { color: [0.25, 0.62, 0.8], roughness: 0.1, metallic: 0.1, emissive: [0.04, 0.14, 0.2], alpha: 0.85 });
  const mushroom = m.material("mushroom", { color: [0.85, 0.3, 0.22], roughness: 0.7 });
  const cream = m.material("cream", { color: [0.95, 0.9, 0.8], roughness: 0.8 });
  const portalStone = m.material("portalStone", { color: [0.58, 0.56, 0.52], roughness: 0.9 });
  const rune = m.material("runeGlow", { color: [0.55, 0.9, 1.0], emissive: [0.3, 0.7, 0.9], roughness: 0.4 });

  // Terrain: rings from centre outward; the centre stays flat under the platform.
  const RINGS = 9, SEG = 56;
  const rings = [];
  for (let k = 0; k <= RINGS; k++) {
    const f = k / RINGS;
    rings.push(Array.from({ length: SEG }, (_, i) => {
      const a = (i / SEG) * Math.PI * 2;
      const e = edgeNoise(a);
      const x = Math.cos(a) * ISLAND_RX * f * (k === RINGS ? e : 1 + (e - 1) * f);
      const z = Math.sin(a) * ISLAND_RZ * f * (k === RINGS ? e : 1 + (e - 1) * f);
      let y = SURFACE_Y;
      if (f > 0.62) y += (Math.sin(a * 5 + k) * 0.5 + 0.5) * 0.012 * (f - 0.62) * 3 + (R() - 0.5) * 0.003;
      if (inStream(x, z)) y = SURFACE_Y - 0.008;
      if (k === RINGS) y = SURFACE_Y - 0.002;
      return [x, y, z];
    }));
  }
  const top = [];
  const c0 = [0, SURFACE_Y, 0];
  for (let i = 0; i < SEG; i++) top.push([c0, rings[1][(i + 1) % SEG], rings[1][i]]);
  for (let k = 1; k < RINGS; k++)
    for (let i = 0; i < SEG; i++) {
      const j = (i + 1) % SEG;
      top.push([rings[k][i], rings[k][j], rings[k + 1][j]], [rings[k][i], rings[k + 1][j], rings[k + 1][i]]);
    }
  // alternate grass tones by facet for a hand-painted feel
  top.forEach((t, i) => m.tris((i * 7919) % 5 === 0 ? grassDark : grass, [t]));

  // Cut-away sides: soil strata with a rocky base, slightly tapered like a lifted chunk of earth.
  const edge = rings[RINGS];
  const layer = (y0, y1, s0, s1, mat) => {
    const t = [];
    for (let i = 0; i < SEG; i++) {
      const j = (i + 1) % SEG;
      const p = (q, y, s) => [q[0] * s, y, q[2] * s];
      const a = p(edge[i], y0, s0), b = p(edge[j], y0, s0), c = p(edge[j], y1, s1), d = p(edge[i], y1, s1);
      t.push([a, b, c], [a, c, d]);
    }
    m.tris(mat, t);
  };
  layer(SURFACE_Y - 0.002, SURFACE_Y - 0.012, 1, 0.985, grassDark);
  layer(SURFACE_Y - 0.012, 0.018, 0.985, 0.965, soil);
  layer(0.018, 0.006, 0.965, 0.95, soilDeep);
  layer(0.006, 0.0, 0.95, 0.93, rockDark);
  { // bottom cap
    const t = [];
    for (let i = 0; i < SEG; i++) t.push([[0, 0, 0], [edge[i][0] * 0.93, 0, edge[i][2] * 0.93], [edge[(i + 1) % SEG][0] * 0.93, 0, edge[(i + 1) % SEG][2] * 0.93]]);
    m.tris(rockDark, t);
  }
  // stones poking out of the cliff sides
  for (let i = 0; i < 26; i++) {
    const a = R() * Math.PI * 2, e = edgeNoise(a);
    m.tris(R() < 0.5 ? rock : rockDark, blob(0.012 + R() * 0.01, R, 0.3), xf({ s: [1.4, 0.8, 1.1], t: [Math.cos(a) * ISLAND_RX * e * 0.96, 0.012 + R() * 0.015, Math.sin(a) * ISLAND_RZ * e * 0.96], r: [0, a, 0] }));
  }

  // Stream bed + water along the left side, fed by the waterfall.
  const streamPts = [[-0.25, -0.085], [-0.255, -0.02], [-0.24, 0.06], [-0.25, 0.14], [-0.238, 0.2], [-0.232, 0.235]];
  const wt = [];
  for (let i = 0; i < streamPts.length - 1; i++) {
    const [x0, z0] = streamPts[i], [x1, z1] = streamPts[i + 1];
    const w0 = 0.03 + (i === 0 ? 0.015 : 0), w1 = 0.03;
    const y = SURFACE_Y - 0.004;
    wt.push([[x0 - w0, y, z0], [x1 - w1, y, z1], [x1 + w1, y, z1]], [[x0 - w0, y, z0], [x1 + w1, y, z1], [x0 + w0, y, z0]]);
  }
  m.tris(water, wt);
  for (let i = 0; i < 14; i++) {
    const s = streamPts[Math.floor(R() * streamPts.length)];
    const side = R() < 0.5 ? -1 : 1;
    m.tris(R() < 0.5 ? rock : rockDark, blob(0.008 + R() * 0.006, R, 0.3), xf({ s: [1.2, 0.7, 1.2], t: [s[0] + side * 0.036, SURFACE_Y, s[1] + (R() - 0.5) * 0.04] }));
  }

  route = "left";
  // Waterfall cliff (back-left): stacked weathered boulders.
  const cliff = [[-0.26, 0.05, -0.16, 0.06], [-0.3, 0.07, -0.12, 0.05], [-0.22, 0.09, -0.19, 0.055], [-0.28, 0.13, -0.17, 0.05], [-0.2, 0.15, -0.21, 0.04], [-0.3, 0.17, -0.2, 0.04], [-0.25, 0.19, -0.19, 0.045], [-0.17, 0.07, -0.16, 0.04], [-0.34, 0.08, -0.08, 0.035]];
  for (const [x, y, z, r] of cliff) m.tris(R() < 0.6 ? rock : rockDark, blob(r, R, 0.22), xf({ s: [1.15, 0.85, 1], t: [x, y, z] }));
  m.tris(grass, blob(0.05, R, 0.2), xf({ s: [1.3, 0.35, 1.1], t: [-0.25, 0.225, -0.19] }));
  // pond at the base of the falls
  m.tris(water, loft([{ n: 12, r: 0.05, y: SURFACE_Y - 0.003, rx: 0.06, rz: 0.04, cx: -0.25, cz: -0.08 }], { capBottom: false, capTop: true }));

  route = "back";
  // Ruins & portal (back centre): broken pillars, fallen blocks, and the standing ring.
  const pillar = (x, z, h, broken) => {
    m.tris(ruin, slab(0.04, 0.012, 0.04, 0.004), xf({ t: [x, SURFACE_Y, z] }));
    const segs = Math.floor(h / 0.03);
    for (let s = 0; s < segs; s++)
      m.tris(ruin, cylinder(8, 0.014, 0.028, { rot: s * 0.2 }), xf({ t: [x, SURFACE_Y + 0.012 + s * 0.03, z], r: [(R() - 0.5) * 0.05, 0, (R() - 0.5) * 0.05] }));
    if (!broken) m.tris(ruin, slab(0.042, 0.012, 0.042, 0.004), xf({ t: [x, SURFACE_Y + 0.012 + segs * 0.03, z] }));
    else m.tris(ruin, cone(8, 0.014, 0.018 + R() * 0.01, 0.3), xf({ t: [x, SURFACE_Y + 0.012 + segs * 0.03, z], r: [0.3, 0, 0.2] }));
  };
  pillar(-0.14, -0.23, 0.15, false);
  pillar(0.14, -0.23, 0.12, true);
  pillar(-0.09, -0.28, 0.09, true);
  pillar(0.19, -0.17, 0.06, true);
  for (let i = 0; i < 7; i++) m.tris(ruin, slab(0.03 + R() * 0.012, 0.016, 0.022, 0.004), xf({ t: [0.09 + R() * 0.13, SURFACE_Y, -0.14 - R() * 0.12], r: [0, R() * 3, (R() - 0.5) * 0.3] }));
  // wall fragment with steps
  for (let row = 0; row < 3; row++)
    for (let k = 0; k < 4 - row; k++) m.tris(ruin, slab(0.034, 0.018, 0.024, 0.003), xf({ t: [-0.06 + k * 0.036 + row * 0.018 - 0.1, SURFACE_Y + row * 0.018, -0.3], r: [0, (R() - 0.5) * 0.06, 0] }));
  // portal ring of wedge-shaped voussoirs standing on a stepped base
  const PC = [0, SURFACE_Y + 0.105, -0.235], PR = 0.085;
  m.tris(portalStone, slab(0.16, 0.012, 0.07, 0.004), xf({ t: [0, SURFACE_Y, PC[2]] }));
  m.tris(portalStone, slab(0.12, 0.01, 0.05, 0.003), xf({ t: [0, SURFACE_Y + 0.012, PC[2]] }));
  const NV = 13;
  for (let i = 0; i < NV; i++) {
    const a = (i / NV) * Math.PI * 2 + Math.PI / 2;
    const px = PC[0] + Math.cos(a) * PR, py = PC[1] + Math.sin(a) * PR;
    m.tris(portalStone, box(0.036, 0.026, 0.03), xf({ r: [0, 0, a + Math.PI / 2], t: [px, py, PC[2]] }));
    if (i % 3 === 0) m.tris(rune, blob(0.005, R, 0), xf({ s: [1, 1, 0.4], t: [px, py, PC[2] + 0.016] }));
  }

  // Trees: pines behind/right, broadleaf on the flanks. Kept off the player-facing side.
  const region = (x) => (x < -0.19 ? "left" : x > 0.19 ? "right" : "back");
  const pineTree = (x, z, h) => {
    route = region(x);
    m.tris(bark, cylinder(6, 0.008, h * 0.35), xf({ t: [x, SURFACE_Y, z] }));
    for (let k = 0; k < 3; k++) {
      const r = (0.05 - k * 0.012) * (h / 0.2);
      m.tris(k % 2 ? pineLight : pine, cone(7, r, h * 0.42, R()), xf({ t: [x, SURFACE_Y + h * (0.22 + k * 0.22), z] }));
    }
  };
  const roundTree = (x, z, h) => {
    route = region(x);
    m.tris(bark, cylinder(6, 0.009, h * 0.5, { rTop: 0.005 }), xf({ t: [x, SURFACE_Y, z], r: [0, 0, (R() - 0.5) * 0.2] }));
    for (let k = 0; k < 3; k++)
      m.tris(k === 1 ? leafyWarm : leafy, blob(h * (0.2 - k * 0.03), R, 0.2), xf({ t: [x + (R() - 0.5) * 0.04, SURFACE_Y + h * (0.6 + k * 0.12), z + (R() - 0.5) * 0.04] }));
  };
  pineTree(0.27, -0.17, 0.24);
  pineTree(0.32, -0.04, 0.19);
  pineTree(0.21, -0.26, 0.2);
  pineTree(-0.33, -0.2, 0.2);
  pineTree(-0.05, -0.31, 0.16);
  roundTree(0.3, 0.13, 0.16);
  roundTree(-0.33, 0.06, 0.13);
  roundTree(0.24, 0.24, 0.1);

  route = "terrain";
  // Foreground: stepping-stone path to the platform, grass tufts and wildflowers.
  const tuft = m.material("tuft", { color: [0.3, 0.52, 0.17], roughness: 1 });
  const tuftLight = m.material("tuftLight", { color: [0.45, 0.62, 0.22], roughness: 1 });
  const flowerW = m.material("flowerW", { color: [0.97, 0.95, 0.88], emissive: [0.12, 0.12, 0.1], roughness: 0.8 });
  const flowerY = m.material("flowerY", { color: [1.0, 0.82, 0.3], emissive: [0.15, 0.1, 0.02], roughness: 0.8 });
  const flowerP = m.material("flowerP", { color: [0.78, 0.55, 0.95], emissive: [0.1, 0.06, 0.12], roughness: 0.8 });
  for (let i = 0; i < 4; i++) {
    const z = 0.235 + i * 0.016, x = Math.sin(i * 1.7) * 0.02;
    m.tris(i % 2 ? rock : ruin, slab(0.026 + R() * 0.008, 0.004, 0.014, 0.0015), xf({ t: [x, SURFACE_Y - 0.001, z], r: [0, (R() - 0.5) * 0.6, 0] }));
  }
  for (let i = 0; i < 170; i++) {
    const a = R() * Math.PI * 2, f = 0.35 + R() * 0.57;
    const x = Math.cos(a) * ISLAND_RX * f, z = Math.sin(a) * ISLAND_RZ * f;
    if (inStream(x, z) || (Math.abs(x) < 0.2 && z > -0.16 && z < 0.24) || (Math.abs(x) < 0.035 && z > 0.22)) continue;
    const blades = 3 + Math.floor(R() * 3);
    for (let k = 0; k < blades; k++)
      m.tris(k % 2 ? tuftLight : tuft, cone(3, 0.0026, 0.014 + R() * 0.012, R() * 3), xf({ t: [x + (R() - 0.5) * 0.008, SURFACE_Y - 0.001, z + (R() - 0.5) * 0.008], r: [(R() - 0.5) * 0.5, 0, (R() - 0.5) * 0.5] }));
    if (R() < 0.35) m.tris([flowerW, flowerY, flowerP][Math.floor(R() * 3)], blob(0.0028, R, 0.1, 0), xf({ s: [1, 0.6, 1], t: [x, SURFACE_Y + 0.012, z] }));
  }
  // Mushrooms and pebbles for miniature detail.
  for (const [x, z] of [[0.22, 0.05], [0.235, 0.07], [-0.18, 0.25], [0.12, -0.3], [-0.2, -0.26]]) {
    const h = 0.01 + R() * 0.008;
    m.tris(cream, cylinder(5, 0.003, h), xf({ t: [x, SURFACE_Y, z] }));
    m.tris(mushroom, cone(7, 0.009, 0.007, R()), xf({ t: [x, SURFACE_Y + h, z] }));
  }
  for (let i = 0; i < 30; i++) {
    const a = R() * Math.PI * 2, f = 0.62 + R() * 0.3;
    const x = Math.cos(a) * ISLAND_RX * f, z = Math.sin(a) * ISLAND_RZ * f;
    if (inStream(x, z) || (z > 0.18 && Math.abs(x) < 0.2)) continue;
    m.tris(R() < 0.5 ? rock : rockDark, blob(0.004 + R() * 0.004, R, 0.3), xf({ s: [1.3, 0.6, 1], t: [x, SURFACE_Y, z] }));
  }
  out("terrain", models.terrain);
  out("props_back", models.back);
  out("props_left", models.left);
  out("props_right", models.right);
}

// ---------------------------------------------------- animated world parts --
{ // Portal core: faces +Z, centred on origin (positioned at the ring centre in the scene).
  const m = new Model();
  const core = m.material("portalCore", { color: [0.55, 0.95, 1.0], emissive: [0.35, 0.8, 0.95], roughness: 0.2, alpha: 0.75, doubleSided: true });
  const t = [];
  const N = 24;
  for (let i = 0; i < N; i++) {
    const a0 = (i / N) * Math.PI * 2, a1 = ((i + 1) / N) * Math.PI * 2;
    const r0 = 0.07 * (1 + 0.05 * Math.sin(i * 3)), r1 = 0.07 * (1 + 0.05 * Math.sin((i + 1) * 3));
    t.push([[0, 0, 0.004], [Math.cos(a0) * r0, Math.sin(a0) * r0, 0], [Math.cos(a1) * r1, Math.sin(a1) * r1, 0]]);
  }
  m.tris(core, t);
  out("portal_core", m);
}
{ // Waterfall ribbon, origin at the lip; flows down -Y and slightly toward +Z.
  const m = new Model();
  const w = m.material("fall", { color: [0.7, 0.9, 1.0], emissive: [0.15, 0.3, 0.4], roughness: 0.1, alpha: 0.7, doubleSided: true });
  const foam = m.material("foam", { color: [0.95, 0.98, 1.0], emissive: [0.3, 0.35, 0.4], roughness: 0.6, alpha: 0.9 });
  const t = [];
  const H = 0.17, S = 8;
  for (let s = 0; s < S; s++) {
    const y0 = -(s / S) * H, y1 = -((s + 1) / S) * H;
    const z0 = 0.012 * Math.sqrt(s / S), z1 = 0.012 * Math.sqrt((s + 1) / S);
    const w0 = 0.022 + s * 0.001, w1 = 0.022 + (s + 1) * 0.001;
    t.push([[-w0, y0, z0], [-w1, y1, z1], [w1, y1, z1]], [[-w0, y0, z0], [w1, y1, z1], [w0, y0, z0]]);
  }
  m.tris(w, t);
  const Rf = rng(5);
  for (let i = 0; i < 6; i++) m.tris(foam, blob(0.01 + Rf() * 0.006, Rf, 0.3), xf({ s: [1.4, 0.6, 1.2], t: [(Rf() - 0.5) * 0.05, -H - 0.002, 0.015 + (Rf() - 0.5) * 0.02] }));
  out("waterfall", m);
}
{ // Flower cluster (grows in as the world awakens)
  const m = new Model();
  const Rb = rng(9);
  const leafM = m.material("bloomLeaf", { color: [0.25, 0.52, 0.2], roughness: 1 });
  const petal = m.material("petal", { color: [0.95, 0.55, 0.75], emissive: [0.2, 0.08, 0.14], roughness: 0.7 });
  const petal2 = m.material("petal2", { color: [0.98, 0.9, 0.55], emissive: [0.2, 0.18, 0.05], roughness: 0.7 });
  m.tris(leafM, blob(0.018, Rb, 0.25), xf({ s: [1.4, 0.6, 1.4], t: [0, 0.006, 0] }));
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2 + Rb();
    const x = Math.cos(a) * 0.014, z = Math.sin(a) * 0.014, h = 0.014 + Rb() * 0.01;
    m.tris(leafM, cylinder(4, 0.0012, h), xf({ t: [x, 0.006, z] }));
    m.tris(i % 2 ? petal : petal2, blob(0.0055, Rb, 0.1, 0), xf({ s: [1, 0.55, 1], t: [x, 0.006 + h, z] }));
  }
  out("bloom", m);
}
{ // Hanging vines for the ruins (origin at the top, grows downward via scaleY)
  const m = new Model();
  const Rv = rng(11);
  const vine = m.material("vine", { color: [0.22, 0.5, 0.2], roughness: 1 });
  const vleaf = m.material("vineLeaf", { color: [0.35, 0.62, 0.22], roughness: 1 });
  for (let s = 0; s < 4; s++) {
    const x = (s - 1.5) * 0.012;
    const len = 0.05 + Rv() * 0.04;
    m.tris(vine, cylinder(4, 0.0015, len), xf({ t: [x, -len, 0.002], r: [0, 0, (Rv() - 0.5) * 0.15] }));
    for (let k = 0; k < 4; k++) m.tris(vleaf, blob(0.0045, Rv, 0.2, 0), xf({ s: [1.3, 0.5, 0.8], t: [x + (Rv() - 0.5) * 0.008, -len * (k + 0.5) / 4, 0.004] }));
  }
  out("vines", m);
}
{ // Glow-crystal cluster embedded in the terrain (pulses with matches)
  const m = new Model();
  const Rc = rng(13);
  const c = m.material("clusterGlow", { color: [0.6, 0.9, 1.0], emissive: [0.35, 0.65, 0.85], metallic: 0.2, roughness: 0.15 });
  const base = m.material("clusterRock", { color: [0.4, 0.39, 0.37], roughness: 0.95 });
  m.tris(base, blob(0.018, Rc, 0.25), xf({ s: [1.4, 0.5, 1.2] }));
  for (let i = 0; i < 5; i++) {
    const h = 0.025 + Rc() * 0.03;
    m.tris(c, loft([{ n: 6, r: 0.005, y: 0 }, { n: 6, r: 0.006, y: h * 0.7 }, { n: 6, r: 0, y: h }]), xf({ t: [(Rc() - 0.5) * 0.02, 0, (Rc() - 0.5) * 0.02], r: [(Rc() - 0.5) * 0.7, 0, (Rc() - 0.5) * 0.7] }));
  }
  out("glow_cluster", m);
}
{ // Soft shadow blob that grounds the diorama on the real table.
  const m = new Model();
  const sh = m.material("groundShadow", { color: [0, 0, 0], roughness: 1, alpha: 0.35 });
  const t = [];
  const N = 40;
  for (let i = 0; i < N; i++) {
    const a0 = (i / N) * Math.PI * 2, a1 = ((i + 1) / N) * Math.PI * 2;
    t.push([[0, 0, 0], [Math.cos(a1) * ISLAND_RX * 1.08, 0, Math.sin(a1) * ISLAND_RZ * 1.1], [Math.cos(a0) * ISLAND_RX * 1.08, 0, Math.sin(a0) * ISLAND_RZ * 1.1]]);
  }
  m.tris(sh, t);
  out("ground_shadow", m);
}

// ---------------------------------------------------------------- textures --
function png(name, w, h, pixel) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      const [r, g, b, a] = pixel(x, y);
      raw.set([r, g, b, a], y * (w * 4 + 1) + 1 + x * 4);
    }
  }
  const crcTable = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (buf) => {
    let c = 0xffffffff;
    for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
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
  const file = Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
  writeFileSync(new URL(name + ".png", TEX), file);
  console.log(name.padEnd(16), (file.length / 1024).toFixed(0).padStart(12), "KB");
}
png("spark", 64, 64, (x, y) => {
  const d = Math.hypot(x - 31.5, y - 31.5) / 32;
  const core = Math.max(0, 1 - d) ** 2.2;
  const rays = Math.max(0, 1 - Math.min(Math.abs(x - 31.5), Math.abs(y - 31.5)) / 2.5) * Math.max(0, 1 - d) ** 1.5;
  const a = Math.min(1, core + rays * 0.6);
  return [255, 255, 255, Math.round(a * 255)];
});
png("ring_glow", 128, 128, (x, y) => {
  const d = Math.hypot(x - 63.5, y - 63.5) / 64;
  const ring = Math.exp(-(((d - 0.8) / 0.08) ** 2)) + 0.25 * Math.exp(-(((d - 0.55) / 0.05) ** 2));
  return [255, 255, 255, Math.round(Math.min(1, ring) * 255)];
});

// ---------------------------------------------------------- lighting (IBL) --
// Radiance .hdr environment: warm sky, dark ground, a sun and two soft "windows" so crystal
// facets pick up crisp glints. Uncompressed RGBE scanlines.
{
  const W = 256, H = 128;
  const px = Buffer.alloc(W * H * 4);
  const rgbe = (r, g, b) => {
    const m = Math.max(r, g, b);
    if (m < 1e-32) return [0, 0, 0, 0];
    const e = Math.ceil(Math.log2(m));
    const s = 256 / 2 ** e;
    return [Math.min(255, r * s), Math.min(255, g * s), Math.min(255, b * s), e + 128].map(Math.floor);
  };
  const sun = [Math.cos(0.9) * Math.cos(-2.2), Math.sin(0.9), Math.cos(0.9) * Math.sin(-2.2)];
  for (let y = 0; y < H; y++) {
    const el = (0.5 - (y + 0.5) / H) * Math.PI; // +pi/2 top
    for (let x = 0; x < W; x++) {
      const az = ((x + 0.5) / W) * Math.PI * 2 - Math.PI;
      const d = [Math.cos(el) * Math.cos(az), Math.sin(el), Math.cos(el) * Math.sin(az)];
      let c;
      if (el > 0) {
        const t = el / (Math.PI / 2);
        c = [1.35 - 0.45 * t, 1.3 - 0.3 * t, 1.2 - 0.05 * t];
      } else {
        c = [0.28, 0.22, 0.17];
      }
      const sd = d[0] * sun[0] + d[1] * sun[1] + d[2] * sun[2];
      if (sd > 0.995) c = c.map((v, i) => v + [40, 36, 30][i]);
      else if (sd > 0.96) c = c.map((v) => v + 3 * ((sd - 0.96) / 0.035));
      // softboxes
      const box = (a0, a1, e0, e1, k) => az > a0 && az < a1 && el > e0 && el < e1 && (c = c.map((v) => v + k));
      box(0.3, 0.9, 0.25, 0.7, 7);
      box(2.2, 2.6, 0.1, 0.45, 4);
      px.set(rgbe(...c), (y * W + x) * 4);
    }
  }
  const header = Buffer.from(`#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y ${H} +X ${W}\n`, "ascii");
  writeFileSync(new URL("studio_forest.hdr", TEX), Buffer.concat([header, px]));
  console.log("studio_forest.hdr".padEnd(16), ((header.length + px.length) / 1024).toFixed(0).padStart(12), "KB");
}

// ---- crystal meshes for ViroGeometry ----------------------------------------------
{
  const header = [
    "// GENERATED by scripts/gen-models.mjs - do not edit. Flat-shaded triangle lists (xyz per vertex).",
    "export interface MeshPart { material: string; color: number[]; alpha: number; emissive: number[]; doubleSided: boolean; v: number[]; n: number[] }",
    "export const GEM_MESHES: Record<string, MeshPart[]> = ",
  ].join("\n");
  const body = JSON.stringify(MESHES);
  writeFileSync(new URL("../src/render/gemMeshes.ts", import.meta.url), header + body + ";\n");
  console.log("gemMeshes.ts".padEnd(16), (body.length / 1024).toFixed(0).padStart(12), "KB");
}

// ---- Tabletop View surroundings (phones without ARCore) ----------------------------
{
  const Rw = rng(77);
  const noise = Array.from({ length: 64 }, () => Rw());
  const n1 = (t) => { const i = Math.floor(t) & 63, f0 = t - Math.floor(t), f = f0 * f0 * (3 - 2 * f0); return noise[i] * (1 - f) + noise[(i + 1) & 63] * f; };
  const fbm = (t) => n1(t) * 0.55 + n1(t * 2.1 + 17) * 0.3 + n1(t * 4.3 + 41) * 0.15;
  png("table_wood", 512, 512, (x, y) => {
    // long planks along X with grain rings, knots and plank seams
    const plank = Math.floor(y / 128);
    const v = (y % 128) + fbm(x / 60 + plank * 7) * 26;
    const ring = Math.pow(0.5 + 0.5 * Math.sin(v * 0.9 + fbm(x / 140 + plank * 3) * 9), 2.2);
    const fine = 0.5 + 0.5 * Math.sin(v * 3.1 + fbm(x / 25) * 4);
    const seam = y % 128 < 2 ? 0.55 : 1;
    const pv = 0.9 + 0.2 * noise[(plank * 13) & 63];
    const tone = [0.5, 0.33, 0.2].map((c) => c * pv * (0.78 + 0.22 * ring + 0.06 * fine) * seam);
    return [...tone.map((c) => Math.round(Math.min(1, c) * 255)), 255];
  });
  png("room_backdrop", 256, 512, (x, y) => {
    const t = y / 511, d = Math.abs(x - 127.5) / 128;
    const top = [0.1, 0.11, 0.14], mid = [0.2, 0.16, 0.12], glow = [0.34, 0.27, 0.18];
    const base = t < 0.6 ? top.map((c, i) => c + (mid[i] - c) * (t / 0.6)) : mid.map((c, i) => c + (glow[i] - c) * ((t - 0.6) / 0.4));
    return [...base.map((c) => Math.round(Math.min(1, c * (1 - d * 0.35)) * 255)), 255];
  });
  // Sky universe: twilight gradient with drifting cloud bands (the islands float in this, not on a table)
  const n2 = (x, y) => n1(x + n1(y * 0.7 + 11) * 6) * 0.6 + n1(y * 1.3 + n1(x * 0.4 + 5) * 4) * 0.4;
  const clouds = (x, y) => n2(x, y) * 0.5 + n2(x * 2.1 + 9, y * 2.1 + 3) * 0.3 + n2(x * 4.3, y * 4.3 + 7) * 0.2;
  png("sky_panorama", 512, 512, (x, y) => {
    const t = y / 511; // 0 = zenith, 1 = below the horizon
    const zen = [0.05, 0.08, 0.2], high = [0.2, 0.28, 0.52], hor = [0.98, 0.72, 0.5], low = [0.55, 0.52, 0.6];
    const mix = (a, b, k) => a.map((c, i) => c + (b[i] - c) * k);
    let col = t < 0.45 ? mix(zen, high, t / 0.45) : t < 0.62 ? mix(high, hor, (t - 0.45) / 0.17) : mix(hor, low, Math.min(1, (t - 0.62) / 0.38));
    // cloud bands thicken toward the horizon, lit warm from below
    const c = clouds(x / 70, y / 26);
    const band = Math.max(0, c - 0.52) * 2.4 * (0.35 + t * 0.9);
    const lit = mix([0.85, 0.82, 0.9], [1, 0.8, 0.62], Math.min(1, t * 1.4));
    col = mix(col, lit, Math.min(0.85, band));
    // a few stars high up
    const star = t < 0.35 && noise[(x * 7 + y * 13) & 63] > 0.985 && (x * 31 + y * 17) % 7 === 0 ? 0.6 : 0;
    return [...col.map((v) => Math.round(Math.min(1, v + star) * 255)), 255];
  });
  png("cloud_sea", 512, 512, (x, y) => {
    const c = clouds(x / 40, y / 40);
    const edge = Math.min(1, Math.hypot(x - 255.5, y - 255.5) / 256);
    const a = Math.max(0, Math.min(1, (c - 0.38) * 2.6)) * (1 - Math.pow(edge, 3));
    const v = 0.78 + c * 0.25;
    return [Math.round(Math.min(1, v * 1.02) * 255), Math.round(Math.min(1, v * 0.96) * 255), Math.round(Math.min(1, v * 1.05) * 255), Math.round(a * 235)];
  });
}
