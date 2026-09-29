import assert from "node:assert/strict";
import { test } from "node:test";
import { applyBoostsToLevel, BOOSTS, BOOST_IDS, boostEffects, invalidLoadout, type BoostId } from "../../game/boosts.ts";
import { findValidMoves } from "../../game/board.ts";
import { LEVELS, playMove, startBoostedSession, startSession, starsFor } from "../../game/level.ts";
import { buyBoost, coinsForRun, consumeBoosts, newPlayer, normalizePlayer } from "../../meta/core.ts";
import { accumulate, GAME_VERSION, newRunStats, replayRun } from "../../meta/verify.ts";
import type { RunReport } from "../../meta/types.ts";

const T0 = Date.UTC(2026, 8, 22, 12);

function playRun(boosts: BoostId[], levelIndex = 0, seed = 1101): RunReport {
  const base = LEVELS[levelIndex];
  const start = startBoostedSession(base, seed, boosts);
  let s = start.session;
  const acc = newRunStats();
  accumulate(acc, start.steps);
  const swaps: [number, number, number, number][] = [];
  while (s.status === "playing") {
    const mv = findValidMoves(s.engine.board)[0];
    if (!mv) break;
    const r = playMove(s, mv[0], mv[1]);
    assert.ok(r.valid);
    accumulate(acc, r.steps);
    swaps.push([mv[0].x, mv[0].y, mv[1].x, mv[1].y]);
    s = r.session;
  }
  return {
    runId: "boost-" + boosts.join("+"), islandId: "waking-stones", levelIndex, seed, gameVersion: GAME_VERSION,
    startedAt: T0, endedAt: T0 + swaps.length * 2000, swaps, relicsUsed: [], boosts: [], ...(boosts.length ? { equipped: boosts } : {}),
    claimed: { won: s.status === "won", stars: starsFor(s), score: s.score, ...acc, ...(s.secretFound ? { secretFound: true } : {}) },
  } as RunReport;
}

test("boost effects are exact and stack", () => {
  assert.deepEqual(boostEffects([]), { extraMoves: 0, scoreMultiplier: 1, startSurges: 0, startingClears: 0, startCharge: 0 });
  const e = boostEffects(["moves_plus_5", "moves_plus_10", "gem_multiplier", "surge_rate_up", "starting_clears"]);
  assert.deepEqual(e, { extraMoves: 15, scoreMultiplier: 1.25, startSurges: 2, startingClears: 2, startCharge: 0 });
  assert.equal(BOOST_IDS.length, Object.keys(BOOSTS).length);
});

test("extra moves and the score multiplier reach the session", () => {
  const base = LEVELS[0];
  assert.equal(applyBoostsToLevel(base, ["moves_plus_10"]).moves, base.moves + 10);
  const plain = startSession(base, 1101);
  const { session } = startBoostedSession(base, 1101, ["gem_multiplier"]);
  const mv = findValidMoves(plain.engine.board)[0];
  const a = playMove(plain, mv[0], mv[1]).session.score;
  const b = playMove(session, mv[0], mv[1]).session.score;
  assert.equal(b, Math.round(a * 1.25));
});

test("Surge Rush forges two surges, Board Prep clears for free", () => {
  const surged = startBoostedSession(LEVELS[0], 1101, ["surge_rate_up"]).session;
  assert.equal(surged.engine.board.cells.filter((c) => c && (c.special === "surgeH" || c.special === "surgeV")).length, 2);
  const prep = startBoostedSession(LEVELS[0], 1101, ["starting_clears"]);
  assert.ok(prep.steps.length > 0);
  assert.ok(prep.session.score > 0, "free matches score");
  assert.equal(prep.session.movesLeft, LEVELS[0].moves, "and cost no moves");
  assert.equal(prep.session.movesMade, 0);
});

test("boosted runs replay-verify; forged loadouts do not", () => {
  const all: BoostId[] = ["moves_plus_5", "gem_multiplier", "starting_clears"];
  for (const set of [[], ["moves_plus_10"], ["surge_rate_up"], all, ["score_x15", "surge_four", "prep_four"], ["charge_start", "moves_plus_3"]] as BoostId[][]) {
    const r = playRun(set);
    const v = replayRun(r);
    assert.ok(v.ok, `${set.join("+") || "none"}: ${v.reasons.join(", ")}`);
  }
  const r = playRun(["gem_multiplier"]);
  assert.equal(replayRun({ ...r, equipped: [] }).ok, false, "score claim without the boost");
  assert.equal(replayRun({ ...r, equipped: ["nope"] }).ok, false, "unknown boost");
  assert.equal(replayRun({ ...r, equipped: ["moves_plus_5", "moves_plus_5"] }).ok, false, "duplicate boost");
  assert.equal(invalidLoadout(["moves_plus_5", "moves_plus_10", "gem_multiplier", "surge_rate_up"]) !== null, true, "over the slot limit");
});

test("buying and using boosts moves coins and inventory correctly", () => {
  let p = newPlayer("k", T0);
  assert.equal(p.wallet.coins, 500);
  const bought = buyBoost(p, "moves_plus_5");
  assert.ok(bought.ok);
  if (!bought.ok) return;
  assert.equal(bought.state.wallet.coins, 250);
  assert.equal(bought.state.items.moves_plus_5, 1);
  p = bought.state;
  assert.equal(buyBoost({ ...p, wallet: { ...p.wallet, coins: 10 } }, "moves_plus_5").ok, false, "too poor");
  assert.equal(consumeBoosts(p, ["gem_multiplier"]).ok, false, "not owned");
  const used = consumeBoosts(p, ["moves_plus_5"]);
  assert.ok(used.ok);
  if (used.ok) assert.equal(used.state.items.moves_plus_5, 0);
  assert.ok(coinsForRun(true, 3) > coinsForRun(true, 1) && coinsForRun(true, 1) > coinsForRun(false, 0));
});

test("old saves gain coins and boost counts without losing anything", () => {
  const p = newPlayer("k", T0);
  const old = structuredClone(p) as typeof p;
  delete (old.wallet as Record<string, number>).coins;
  delete (old.items as Record<string, number>).moves_plus_5;
  old.wallet.prismDust = 999;
  const n = normalizePlayer(old);
  assert.equal(n.wallet.coins, 500);
  assert.equal(n.items.moves_plus_5, 0);
  assert.equal(n.wallet.prismDust, 999);
});

test("Portal Spark stores 25 energy up front and it counts", () => {
  assert.equal(startBoostedSession(LEVELS[0], 1101, ["charge_start"]).session.charge, 25);
  assert.equal(startBoostedSession(LEVELS[0], 1101, []).session.charge, 0);
  assert.equal(startBoostedSession(LEVELS[0], 1101, ["prep_four"]).steps.length >= startBoostedSession(LEVELS[0], 1101, ["starting_clears"]).steps.length, true);
});
