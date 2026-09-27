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
  if (name.startsWith("gem_") || name === "surge_aura") {
    MESHES[name] = [...model.buckets].filter(([, b]) => b.pos.length).map(([mat, b]) => {
      const def = model.materials.find((x) => x.name === mat);
      const r = (v) => Math.round(v * 1e4) / 1e4;
      return { material: mat, color: def.color, alpha: def.alpha, emissive: def.emissive, v: b.pos.map(r), n: b.nrm.map(r) };
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
  red: [0.86, 0.07, 0.16],
  blue: [0.1, 0.36, 0.96],
  green: [0.07, 0.7, 0.3],
  purple: [0.56, 0.2, 0.88],
  gold: [1.0, 0.72, 0.1],
};
const gemMaterial = (m, name, c) =>
  m.material(name, { color: c, metallic: 0.35, roughness: 0.07, emissive: c.map((v) => v * 0.22), alpha: 0.82 });
const coreMaterial = (m, name, c) =>
  m.material(name + "_core", { color: c.map((v) => Math.min(1, v * 0.6 + 0.4)), roughness: 0.3, emissive: c.map((v) => Math.min(1, v * 0.9 + 0.25)) });

const outline = (n, f) => Array.from({ length: n }, (_, i) => f((i / n) * Math.PI * 2));
const heart = outline(30, (t) => [
  (16 * Math.sin(t) ** 3) / 34,
  (13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t)) / 34 + 0.05,
]);
const leaf = outline(26, (t) => {
  const y = Math.cos(t) * 0.52;
  const w = 0.3 * Math.sin(t) * (1 - 0.25 * Math.cos(t));
  return [w + 0.04 * Math.cos(t) * Math.sin(t), y];
});
const star = Array.from({ length: 10 }, (_, i) => {
  const a = Math.PI / 2 + (i / 10) * Math.PI * 2;
  const r = i % 2 === 0 ? 0.52 : 0.24;
  return [Math.cos(a) * r, Math.sin(a) * r - 0.02];
});

const gems = {
  gem_red: (m, mat) => m.tris(mat, pillowGem(heart, 0.3, 0.17, 0.5)),
  gem_blue: (m, mat) =>
    m.tris(mat, loft([
      { n: 8, r: 0, y: -0.52 },
      { n: 8, r: 0.5, y: 0.06, rot: 0 },
      { n: 8, r: 0.47, y: 0.13, rot: Math.PI / 8 },
      { n: 8, r: 0.3, y: 0.34, rot: Math.PI / 8 },
    ])),
  gem_green: (m, mat) => m.tris(mat, pillowGem(leaf, 0.24, 0.14, 0.45)),
  gem_purple: (m, mat) =>
    m.tris(mat, loft([
      { n: 6, r: 0, y: -0.55 },
      { n: 6, r: 0.24, y: -0.3, rot: 0 },
      { n: 6, r: 0.27, y: -0.05, rot: 0.3 },
      { n: 6, r: 0.27, y: 0.2, rot: 0.6 },
      { n: 6, r: 0.22, y: 0.36, rot: 0.9 },
      { n: 6, r: 0, y: 0.58, rot: 1.2 },
    ])),
  gem_gold: (m, mat) => m.tris(mat, pillowGem(star, 0.26, 0.15, 0.45)),
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
    "export interface MeshPart { material: string; color: number[]; alpha: number; emissive: number[]; v: number[]; n: number[] }",
    "export const GEM_MESHES: Record<string, MeshPart[]> = ",
  ].join("\n");
  const body = JSON.stringify(MESHES);
  writeFileSync(new URL("../src/render/gemMeshes.ts", import.meta.url), header + body + ";\n");
  console.log("gemMeshes.ts".padEnd(16), (body.length / 1024).toFixed(0).padStart(12), "KB");
}
