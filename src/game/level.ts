import { applyBoostsToLevel, boostEffects, type BoostId } from "./boosts.ts";
import { cloneState, createEngine, findValidMoves, parseMask, reshuffle, type BoardSetup, type EngineState } from "./board.ts";
import { rotatedGravity, shiftGravity, spreadCover, trySwap } from "./resolve.ts";
import { createRng, nextInt } from "./rng.ts";
import { buildCampaign } from "./campaign.ts";
import { applyTwist, revealsSecret, type Secret, type Twist } from "./twists.ts";
import { islandStory } from "./lore.ts";
import type { CoverKind, CrystalType, Gravity, Pos, ResolveStep } from "./types.ts";

export type Objective =
  | { kind: "power"; target: number } // charge the portal with crystal energy
  | { kind: "score"; target: number }
  | { kind: "collect"; crystal: CrystalType; target: number }
  | { kind: "cover"; cover: CoverKind; target: number } // melt ice / cut vines / break chains / quench embers
  | { kind: "stone"; target: number } // break cracked stone
  | { kind: "rune"; target: number } // unearth buried runes
  | { kind: "relic"; target: number }; // bring Solar relics down to the edge

export interface LevelDef {
  id: number;
  /** shown instead of "Level {id}" for islands outside the numbered campaign */
  label?: string;
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
  /** points multiplier applied to every match (set by the Gem Multiplier boost) */
  scoreMultiplier?: number;
  /** board size (default 6 × 6) */
  width?: number;
  height?: number;
  /** obstacles placed at the start */
  setup?: BoardSetup;
  /** embers / vines creep onto a neighbour after `every` moves in which none were cleared */
  creep?: { cover: "ember" | "vine"; every: number };
  /** realm this level belongs to (campaign levels) – drives the island biome */
  realm?: string;
  /** seed for the island's terrain and props (defaults to the level seed) */
  islandSeed?: number;
  /** hidden events that strike mid-level (never shown in advance) */
  twists?: Twist[];
  /** a buried secret – or nothing; the story line may hint at it */
  secret?: Secret;
  /** the island's arrival passage */
  story?: string;
}

export const MAX_GRAVITY_CHARGES = 3;

/**
 * Every playable board. Indices are stable IDs (saved runs, replays and Realm Trials store them), so
 * the six original levels keep 0–5 and the generated campaign is appended after them.
 * Play order lives in CAMPAIGN.
 */
const AUTHORED: LevelDef[] = [
  { id: 1, name: "Waking Stones", seed: 1101, moves: 20, objective: { kind: "power", target: 170 }, realm: "verdant", islandSeed: 1101 },
  // HERO LEVEL: irregular canyon board; sheltered pockets under the ruins only fill via Gravity Shift
  {
    id: 21, name: "Emerald Canyon", seed: 2207, moves: 22, gravityCharges: 2, spawnWeights: [1, 1, 1.6, 1, 1],
    objective: { kind: "collect", crystal: 2, target: 32 },
    // two sheltered pockets: under the ruin pillar (column 3) and the left cliff (column 0)
    mask: ["OOOOOO", "OOOXOO", "OOOXOO", "XOOOOO", "OOXOOO", "OOXOOO"],
    realm: "canyon", islandSeed: 2207,
  },
  { id: 20, name: "Heart of the Falls", seed: 3313, moves: 18, objective: { kind: "score", target: 5600 }, realm: "verdant", islandSeed: 3313 },
  // discovery / seasonal / expedition islands (meta-game content, outside the numbered campaign)
  { id: 4, label: "Discovery", name: "Hollow of Lanterns", seed: 4421, moves: 18, objective: { kind: "collect", crystal: 4, target: 30 }, realm: "hollow", islandSeed: 4421 },
  { id: 5, label: "Eclipse", name: "Eclipse Threshold", seed: 5527, moves: 16, objective: { kind: "power", target: 190 }, realm: "void", islandSeed: 5527 },
  { id: 6, label: "Expedition", name: "Frostbound Signal", seed: 6637, moves: 18, objective: { kind: "collect", crystal: 1, target: 34 }, realm: "frozen", islandSeed: 6637 },
];
/** campaign numbers played on the authored boards above (number → LEVELS index) */
const AUTHORED_AT: Record<number, number> = { 1: 0, 20: 2, 21: 1 };

const GENERATED = buildCampaign().filter((l) => AUTHORED_AT[l.number] === undefined);
// authored islands keep their hand-tuned boards (no twists) but get arrival passages too
for (const l of AUTHORED) l.story ??= islandStory(l.realm ?? "verdant", l.seed);
export const LEVELS: LevelDef[] = [...AUTHORED, ...GENERATED];

/** The 200 campaign levels in play order, as LEVELS indices. */
export const CAMPAIGN: number[] = Array.from({ length: 200 }, (_, i) => {
  const n = i + 1;
  return AUTHORED_AT[n] ?? LEVELS.indexOf(GENERATED.find((l) => l.number === n)!);
});

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
  /** obstacles fully removed this run */
  tally: { cover: Record<CoverKind, number>; stone: number; rune: number; relic: number };
  /** moves in a row without cutting the creeping cover */
  creepIdle: number;
  /** player moves made (twists fire on these, independent of bonus moves) */
  movesMade: number;
  /** how many of the level's twists have struck */
  twistsFired: number;
  secretFound: boolean;
}

export function startSession(level: LevelDef, seedOverride?: number): Session {
  return {
    level,
    engine: createEngine(level.width ?? 6, level.height ?? 6, 5, createRng(seedOverride ?? level.seed), parseMask(level.mask, level.width ?? 6, level.height ?? 6), level.spawnWeights, level.setup),
    score: 0,
    movesLeft: level.moves,
    charge: 0,
    collected: [0, 0, 0, 0, 0],
    status: "playing",
    bestCascade: 0,
    gravityCharges: Math.min(MAX_GRAVITY_CHARGES, level.gravityCharges ?? 0),
    tally: { cover: { ice: 0, vine: 0, chain: 0, ember: 0 }, stone: 0, rune: 0, relic: 0 },
    creepIdle: 0,
    movesMade: 0,
    twistsFired: 0,
    secretFound: false,
  };
}

/** Points a match is worth on this level (boosts may scale it). */
export const scoreOf = (level: LevelDef, base: number) => Math.round(base * (level.scoreMultiplier ?? 1));

/** Forges `count` Surge crystals on distinct plain cells, chosen with the session's own RNG (deterministic). */
function seedSurges(s: Session, count: number): Session {
  const b = s.engine.board;
  const cells = b.cells.slice();
  const rng = { state: s.engine.rng.state };
  const free = cells.map((c, i) => (c && c.special === "none" && !c.cover ? i : -1)).filter((i) => i >= 0);
  for (let n = 0; n < count && free.length; n++) {
    const i = free.splice(nextInt(rng, free.length), 1)[0];
    cells[i] = { ...cells[i]!, special: n % 2 ? "surgeV" : "surgeH" };
  }
  return { ...s, engine: { ...s.engine, rng, board: { ...b, cells } } };
}

/** Board Prep: clears the first valid matches for free (no move spent, no twist tick). */
function prepMatches(s: Session, count: number): { session: Session; steps: ResolveStep[] } {
  let cur = s;
  const steps: ResolveStep[] = [];
  for (let i = 0; i < count; i++) {
    const mv = findValidMoves(cur.engine.board)[0];
    if (!mv) break;
    const r = trySwap(cur.engine, mv[0], mv[1]);
    if (!r.valid) break;
    const next: Session = { ...cur, engine: r.state, collected: cur.collected.slice(), tally: cloneTally(cur.tally) };
    account(next, r.steps);
    steps.push(...r.steps);
    cur = next;
  }
  return { session: cur, steps };
}

/** A session with the equipped boosts applied. `steps` are the free Board Prep matches (already resolved). */
export function startBoostedSession(level: LevelDef, seed: number | undefined, boosts: readonly BoostId[]): { session: Session; steps: ResolveStep[] } {
  const e = boostEffects(boosts);
  let session = startSession(applyBoostsToLevel(level, boosts), seed);
  if (e.startSurges) session = seedSurges(session, e.startSurges);
  return e.startingClears ? prepMatches(session, e.startingClears) : { session, steps: [] };
}

/** Portal energy granted by a clear step: crystals, specials and cascades all feed the portal. */
export function chargeForStep(step: Extract<ResolveStep, { kind: "clear" }>): number {
  return step.cleared.length + step.created.length * 3 + step.activated.length * 2 + (step.cascade - 1) * 2;
}

/** 0..1 progress toward the level objective. Drives the world's evolution stages. */
export function objectiveProgress(s: Session): number {
  const o = s.level.objective;
  return Math.min(1, objectiveValue(s) / o.target);
}

/** Current count toward the objective's target. */
export const objectiveValue = (s: Session) => objectiveValueFrom(s.level.objective, s);

/** Shared with the view layer, which tracks the same counters while steps play back. */
export function objectiveValueFrom(o: Objective, s: Pick<Session, "charge" | "score" | "collected" | "tally">): number {
  switch (o.kind) {
    case "power": return s.charge;
    case "score": return s.score;
    case "collect": return s.collected[o.crystal];
    case "cover": return s.tally.cover[o.cover];
    case "stone": return s.tally.stone;
    case "rune": return s.tally.rune;
    case "relic": return s.tally.relic;
  }
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
    movesMade: s.movesMade + 1,
    collected: s.collected.slice(),
    tally: cloneTally(s.tally),
  };
  account(next, r.steps);
  creep(next, r.steps);
  twist(next, r.steps);
  findSecret(next, r.steps);
  if (objectiveProgress(next) >= 1) next.status = "won";
  else if (next.movesLeft <= 0) next.status = "lost";
  return { valid: true, session: next, steps: r.steps };
}

const cloneTally = (t: Session["tally"]): Session["tally"] => ({ ...t, cover: { ...t.cover } });

/** A hidden twist strikes after its move (only while the level is still being played). */
function twist(next: Session, steps: ResolveStep[]) {
  const t = next.level.twists?.[next.twistsFired];
  if (!t || next.movesMade !== t.atMove || objectiveProgress(next) >= 1 || next.movesLeft <= 0) return;
  next.twistsFired++;
  const o = next.level.objective;
  const r = applyTwist(next.engine, t.kind, o.kind === "collect" ? o.crystal : undefined);
  next.engine = r.state;
  steps.push({ kind: "twist", twist: t.kind, ...(t.kind === "blessing" ? { moves: 3 } : {}) }, ...r.steps);
  if (t.kind === "blessing") next.movesLeft += 3;
  account(next, r.steps);
}

/** The island's secret answers one kind of clear on one buried cell. */
function findSecret(next: Session, steps: ResolveStep[]) {
  const sec = next.level.secret;
  if (!sec || next.secretFound) return;
  if (steps.some((st) => revealsSecret(st, sec))) {
    next.secretFound = true;
    steps.push({ kind: "secret", x: sec.x, y: sec.y });
  }
}

/** Embers / vines creep after enough moves in which none were cut. Appends the spread steps. */
function creep(next: Session, steps: ResolveStep[]) {
  const c = next.level.creep;
  if (!c || next.status !== "playing") return;
  const cut = steps.some((st) => st.kind === "clear" && st.hits?.some((h) => h.layer === "cover" && h.kind === c.cover));
  next.creepIdle = cut ? 0 : next.creepIdle + 1;
  if (next.creepIdle < c.every) return;
  next.creepIdle = 0;
  const r = spreadCover(next.engine, c.cover);
  if (!r) return;
  next.engine = r.state;
  steps.push(...r.steps);
}

/** Score, portal charge, collection, obstacles and Gravity Charge recharge from resolved steps. */
function account(next: Session, steps: ResolveStep[]) {
  for (const step of steps) {
    if (step.kind === "relics") next.tally.relic += step.collected.length;
    if (step.kind !== "clear") continue;
    for (const h of step.hits ?? []) {
      if (h.hp > 0) continue;
      if (h.layer === "cover") next.tally.cover[h.kind as CoverKind]++;
      else if (h.layer === "block") next.tally.stone++;
      else next.tally.rune++;
    }
    next.score += scoreOf(next.level, step.score);
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
  const next: Session = { ...s, engine: r.state, gravityCharges: s.gravityCharges - 1, collected: s.collected.slice(), tally: cloneTally(s.tally) };
  account(next, r.steps);
  findSecret(next, r.steps);
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
