import { cloneState, createEngine, parseMask, reshuffle, type EngineState } from "./board.ts";
import { rotatedGravity, shiftGravity, trySwap } from "./resolve.ts";
import { createRng } from "./rng.ts";
import type { CrystalType, Gravity, Pos, ResolveStep } from "./types.ts";

export type Objective =
  | { kind: "power"; target: number } // charge the portal with crystal energy
  | { kind: "score"; target: number }
  | { kind: "collect"; crystal: CrystalType; target: number };

export interface LevelDef {
  id: number;
  name: string;
  seed: number;
  moves: number;
  objective: Objective;
  /** board shape: rows of O (playable) / X (void terrain). Omit for a full 6×6. */
  mask?: string[];
  /** Gravity Charges at the start (0 = no Gravity Shift on this level). Max 3. */
  gravityCharges?: number;
  /** spawn weight per crystal kind (default 1 each) */
  spawnWeights?: number[];
}

export const MAX_GRAVITY_CHARGES = 3;

export const LEVELS: LevelDef[] = [
  { id: 1, name: "Waking Stones", seed: 1101, moves: 20, objective: { kind: "power", target: 170 } },
  // HERO LEVEL: irregular canyon board; sheltered pockets under the ruins only fill via Gravity Shift
  {
    id: 2, name: "Emerald Canyon", seed: 2207, moves: 22, gravityCharges: 2, spawnWeights: [1, 1, 1.6, 1, 1],
    objective: { kind: "collect", crystal: 2, target: 32 },
    // two sheltered pockets: under the ruin pillar (column 3) and the left cliff (column 0)
    mask: ["OOOOOO", "OOOXOO", "OOOXOO", "XOOOOO", "OOXOOO", "OOXOOO"],
  },
  { id: 3, name: "Heart of the Falls", seed: 3313, moves: 18, objective: { kind: "score", target: 5600 } },
  // discovery / seasonal / expedition islands (meta-game content)
  { id: 4, name: "Hollow of Lanterns", seed: 4421, moves: 18, objective: { kind: "collect", crystal: 4, target: 30 } },
  { id: 5, name: "Eclipse Threshold", seed: 5527, moves: 16, objective: { kind: "power", target: 190 } },
  { id: 6, name: "Frostbound Signal", seed: 6637, moves: 18, objective: { kind: "collect", crystal: 1, target: 34 } },
];

export type SessionStatus = "playing" | "won" | "lost";

export interface Session {
  level: LevelDef;
  engine: EngineState;
  score: number;
  movesLeft: number;
  charge: number;
  collected: number[];
  status: SessionStatus;
  bestCascade: number;
  gravityCharges: number;
}

export function startSession(level: LevelDef, seedOverride?: number): Session {
  return {
    level,
    engine: createEngine(6, 6, 5, createRng(seedOverride ?? level.seed), parseMask(level.mask, 6, 6), level.spawnWeights),
    score: 0,
    movesLeft: level.moves,
    charge: 0,
    collected: [0, 0, 0, 0, 0],
    status: "playing",
    bestCascade: 0,
    gravityCharges: Math.min(MAX_GRAVITY_CHARGES, level.gravityCharges ?? 0),
  };
}

/** Portal energy granted by a clear step: crystals, specials and cascades all feed the portal. */
export function chargeForStep(step: Extract<ResolveStep, { kind: "clear" }>): number {
  return step.cleared.length + step.created.length * 3 + step.activated.length * 2 + (step.cascade - 1) * 2;
}

/** 0..1 progress toward the level objective. Drives the world's evolution stages. */
export function objectiveProgress(s: Session): number {
  const o = s.level.objective;
  const v = o.kind === "power" ? s.charge : o.kind === "score" ? s.score : s.collected[o.crystal];
  return Math.min(1, v / o.target);
}

export interface MoveResult {
  valid: boolean;
  session: Session;
  steps: ResolveStep[];
}

export function playMove(s: Session, a: Pos, b: Pos): MoveResult {
  if (s.status !== "playing") return { valid: false, session: s, steps: [] };
  const r = trySwap(s.engine, a, b);
  if (!r.valid) return { valid: false, session: s, steps: r.steps };

  const next: Session = {
    ...s,
    engine: r.state,
    movesLeft: s.movesLeft - 1,
    collected: s.collected.slice(),
  };
  account(next, r.steps);
  if (objectiveProgress(next) >= 1) next.status = "won";
  else if (next.movesLeft <= 0) next.status = "lost";
  return { valid: true, session: next, steps: r.steps };
}

/** Score, portal charge, collection and Gravity Charge recharge from resolved steps. */
function account(next: Session, steps: ResolveStep[]) {
  for (const step of steps) {
    if (step.kind !== "clear") continue;
    next.score += step.score;
    next.charge += chargeForStep(step);
    next.bestCascade = Math.max(next.bestCascade, step.cascade);
    for (const c of step.cleared) next.collected[c.type]++;
    // forging a Prism or fusing specials recharges the tabletop (only on levels that use it)
    if (next.level.gravityCharges && (step.combo || step.created.some((c) => c.special === "prism"))) {
      next.gravityCharges = Math.min(MAX_GRAVITY_CHARGES, next.gravityCharges + 1);
    }
  }
}

/**
 * GRAVITY SHIFT: turn the tabletop one step. Costs a Gravity Charge, not a move.
 * turn -1 = counter-clockwise (gravity toward the left side), +1 = clockwise (toward the right).
 */
export function playShift(s: Session, turn: -1 | 1): MoveResult & { gravity?: Gravity } {
  if (s.status !== "playing" || s.gravityCharges <= 0) return { valid: false, session: s, steps: [] };
  const to = rotatedGravity(s.engine.gravity, turn);
  if (!to) return { valid: false, session: s, steps: [] };
  const r = shiftGravity(s.engine, to);
  if (!r.valid) return { valid: false, session: s, steps: [] };
  const next: Session = { ...s, engine: r.state, gravityCharges: s.gravityCharges - 1, collected: s.collected.slice() };
  account(next, r.steps);
  if (objectiveProgress(next) >= 1) next.status = "won";
  return { valid: true, session: next, steps: r.steps, gravity: to };
}

/** Stars awarded on a win: remaining moves reward efficiency. */
export function starsFor(s: Session): number {
  if (s.status !== "won") return 0;
  const ratio = s.movesLeft / s.level.moves;
  return ratio >= 0.35 ? 3 : ratio >= 0.15 ? 2 : 1;
}

/** "Stabilize Portal": a lost session resumes with extra moves (same board, same score). */
export function extendMoves(s: Session, moves: number): Session {
  if (s.status !== "lost") return s;
  return { ...s, movesLeft: s.movesLeft + moves, status: "playing" };
}

/** Relic: add moves mid-run (also resumes a just-lost board). */
export function addMoves(s: Session, moves: number): Session {
  if (s.status === "won") return s;
  return { ...s, movesLeft: s.movesLeft + moves, status: "playing" };
}

/** Relic: rearrange the board with the session's own RNG – deterministic, so replays match. */
export function reshuffleSession(s: Session): { session: Session; placements: { id: number; x: number; y: number }[] } {
  const engine = cloneState(s.engine);
  const placements = reshuffle(engine);
  return { session: { ...s, engine }, placements };
}
