// The 200-level campaign: every level builds, is playable from its first move, and is deterministic.
import { test } from "node:test";
import assert from "node:assert/strict";
import { findMatches, hasValidMove, isSolid } from "../../game/board.ts";
import { buildCampaign, buildCampaignLevel, CAMPAIGN_REALMS, LEVELS_PER_REALM } from "../../game/campaign.ts";
import { startSession } from "../../game/level.ts";

const ALL = buildCampaign();

test("200 levels in 10 realms of 20, uniquely named", () => {
  assert.equal(ALL.length, 200);
  assert.equal(CAMPAIGN_REALMS.length * LEVELS_PER_REALM, 200);
  assert.equal(new Set(ALL.map((l) => l.name)).size, 200);
  for (const l of ALL) assert.equal(l.realm, CAMPAIGN_REALMS[l.realmIndex].id);
});

test("levels are deterministic", () => {
  const a = buildCampaignLevel(137), b = buildCampaignLevel(137);
  assert.deepEqual({ ...a, name: "" }, { ...b, name: "" });
});

test("every level starts on a stable, playable board", () => {
  for (const l of ALL) {
    const s = startSession(l);
    const b = s.engine.board;
    assert.equal(findMatches(b).length, 0, `level ${l.number} starts with a match`);
    assert.ok(hasValidMove(b), `level ${l.number} has no opening move`);
    for (let i = 0; i < b.cells.length; i++) {
      const x = i % 6, y = Math.floor(i / 6);
      if (isSolid(b, x, y)) assert.equal(b.cells[i], null, `level ${l.number}: crystal inside a solid cell`);
    }
    assert.ok(l.objective.target > 0, `level ${l.number} has an empty objective`);
    assert.ok(l.moves >= 10 && l.moves <= 45, `level ${l.number} moves ${l.moves}`);
  }
});

test("each realm teaches its mechanic", () => {
  const realm = (i: number) => ALL.filter((l) => l.realmIndex === i);
  assert.ok(realm(1).every((l) => (l.gravityCharges ?? 0) > 0), "canyon levels grant Gravity Charges");
  assert.ok(realm(2).every((l) => l.objective.kind === "cover" && l.objective.cover === "ice"));
  assert.ok(realm(3).every((l) => l.objective.kind === "stone" && (l.setup?.blocks?.length ?? 0) > 0));
  assert.ok(realm(4).every((l) => l.creep?.cover === "vine"));
  assert.ok(realm(5).every((l) => l.objective.kind === "rune"));
  assert.ok(realm(6).every((l) => l.setup?.covers?.some((c) => c[2] === "chain")));
  assert.ok(realm(7).every((l) => l.objective.kind === "relic"));
  assert.ok(realm(8).every((l) => l.creep?.cover === "ember"));
  const voidKinds = new Set(realm(9).map((l) => l.objective.kind + (l.creep ? "+creep" : "")));
  assert.ok(voidKinds.size >= 4, "the Void Spire mixes mechanics");
});

test("cover objectives never ask for more than the board can hold", () => {
  for (const l of ALL) {
    if (l.objective.kind !== "cover") continue;
    const own = l.setup!.covers!.filter((c) => c[2] === (l.objective as { cover: string }).cover).length;
    assert.equal(l.objective.target, own, `level ${l.number}`);
  }
});
