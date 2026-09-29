// Tunes campaign move budgets: a greedy bot plays every generated level from many boards and we
// pick the budget that gives the target win rate for the level's difficulty.
// Usage: node scripts/tune-campaign.ts [from] [to] [runs]   → rewrites src/game/campaignTuning.ts
import { writeFileSync, readFileSync } from "node:fs";
import { findValidMoves } from "../src/game/board.ts";
import { buildCampaign, difficulty } from "../src/game/campaign.ts";
import { objectiveValue, playMove, startSession, type LevelDef, type Session } from "../src/game/level.ts";
import { createRng, nextFloat } from "../src/game/rng.ts";

const [from = 1, to = 200, runs = 24] = process.argv.slice(2).map(Number);
const CAP = 70;
// campaign numbers played with hand-authored levels (not generated)
const AUTHORED = new Set([1, 20, 21]);

/** Everything the bot values: objective progress, obstacle damage, relic depth, a little score. */
function potential(s: Session): number {
  const b = s.engine.board;
  let hp = 0, depth = 0;
  b.cells.forEach((c, i) => {
    if (c?.cover) hp += c.cover.hp;
    if (c?.special === "relic") depth += Math.floor(i / b.width);
  });
  for (const v of b.block ?? []) hp += v;
  for (const v of b.floor ?? []) hp += v;
  return objectiveValue(s) * 100 - hp * 12 + depth * 6 + s.score * 0.002;
}

function play(level: LevelDef, seed: number, botSeed: number): number {
  let s = startSession({ ...level, moves: CAP }, seed);
  const rng = createRng(botSeed);
  for (let used = 1; used <= CAP; used++) {
    const moves = findValidMoves(s.engine.board);
    if (!moves.length) return Infinity;
    let best = s, bestScore = -Infinity;
    for (const [a, b] of moves) {
      const r = playMove(s, a, b);
      if (!r.valid) continue;
      const v = potential(r.session) + nextFloat(rng) * 3;
      if (v > bestScore) {
        bestScore = v;
        best = r.session;
      }
    }
    s = best;
    if (s.status === "won") return used;
  }
  return Infinity;
}

const levels = buildCampaign();
const tuningPath = new URL("../src/game/campaignTuning.ts", import.meta.url);
const current: Record<number, number> = {};
for (const m of readFileSync(tuningPath, "utf8").matchAll(/^\s*(\d+): (\d+),/gm)) current[Number(m[1])] = Number(m[2]);

const report: string[] = [];
const t0 = Date.now();
for (const level of levels) {
  if (level.number < from || level.number > to || AUTHORED.has(level.number)) continue;
  const needed = Array.from({ length: runs }, (_, k) => play(level, level.seed + k * 7919, k + 1)).sort((a, b) => a - b);
  const d = difficulty(level.step);
  const target = 0.92 - 0.32 * d; // bot win rate: easy openers → hard finales
  const at = needed[Math.min(runs - 1, Math.ceil(target * runs) - 1)];
  const moves = Number.isFinite(at) ? Math.max(12, Math.min(40, at)) : 40;
  current[level.number] = moves;
  const winRate = needed.filter((n) => n <= moves).length / runs;
  report.push(`${String(level.number).padStart(3)} ${level.realm!.padEnd(8)} ${level.objective.kind.padEnd(7)} target ${String(level.objective.target).padStart(5)}  moves ${String(moves).padStart(2)}  bot win ${(winRate * 100).toFixed(0).padStart(3)}%  (goal ${(target * 100).toFixed(0)}%)  median ${needed[runs >> 1]}`);
  console.log(report.at(-1));
}

const body = Object.keys(current).map(Number).sort((a, b) => a - b).map((n) => `  ${n}: ${current[n]},`).join("\n");
writeFileSync(tuningPath, `// Move budgets per campaign level, written by scripts/tune-campaign.ts (a bot plays every level).
// Levels missing here fall back to the estimate in campaign.ts.
export const CAMPAIGN_MOVES: Record<number, number> = {
${body}
};
`);
console.log(`tuned ${report.length} levels in ${((Date.now() - t0) / 1000).toFixed(0)}s`);
