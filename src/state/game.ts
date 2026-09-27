// Game controller: runs the pure engine, then plays its ResolveSteps back as timed view states.
// Renderers (AR and mock) only read `gameStore`; audio/haptics subscribe to `gameEvents`.
import { boardHash, isAdjacent } from "../game/board.ts";
import { chargeForStep, LEVELS, objectiveProgress, playMove, startSession, starsFor, type Session } from "../game/level.ts";
import { eventsForStep, stageForProgress, type WorldEvent, type WorldStage } from "../game/reactions.ts";
import type { CrystalType, Pos, ResolveStep, Special } from "../game/types.ts";
import { neighbourToward } from "../render/layout.ts";
import { createStore } from "./store.ts";

export type Anim =
  | { kind: "move"; fromX: number; fromY: number; ms: number; seq: number }
  | { kind: "spawn"; fromY: number; ms: number; seq: number }
  | { kind: "pop"; ms: number; seq: number }
  | { kind: "forge"; ms: number; seq: number };

export interface CrystalView {
  id: number;
  type: CrystalType;
  special: Special;
  x: number;
  y: number;
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
}

export interface GameState {
  levelIndex: number;
  session: Session | null;
  crystals: CrystalView[];
  selected: Pos | null;
  busy: boolean;
  hud: Hud;
  progress: number;
  stage: WorldStage;
  reactions: Record<WorldEvent, number>;
  bursts: Burst[];
  comboText: { text: string; seq: number } | null;
  result: { won: boolean; stars: number } | null;
  lastMatch: string;
  moveCount: number;
}

const emptyReactions = (): Record<WorldEvent, number> => ({
  MATCH_3: 0, MATCH_4: 0, MATCH_5: 0, CASCADE_2: 0, CASCADE_3: 0, CASCADE_4_PLUS: 0,
  SPECIAL_CREATED: 0, SPECIAL_ACTIVATED: 0, COMBO: 0, LEVEL_COMPLETE: 0,
});

export const gameStore = createStore<GameState>({
  levelIndex: 0,
  session: null,
  crystals: [],
  selected: null,
  busy: false,
  hud: { score: 0, movesLeft: 0, charge: 0, collected: [0, 0, 0, 0, 0] },
  progress: 0,
  stage: 0,
  reactions: emptyReactions(),
  bursts: [],
  comboText: null,
  result: null,
  lastMatch: "-",
  moveCount: 0,
});

// ---- side-effect channel (audio, haptics, analytics) -----------------------
export type GameEvent =
  | { type: "sfx"; name: SfxName }
  | { type: "haptic"; kind: "light" | "medium" | "heavy" | "success" | "error" }
  | { type: "levelEnd"; won: boolean; stars: number; level: number };
export type SfxName =
  | "select" | "swap" | "invalid" | "match1" | "match2" | "match3" | "match4"
  | "special_create" | "special_activate" | "place" | "complete" | "portal";

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
export const TIMING = { swap: 170, pop: 230, forge: 280, fallBase: 120, fallPerRow: 55, shuffle: 420, cascadeGap: 70 };
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
    if (c) out.push({ id: c.id, type: c.type, special: c.special, x: i % b.width, y: Math.floor(i / b.width) });
  });
  return out;
};

export function startLevel(levelIndex: number, seedOverride?: number) {
  generation++;
  const level = LEVELS[Math.max(0, Math.min(LEVELS.length - 1, levelIndex))];
  const session = startSession(level, seedOverride);
  gameStore.set({
    levelIndex: LEVELS.indexOf(level),
    session,
    crystals: viewsFromSession(session).map((c) => ({ ...c, anim: { kind: "spawn", fromY: c.y - 7, ms: 380 + c.y * 40, seq: seq++ } })),
    selected: null,
    busy: false,
    hud: { score: 0, movesLeft: session.movesLeft, charge: 0, collected: [0, 0, 0, 0, 0] },
    progress: 0,
    stage: 0,
    reactions: emptyReactions(),
    bursts: [],
    comboText: null,
    result: null,
    lastMatch: "-",
    moveCount: 0,
  });
}

export const restartLevel = () => startLevel(gameStore.get().levelIndex);

/** After the world is re-placed, replay the entrance so crystals rise into the new spot. */
export function respawnView() {
  gameStore.set((s) => ({
    selected: null,
    crystals: s.crystals.map((c) => ({ ...c, anim: { kind: "spawn" as const, fromY: c.y - 7, ms: 380 + c.y * 40, seq: seq++ } })),
  }));
}

/** Leaving the level: drop the session so the next play starts clean. */
export function endSession() {
  generation++;
  gameStore.set({ session: null, crystals: [], selected: null, busy: false, result: null, bursts: [] });
}

/** CLICK_DOWN on a cell: select it (or complete a tap-tap swap). */
export function pressCell(p: Pos) {
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
  const gen = generation;
  gameStore.set({ busy: true, selected: null });
  await playSteps(r.steps, gen);
  if (gen !== generation) return;
  const session = r.session;
  const progress = objectiveProgress(session);
  let result: GameState["result"] = null;
  if (session.status !== "playing") {
    result = { won: session.status === "won", stars: starsFor(session) };
    if (result.won) {
      bumpReactions(["LEVEL_COMPLETE"]);
      gameEvents.emit({ type: "sfx", name: "complete" });
      gameEvents.emit({ type: "haptic", kind: "success" });
    }
    gameEvents.emit({ type: "levelEnd", won: result.won, stars: result.stars, level: session.level.id });
  }
  gameStore.set({
    session,
    busy: false,
    crystals: viewsFromSession(session),
    hud: { score: session.score, movesLeft: session.movesLeft, charge: session.charge, collected: session.collected },
    progress,
    stage: stageForProgress(progress),
    result,
    moveCount: s.moveCount + (r.valid ? 1 : 0),
  });
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
        setCrystals((cs) => cs.map((c) => (ids.has(c.id) ? { ...c, anim: { kind: "pop", ms: TIMING.pop, seq: seq++ } } : c)));
        const cascadeLevel = Math.min(4, step.cascade) as 1 | 2 | 3 | 4;
        gameEvents.emit({ type: "sfx", name: `match${cascadeLevel}` });
        if (step.activated.length) gameEvents.emit({ type: "sfx", name: "special_activate" });
        gameEvents.emit({ type: "haptic", kind: step.activated.length || step.cascade >= 3 ? "heavy" : "medium" });
        bumpReactions(eventsForStep(step));

        const big = step.cleared.length > 12;
        const bursts: Burst[] = (big ? step.cleared.filter((_, i) => i % 3 === 0) : step.cleared).map((c) => ({
          id: burstId++, x: c.x, y: c.y, type: c.type, big: c.special !== "none",
        }));
        const text =
          step.combo ? "Resonance!" : step.cascade >= 4 ? "Crystal Storm!" : step.cascade === 3 ? "Radiant!" : step.cascade === 2 ? "Chain!" : null;
        gameStore.set((s) => {
          const hud = { ...s.hud, collected: s.hud.collected.slice() };
          hud.score += step.score;
          hud.charge += chargeForStep(step);
          for (const c of step.cleared) hud.collected[c.type]++;
          const session = s.session!;
          const o = session.level.objective;
          const v = o.kind === "power" ? hud.charge : o.kind === "score" ? hud.score : hud.collected[o.crystal];
          const progress = Math.min(1, v / o.target);
          const stage = stageForProgress(progress);
          if (stage > s.stage) gameEvents.emit({ type: "sfx", name: "portal" });
          return {
            hud,
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
            const ms = dur(m.toY - m.fromY);
            longest = Math.max(longest, ms);
            return { ...c, y: m.toY, anim: { kind: "move" as const, fromX: c.x, fromY: m.fromY, ms, seq: seq++ } };
          }),
          ...step.spawned.map((sp) => {
            const ms = dur(sp.y - sp.fromY) + 40;
            longest = Math.max(longest, ms);
            return { id: sp.id, type: sp.type, special: sp.special, x: sp.x, y: sp.y, anim: { kind: "spawn" as const, fromY: sp.fromY, ms, seq: seq++ } };
          }),
        ]);
        if (!(await sleep(longest + TIMING.cascadeGap))) return;
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

/** Diagnostics helper. */
export function currentBoardHash(): string {
  const s = gameStore.get().session;
  return s ? boardHash(s.engine.board) : "-";
}
