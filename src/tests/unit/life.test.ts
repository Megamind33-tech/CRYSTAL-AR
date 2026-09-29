// The living environment (render/island/life.ts) is data + placement; these checks keep every realm alive, keep the
// creatures where the camera can see them, and make sure everything the renderer needs is registered.
import { test } from "node:test";
import assert from "node:assert/strict";
import { BIOMES } from "../../render/island/biomes.ts";
import { EXCITED_MS, LIFE, lifeMaterial, lifeMaterialSet, ORBIT_MS, placeCritters, TINTS } from "../../render/island/life.ts";

test("every realm has creatures, and only realms that exist", () => {
  assert.deepEqual(Object.keys(LIFE).sort(), Object.keys(BIOMES).sort());
  for (const realm of Object.keys(BIOMES)) assert.ok(placeCritters(realm).length >= 5, `${realm} feels empty`);
});

test("laps use registered orbit animations, and excited laps are never slower", () => {
  for (const list of Object.values(LIFE)) for (const c of list) {
    assert.ok((ORBIT_MS as readonly number[]).includes(c.lap), `lap ${c.lap} has no orbit animation`);
    assert.ok(EXCITED_MS[c.lap] !== undefined && (ORBIT_MS as readonly number[]).includes(EXCITED_MS[c.lap]) && EXCITED_MS[c.lap] <= c.lap);
    assert.ok(c.tint >= 0 && c.tint < TINTS.length);
  }
});

test("creatures stay where the tabletop camera sees them (not sweeping past it or under the sea)", () => {
  for (const realm of Object.keys(BIOMES)) for (const c of placeCritters(realm)) {
    assert.ok(c.r > 0.05 && c.r <= 0.65, `${c.key} orbits at ${c.r}`);
    assert.ok(c.y > 0 && c.y < 0.5, `${c.key} flies at height ${c.y}`);
    assert.ok(c.size >= 0.02 && c.size <= 0.16, `${c.key} is ${c.size} m`);
    assert.ok(c.delay >= 0 && c.delay < c.lap * 2);
  }
});

test("placement is deterministic and gives unique keys", () => {
  for (const realm of Object.keys(BIOMES)) {
    const a = placeCritters(realm), b = placeCritters(realm);
    assert.deepEqual(a, b);
    assert.equal(new Set(a.map((c) => c.key)).size, a.length);
  }
});

test("few fast flappers (240 ms beat) and a bounded number of slow pulsers (1.45 s beat)", () => {
  for (const realm of Object.keys(BIOMES)) {
    const all = placeCritters(realm);
    assert.ok(all.filter((c) => c.flap && c.sprite === "butterfly").length <= 9, `${realm} has too many fast flappers`);
    assert.ok(all.filter((c) => c.flap && c.sprite !== "butterfly").length <= 14, `${realm} has too many pulsers`);
  }
});

test("materials: each used (sprite, tint) has a unique name and the set is small", () => {
  const set = lifeMaterialSet();
  assert.equal(new Set(set.map((m) => lifeMaterial(m.sprite, m.tint))).size, set.length);
  assert.ok(set.length <= 24, `${set.length} materials registered at boot`);
});
