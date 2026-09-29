// Game controller: runs the pure engine, then plays its ResolveSteps back as timed view states.
// Renderers (AR and mock) only read `gameStore`; audio/haptics subscribe to `gameEvents`.
import { boardHash, findValidMoves, isAdjacent } from "../game/board.ts";
import { accumulate, newRunStats, type RunStats } from "../meta/verify.ts";
import type { RunBoost } from "../meta/types.ts";
import type { BoostId } from "../game/boosts.ts";
import { addMoves, chargeForStep, scoreOf, startBoostedSession, playShift, extendMoves, reshuffleSession, LEVELS, objectiveProgress, objectiveValueFrom, playMove, startSession, starsFor, type Session } from "../game/level.ts";
import { eventsForStep, stageForProgress, type WorldEvent, type WorldStage } from "../game/reactions.ts";
import type { Cover, CrystalType, Gravity, Pos, ResolveStep, Special } from "../game/types.ts";
import { neighbourToward } from "../render/layout.ts";
import { TWIST_TEXT, type TwistKind } from "../game/twists.ts";
import { createStore } from "./store.ts";

export type Anim =
  | { kind: "move"; fromX: number; fromY: number; ms: number; seq: number }
  | { kind: "spawn"; fromX: number; fromY: number; ms: number; seq: number }
  | { kind: "pop"; ms: number; seq: number }
  | { kind: "forge"; ms: number; seq: number }
  /** an obstacle layer chipped off / a cover crept on */
  | { kind: "crack"; ms: number; seq: number };

export interface CrystalView {
  id: number;
  type: CrystalType;
  special: Special;
  x: number;
  y: number;
  cover?: Cover;
  anim?: Anim;
}

export interface Burst {
  id: number;
  x: number;
  y: number;
  type: CrystalType;
  big: boolean;
}

export interface Hud {
  score: number;
  movesLeft: number;
  charge: number;
  collected: number[];
  tally: Session["tally"];
}

export interface GameState {
  levelIndex: number;
  /** bumps on every level start, so the renderer builds fresh nodes instead of animating the reset */
  runId: number;
  session: Session | null;
  crystals: CrystalView[];
  selected: Pos | null;
  busy: boolean;
  hud: Hud;
  /** boosts equipped for this run (their effects are already part of the session) */
  activeBoosts: BoostId[];
  progress: number;
  stage: WorldStage;
  reactions: Record<WorldEvent, number>;
  bursts: Burst[];
  comboText: { text: string; seq: number } | null;
  result: { won: boolean; stars: number } | null;
  lastMatch: string;
  moveCount: number;
  /** idle hint: two cells of a valid swap, glowing */
  hint: [Pos, Pos] | null;
  /** current gravity (drives the tabletop tilt) and Gravity Charges left */
  gravity: Gravity;
  gravityCharges: number;
  /** cracked stone hp and buried rune layers per cell (null on levels without them) */
  blocks: number[] | null;
  floor: number[] | null;
  /** story / twist / secret banner */
  announce: { text: string; tone: "story" | "twist" | "secret"; seq: number } | null;
  /** a dragon is summoned to sweep a board row */
  dragon: { seq: number; row: number } | null;
  /** portal traversal to the next island */
  travel: { phase: "dive" | "emerge"; seq: number; to: string } | null;
}

const emptyTally = (): Session["tally"] => ({ cover: { ice: 0, vine: 0, chain: 0, ember: 0 }, stone: 0, rune: 0, relic: 0 });

const emptyReactions = (): Record<WorldEvent, number> => ({
  MATCH_3: 0, MATCH_4: 0, MATCH_5: 0, CASCADE_2: 0, CASCADE_3: 0, CASCADE_4_PLUS: 0,
  SPECIAL_CREATED: 0, SPECIAL_ACTIVATED: 0, COMBO: 0, LEVEL_COMPLETE: 0, GRAVITY_SHIFT: 0,
});

export const gameStore = createStore<GameState>({
  levelIndex: 0,
  runId: 0,
  session: null,
  crystals: [],
  selected: null,
  busy: false,
  hud: { score: 0, movesLeft: 0, charge: 0, collected: [0, 0, 0, 0, 0], tally: emptyTally() },
  progress: 0,
  stage: 0,
  reactions: emptyReactions(),
  bursts: [],
  comboText: null,
  result: null,
  lastMatch: "-",
  moveCount: 0,
  hint: null,
  gravity: "down",
  gravityCharges: 0,
  blocks: null,
  floor: null,
  announce: null,
  dragon: null,
  travel: null,
  activeBoosts: [],
});

// ---- side-effect channel (audio, haptics, analytics) -----------------------
export type GameEvent =
  | { type: "sfx"; name: SfxName }
  | { type: "haptic"; kind: "light" | "medium" | "heavy" | "success" | "error" }
  | { type: "levelEnd"; won: boolean; stars: number; level: number; run: RunRecord };

/** Everything needed to build a verifiable RunReport for the meta layer. */
export interface RunRecord {
  levelIndex: number;
  seed: number;
  startedAt: number;
  endedAt: number;
  swaps: [number, number, number, number][];
  stats: RunStats;
  boosts: RunBoost[];
  /** pre-match Armory boosts equipped for this run */
  equipped: BoostId[];
  relicsUsed: string[];
  score: number;
  won: boolean;
  stars: number;
  /** the island's buried secret was uncovered this run */
  secretFound?: boolean;
}
let run: RunRecord | null = null;
export const currentRun = () => run;
export type SfxName =
  | "select" | "swap" | "invalid" | "match1" | "match2" | "match3" | "match4"
  | "special_create" | "special_activate" | "place" | "complete" | "portal" | "gravity";

const listeners = new Set<(e: GameEvent) => void>();
export const gameEvents = {
  on(l: (e: GameEvent) => void) {
    listeners.add(l);
    return () => listeners.delete(l);
  },
  emit(e: GameEvent) {
    listeners.forEach((l) => l(e));
  },
};

// ---- timing ----------------------------------------------------------------
export const TIMING = { tilt: 380, swap: 170, pop: 230, forge: 280, fallBase: 120, fallPerRow: 55, shuffle: 420, cascadeGap: 70 };
let sleepImpl = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
/** Tests replace the clock so step playback runs instantly. */
export function setSleep(fn: (ms: number) => Promise<void>) {
  sleepImpl = fn;
}

let seq = 1;
let burstId = 1;
let generation = 0; // invalidates in-flight playback on restart

const viewsFromSession = (s: Session): CrystalView[] => {
  const b = s.engine.board;
  const out: CrystalView[] = [];
  b.cells.forEach((c, i) => {
    if (c) out.push({ id: c.id, type: c.type, special: c.special, x: i % b.width, y: Math.floor(i / b.width), ...(c.cover ? { cover: c.cover } : {}) });
  });
  return out;
};

/** What the current run was started with, so a restart replays the exact same setup. */
let lastStart: { seed?: number; moves?: number } = {};

export function startLevel(levelIndex: number, seedOverride?: number, movesOverride?: number, boosts: BoostId[] = []) {
  generation++;
  lastStart = { seed: seedOverride, moves: movesOverride };
  const base = LEVELS[Math.max(0, Math.min(LEVELS.length - 1, levelIndex))];
  const played = movesOverride ? { ...base, moves: movesOverride } : base;
  const { session, steps: prepSteps } = startBoostedSession(played, seedOverride, boosts);
  const level = session.level;

  run = {
    levelIndex: LEVELS.indexOf(base),
    seed: seedOverride ?? level.seed,
    startedAt: Date.now(),
    endedAt: 0,
    swaps: [],
    stats: newRunStats(),
    boosts: [],
    equipped: [...boosts],
    relicsUsed: [],
    score: 0,
    won: false,
    stars: 0
  };
  accumulate(run.stats, prepSteps);
  const progress0 = objectiveProgress(session);

  gameStore.set({
    levelIndex: LEVELS.indexOf(base),
    runId: gameStore.get().runId + 1,
    session,
    crystals: viewsFromSession(session).map((c) => ({ ...c, anim: { kind: "spawn", fromX: c.x, fromY: c.y - 7, ms: 380 + c.y * 40, seq: seq++ } })),
    selected: null,
    busy: false,
    hud: { score: session.score, movesLeft: session.movesLeft, charge: session.charge, collected: session.collected.slice(), tally: { ...session.tally, cover: { ...session.tally.cover } } },
    progress: progress0,
    stage: stageForProgress(progress0),
    reactions: emptyReactions(),
    bursts: [],
    comboText: null,
    result: null,
    lastMatch: "-",
    moveCount: 0,
    hint: null,
    gravity: session.engine.gravity,
    gravityCharges: session.gravityCharges,
    blocks: session.engine.board.block?.slice() ?? null,
    floor: session.engine.board.floor?.slice() ?? null,
    announce: session.level.story ? { text: session.level.story, tone: "story", seq: seq++ } : null,
    activeBoosts: boosts,
  });
  scheduleHint();
}

/** Replays the current level from scratch with the given boosts (the caller has already paid for them). */
export const restartLevel = (boosts: BoostId[] = []) => startLevel(gameStore.get().levelIndex, lastStart.seed, lastStart.moves, boosts);

/** "Stabilize Portal": resume a lost board with extra moves (payment is handled by the meta layer). */
export function stabilizeLevel(moves: number) {
  const s = gameStore.get();
  if (!s.session || s.session.status !== "lost") return false;
  const session = extendMoves(s.session, moves);
  if (run) run.boosts.push({ atSwap: run.swaps.length, kind: "moves", value: moves, source: "stabilize" });
  gameStore.set({ session, result: null, hud: { ...s.hud, movesLeft: session.movesLeft } });
  scheduleHint();
  return true;
}

/** After the world is re-placed, replay the entrance so crystals rise into the new spot. */
export function respawnView() {
  gameStore.set((s) => ({
    selected: null,
    crystals: s.crystals.map((c) => ({ ...c, anim: { kind: "spawn" as const, fromX: c.x, fromY: c.y - 7, ms: 380 + c.y * 40, seq: seq++ } })),
  }));
}

/** Leaving the level: drop the session so the next play starts clean. */
export function endSession() {
  generation++;
  clearHint();
  gameStore.set({ session: null, crystals: [], selected: null, busy: false, result: null, bursts: [] });
}

/** CLICK_DOWN on a cell: select it (or complete a tap-tap swap). */
export function pressCell(p: Pos) {
  clearHint();
  const s = gameStore.get();
  if (s.busy || !s.session || s.result) return;
  if (s.selected && isAdjacent(s.selected, p)) {
    void attemptSwap(s.selected, p);
    return;
  }
  if (s.selected && s.selected.x === p.x && s.selected.y === p.y) return;
  gameStore.set({ selected: p });
  gameEvents.emit({ type: "sfx", name: "select" });
  gameEvents.emit({ type: "haptic", kind: "light" });
}

/** CLICK_UP on a cell: a swipe that started on the selected crystal and ended elsewhere. */
export function releaseCell(p: Pos) {
  const s = gameStore.get();
  if (s.busy || !s.selected || s.result) return;
  if (s.selected.x === p.x && s.selected.y === p.y) return; // plain tap keeps the selection
  const n = neighbourToward(s.selected, p);
  if (n) void attemptSwap(s.selected, n);
}

export function clearSelection() {
  gameStore.set({ selected: null });
}

export async function attemptSwap(a: Pos, b: Pos) {
  const s = gameStore.get();
  if (s.busy || !s.session || s.result) return;
  const r = playMove(s.session, a, b);
  if (r.steps.length === 0) {
    gameStore.set({ selected: null });
    return;
  }
  if (r.valid && run) {
    run.swaps.push([a.x, a.y, b.x, b.y]);
    accumulate(run.stats, r.steps);
  }
  const gen = generation;
  gameStore.set({ busy: true, selected: null });
  await playSteps(r.steps, gen);
  if (gen !== generation) return;
  finishTurn(s, r.session, r.valid);
}

/** Shared end of a swap or tabletop turn: outcome detection, HUD sync, level-end event. */
function finishTurn(s: GameState, session: Session, countsAsMove: boolean) {
  const progress = objectiveProgress(session);
  let result: GameState["result"] = null;
  if (session.status !== "playing") {
    result = { won: session.status === "won", stars: starsFor(session) };
    if (result.won) {
      bumpReactions(["LEVEL_COMPLETE"]);
      gameEvents.emit({ type: "sfx", name: "complete" });
      gameEvents.emit({ type: "haptic", kind: "success" });
    }
    if (run) Object.assign(run, { endedAt: Date.now(), score: session.score, won: result.won, stars: result.stars, secretFound: session.secretFound });
    gameEvents.emit({ type: "levelEnd", won: result.won, stars: result.stars, level: session.level.id, run: { ...run!, swaps: [...run!.swaps], stats: { ...run!.stats }, boosts: [...run!.boosts], equipped: [...run!.equipped], relicsUsed: [...run!.relicsUsed] } });
  }
  scheduleHint();
  gameStore.set({
    session,
    busy: false,
    crystals: viewsFromSession(session),
    hud: { score: session.score, movesLeft: session.movesLeft, charge: session.charge, collected: session.collected, tally: session.tally },
    progress,
    stage: stageForProgress(progress),
    result,
    moveCount: s.moveCount + (countsAsMove ? 1 : 0),
    gravity: session.engine.gravity,
    gravityCharges: session.gravityCharges,
    blocks: session.engine.board.block?.slice() ?? null,
    floor: session.engine.board.floor?.slice() ?? null,
  });
}

/**
 * GRAVITY SHIFT – turn the tabletop one step. Crystals slide, pockets fill, cascades resolve.
 * Logged as a run boost so the run stays replay-verifiable.
 */
export async function turnTabletop(turn: -1 | 1): Promise<boolean> {
  const s = gameStore.get();
  if (s.busy || !s.session || s.result) return false;
  const r = playShift(s.session, turn);
  if (!r.valid) {
    gameEvents.emit({ type: "sfx", name: "invalid" });
    gameEvents.emit({ type: "haptic", kind: "error" });
    return false;
  }
  clearHint();
  if (run) run.boosts.push({ atSwap: run.swaps.length, kind: "gravity", value: turn, source: "gravity" });
  if (run) accumulate(run.stats, r.steps);
  const gen = generation;
  gameStore.set({ busy: true, selected: null, gravityCharges: r.session.gravityCharges });
  await playSteps(r.steps, gen);
  if (gen !== generation) return true;
  finishTurn(s, r.session, false);
  return true;
}

function bumpReactions(events: WorldEvent[]) {
  if (!events.length) return;
  gameStore.set((s) => {
    const reactions = { ...s.reactions };
    for (const e of events) reactions[e]++;
    return { reactions };
  });
}

const setCrystals = (fn: (c: CrystalView[]) => CrystalView[]) => gameStore.set((s) => ({ crystals: fn(s.crystals) }));

async function playSteps(steps: ResolveStep[], gen: number) {
  const sleep = async (ms: number) => {
    await sleepImpl(ms);
    return gen === generation;
  };
  for (const step of steps) {
    if (gen !== generation) return;
    switch (step.kind) {
      case "swap":
      case "revert": {
        const { a, b, aId, bId } = step;
        // after "swap" aId sits at b; after "revert" it returns to a
        const [aTo, bTo, aFrom, bFrom] = step.kind === "swap" ? [b, a, a, b] : [a, b, b, a];
        setCrystals((cs) =>
          cs.map((c) =>
            c.id === aId
              ? { ...c, x: aTo.x, y: aTo.y, anim: { kind: "move", fromX: aFrom.x, fromY: aFrom.y, ms: TIMING.swap, seq: seq++ } }
              : c.id === bId
                ? { ...c, x: bTo.x, y: bTo.y, anim: { kind: "move", fromX: bFrom.x, fromY: bFrom.y, ms: TIMING.swap, seq: seq++ } }
                : c,
          ),
        );
        gameEvents.emit({ type: "sfx", name: step.kind === "swap" ? "swap" : "invalid" });
        if (step.kind === "revert") gameEvents.emit({ type: "haptic", kind: "error" });
        if (!(await sleep(TIMING.swap + 20))) return;
        break;
      }
      case "clear": {
        const ids = new Set(step.cleared.map((c) => c.id));
        // covered crystals stay put and lose a layer
        const coverHits = new Map((step.hits ?? []).filter((h) => h.layer === "cover").map((h) => [h.id!, h]));
        setCrystals((cs) =>
          cs.map((c) => {
            if (ids.has(c.id)) return { ...c, anim: { kind: "pop", ms: TIMING.pop, seq: seq++ } };
            const h = coverHits.get(c.id);
            if (!h) return c;
            const { cover: _old, ...rest } = c;
            return { ...rest, ...(h.hp > 0 ? { cover: { kind: h.kind as Cover["kind"], hp: h.hp } } : {}), anim: { kind: "crack", ms: TIMING.pop, seq: seq++ } };
          }),
        );
        const cascadeLevel = Math.min(4, step.cascade) as 1 | 2 | 3 | 4;
        gameEvents.emit({ type: "sfx", name: `match${cascadeLevel}` });
        if (step.activated.length) gameEvents.emit({ type: "sfx", name: "special_activate" });
        gameEvents.emit({ type: "haptic", kind: step.activated.length || step.cascade >= 3 ? "heavy" : "medium" });
        bumpReactions(eventsForStep(step));

        const big = step.cleared.length > 12;
        const bursts: Burst[] = (big ? step.cleared.filter((_, i) => i % 3 === 0) : step.cleared).map((c) => ({
          id: burstId++, x: c.x, y: c.y, type: c.type, big: c.special !== "none",
        }));
        // a small spark puff where an obstacle layer took a hit (cover, stone or rune), via the same pool
        const HIT_TYPE = { ice: 1, vine: 2, chain: 4, ember: 0 } as const;
        for (const h of step.hits ?? []) {
          const t = h.layer === "cover" ? HIT_TYPE[h.kind as Cover["kind"]] ?? 4 : h.layer === "block" ? 4 : 3;
          bursts.push({ id: burstId++, x: h.x, y: h.y, type: t as CrystalType, big: false });
        }
        const text =
          step.combo ? "Resonance!" : step.cascade >= 4 ? "Crystal Storm!" : step.cascade === 3 ? "Radiant!" : step.cascade === 2 ? "Chain!" : null;
        gameStore.set((s) => {
          const hud = { ...s.hud, collected: s.hud.collected.slice(), tally: { ...s.hud.tally, cover: { ...s.hud.tally.cover } } };
          hud.score += scoreOf(s.session!.level, step.score);
          hud.charge += chargeForStep(step);
          for (const c of step.cleared) hud.collected[c.type]++;
          let blocks = s.blocks, floor = s.floor;
          for (const h of step.hits ?? []) {
            const i = h.y * s.session!.engine.board.width + h.x;
            if (h.layer === "block" && blocks) (blocks = blocks === s.blocks ? blocks.slice() : blocks)[i] = h.hp;
            if (h.layer === "floor" && floor) (floor = floor === s.floor ? floor.slice() : floor)[i] = h.hp;
            if (h.hp > 0) continue;
            if (h.layer === "cover") hud.tally.cover[h.kind as Cover["kind"]]++;
            else if (h.layer === "block") hud.tally.stone++;
            else hud.tally.rune++;
          }
          const session = s.session!;
          const progress = Math.min(1, objectiveValueFrom(session.level.objective, hud) / session.level.objective.target);
          const stage = stageForProgress(progress);
          if (stage > s.stage) gameEvents.emit({ type: "sfx", name: "portal" });
          return {
            hud,
            blocks,
            floor,
            progress,
            stage,
            bursts: [...s.bursts, ...bursts].slice(-24),
            comboText: text ? { text, seq: seq++ } : s.comboText,
            lastMatch: `c${step.cascade} ${step.groups.map((g) => g.size).join("+") || step.combo} (+${step.score})`,
          };
        });
        const burstIds = new Set(bursts.map((b) => b.id));
        setTimeout(() => gameStore.set((s) => ({ bursts: s.bursts.filter((b) => !burstIds.has(b.id)) })), 1400);
        if (!(await sleep(TIMING.pop))) return;

        setCrystals((cs) => [
          ...cs.filter((c) => !ids.has(c.id)),
          ...step.created.map((c) => ({ id: c.id, type: c.type, special: c.special, x: c.x, y: c.y, anim: { kind: "forge" as const, ms: TIMING.forge, seq: seq++ } })),
        ]);
        if (step.created.length) {
          gameEvents.emit({ type: "sfx", name: "special_create" });
          if (!(await sleep(TIMING.forge * 0.6))) return;
        }
        break;
      }
      case "fall": {
        let longest = 0;
        const moved = new Map(step.moves.map((m) => [m.id, m]));
        const dur = (rows: number) => TIMING.fallBase + TIMING.fallPerRow * Math.sqrt(rows) * 2;
        setCrystals((cs) => [
          ...cs.map((c) => {
            const m = moved.get(c.id);
            if (!m) return c;
            const ms = dur(Math.abs(m.toY - m.fromY) + Math.abs(m.toX - m.fromX));
            longest = Math.max(longest, ms);
            return { ...c, x: m.toX, y: m.toY, anim: { kind: "move" as const, fromX: m.fromX, fromY: m.fromY, ms, seq: seq++ } };
          }),
          ...step.spawned.map((sp) => {
            const ms = dur(Math.abs(sp.y - sp.fromY) + Math.abs(sp.x - sp.fromX)) + 40;
            longest = Math.max(longest, ms);
            return { id: sp.id, type: sp.type, special: sp.special, x: sp.x, y: sp.y, anim: { kind: "spawn" as const, fromX: sp.fromX, fromY: sp.fromY, ms, seq: seq++ } };
          }),
        ]);
        if (!(await sleep(longest + TIMING.cascadeGap))) return;
        break;
      }
      case "gravity": {
        // the tabletop tilts (BoardView reads session gravity via gameStore.gravity)
        gameStore.set({ gravity: step.to });
        gameEvents.emit({ type: "sfx", name: "gravity" });
        gameEvents.emit({ type: "haptic", kind: "heavy" });
        bumpReactions(["GRAVITY_SHIFT"]);
        if (!(await sleep(TIMING.tilt))) return;
        break;
      }
      case "relics": {
        // Solar relics sink into the island's edge and are gathered
        const gone = new Set(step.collected.map((r) => r.id));
        setCrystals((cs) => cs.map((c) => (gone.has(c.id) ? { ...c, anim: { kind: "pop", ms: TIMING.pop * 2, seq: seq++ } } : c)));
        gameStore.set((s) => {
          const hud = { ...s.hud, tally: { ...s.hud.tally, relic: s.hud.tally.relic + step.collected.length } };
          const o = s.session!.level.objective;
          const progress = Math.min(1, objectiveValueFrom(o, hud) / o.target);
          return { hud, progress, stage: Math.max(s.stage, stageForProgress(progress)) as WorldStage };
        });
        gameEvents.emit({ type: "sfx", name: "portal" });
        gameEvents.emit({ type: "haptic", kind: "success" });
        if (!(await sleep(TIMING.pop * 2))) return;
        setCrystals((cs) => cs.filter((c) => !gone.has(c.id)));
        break;
      }
      case "spread": {
        const hit = new Map(step.cells.map((c) => [c.id, c]));
        setCrystals((cs) =>
          cs.map((c) => {
            const h = hit.get(c.id);
            return h ? { ...c, cover: { kind: h.cover, hp: 1 }, anim: { kind: "crack" as const, ms: TIMING.forge, seq: seq++ } } : c;
          }),
        );
        gameEvents.emit({ type: "sfx", name: "invalid" });
        if (!(await sleep(TIMING.forge))) return;
        break;
      }
      case "twist": {
        gameStore.set((st) => ({
          announce: { text: TWIST_TEXT[step.twist as TwistKind] ?? "Something changes…", tone: "twist", seq: seq++ },
          hud: step.moves ? { ...st.hud, movesLeft: st.hud.movesLeft + step.moves } : st.hud,
        }));
        if (step.twist === "dragonFire") {
          // the dragon sweeps the row that is about to burn, then the fire lands
          const after = steps[steps.indexOf(step) + 1];
          gameStore.set({ dragon: { seq: seq++, row: after?.kind === "spread" ? after.cells[0]?.y ?? 2 : 2 } });
          if (!(await sleep(1400))) return;
        }
        gameEvents.emit({ type: "sfx", name: step.twist === "blessing" ? "portal" : "gravity" });
        gameEvents.emit({ type: "haptic", kind: step.twist === "blessing" ? "success" : "heavy" });
        bumpReactions(["GRAVITY_SHIFT"]);
        if (!(await sleep(900))) return;
        break;
      }
      case "blocks": {
        // rocks crash down: those crystals shatter and stone takes their cells
        const gone = new Set(step.cells.map((c) => c.id));
        setCrystals((cs) => cs.map((c) => (gone.has(c.id) ? { ...c, anim: { kind: "pop" as const, ms: TIMING.pop, seq: seq++ } } : c)));
        if (!(await sleep(TIMING.pop))) return;
        gameStore.set((st) => {
          const w = st.session!.engine.board.width;
          const blocks = st.blocks ? st.blocks.slice() : new Array(w * st.session!.engine.board.height).fill(0);
          for (const c of step.cells) blocks[c.y * w + c.x] = c.hp;
          return { blocks, crystals: st.crystals.filter((c) => !gone.has(c.id)) };
        });
        gameEvents.emit({ type: "haptic", kind: "heavy" });
        if (!(await sleep(200))) return;
        break;
      }
      case "empower": {
        const up = new Map(step.cells.map((c) => [c.id, c.special]));
        setCrystals((cs) => cs.map((c) => (up.has(c.id) ? { ...c, special: up.get(c.id)!, anim: { kind: "forge" as const, ms: TIMING.forge, seq: seq++ } } : c)));
        gameEvents.emit({ type: "sfx", name: "special_create" });
        if (!(await sleep(TIMING.forge))) return;
        break;
      }
      case "steal": {
        const gone = new Set(step.cells.map((c) => c.id));
        setCrystals((cs) => cs.map((c) => (gone.has(c.id) ? { ...c, anim: { kind: "pop" as const, ms: TIMING.pop, seq: seq++ } } : c)));
        gameEvents.emit({ type: "sfx", name: "invalid" });
        if (!(await sleep(TIMING.pop + 60))) return;
        setCrystals((cs) => cs.filter((c) => !gone.has(c.id)));
        break;
      }
      case "secret": {
        gameStore.set({ announce: { text: "A secret stirs beneath the stones… a Memory Shard is yours.", tone: "secret", seq: seq++ } });
        gameEvents.emit({ type: "sfx", name: "portal" });
        gameEvents.emit({ type: "haptic", kind: "success" });
        bumpReactions(["LEVEL_COMPLETE"]);
        if (!(await sleep(700))) return;
        break;
      }
      case "shuffle": {
        const to = new Map(step.placements.map((p) => [p.id, p]));
        setCrystals((cs) =>
          cs.map((c) => {
            const p = to.get(c.id);
            return p ? { ...c, x: p.x, y: p.y, anim: { kind: "move" as const, fromX: c.x, fromY: c.y, ms: TIMING.shuffle, seq: seq++ } } : c;
          }),
        );
        if (!(await sleep(TIMING.shuffle + 40))) return;
        break;
      }
    }
  }
}

// ---- idle hint -------------------------------------------------------------
export const HINT_DELAY_MS = 5000;
let hintTimer: ReturnType<typeof setTimeout> | null = null;
function clearHint() {
  if (hintTimer) clearTimeout(hintTimer);
  hintTimer = null;
  if (gameStore.get().hint) gameStore.set({ hint: null });
}
function scheduleHint() {
  if (hintTimer) clearTimeout(hintTimer);
  const gen = generation;
  hintTimer = setTimeout(() => {
    const s = gameStore.get();
    if (gen !== generation || s.busy || s.result || !s.session || s.selected) return;
    const moves = findValidMoves(s.session.engine.board);
    if (moves.length) gameStore.set({ hint: moves[Math.floor(moves.length / 2)] });
  }, HINT_DELAY_MS);
}

/**
 * Applies a relic's in-run effect to the live board and logs it so the run stays replay-verifiable.
 * Charges are spent by the meta layer (activateRelic) before this is called.
 */
export async function applyRelicEffect(relicId: string, kind: RunBoost["kind"], value: number): Promise<boolean> {
  const s = gameStore.get();
  if (!s.session || s.busy || s.session.status === "won") return false;
  if (!run) return false;
  run.boosts.push({ atSwap: run.swaps.length, kind, value, source: "relic", relic: relicId });
  if (!run.relicsUsed.includes(relicId)) run.relicsUsed.push(relicId);
  if (kind === "hint") {
    const moves = findValidMoves(s.session.engine.board);
    if (moves.length) gameStore.set({ hint: moves[0] });
    return true;
  }
  if (kind === "moves") {
    const session = addMoves(s.session, value);
    gameStore.set({ session, result: null, hud: { ...s.hud, movesLeft: session.movesLeft } });
    return true;
  }
  const { session, placements } = reshuffleSession(s.session);
  const gen = generation;
  gameStore.set({ busy: true, selected: null, hint: null });
  await playSteps([{ kind: "shuffle", placements }], gen);
  if (gen === generation) gameStore.set({ session, busy: false, crystals: viewsFromSession(session) });
  return true;
}

/** Diagnostics helper. */
export function currentBoardHash(): string {
  const s = gameStore.get().session;
  return s ? boardHash(s.engine.board) : "-";
}
