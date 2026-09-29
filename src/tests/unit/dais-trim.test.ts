import { test } from "node:test";
import assert from "node:assert/strict";
import { DAIS, PORTAL_CENTER } from "../../render/island/buildIsland.ts";
import { trimDashes } from "../../render/island/daisTrimLayout.ts";
import { BIOMES } from "../../render/island/biomes.ts";

test("every trim dash lies on the dais and clear of the portal", () => {
  const { dashes, studs } = trimDashes();
  assert.ok(dashes.length >= 12, `only ${dashes.length} dashes`);
  for (const d of dashes) {
    assert.ok(Math.abs(d.x) + d.w / 2 <= DAIS.halfX && d.z + d.h / 2 <= DAIS.zMax && d.z - d.h / 2 >= DAIS.zMin, "dash off the dais");
    assert.ok(Math.hypot(d.x - PORTAL_CENTER[0], d.z - PORTAL_CENTER[2]) > 0.09, "dash under the portal arch");
  }
  for (const [x, z] of studs) assert.ok(Math.abs(x) <= DAIS.halfX && z >= DAIS.zMin && z <= DAIS.zMax);
});

test("dashes do not overlap each other", () => {
  const { dashes } = trimDashes();
  for (let i = 0; i < dashes.length; i++) for (let j = i + 1; j < dashes.length; j++) {
    const a = dashes[i], b = dashes[j];
    const overlap = Math.abs(a.x - b.x) < (a.w + b.w) / 2 && Math.abs(a.z - b.z) < (a.h + b.h) / 2;
    assert.ok(!overlap, `dashes ${i} and ${j} overlap`);
  }
});

test("every realm has a glow colour for its trim", () => {
  for (const b of Object.values(BIOMES)) assert.match(b.glow, /^#[0-9a-f]{6}$/i, b.id);
});
