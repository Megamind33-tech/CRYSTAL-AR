// The baked Meshy crystals (src/render/meshyMeshes.ts) are generated data that feeds ViroGeometry directly, so
// a bad bake would show up as a crash or a broken crystal on a phone. These checks catch that at test time.
import { test } from "node:test";
import assert from "node:assert/strict";
import { MESHY_MESHES } from "../../render/meshyMeshes.ts";
import { GEM_MESHES } from "../../render/gemMeshes.ts";

const NAMES = ["gem_red", "gem_blue", "gem_green", "gem_purple", "gem_gold", "gem_prism", "gem_relic", "surge_aura"];
/** numbers sent over the React Native bridge per instance: vertices + normals + texcoords + triangle indices */
const bridge = (m: { v: number[]; n: number[]; t: number[]; i: number[] }) => m.v.length + m.n.length + m.t.length + m.i.length;

test("every crystal has a Meshy version, and the classic fallback exists for each", () => {
  for (const n of NAMES) {
    assert.ok(MESHY_MESHES[n], `${n} missing from meshyMeshes`);
    assert.ok(GEM_MESHES[n], `${n} missing classic fallback`);
  }
});

test("Meshy meshes are well-formed geometry", () => {
  for (const n of NAMES) {
    const m = MESHY_MESHES[n], verts = m.v.length / 3;
    assert.equal(m.v.length % 3, 0, n);
    assert.equal(m.n.length, m.v.length, `${n}: one normal per vertex`);
    assert.equal(m.t.length / 2, verts, `${n}: one uv per vertex`);
    assert.equal(m.i.length % 3, 0, n);
    assert.ok(m.i.every((i) => Number.isInteger(i) && i >= 0 && i < verts), `${n}: index out of range`);
    // a triangle with a repeated index is degenerate
    for (let k = 0; k < m.i.length; k += 3) assert.ok(m.i[k] !== m.i[k + 1] && m.i[k + 1] !== m.i[k + 2] && m.i[k] !== m.i[k + 2], `${n}: degenerate triangle ${k / 3}`);
    for (let k = 0; k < m.n.length; k += 3) {
      const l = Math.hypot(m.n[k], m.n[k + 1], m.n[k + 2]);
      assert.ok(Math.abs(l - 1) < 0.02, `${n}: normal ${k / 3} length ${l}`);
    }
    assert.ok(m.v.every(Number.isFinite) && m.t.every(Number.isFinite), `${n}: non-finite value`);
    // uvs stay in the atlas (extrapolation past an island edge is small, never a whole texture away)
    assert.ok(m.t.every((x) => x > -0.15 && x < 1.15), `${n}: uv far outside the texture`);
  }
});

test("bridge budget: a crystal costs about what a classic one does", () => {
  const classic = (n: string) => GEM_MESHES[n].reduce((a, p) => a + (p.v.length + p.n.length + p.v.length / 3), 0);
  const gems = NAMES.slice(0, 5);
  const avgMeshy = gems.reduce((a, n) => a + bridge(MESHY_MESHES[n]), 0) / gems.length;
  const avgClassic = gems.reduce((a, n) => a + classic(n), 0) / gems.length;
  assert.ok(avgMeshy <= avgClassic * 2.4, `plain gems average ${avgMeshy} numbers vs classic ${avgClassic}`);
  for (const n of gems) assert.ok(bridge(MESHY_MESHES[n]) <= 8000, `${n} sends ${bridge(MESHY_MESHES[n])} numbers`);
  // specials are one or two per board. Decimated triangles straddle many UV islands, so vertices split at island
  // edges (~1.7 per triangle); that is the real floor for these atlases, hence the higher ceiling
  for (const n of NAMES.slice(5)) assert.ok(bridge(MESHY_MESHES[n]) <= 13000, `${n} sends ${bridge(MESHY_MESHES[n])} numbers`);
  const tris = (n: string) => MESHY_MESHES[n].i.length / 3;
  for (const n of gems) assert.ok(tris(n) <= 400, `${n} has ${tris(n)} triangles`);
});

test("sizes match the classic meshes they replace (drop-in for GEM_SCALE) and stay centred", () => {
  const extent = (v: number[]) => [0, 1, 2].map((k) => { const xs = v.filter((_, i) => i % 3 === k); return [Math.min(...xs), Math.max(...xs)]; });
  for (const n of NAMES) {
    const e = extent(MESHY_MESHES[n].v), longest = Math.max(...e.map(([a, b]) => b - a));
    assert.ok(longest > 0.7 && longest < 1.9, `${n}: longest edge ${longest}`);
    for (const [a, b] of e) assert.ok(Math.abs((a + b) / 2) < 0.02, `${n}: not centred`);
  }
});

test("the aura ring's axis is local Z (the code yaws it onto the clear direction)", () => {
  const e = [0, 1, 2].map((k) => { const xs = MESHY_MESHES.surge_aura.v.filter((_, i) => i % 3 === k); return Math.max(...xs) - Math.min(...xs); });
  assert.ok(e[2] < e[0] * 0.3 && e[2] < e[1] * 0.3, `expected a ring in the XY plane, got extents ${e}`);
  assert.ok(Math.abs(e[0] - e[1]) < 0.15 * Math.max(e[0], e[1]), `expected a round ring, got ${e}`);
});
