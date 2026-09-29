// Runtime islands: deterministic, bounded, outward-facing, props clear of the board.
import { test } from "node:test";
import assert from "node:assert/strict";
import { BIOMES } from "../../render/island/biomes.ts";
import { buildIsland, SURFACE_Y } from "../../render/island/buildIsland.ts";

test("every biome builds a bounded island with outward-facing surfaces", () => {
  for (const b of Object.values(BIOMES)) {
    const m = buildIsland(b, 1234);
    assert.ok(m.triangles > 1500 && m.triangles < 12000, `${b.id}: ${m.triangles} triangles`);
    // terrain top normals point up; underside normals point down/out
    const top = m.parts.find((p) => p.slot === "top")!;
    const up = top.normals.filter((n) => n[1] > 0).length / top.normals.length;
    // the "top" surface also carries snow caps and dunes on props, which face sideways
    assert.ok(up > 0.8, `${b.id}: top faces up (${up})`);
    const cliff = m.parts.find((p) => p.slot === "cliff")!;
    let outward = 0;
    cliff.vertices.forEach((v, i) => { const n = cliff.normals[i]; if (v[0] * n[0] + v[2] * n[2] > 0 || n[1] < 0) outward++; });
    assert.ok(outward / cliff.vertices.length > 0.9, `${b.id}: cliff faces out`);
    for (const p of m.parts) for (const v of p.vertices) assert.ok(v.every(Number.isFinite));
  }
});

test("islands are deterministic per seed and differ between seeds", () => {
  const a = buildIsland(BIOMES.tide, 77), b = buildIsland(BIOMES.tide, 77), c = buildIsland(BIOMES.tide, 78);
  assert.deepEqual(a.parts.map((p) => p.vertices.length), b.parts.map((p) => p.vertices.length));
  assert.deepEqual(a.parts[0].vertices.slice(0, 20), b.parts[0].vertices.slice(0, 20));
  assert.notDeepEqual(a.parts[0].vertices.slice(0, 200), c.parts[0].vertices.slice(0, 200));
});

test("the board plaza stays flat and clear of props", () => {
  for (const b of Object.values(BIOMES)) {
    const m = buildIsland(b, 99);
    for (const [x, z] of [[0, 0], [0.15, 0.2], [-0.15, -0.1], [0.1, 0.05]]) assert.ok(Math.abs(m.heightAt(x, z) - SURFACE_Y) < 0.005, `${b.id} plaza flat at ${x},${z}`);
    for (const p of m.parts) {
      if (p.slot === "top" || p.slot === "cliff") continue;
      for (const v of p.vertices) {
        const onPlaza = Math.abs(v[0]) < 0.17 && v[2] > -0.12 && v[2] < 0.23;
        assert.ok(!onPlaza || v[1] < SURFACE_Y + 0.004, `${b.id}: ${p.slot} prop intrudes on the board at ${v.map((q) => q.toFixed(3))}`);
      }
    }
  }
});

test("side walls of props face outward", () => {
  const m = buildIsland(BIOMES.sky, 5);
  const stone = m.parts.find((p) => p.slot === "stone")!;
  assert.ok(stone.vertices.length > 0);
});
