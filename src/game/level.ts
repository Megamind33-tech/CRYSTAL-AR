import { createEngine, type EngineState } from "./board.ts";
import { trySwap } from "./resolve.ts";
import { createRng } from "./rng.ts";
import type { CrystalType, Pos, ResolveStep } from "./types.ts";

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
}

export const LEVELS: LevelDef[] = [
  { id: 1, name: "Waking Stones", seed: 1101, moves: 20, objective: { kind: "power", target: 170 } },
  { id: 2, name: "Emerald Canopy", seed: 2207, moves: 16, objective: { kind: "collect", crystal: 2, target: 32 } },
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
}

export function startSession(level: LevelDef, seedOverride?: number): Session {
  return {
    level,
    engine: createEngine(6, 6, 5, createRng(seedOverride ?? level.seed)),
    score: 0,
    movesLeft: level.moves,
    charge: 0,
    collected: [0, 0, 0, 0, 0],
    status: "playing",
    bestCascade: 0,
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
  for (const step of r.steps) {
    if (step.kind !== "clear") continue;
    next.score += step.score;
    next.charge += chargeForStep(step);
    next.bestCascade = Math.max(next.bestCascade, step.cascade);
    for (const c of step.cleared) next.collected[c.type]++;
  }
  if (objectiveProgress(next) >= 1) next.status = "won";
  else if (next.movesLeft <= 0) next.status = "lost";
  return { valid: true, session: next, steps: r.steps };
}

/** Stars awarded on a win: remaining moves reward efficiency. */
export function starsFor(s: Session): number {
  if (s.status !== "won") return 0;
  const ratio = s.movesLeft / s.level.moves;
  return ratio >= 0.35 ? 3 : ratio >= 0.15 ? 2 : 1;
}
