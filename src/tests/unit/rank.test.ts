// Keeper Rank: breadth beats grinding one thing.
import { test } from "node:test";
import assert from "node:assert/strict";
import { ISLANDS } from "../../meta/config/world.ts";
import { newPlayer } from "../../meta/core.ts";
import { keeperRank, RANKS } from "../../meta/rank.ts";
import type { PlayerState } from "../../meta/types.ts";

const fresh = () => newPlayer("k", 0);

test("a new Keeper is a Seeker", () => {
  assert.equal(keeperRank(fresh()).name, "Seeker");
});

test("maximum XP alone does not climb past the lower ranks", () => {
  const p: PlayerState = { ...fresh(), keeperXp: 1e9 };
  assert.ok(keeperRank(p).index <= 1, keeperRank(p).name);
});

test("restoring every island alone does not reach the top ranks", () => {
  const p = fresh();
  for (const i of ISLANDS) p.islands[i.id] = { stars: 3, bestScore: 1, restoredAt: 0 };
  const r = keeperRank(p);
  assert.ok(r.index >= 2 && r.index <= 4, r.name);
});

test("broad mastery reaches Eternal Keeper, and ranks are ordered", () => {
  const p = fresh();
  for (const i of ISLANDS) p.islands[i.id] = { stars: 3, bestScore: 1, restoredAt: 0 };
  p.secrets = ISLANDS.slice(0, 150).map((i) => i.id);
  p.heartShards = Array.from({ length: 11 }, (_, i) => `s${i}`);
  p.memories = Array.from({ length: 12 }, (_, i) => `m${i}`);
  p.keeperXp = 1e9;
  for (let i = 0; i < 40; i++) p.lumins[`l${i}`] = { bond: 1, rescuedAt: 0 };
  for (let i = 0; i < 40; i++) p.relics[`r${i}`] = { level: 1 } as never;
  Object.assign(p.stats, { trialPoints: 20000, trialsWon: 200, checkins: 900, dutiesCompleted: 2000, bestCascade: 30, combos: 3000, specialsActivated: 20000 });
  assert.equal(keeperRank(p).name, RANKS[7]);
});

test("the next-rank hint points somewhere useful", () => {
  const r = keeperRank(fresh());
  assert.match(r.next, /Pathfinder/);
});
