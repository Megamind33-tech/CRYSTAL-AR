// Anti-cheat. The match engine is deterministic, so the authority replays seed + swap list and compares
// every claimed number. Local validation is for honest-client UX only – it is NOT security: the real
// checks (signature with a server-held key, duplicate run IDs, trial windows) must run on the backend.
import { extendMoves, LEVELS, playMove, startSession, starsFor } from "../game/level.ts";
import { ECONOMY } from "./config/live.ts";
import { trialDef, trialInstances } from "./competition.ts";
import { hash } from "./core.ts";
import { RELICS } from "./config/collection.ts";
import type { RunReport } from "./types.ts";
import type { ResolveStep } from "../game/types.ts";

/** Run statistics derived from engine steps – shared by the game controller and the replay verifier. */
export const newRunStats = () => ({ resonance: 0, matches: 0, cascades: 0, bestCascade: 0, specialsCreated: 0, specialsActivated: 0, combos: 0, crystalsCleared: 0, blueCleared: 0 });
export type RunStats = ReturnType<typeof newRunStats>;
export function accumulate(acc: RunStats, steps: ResolveStep[]) {
  for (const st of steps) {
    if (st.kind !== "clear") continue;
    acc.matches += st.groups.length || 1;
    if (st.cascade > 1) acc.cascades++;
    acc.bestCascade = Math.max(acc.bestCascade, st.cascade);
    acc.specialsCreated += st.created.length;
    acc.specialsActivated += st.activated.length;
    if (st.combo) acc.combos++;
    acc.crystalsCleared += st.cleared.length;
    acc.blueCleared += st.cleared.filter((c) => c.type === 1).length;
    acc.resonance += st.cleared.length * 10 * st.cascade;
  }
  return acc;
}

export const GAME_VERSION = "0.3.0";
export const MIN_MS_PER_SWAP = 250;

export interface Verdict {
  ok: boolean;
  reasons: string[];
  /** recomputed truth, used instead of the client's numbers */
  truth?: { won: boolean; stars: number; score: number };
}

/** Replays a run and compares every claim. Used by the mock backend and (later) the real server. */
export function replayRun(r: RunReport, opts: { moves?: number } = {}): Verdict {
  const reasons: string[] = [];
  const base = LEVELS[r.levelIndex];
  if (!base) return { ok: false, reasons: ["unknown level"] };
  const level = opts.moves ? { ...base, moves: opts.moves } : base;
  const stabs = Math.min(r.stabilizations ?? 0, ECONOMY.stabilize.perRunLimit);
  if ((r.stabilizations ?? 0) > ECONOMY.stabilize.perRunLimit) reasons.push("too many stabilizations");
  if (r.swaps.length > level.moves + stabs * ECONOMY.stabilize.moves) reasons.push("more swaps than moves allowed");
  const duration = r.endedAt - r.startedAt;
  if (duration < r.swaps.length * MIN_MS_PER_SWAP) reasons.push("swaps faster than humanly possible");
  if (r.endedAt < r.startedAt) reasons.push("clock went backwards");
  let s = startSession(level, r.seed);
  const acc = newRunStats();
  let used = 0;
  for (const [ax, ay, bx, by] of r.swaps) {
    const m = playMove(s, { x: ax, y: ay }, { x: bx, y: by });
    if (!m.valid) {
      reasons.push("invalid swap in log");
      break;
    }
    accumulate(acc, m.steps);
    s = m.session;
    if (s.status === "lost" && used < stabs) {
      s = extendMoves(s, ECONOMY.stabilize.moves);
      used++;
    }
  }
  const { resonance, matches, cascades, bestCascade, specialsCreated: created, specialsActivated: activated, combos, crystalsCleared: cleared, blueCleared: blue } = acc;
  const truth = { won: s.status === "won", stars: starsFor(s), score: s.score };
  const c = r.claimed;
  if (c.score !== truth.score) reasons.push(`score ${c.score} ≠ replay ${truth.score}`);
  if (c.won !== truth.won) reasons.push("outcome mismatch");
  if (c.stars !== truth.stars) reasons.push("stars mismatch");
  if (c.resonance !== resonance) reasons.push("resonance mismatch");
  if (c.bestCascade !== bestCascade) reasons.push("cascade mismatch");
  if (c.crystalsCleared !== cleared || c.blueCleared !== blue) reasons.push("cleared-count mismatch");
  if (c.matches !== matches || c.cascades !== cascades || c.specialsCreated !== created || c.specialsActivated !== activated || c.combos !== combos) {
    reasons.push("match statistics mismatch");
  }
  return { ok: reasons.length === 0, reasons, truth };
}

/** Additional rules for ranked Realm Trial submissions. */
export function verifyTrialRun(r: RunReport, now: number): Verdict {
  const inst = trialInstances(r.endedAt).find((i) => i.instanceId === r.trialInstanceId);
  if (!inst) return { ok: false, reasons: ["trial instance not open"] };
  const def = trialDef(inst.trialId)!;
  const reasons: string[] = [];
  if (r.seed !== inst.seed) reasons.push("seed does not match the trial board");
  if (r.levelIndex !== def.levelIndex) reasons.push("wrong trial level");
  if (r.startedAt < inst.opensAt || r.endedAt > inst.closesAt || now > inst.closesAt + 5 * 60000) reasons.push("outside trial window");
  for (const relic of r.relicsUsed) {
    if (!def.approvedRelics.includes(relic) || !RELICS.find((x) => x.id === relic)?.trialApproved) reasons.push(`relic ${relic} not approved`);
  }
  if (def.timeLimitSec && r.endedAt - r.startedAt > def.timeLimitSec * 1000 + 3000) reasons.push("time limit exceeded");
  if (r.buildFlags?.debug || r.buildFlags?.emulator) reasons.push("debug/emulator builds are unranked");
  const replay = replayRun(r, { moves: def.moves });
  return { ok: reasons.length === 0 && replay.ok, reasons: [...reasons, ...replay.reasons], truth: replay.truth };
}

/**
 * Submission envelope. `sign` is a mock HMAC stand-in: the real key must live on the server / in a
 * platform attestation flow (Play Integrity). Never ship a secret in the client and call it secure.
 */
export function canonical(r: RunReport) {
  return JSON.stringify([r.runId, r.islandId, r.levelIndex, r.seed, r.gameVersion, r.startedAt, r.endedAt, r.swaps, r.relicsUsed, r.claimed, r.trialInstanceId ?? null]);
}
export const mockSign = (r: RunReport, key: string) => (hash(key + canonical(r)) >>> 0).toString(16);

/** Builds the report the game controller hands to the meta layer after a run. */
export function makeRunId(keeperId: string, startedAt: number, seed: number) {
  return `${keeperId}-${startedAt.toString(36)}-${(hash(keeperId + startedAt + seed) >>> 0).toString(36)}`;
}
