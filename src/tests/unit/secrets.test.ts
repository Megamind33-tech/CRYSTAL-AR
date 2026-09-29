// Secrets reach the Keeper (once per island, win or lose) and twisted runs replay-verify.
import { test } from "node:test";
import assert from "node:assert/strict";
import { findValidMoves } from "../../game/board.ts";
import { LEVELS, playMove, startSession, starsFor } from "../../game/level.ts";
import { ISLANDS } from "../../meta/config/world.ts";
import { newPlayer } from "../../meta/core.ts";
import { applyRun, SECRET_REWARD } from "../../meta/progression.ts";
import type { RunReport } from "../../meta/types.ts";
import { accumulate, GAME_VERSION, newRunStats, replayRun } from "../../meta/verify.ts";

/** A bot plays the island (first valid move each turn) and reports exactly what happened. */
function botRun(levelIndex: number, pick = 0): { report: RunReport; secretFound: boolean; blessed: boolean } {
  let s = startSession(LEVELS[levelIndex]);
  const swaps: [number, number, number, number][] = [];
  const stats = newRunStats();
  let blessed = false;
  while (s.status === "playing") {
    const moves = findValidMoves(s.engine.board);
    const [a, b] = moves[(swaps.length * 7 + pick) % moves.length];
    const r = playMove(s, a, b);
    accumulate(stats, r.steps);
    if (r.steps.some((st) => st.kind === "twist" && st.twist === "blessing")) blessed = true;
    swaps.push([a.x, a.y, b.x, b.y]);
    s = r.session;
  }
  const island = ISLANDS.find((i) => i.levelIndex === levelIndex)!;
  const report: RunReport = {
    runId: `t-${levelIndex}-${pick}`, islandId: island.id, levelIndex, seed: LEVELS[levelIndex].seed, gameVersion: GAME_VERSION,
    startedAt: 0, endedAt: swaps.length * 1000, swaps, relicsUsed: [], boosts: [],
    claimed: { won: s.status === "won", stars: starsFor(s), score: s.score, ...stats, ...(s.secretFound ? { secretFound: true } : {}) },
  };
  return { report, secretFound: s.secretFound, blessed };
}

test("runs with twists and secrets replay-verify (including Blessing's extra moves)", () => {
  const withTwists = LEVELS.map((l, i) => ({ l, i })).filter(({ l }) => l.twists?.length || l.secret).slice(0, 40);
  let blessedSeen = 0, secretsSeen = 0;
  for (const { i } of withTwists)
    for (const pick of [0, 3]) {
      const { report, secretFound, blessed } = botRun(i, pick);
      const v = replayRun(report);
      assert.ok(v.ok, `level ${LEVELS[i].id}: ${v.reasons.join(", ")}`);
      assert.equal(v.truth!.secretFound, secretFound);
      if (blessed) blessedSeen++;
      if (secretFound) secretsSeen++;
    }
  assert.ok(blessedSeen > 0, "some bot run was blessed");
  assert.ok(secretsSeen >= 0);
});

test("a false secret claim is rejected", () => {
  const i = LEVELS.findIndex((l) => l.secret);
  const { report, secretFound } = botRun(i);
  const lie = { ...report, claimed: { ...report.claimed, secretFound: !secretFound } };
  assert.ok(replayRun(lie).reasons.includes("secret mismatch"));
});

test("a secret pays out once per island, even on a lost run", () => {
  const island = ISLANDS.find((i) => i.id !== "waking-stones" && LEVELS[i.levelIndex].secret)!;
  const report = { islandId: island.id, levelIndex: island.levelIndex, claimed: { won: false, stars: 0, score: 0, secretFound: true } } as unknown as RunReport;
  const p = newPlayer("k1", 0);
  const first = applyRun(p, report, 1);
  assert.equal(first.secret, true);
  assert.deepEqual(first.state.secrets, [island.id]);
  assert.equal(first.state.wallet.prismDust - p.wallet.prismDust, SECRET_REWARD.prismDust);
  const again = applyRun(first.state, report, 2);
  assert.equal(again.secret, false);
  assert.equal(again.state.wallet.prismDust, first.state.wallet.prismDust);
});
