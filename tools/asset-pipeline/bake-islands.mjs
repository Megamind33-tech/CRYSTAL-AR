// Meshy realm islands -> game geometry, fitted to the board.
//
// A Meshy island is an organic hilly model, so it cannot be levelled under the board. Instead, per island:
//   1. try 4 yaws and every window position, rasterise the terrain height on a 1 cm grid, and pick the placement
//      where the dais footprint (buildIsland.DAIS) sits on the flattest ground with nothing tall in front of it,
//   2. bake scale / yaw / translation into the vertices so the dais top is exactly SURFACE_Y,
//   3. decimate to a hero LOD (under the board) and a far LOD (horizon), keeping the texture mapping,
//   4. write src/render/meshyIslands/<realm>.ts (+ index.ts) and a 1024 px texture per realm.
// The runtime adds the dais (stone slab + portal arch) from buildIsland.buildDais.
//   node bake-islands.mjs [realm ...]        (needs .cache/mid/<realm>.glb from mid.mjs)
import { mkdirSync, writeFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { NodeIO } from "@gltf-transform/core";
import sharp from "sharp";
import { GAME_TEX_DIR, ISLAND_DIR, ISLAND_LOD, ISLAND_WIDTH, REALMS } from "./config.mjs";
import { decimateTextured } from "./reproject.mjs";

// keep in sync with src/render/island/buildIsland.ts (DAIS, SURFACE_Y); the unit test checks the numbers
const DAIS = { halfX: 0.25, zMin: -0.33, zMax: 0.25 };
const SURFACE_Y = 0.04;
const GRID = 0.01;

mkdirSync(ISLAND_DIR, { recursive: true });
mkdirSync(GAME_TEX_DIR, { recursive: true });
const io = new NodeIO();
const r = (v, d) => Math.round(v * 10 ** d) / 10 ** d;

function transform(P, N, yawDeg, s) {
  const a = (yawDeg * Math.PI) / 180, c = Math.cos(a), sn = Math.sin(a);
  const P2 = new Float32Array(P.length), N2 = new Float32Array(N.length);
  for (let i = 0; i < P.length; i += 3) {
    P2[i] = (P[i] * c + P[i + 2] * sn) * s; P2[i + 1] = P[i + 1] * s; P2[i + 2] = (-P[i] * sn + P[i + 2] * c) * s;
    N2[i] = N[i] * c + N[i + 2] * sn; N2[i + 1] = N[i + 1]; N2[i + 2] = -N[i] * sn + N[i + 2] * c;
  }
  return { P2, N2 };
}

function heightMap(P, I) {
  let x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity;
  for (let i = 0; i < P.length; i += 3) { x0 = Math.min(x0, P[i]); x1 = Math.max(x1, P[i]); z0 = Math.min(z0, P[i + 2]); z1 = Math.max(z1, P[i + 2]); }
  const W = Math.ceil((x1 - x0) / GRID) + 2, H = Math.ceil((z1 - z0) / GRID) + 2;
  const h = new Float32Array(W * H).fill(-Infinity);
  for (let t = 0; t < I.length; t += 3) {
    const a = I[t] * 3, b = I[t + 1] * 3, c = I[t + 2] * 3;
    const ax = (P[a] - x0) / GRID, az = (P[a + 2] - z0) / GRID, bx = (P[b] - x0) / GRID, bz = (P[b + 2] - z0) / GRID, cx = (P[c] - x0) / GRID, cz = (P[c + 2] - z0) / GRID;
    const den = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz);
    if (Math.abs(den) < 1e-9) continue;
    for (let j = Math.floor(Math.min(az, bz, cz)); j <= Math.ceil(Math.max(az, bz, cz)); j++) for (let i = Math.floor(Math.min(ax, bx, cx)); i <= Math.ceil(Math.max(ax, bx, cx)); i++) {
      const l1 = ((bz - cz) * (i - cx) + (cx - bx) * (j - cz)) / den, l2 = ((cz - az) * (i - cx) + (ax - cx) * (j - cz)) / den, l3 = 1 - l1 - l2;
      if (l1 < -0.05 || l2 < -0.05 || l3 < -0.05) continue;
      const y = l1 * P[a + 1] + l2 * P[b + 1] + l3 * P[c + 1];
      if (i >= 0 && j >= 0 && i < W && j < H && y > h[j * W + i]) h[j * W + i] = y;
    }
  }
  return { h, W, H, x0, z0 };
}

/** Best (lowest score) window position for the dais on one heightmap; null if the island never covers it. */
function bestWindow(map) {
  const { h, W, H, x0, z0 } = map;
  const cell = (x, z) => [Math.round((x - x0) / GRID), Math.round((z - z0) / GRID)];
  let best = null;
  for (let cz = -0.3; cz <= 0.3; cz += 0.02) for (let cx = -0.4; cx <= 0.4; cx += 0.02) {
    const zc = cz - (DAIS.zMin + DAIS.zMax) / 2; // world z of the dais centre for this offset is cz; dais spans cz+zMin-mid.. see below
    void zc;
    // dais rect in island coordinates: centred at (cx, cz + mid) so the rect [zMin,zMax] maps to [cz+zMin-mid+mid...]
    const mid = (DAIS.zMin + DAIS.zMax) / 2;
    const xa = cx - DAIS.halfX, xb = cx + DAIS.halfX, za = cz + mid - (DAIS.zMax - DAIS.zMin) / 2, zb = cz + mid + (DAIS.zMax - DAIS.zMin) / 2;
    let lo = Infinity, hi = -Infinity, ok = true;
    for (let z = za; z <= zb && ok; z += GRID * 2) for (let x = xa; x <= xb; x += GRID * 2) {
      const [i, j] = cell(x, z);
      const v = i >= 0 && j >= 0 && i < W && j < H ? h[j * W + i] : -Infinity;
      if (!Number.isFinite(v)) { ok = false; break; }
      lo = Math.min(lo, v); hi = Math.max(hi, v);
    }
    if (!ok) continue;
    // ground must exist 3 cm beyond the dais on every side (no slab hanging over the void)
    for (const [x, z] of [[xa - 0.03, za], [xb + 0.03, za], [xa - 0.03, zb], [xb + 0.03, zb], [cx, zb + 0.03], [cx, za - 0.02], [xa - 0.03, (za + zb) / 2], [xb + 0.03, (za + zb) / 2]]) {
      const [i, j] = cell(x, z);
      if (!(i >= 0 && j >= 0 && i < W && j < H && Number.isFinite(h[j * W + i]))) ok = false;
    }
    if (!ok) continue;
    // anything tall in front / to the sides hides the board from the camera
    let over = 0, n = 0;
    for (let z = za - 0.1; z <= zb + 0.14; z += GRID * 3) for (let x = xa - 0.1; x <= xb + 0.1; x += GRID * 3) {
      if (x >= xa && x <= xb && z >= za && z <= zb) continue;
      if (z < zb && z > za - 0.0) { /* sides */ }
      const [i, j] = cell(x, z);
      const v = i >= 0 && j >= 0 && i < W && j < H ? h[j * W + i] : -Infinity;
      n++;
      if (Number.isFinite(v) && v > hi + 0.015 && z > za + 0.05) over += v - (hi + 0.015);
    }
    const score = (hi - lo) + (over / Math.max(1, n)) * 6 + 0.2 * Math.hypot(cx, cz) * 0.1;
    if (!best || score < best.score) best = { score, cx, cz, mid, lo, hi, range: hi - lo };
  }
  return best;
}

const realms = process.argv.slice(2).length ? process.argv.slice(2) : REALMS;
console.log("realm      yaw   scale  win range  dais bottom   hero tris/verts   far tris   tex KB");
for (const realm of realms) {
  const file = `.cache/mid/${realm}.glb`;
  if (!existsSync(file)) { console.log(realm.padEnd(10), "missing", file); continue; }
  const doc = await io.read(file);
  const prim = doc.getRoot().listMeshes()[0].listPrimitives()[0];
  const P = prim.getAttribute("POSITION").getArray(), N = prim.getAttribute("NORMAL").getArray(), U = prim.getAttribute("TEXCOORD_0").getArray(), I = prim.getIndices().getArray();
  let pick = null;
  for (const yaw of [0, 90, 180, 270]) {
    // width along X after the yaw
    const { P2 } = transform(P, N, yaw, 1);
    let x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity;
    for (let i = 0; i < P2.length; i += 3) { x0 = Math.min(x0, P2[i]); x1 = Math.max(x1, P2[i]); z0 = Math.min(z0, P2[i + 2]); z1 = Math.max(z1, P2[i + 2]); }
    const s = Math.min(ISLAND_WIDTH / (x1 - x0), 1.0 / (z1 - z0));
    const t = transform(P, N, yaw, s);
    const w = bestWindow(heightMap(t.P2, I));
    if (w && (!pick || w.score < pick.w.score)) pick = { yaw, s, w, t };
  }
  if (!pick) { console.log(realm.padEnd(10), "NO PLACEMENT FOUND"); continue; }
  const { yaw, s, w, t } = pick;
  // place: dais centre -> (0, mid), dais top -> SURFACE_Y (terrain top in the window sits 6 mm below it)
  const dx = -w.cx, dz = -w.cz, dy = SURFACE_Y - 0.006 - w.hi;
  const bottomY = r(w.lo + dy - 0.035, 4);
  for (let i = 0; i < t.P2.length; i += 3) { t.P2[i] += dx; t.P2[i + 1] += dy; t.P2[i + 2] += dz; }
  const src = { P: t.P2, N: t.N2, U, I };
  const hero = await decimateTextured(src, ISLAND_LOD.hero);
  const far = await decimateTextured(src, ISLAND_LOD.far);
  // the window search samples the ground every 2 cm, so a thin spike can slip through: clamp anything under the dais
  // (1 cm margin) below the dais top so nothing pokes through the slab
  let clamped = 0;
  for (let k = 0; k < hero.v.length; k += 3) {
    if (Math.abs(hero.v[k]) < DAIS.halfX + 0.01 && hero.v[k + 2] > DAIS.zMin - 0.01 && hero.v[k + 2] < DAIS.zMax + 0.01 && hero.v[k + 1] > SURFACE_Y - 0.006) { hero.v[k + 1] = SURFACE_Y - 0.006; clamped++; }
  }
  const pack = (m, d) => ({ v: m.v.map((x) => r(x, d)), n: m.n.map((x) => r(x, 2)), t: m.t.map((x) => r(x, 4)), i: m.i });
  const img = doc.getRoot().listMaterials()[0].getBaseColorTexture().getImage();
  await sharp(Buffer.from(img)).resize(ISLAND_LOD.tex, ISLAND_LOD.tex).jpeg({ quality: 80 }).toFile(`${GAME_TEX_DIR}island_${realm}.jpg`);
  writeFileSync(`${ISLAND_DIR}${realm}.ts`, `// GENERATED by tools/asset-pipeline/bake-islands.mjs - do not edit.
import type { MeshyIsland } from "./types";
export const ISLAND: MeshyIsland = ${JSON.stringify({ realm, yaw, scale: r(s, 4), bottomY, hero: pack(hero, 4), far: pack(far, 3) })};
`);
  const bridge = (m) => m.v.length + m.n.length + m.t.length + m.i.length;
  console.log(`${realm.padEnd(10)} ${String(yaw).padStart(3)}  ${s.toFixed(3)}  ${w.range.toFixed(3)}m  ${bottomY.toFixed(3)}   ${hero.stats.tris}/${hero.stats.verts} (${bridge(pack(hero, 4))} nums)   ${far.stats.tris}   clamped ${clamped}   ${(statSync(`${GAME_TEX_DIR}island_${realm}.jpg`).size / 1024) | 0}`);
}
const have = readdirSync(ISLAND_DIR).filter((f) => f.endsWith(".ts") && !["index.ts", "types.ts"].includes(f)).map((f) => f.slice(0, -3)).sort();
writeFileSync(`${ISLAND_DIR}types.ts`, `export interface IslandMesh { v: number[]; n: number[]; t: number[]; i: number[] }
/** A Meshy realm island fitted to the board (see tools/asset-pipeline/bake-islands.mjs). Coordinates are world-local
 *  game units: the dais top is at SURFACE_Y and the dais is centred on the board. */
export interface MeshyIsland { realm: string; yaw: number; scale: number; bottomY: number; hero: IslandMesh; far: IslandMesh }
`);
writeFileSync(`${ISLAND_DIR}index.ts`, `// GENERATED by tools/asset-pipeline/bake-islands.mjs - do not edit.
// Each realm is required lazily, so only the islands actually shown are evaluated at runtime.
import type { MeshyIsland } from "./types";
export type { MeshyIsland } from "./types";
const LOADERS: Record<string, () => MeshyIsland> = {
${have.map((n) => `  ${n}: () => require("./${n}").ISLAND,`).join("\n")}
};
export const MESHY_ISLAND_REALMS = ${JSON.stringify(have)};
const cache = new Map<string, MeshyIsland>();
export function meshyIsland(realm: string): MeshyIsland | null {
  let m = cache.get(realm);
  if (!m && LOADERS[realm]) cache.set(realm, (m = LOADERS[realm]()));
  return m ?? null;
}
`);
