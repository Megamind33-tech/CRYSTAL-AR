// The baked Meshy islands (src/render/meshyIslands) feed ViroGeometry directly and must fit the board: the dais top
// is at SURFACE_Y with terrain below it, the numbers are finite, and the geometry stays inside the bridge budget.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DAIS, SURFACE_Y as ISLAND_SURFACE, buildDais } from "../../render/island/buildIsland.ts";
import { BIOMES } from "../../render/island/biomes.ts";
import { SURFACE_Y } from "../../render/layout.ts";
import { MESHY_ISLAND_REALMS, meshyIsland } from "../../render/meshyIslands/index.ts";

test("every realm has a baked Meshy island", () => {
  assert.deepEqual([...MESHY_ISLAND_REALMS].sort(), Object.keys(BIOMES).sort());
});

test("the bake script's dais numbers match the runtime's", () => {
  const src = readFileSync(new URL("../../../tools/asset-pipeline/bake-islands.mjs", import.meta.url), "utf8");
  const m = src.match(/const DAIS = \{ halfX: ([\d.]+), zMin: (-?[\d.]+), zMax: ([\d.]+) \}/)!;
  assert.deepEqual([Number(m[1]), Number(m[2]), Number(m[3])], [DAIS.halfX, DAIS.zMin, DAIS.zMax]);
  assert.equal(Number(src.match(/const SURFACE_Y = ([\d.]+)/)![1]), ISLAND_SURFACE);
  assert.equal(ISLAND_SURFACE, SURFACE_Y, "buildIsland and layout must agree on the surface height");
});

for (const realm of Object.keys(BIOMES)) {
  test(`${realm}: island geometry is well-formed and within the bridge budget`, () => {
    const isl = meshyIsland(realm)!;
    for (const [lod, cap] of [["hero", 90000], ["far", 16000]] as const) {
      const m = isl[lod], verts = m.v.length / 3;
      assert.equal(m.n.length, m.v.length, `${lod}: one normal per vertex`);
      assert.equal(m.t.length / 2, verts, `${lod}: one uv per vertex`);
      assert.equal(m.i.length % 3, 0);
      assert.ok(m.v.every(Number.isFinite) && m.n.every(Number.isFinite) && m.t.every(Number.isFinite), `${lod}: non-finite value`);
      assert.ok(m.i.every((i) => Number.isInteger(i) && i >= 0 && i < verts), `${lod}: index out of range`);
      for (let k = 0; k < m.n.length; k += 3) assert.ok(Math.abs(Math.hypot(m.n[k], m.n[k + 1], m.n[k + 2]) - 1) < 0.03, `${lod}: normal ${k / 3} not unit`);
      assert.ok(m.v.length + m.n.length + m.t.length + m.i.length <= cap, `${lod} sends ${m.v.length + m.n.length + m.t.length + m.i.length} numbers (cap ${cap})`);
    }
  });

  test(`${realm}: terrain sits under the dais and the dais covers what is left`, () => {
    const isl = meshyIsland(realm)!, v = isl.hero.v;
    let over = 0;
    for (let k = 0; k < v.length; k += 3) {
      const inside = Math.abs(v[k]) < DAIS.halfX && v[k + 2] > DAIS.zMin && v[k + 2] < DAIS.zMax;
      if (inside && v[k + 1] > SURFACE_Y - 0.001) over++;
    }
    assert.equal(over, 0, "terrain vertices poke through the dais top");
    assert.ok(isl.bottomY < SURFACE_Y - 0.01 && isl.bottomY > -0.4, `dais bottom ${isl.bottomY}`);
    const dais = buildDais(BIOMES[realm], 1, isl.bottomY);
    assert.equal(dais.length, 1);
    assert.ok(dais[0].vertices.flat().every(Number.isFinite));
  });
}
