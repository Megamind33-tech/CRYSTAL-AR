// Builds a level's island as plain geometry: textured terrain, a rocky floating underside, the portal
// arch and a seeded scatter of biome props. Pure (no Viro) and deterministic in (biome, seed), so every
// level gets its own island without shipping hundreds of model files.
//
// World-local frame (same as the rest of the diorama): origin = island centre on the table, +Y up,
// +Z toward the player. The board stands on a flat plaza; the portal sits behind it.
import { fbm, prng, ringNoise } from "./noise.ts";
import type { Biome, PropKind, PropSpec } from "./biomes.ts";

export type V3 = [number, number, number];
export type V2 = [number, number];

/** Material slots every island uses; the renderer maps them to biome materials. */
export type Slot = "top" | "cliff" | "stone" | "bark" | "leaf" | "leafDark" | "accent" | "glow" | "stem" | "lava" | "ice" | "water";

export interface MeshPart {
  slot: Slot;
  vertices: V3[];
  normals: V3[];
  texcoords: V2[];
  indices: V3[];
}

export interface IslandMesh {
  parts: MeshPart[];
  /** terrain height at a point (for placing reactive props on the ground) */
  heightAt: (x: number, z: number) => number;
  /** anchor points for the reactive crystal outcrops and blooms */
  anchors: { clusters: V3[]; blooms: V3[] };
  triangles: number;
}

export const SURFACE_Y = 0.04; // keep in sync with render/layout.ts
const RX = 0.37, RZ = 0.33;
export const PORTAL_CENTER: V3 = [0, SURFACE_Y + 0.105, -0.232];
const PORTAL_R = 0.075;

const smooth = (a: number, b: number, x: number) => {
  const t = Math.max(0, Math.min(1, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};

/** Signed-ish distance outside the plaza the board stands on. */
function plazaDistance(x: number, z: number) {
  const dx = Math.abs(x) - 0.19, dz = Math.max(z - 0.25, -0.15 - z);
  return Math.max(dx, dz, 0) + Math.hypot(Math.max(dx, 0), Math.max(dz, 0)) * 0.3;
}

// ------------------------------------------------------------- accumulation --
class Acc {
  pos: number[] = [];
  uv: number[] = [];
  smoothFlags: boolean[] = [];
  slot: Slot;
  tile: number;
  constructor(slot: Slot, tile: number) {
    this.slot = slot;
    this.tile = tile;
  }
  /** triangle with box-projected UVs (world metres × tile) */
  tri(a: V3, b: V3, c: V3, smoothShade = false) {
    const n = faceNormal(a, b, c);
    const ax = Math.abs(n[0]), ay = Math.abs(n[1]), az = Math.abs(n[2]);
    const proj = (p: V3): V2 => (ay >= ax && ay >= az ? [p[0], p[2]] : ax >= az ? [p[2], p[1]] : [p[0], p[1]]);
    for (const p of [a, b, c]) {
      this.pos.push(p[0], p[1], p[2]);
      const [u, v] = proj(p);
      this.uv.push(u * this.tile, v * this.tile);
    }
    this.smoothFlags.push(smoothShade);
  }
  tris(ts: V3[][], f: (p: V3) => V3, smoothShade = false) {
    for (const t of ts) this.tri(f(t[0]), f(t[1]), f(t[2]), smoothShade);
  }
}

function faceNormal(a: V3, b: V3, c: V3): V3 {
  const u = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], v = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
  const n: V3 = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
  const l = Math.hypot(n[0], n[1], n[2]) || 1;
  return [n[0] / l, n[1] / l, n[2] / l];
}

/** Flat or smooth normals (smooth: averaged over coincident positions within the part). */
function finishAcc(acc: Acc): MeshPart {
  const count = acc.pos.length / 3;
  const P = (i: number): V3 => [acc.pos[i * 3], acc.pos[i * 3 + 1], acc.pos[i * 3 + 2]];
  const normals: V3[] = new Array(count);
  const sums = new Map<string, V3>();
  const key = (p: V3) => `${Math.round(p[0] * 2e4)},${Math.round(p[1] * 2e4)},${Math.round(p[2] * 2e4)}`;
  for (let t = 0; t < count / 3; t++) {
    const n = faceNormal(P(t * 3), P(t * 3 + 1), P(t * 3 + 2));
    for (let k = 0; k < 3; k++) {
      normals[t * 3 + k] = n;
      if (acc.smoothFlags[t]) {
        const s = sums.get(key(P(t * 3 + k))) ?? [0, 0, 0];
        sums.set(key(P(t * 3 + k)), [s[0] + n[0], s[1] + n[1], s[2] + n[2]]);
      }
    }
  }
  for (let t = 0; t < count / 3; t++) {
    if (!acc.smoothFlags[t]) continue;
    for (let k = 0; k < 3; k++) {
      const s = sums.get(key(P(t * 3 + k)))!;
      const l = Math.hypot(s[0], s[1], s[2]) || 1;
      normals[t * 3 + k] = [s[0] / l, s[1] / l, s[2] / l];
    }
  }
  const vertices: V3[] = [], texcoords: V2[] = [], indices: V3[] = [];
  for (let i = 0; i < count; i++) {
    vertices.push(P(i));
    texcoords.push([acc.uv[i * 2], acc.uv[i * 2 + 1]]);
  }
  for (let i = 0; i < count; i += 3) indices.push([i, i + 1, i + 2]);
  return { slot: acc.slot, vertices, normals, texcoords, indices };
}

// --------------------------------------------------------------- primitives --
type Tris = V3[][];
function ring(n: number, r: number, y: number, rot = 0, jitter?: (i: number) => number): V3[] {
  return Array.from({ length: n }, (_, i) => {
    const a = (i / n) * Math.PI * 2 + rot, j = jitter ? jitter(i) : 1;
    return [Math.cos(a) * r * j, y, Math.sin(a) * r * j];
  });
}
/** Stack of rings (bottom → top); r = 0 rings become points. Outward-facing. */
function loftT(rings: V3[][], capBottom = true, capTop = true): Tris {
  const t: Tris = [];
  for (let k = 0; k < rings.length - 1; k++) {
    const A = rings[k], B = rings[k + 1], n = A.length;
    for (let i = 0; i < n; i++) {
      const i2 = (i + 1) % n;
      t.push([A[i], B[i2], B[i]], [A[i], A[i2], B[i2]]);
    }
  }
  const centre = (R: V3[]): V3 => [R.reduce((s, p) => s + p[0], 0) / R.length, R[0][1], R.reduce((s, p) => s + p[2], 0) / R.length];
  if (capBottom) {
    const R = rings[0], c = centre(R);
    for (let i = 0; i < R.length; i++) t.push([c, R[i], R[(i + 1) % R.length]]);
  }
  if (capTop) {
    const R = rings[rings.length - 1], c = centre(R);
    for (let i = 0; i < R.length; i++) t.push([c, R[(i + 1) % R.length], R[i]]);
  }
  return t;
}
const cyl = (n: number, r0: number, r1: number, h: number, y0 = 0) => loftT([ring(n, r0, y0), ring(n, r1, y0 + h)]);
const cone = (n: number, r: number, h: number, y0 = 0, rot = 0) => loftT([ring(n, r, y0, rot), ring(n, 0.0001, y0 + h, rot)], true, false);
function boxT(w: number, h: number, d: number): Tris {
  const x = w / 2, z = d / 2;
  const v: V3[] = [[-x, 0, -z], [x, 0, -z], [x, 0, z], [-x, 0, z], [-x, h, -z], [x, h, -z], [x, h, z], [-x, h, z]];
  const f = [[0, 1, 2, 3], [7, 6, 5, 4], [3, 2, 6, 7], [1, 0, 4, 5], [0, 3, 7, 4], [2, 1, 5, 6]];
  const t: Tris = [];
  for (const [a, b, c, d] of f) t.push([v[a], v[c], v[b]], [v[a], v[d], v[c]]);
  return t;
}
/** Displaced icosphere (rocks, canopies, caps). */
function blobT(r: number, rand: () => number, amount: number, subdiv = 1): Tris {
  const p = (1 + Math.sqrt(5)) / 2;
  let v: V3[] = ([[-1, p, 0], [1, p, 0], [-1, -p, 0], [1, -p, 0], [0, -1, p], [0, 1, p], [0, -1, -p], [0, 1, -p], [p, 0, -1], [p, 0, 1], [-p, 0, -1], [-p, 0, 1]] as V3[]).map(nrm);
  let f = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]];
  for (let s = 0; s < subdiv; s++) {
    const cache = new Map<string, number>();
    const mid = (a: number, b: number) => {
      const k = a < b ? `${a}_${b}` : `${b}_${a}`;
      if (!cache.has(k)) {
        v.push(nrm([(v[a][0] + v[b][0]) / 2, (v[a][1] + v[b][1]) / 2, (v[a][2] + v[b][2]) / 2]));
        cache.set(k, v.length - 1);
      }
      return cache.get(k)!;
    };
    const nf: number[][] = [];
    for (const [a, b, c] of f) {
      const ab = mid(a, b), bc = mid(b, c), ca = mid(c, a);
      nf.push([a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]);
    }
    f = nf;
  }
  v = v.map((q) => {
    const k = r * (1 + (rand() * 2 - 1) * amount);
    return [q[0] * k, q[1] * k, q[2] * k];
  });
  return f.map(([a, b, c]) => [v[a], v[b], v[c]]);
}
function nrm(a: V3): V3 {
  const l = Math.hypot(a[0], a[1], a[2]);
  return [a[0] / l, a[1] / l, a[2] / l];
}
/** scale → rotate (x, then y, then z) → translate */
function xf(s: V3 | number, r: V3, t: V3): (p: V3) => V3 {
  const sc: V3 = typeof s === "number" ? [s, s, s] : s;
  const [cx, sx] = [Math.cos(r[0]), Math.sin(r[0])], [cy, sy] = [Math.cos(r[1]), Math.sin(r[1])], [cz, sz] = [Math.cos(r[2]), Math.sin(r[2])];
  return (p) => {
    let x = p[0] * sc[0], y = p[1] * sc[1], z = p[2] * sc[2];
    [y, z] = [y * cx - z * sx, y * sx + z * cx];
    [x, z] = [x * cy + z * sy, -x * sy + z * cy];
    [x, y] = [x * cz - y * sz, x * sz + y * cz];
    return [x + t[0], y + t[1], z + t[2]];
  };
}

// ---------------------------------------------------------------------- build --
/** far = a distant island on the horizon: fewer rings, no portal, a handful of props */
export function buildIsland(biome: Biome, seed: number, far = false): IslandMesh {
  const rand = prng(seed);
  const hills = fbm(seed ^ 0x51f1, 3);
  const coast = ringNoise(seed ^ 0x2c1b);
  const under = fbm(seed ^ 0x77a3, 2);
  const tileOf = { top: biome.top.tile, cliff: biome.cliff.tile, stone: biome.stone.tile, bark: 30, leaf: 20, leafDark: 20, accent: 20, glow: 20, stem: 20, lava: 10, ice: 14, water: 6 } as const;
  const accs = new Map<Slot, Acc>();
  const acc = (slot: Slot) => {
    let a = accs.get(slot);
    if (!a) accs.set(slot, (a = new Acc(slot, tileOf[slot])));
    return a;
  };

  const edgeScale = (a: number) => 1 + coast(a) * 0.1;
  const heightAt = (x: number, z: number): number => {
    const plaza = 1 - smooth(0, 0.06, plazaDistance(x, z));
    const portal = 1 - smooth(0.07, 0.12, Math.hypot(x - PORTAL_CENTER[0], z - PORTAL_CENTER[2]));
    const t = Math.min(1.2, Math.hypot(x / RX, z / RZ));
    const hill = (hills(x * 7 + 3, z * 7 - 5) * 0.5 + 0.5) * 0.038 * biome.hills + smooth(-0.1, -0.3, z) * 0.03 * biome.backRise;
    const rim = smooth(0.78, 1.02, t) * 0.02;
    const ground = SURFACE_Y - 0.003 + hill * (1 - plaza) - rim;
    return ground * (1 - portal) + (SURFACE_Y + 0.004) * portal;
  };

  // ---- terrain top: polar grid (smooth, indexed per quad through the accumulator)
  const NR = far ? 6 : 14, NS = far ? 28 : 64;
  const grid: V3[][] = [];
  for (let i = 0; i <= NR; i++) {
    const t = i / NR;
    const row: V3[] = [];
    for (let j = 0; j < NS; j++) {
      const a = (j / NS) * Math.PI * 2, e = edgeScale(a);
      const x = Math.cos(a) * RX * t * e, z = Math.sin(a) * RZ * t * e;
      row.push([x, heightAt(x, z), z]);
    }
    grid.push(row);
  }
  const top = acc("top");
  for (let i = 0; i < NR; i++)
    for (let j = 0; j < NS; j++) {
      const j2 = (j + 1) % NS;
      const a = grid[i][j], b = grid[i][j2], c = grid[i + 1][j2], d = grid[i + 1][j];
      if (i === 0) top.tri(a, c, d, true);
      else {
        top.tri(a, c, d, true);
        top.tri(a, b, c, true);
      }
    }

  // ---- floating underside: jagged rock tapering to a point
  const cliff = acc("cliff");
  const K = far ? 4 : 6;
  const layers: V3[][] = [grid[NR]];
  for (let k = 1; k <= K; k++) {
    const f = k / K;
    layers.push(grid[NR].map((p, j) => {
      const a = (j / NS) * Math.PI * 2;
      const n = under(Math.cos(a) * 3 + k, Math.sin(a) * 3 - k);
      const s = Math.max(0.04, (1 - Math.pow(f, 1.35) * 0.95) * (1 + n * 0.12));
      const y = SURFACE_Y - 0.012 - f * biome.depth * (0.85 + 0.3 * (n * 0.5 + 0.5));
      return [p[0] * s, y, p[2] * s];
    }));
  }
  for (let k = 0; k < K; k++)
    for (let j = 0; j < NS; j++) {
      const j2 = (j + 1) % NS;
      const a = layers[k][j], b = layers[k][j2], c = layers[k + 1][j2], d = layers[k + 1][j];
      cliff.tri(a, c, d, true);
      cliff.tri(a, b, c, true);
    }
  const tip: V3 = [0, SURFACE_Y - biome.depth * 1.15, 0];
  for (let j = 0; j < NS; j++) cliff.tri(layers[K][j], layers[K][(j + 1) % NS], tip, true);

  // ---- portal arch behind the board: carved ring of blocks on a plinth
  const stone = acc("stone");
  const [pcx, pcy, pcz] = PORTAL_CENTER;
  const blocks = far ? 0 : 13;
  for (let i = 0; i < blocks; i++) {
    const a = (i / blocks) * Math.PI * 2;
    const tilt = rand() * 0.08 - 0.04;
    stone.tris(boxT(0.026, 0.018, 0.024), xf(1, [0, 0, a + Math.PI / 2 + tilt], [pcx + Math.cos(a) * PORTAL_R, pcy + Math.sin(a) * PORTAL_R - 0.009, pcz]));
  }
  if (!far) {
    stone.tris(boxT(0.2, 0.012, 0.05), xf(1, [0, 0, 0], [pcx, SURFACE_Y - 0.004, pcz]));
    stone.tris(boxT(0.14, 0.008, 0.04), xf(1, [0, 0, 0], [pcx, SURFACE_Y + 0.008, pcz]));
  }

  // ---- props
  const placed: { x: number; z: number; r: number }[] = [{ x: pcx, z: pcz, r: 0.11 }];
  const specs = biome.props;
  const total = specs.reduce((s, p) => s + p.weight, 0);
  const pickSpec = (): PropSpec => {
    let r = rand() * total;
    for (const s of specs) if ((r -= s.weight) < 0) return s;
    return specs[0];
  };
  const count = Math.round((biome.propCount[0] + Math.floor(rand() * (biome.propCount[1] - biome.propCount[0] + 1))) * (far ? 0.35 : 1));
  const anchors = { clusters: [] as V3[], blooms: [] as V3[] };
  for (let n = 0, guard = 0; n < count && guard < count * 40; guard++) {
    const spec = pickSpec();
    const size = spec.size[0] + rand() * (spec.size[1] - spec.size[0]);
    const a = rand() * Math.PI * 2, t = 0.25 + Math.sqrt(rand()) * 0.68;
    const x = Math.cos(a) * RX * t * edgeScale(a), z = Math.sin(a) * RZ * t * edgeScale(a);
    const radius = FOOTPRINT[spec.kind] * size;
    if (plazaDistance(x, z) < radius + 0.012) continue;
    if (!inZone(spec, x, z)) continue;
    if (placed.some((p) => Math.hypot(p.x - x, p.z - z) < p.r + radius)) continue;
    placed.push({ x, z, r: radius });
    buildProp(spec.kind, size, [x, heightAt(x, z), z], rand() * Math.PI * 2, rand, acc, biome);
    n++;
  }
  // reactive outcrops and blooms stand on free ground near the board
  for (let i = 0, guard = 0; !far && (anchors.clusters.length < 3 || anchors.blooms.length < 7) && guard < 400; guard++) {
    const a = rand() * Math.PI * 2, t = 0.35 + rand() * 0.55;
    const x = Math.cos(a) * RX * t, z = Math.sin(a) * RZ * t;
    if (plazaDistance(x, z) < 0.02 || placed.some((p) => Math.hypot(p.x - x, p.z - z) < p.r + 0.02)) continue;
    const want = anchors.clusters.length < 3 && z < 0.1 ? "clusters" : "blooms";
    if (want === "blooms" && anchors.blooms.length >= 7) continue;
    anchors[want].push([x, heightAt(x, z), z]);
    placed.push({ x, z, r: 0.02 });
    i++;
  }

  const parts = [...accs.values()].filter((a) => a.pos.length).map(finishAcc);
  return { parts, heightAt, anchors, triangles: parts.reduce((s, p) => s + p.indices.length, 0) };
}

/** Tall props keep behind or beside the board so they never hide the crystals. */
const TALL = new Set<PropKind>(["pine", "snowPine", "broadleaf", "spire", "arch", "column", "obelisk", "kelp", "deadTree", "voidShard", "brokenColumn"]);
function inZone(spec: PropSpec, x: number, z: number): boolean {
  if (TALL.has(spec.kind) && z > 0.02 && Math.abs(x) < 0.3) return false;
  if (spec.zone === "back") return z < -0.08;
  if (spec.zone === "side") return Math.abs(x) > 0.2 || z < -0.05;
  return true;
}

const FOOTPRINT: Record<PropKind, number> = {
  pine: 0.03, snowPine: 0.03, broadleaf: 0.035, bush: 0.016, rock: 0.012, boulder: 0.026, spire: 0.03, arch: 0.05,
  column: 0.016, brokenColumn: 0.02, mushroom: 0.022, stalagmite: 0.02, iceSpike: 0.02, coral: 0.02, kelp: 0.012,
  obelisk: 0.02, dune: 0.045, lavaPool: 0.035, vent: 0.024, deadTree: 0.025, voidShard: 0.018, pool: 0.035,
};

function buildProp(kind: PropKind, s: number, at: V3, yaw: number, rand: () => number, acc: (slot: Slot) => Acc, biome: Biome) {
  const put = (dx: number, dy: number, dz: number, extra: V3 = [0, 0, 0], scale: V3 | number = 1) =>
    xf(scale, [extra[0], yaw + extra[1], extra[2]], [at[0] + dx, at[1] + dy, at[2] + dz]);
  const lean = () => (rand() - 0.5) * 0.12;
  switch (kind) {
    case "pine":
    case "snowPine": {
      acc("bark").tris(cyl(6, 0.006 * s, 0.004 * s, 0.035 * s), put(0, -0.004, 0));
      for (let k = 0; k < 3; k++) {
        const r = (0.034 - k * 0.008) * s, y = (0.022 + k * 0.026) * s;
        acc(k % 2 ? "leaf" : "leafDark").tris(cone(8, r, 0.05 * s, 0, rand()), put(0, y, 0), true);
        if (kind === "snowPine") acc("top").tris(cone(8, r * 0.55, 0.022 * s, 0, rand()), put(0, y + 0.03 * s, 0), true);
      }
      break;
    }
    case "broadleaf": {
      acc("bark").tris(cyl(6, 0.006 * s, 0.004 * s, 0.05 * s), put(0, -0.004, 0, [lean(), 0, lean()]));
      for (let k = 0; k < 3; k++)
        acc(k === 1 ? "leafDark" : "leaf").tris(blobT(0.024 * s, rand, 0.25), put((rand() - 0.5) * 0.03 * s, (0.055 + rand() * 0.02) * s, (rand() - 0.5) * 0.03 * s), true);
      break;
    }
    case "bush":
      for (let k = 0; k < 2; k++) acc(k ? "leaf" : "leafDark").tris(blobT(0.012 * s, rand, 0.3), put((rand() - 0.5) * 0.014 * s, 0.006 * s, (rand() - 0.5) * 0.014 * s, [0, 0, 0], [1, 0.75, 1]), true);
      break;
    case "rock":
      acc("stone").tris(blobT(0.011 * s, rand, 0.35), put(0, 0.002, 0, [0, 0, 0], [1.2, 0.7, 1]), true);
      break;
    case "boulder":
      acc("stone").tris(blobT(0.024 * s, rand, 0.3), put(0, 0.006 * s, 0, [lean(), 0, lean()], [1.15, 0.8, 1]), true);
      acc("stone").tris(blobT(0.011 * s, rand, 0.35), put(0.022 * s, 0.002, 0.01 * s), true);
      break;
    case "spire": {
      const h = (0.12 + rand() * 0.06) * s, r = 0.026 * s;
      const rings: V3[][] = [0, 0.3, 0.6, 0.85, 1].map((f, i) => ring(6, r * (1 - f * 0.8), -0.01 + f * h, i * 0.4, () => 0.8 + rand() * 0.4));
      acc("stone").tris(loftT(rings, false, true), put(0, 0, 0, [lean(), 0, lean()]), true);
      break;
    }
    case "arch": {
      const R = 0.045 * s;
      for (let i = 0; i <= 8; i++) {
        const a = (i / 8) * Math.PI;
        acc("stone").tris(boxT(0.016 * s, 0.014 * s, 0.018 * s), put(Math.cos(a) * R * Math.cos(yaw), Math.sin(a) * R, -Math.cos(a) * R * Math.sin(yaw), [0, 0, a - Math.PI / 2]));
      }
      break;
    }
    case "column":
    case "brokenColumn": {
      const h = (kind === "column" ? 0.13 : 0.04 + rand() * 0.05) * s;
      acc("stone").tris(boxT(0.03 * s, 0.008 * s, 0.03 * s), put(0, -0.002, 0));
      acc("stone").tris(cyl(10, 0.011 * s, 0.01 * s, h), put(0, 0.006 * s, 0), true);
      if (kind === "column") acc("stone").tris(boxT(0.03 * s, 0.008 * s, 0.03 * s), put(0, 0.006 * s + h, 0));
      else acc("stone").tris(cyl(10, 0.011 * s, 0.011 * s, 0.03 * s), put(0.028 * s, 0.006, 0.006, [0, 0, Math.PI / 2 - 0.2]), true);
      break;
    }
    case "mushroom": {
      const h = (0.03 + rand() * 0.03) * s;
      acc("stem").tris(cyl(8, 0.005 * s, 0.004 * s, h), put(0, -0.002, 0, [lean(), 0, lean()]), true);
      const cap = loftT([ring(10, 0.022 * s, 0), ring(10, 0.019 * s, 0.008 * s), ring(10, 0.011 * s, 0.015 * s), ring(10, 0.001, 0.018 * s)], true, false);
      acc(rand() < 0.5 ? "glow" : "accent").tris(cap, put(0, h - 0.004, 0), true);
      break;
    }
    case "stalagmite":
      for (let k = 0; k < 3; k++) acc("stone").tris(cone(7, (0.012 - k * 0.003) * s, (0.07 - k * 0.018) * s, -0.004, rand()), put((k - 1) * 0.012 * s, 0, (rand() - 0.5) * 0.012 * s, [lean(), 0, lean()]), true);
      break;
    case "iceSpike":
      for (let k = 0; k < 3; k++) acc("ice").tris(cone(5, (0.012 - k * 0.002) * s, (0.09 - k * 0.022) * s, -0.004, rand()), put((k - 1) * 0.011 * s, 0, (rand() - 0.5) * 0.012 * s, [lean() * 2, 0, lean() * 2]));
      break;
    case "coral":
      for (let k = 0; k < 4; k++) {
        const ang = (k / 4) * Math.PI * 2;
        acc("accent").tris(cyl(5, 0.004 * s, 0.0025 * s, 0.035 * s), put(0, 0, 0, [Math.sin(ang) * 0.5, 0, Math.cos(ang) * 0.5]), true);
        acc("accent").tris(blobT(0.005 * s, rand, 0.2, 0), put(Math.cos(ang) * 0.016 * s, 0.032 * s, Math.sin(ang) * 0.016 * s), true);
      }
      break;
    case "kelp":
      for (let k = 0; k < 3; k++) acc(k % 2 ? "leaf" : "leafDark").tris(cyl(4, 0.003 * s, 0.0015 * s, (0.06 + rand() * 0.04) * s), put((k - 1) * 0.006 * s, 0, 0, [lean() * 3, 0, lean() * 3]), true);
      break;
    case "obelisk": {
      const h = 0.12 * s;
      acc("stone").tris(loftT([ring(4, 0.016 * s, 0, Math.PI / 4), ring(4, 0.011 * s, h, Math.PI / 4)], false, false), put(0, -0.002, 0));
      acc("stone").tris(cone(4, 0.011 * s, 0.02 * s, h, Math.PI / 4), put(0, -0.002, 0));
      acc("glow").tris(boxT(0.004 * s, 0.004 * s, 0.001), put(0, h * 0.7, 0.0112 * s));
      break;
    }
    case "dune":
      acc("top").tris(blobT(0.045 * s, rand, 0.1), put(0, -0.004, 0, [0, 0, 0], [1.3, 0.22, 0.9]), true);
      break;
    case "lavaPool":
    case "pool": {
      const r = 0.03 * s;
      acc(kind === "lavaPool" ? "lava" : "water").tris(cyl(16, r, r, 0.002), put(0, 0.001, 0));
      for (let k = 0; k < 6; k++) {
        const a = (k / 6) * Math.PI * 2 + rand();
        acc("stone").tris(blobT(0.007 * s, rand, 0.3, 0), put(Math.cos(a) * r, 0.002, Math.sin(a) * r, [0, 0, 0], [1.2, 0.6, 1]), true);
      }
      break;
    }
    case "vent":
      acc("stone").tris(loftT([ring(8, 0.02 * s, -0.004), ring(8, 0.012 * s, 0.022 * s), ring(8, 0.008 * s, 0.024 * s)], false, false), put(0, 0, 0), true);
      acc("lava").tris(cyl(8, 0.008 * s, 0.008 * s, 0.001), put(0, 0.023 * s, 0));
      break;
    case "deadTree": {
      acc("bark").tris(cyl(5, 0.006 * s, 0.003 * s, 0.07 * s), put(0, -0.004, 0, [lean(), 0, lean()]));
      for (let k = 0; k < 3; k++) acc("bark").tris(cyl(4, 0.0025 * s, 0.001 * s, 0.03 * s), put(0, (0.035 + k * 0.012) * s, 0, [0.9, (k / 3) * Math.PI * 2 + rand(), 0]));
      break;
    }
    case "voidShard": {
      const h = (0.07 + rand() * 0.04) * s;
      const float = 0.012 + rand() * 0.02;
      acc("glow").tris(loftT([ring(4, 0.0001, 0), ring(4, 0.012 * s, h * 0.45), ring(4, 0.0001, h)], false, false), put(0, float, 0, [lean() * 2, 0, lean() * 2]));
      acc("stone").tris(blobT(0.012 * s, rand, 0.4, 0), put(0, 0.002, 0, [0, 0, 0], [1.3, 0.5, 1.1]), true);
      break;
    }
  }
  void biome;
}

// ------------------------------------------------------------------ dais --
/** Half-width (x) and z range of the stone dais a Meshy island is fitted around; tools/asset-pipeline/bake-islands.mjs
 *  must keep these in sync when it searches for the flattest ground. */
export const DAIS = { halfX: 0.25, zMin: -0.33, zMax: 0.25, wall: 0.03 } as const;

/**
 * What stands on a Meshy island where the board sits: a stone dais (a slab down to `bottomY`), the
 * portal arch and its plinth. Deterministic in `seed`. A Meshy island is an organic hilly model, so instead of
 * levelling its ground the board gets a flat stone platform (like the plaza on the procedural islands); the island
 * is placed so its terrain sits below the dais top, and the slab hides whatever is left.
 */
export function buildDais(biome: Biome, seed: number, bottomY: number): MeshPart[] {
  const rand = prng(seed ^ 0x9e37);
  const stone = new Acc("stone", biome.stone.tile);
  const { halfX, zMin, zMax } = DAIS;
  const top = SURFACE_Y;
  // slab: a box from bottomY up to the dais top (the top face is hidden by the board's own sockets in most places)
  stone.tris(boxT(halfX * 2, top - bottomY, zMax - zMin), xf(1, [0, 0, 0], [0, bottomY, (zMin + zMax) / 2]));
  // portal arch, identical to the procedural islands'
  const [pcx, pcy, pcz] = PORTAL_CENTER;
  for (let i = 0; i < 13; i++) {
    const a = (i / 13) * Math.PI * 2;
    const tilt = rand() * 0.08 - 0.04;
    stone.tris(boxT(0.026, 0.018, 0.024), xf(1, [0, 0, a + Math.PI / 2 + tilt], [pcx + Math.cos(a) * PORTAL_R, pcy + Math.sin(a) * PORTAL_R - 0.009, pcz]));
  }
  stone.tris(boxT(0.2, 0.012, 0.05), xf(1, [0, 0, 0], [pcx, top - 0.004, pcz]));
  stone.tris(boxT(0.14, 0.008, 0.04), xf(1, [0, 0, 0], [pcx, top + 0.008, pcz]));
  return [finishAcc(stone)];
}
