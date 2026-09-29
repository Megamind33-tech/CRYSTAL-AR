import {
  cloneState,
  findMatches,
  get,
  hasValidMove,
  idx,
  inBounds,
  isAdjacent,
  isSolid,
  isVoid,
  matchable,
  newCrystal,
  randomType,
  reshuffle,
  set,
  specialForGroup,
  type EngineState,
} from "./board.ts";
import { nextFloat } from "./rng.ts";
import type {
  ActivatedSpecial,
  ClearedCrystal,
  ComboKind,
  CoverKind,
  CreatedSpecial,
  Crystal,
  CrystalType,
  FallMove,
  Gravity,
  ObstacleHit,
  Pos,
  ResolveStep,
  Spawned,
} from "./types.ts";

export interface SwapResult {
  valid: boolean;
  state: EngineState;
  steps: ResolveStep[];
}

const POINTS_PER_CRYSTAL = 10;
const POINTS_PER_SPECIAL = 40;
const POINTS_PER_HIT = 20;

/** Kind of ordinary crystal most common on the board – the target of a prism triggered by a match. */
function dominantType(s: EngineState): CrystalType {
  const counts = new Array(s.typeCount).fill(0);
  for (const c of s.board.cells) if (matchable(c)) counts[c.type]++;
  let best = 0;
  for (let t = 1; t < counts.length; t++) if (counts[t] > counts[best]) best = t;
  return best as CrystalType;
}

/**
 * Expands a seed clear set through special-crystal chain reactions.
 * Returns activations in the order they fired.
 */
function expandActivations(s: EngineState, clear: Set<number>, preActivated: Set<number>): ActivatedSpecial[] {
  const b = s.board;
  const activated: ActivatedSpecial[] = [];
  const queue = [...clear];
  const fired = new Set<number>(preActivated);
  while (queue.length) {
    const i = queue.shift()!;
    const c = b.cells[i];
    // relics never fire; a covered special is protected by its cover
    if (!c || c.special === "none" || c.special === "relic" || c.cover || fired.has(i)) continue;
    fired.add(i);
    const x = i % b.width, y = Math.floor(i / b.width);
    const add = (cx: number, cy: number) => {
      if (!inBounds(b, cx, cy)) return;
      const k = idx(b, cx, cy);
      if (!b.cells[k] || b.cells[k]!.special === "relic" || clear.has(k)) return;
      clear.add(k);
      queue.push(k);
    };
    if (c.special === "surgeH") {
      for (let cx = 0; cx < b.width; cx++) add(cx, y);
      activated.push({ id: c.id, x, y, special: c.special });
    } else if (c.special === "surgeV") {
      for (let cy = 0; cy < b.height; cy++) add(x, cy);
      activated.push({ id: c.id, x, y, special: c.special });
    } else if (c.special === "prism") {
      const target = dominantType(s);
      b.cells.forEach((o, k) => {
        if (matchable(o) && o.type === target) add(k % b.width, Math.floor(k / b.width));
      });
      activated.push({ id: c.id, x, y, special: c.special, targetType: target });
    }
  }
  return activated;
}

/**
 * Applies a clear set to the obstacles. Covered crystals lose a cover layer instead of clearing,
 * relics are immune, runes under cleared crystals wear down, and every stone orthogonally next to
 * the action cracks once. Mutates `clear` (removes protected cells) and the board.
 */
function hitObstacles(s: EngineState, clear: Set<number>): ObstacleHit[] {
  const b = s.board;
  const hits: ObstacleHit[] = [];
  const touched: number[] = [];
  for (const i of [...clear].sort((p, q) => p - q)) {
    const c = b.cells[i];
    const x = i % b.width, y = Math.floor(i / b.width);
    if (!c) continue;
    if (c.special === "relic") {
      clear.delete(i);
      continue;
    }
    touched.push(i);
    if (c.cover) {
      clear.delete(i);
      const hp = c.cover.hp - 1;
      b.cells[i] = hp > 0 ? { ...c, cover: { kind: c.cover.kind, hp } } : { id: c.id, type: c.type, special: c.special };
      hits.push({ x, y, layer: "cover", kind: c.cover.kind, hp, id: c.id });
      continue;
    }
    if (b.floor && b.floor[i] > 0) {
      b.floor[i]--;
      hits.push({ x, y, layer: "floor", kind: "rune", hp: b.floor[i] });
    }
  }
  if (b.block) {
    const cracked = new Set<number>();
    for (const i of touched) {
      const x = i % b.width, y = Math.floor(i / b.width);
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = x + dx, ny = y + dy;
        if (!inBounds(b, nx, ny)) continue;
        const k = idx(b, nx, ny);
        if (b.block[k] > 0) cracked.add(k);
      }
    }
    for (const k of [...cracked].sort((p, q) => p - q)) {
      b.block[k]--;
      hits.push({ x: k % b.width, y: Math.floor(k / b.width), layer: "block", kind: "stone", hp: b.block[k] });
    }
  }
  return hits;
}

function collectCleared(s: EngineState, clear: Set<number>): ClearedCrystal[] {
  const b = s.board;
  const out: ClearedCrystal[] = [];
  for (const i of [...clear].sort((p, q) => p - q)) {
    const c = b.cells[i];
    if (c) out.push({ ...c, x: i % b.width, y: Math.floor(i / b.width) });
  }
  return out;
}

/** Unit step in the direction crystals fall. */
export const GRAVITY_DIR: Record<Gravity, Pos> = { down: { x: 0, y: 1 }, left: { x: -1, y: 0 }, right: { x: 1, y: 0 } };

/**
 * Lines of cells along the gravity axis, each ordered upstream → downstream.
 * down: columns top→bottom · left: rows right→left · right: rows left→right.
 */
function gravityLines(b: { width: number; height: number }, g: Gravity): Pos[][] {
  const lines: Pos[][] = [];
  if (g === "down") {
    for (let x = 0; x < b.width; x++) lines.push(Array.from({ length: b.height }, (_, y) => ({ x, y })));
  } else {
    for (let y = 0; y < b.height; y++) {
      const row = Array.from({ length: b.width }, (_, x) => ({ x, y }));
      lines.push(g === "right" ? row : row.reverse());
    }
  }
  return lines;
}

/**
 * Settle + refill under the current gravity.
 * 1. Within each run of playable cells between voids, crystals slide downstream (voids are solid).
 * 2. New crystals enter only from the upstream edge, filling empty cells that have an open path
 *    to it. Cells sheltered by a void overhang stay empty – a Gravity Shift is how they get filled.
 */
function applyGravity(s: EngineState): ResolveStep {
  const b = s.board;
  const moves: FallMove[] = [];
  const spawned: Spawned[] = [];
  const d = GRAVITY_DIR[s.gravity];
  for (const line of gravityLines(b, s.gravity)) {
    // settle each void-separated segment toward its downstream end
    let seg: Pos[] = [];
    const flush = () => {
      const crystals = seg.map((p) => get(b, p.x, p.y)).filter((c): c is Crystal => !!c);
      for (const p of seg) set(b, p.x, p.y, null);
      // fill from the downstream end of the segment
      for (let i = 0; i < crystals.length; i++) {
        const to = seg[seg.length - 1 - i];
        const c = crystals[crystals.length - 1 - i];
        set(b, to.x, to.y, c);
        const from = findPos(c);
        if (from && (from.x !== to.x || from.y !== to.y)) moves.push({ id: c.id, fromX: from.x, fromY: from.y, toX: to.x, toY: to.y });
      }
      seg = [];
    };
    const before = new Map<number, Pos>();
    for (const p of line) {
      const c = get(b, p.x, p.y);
      if (c) before.set(c.id, p);
    }
    const findPos = (c: Crystal) => before.get(c.id);
    for (const p of line) {
      if (isSolid(b, p.x, p.y)) flush();
      else seg.push(p);
    }
    flush();
    // refill: empty playable cells reachable from the upstream edge (stop at the first solid/crystal)
    const open: Pos[] = [];
    for (const p of line) {
      if (isSolid(b, p.x, p.y) || get(b, p.x, p.y)) break;
      open.push(p);
    }
    const gaps = open.length;
    for (const p of open) {
      const relic = wantsRelic(s);
      const base = newCrystal(s, randomType(s));
      const c: Crystal = relic ? { ...base, special: "relic" } : base;
      if (relic) s.relics!.pending--;
      set(b, p.x, p.y, c);
      spawned.push({ ...c, x: p.x, y: p.y, fromX: p.x - d.x * gaps, fromY: p.y - d.y * gaps });
    }
  }
  return { kind: "fall", moves, spawned };
}

/** A Solar relic enters with the refill when fewer than the allowed number are on the board. */
function wantsRelic(s: EngineState): boolean {
  if (!s.relics || s.relics.pending <= 0) return false;
  const onBoard = s.board.cells.filter((c) => c?.special === "relic").length;
  return onBoard < s.relics.maxOnBoard;
}

/** Relics resting on the downstream edge of the board leave it (and count toward the objective). */
function collectRelics(s: EngineState): ResolveStep | null {
  const b = s.board;
  const d = GRAVITY_DIR[s.gravity];
  const collected: { id: number; x: number; y: number }[] = [];
  for (let y = 0; y < b.height; y++)
    for (let x = 0; x < b.width; x++) {
      const c = get(b, x, y);
      // the edge of the board, or a gap in the island, is where relics are gathered
      if (c?.special === "relic" && (!inBounds(b, x + d.x, y + d.y) || isVoid(b, x + d.x, y + d.y))) {
        collected.push({ id: c.id, x, y });
        set(b, x, y, null);
      }
    }
  return collected.length ? { kind: "relics", collected } : null;
}

/** Gravity + refill, then let any relics that reached the edge leave and refill again. */
function settle(s: EngineState, steps: ResolveStep[]) {
  steps.push(applyGravity(s));
  for (let guard = 0; guard < 10; guard++) {
    const r = collectRelics(s);
    if (!r) break;
    steps.push(r, applyGravity(s));
  }
}

function removeCleared(s: EngineState, clear: Set<number>) {
  for (const i of clear) s.board.cells[i] = null;
}

/** Runs match → clear → fall → refill until the board is stable. Mutates `s`. */
function cascade(s: EngineState, steps: ResolveStep[], startCascade: number, swapped: Pos[]) {
  const b = s.board;
  for (let n = startCascade; n < 50; n++) {
    const groups = findMatches(b);
    if (groups.length === 0) break;

    const clear = new Set<number>();
    const pendingSpecials: CreatedSpecial[] = [];
    for (const g of groups) {
      for (const p of g.cells) clear.add(idx(b, p.x, p.y));
      const special = specialForGroup(g);
      if (special !== "none") {
        const anchor =
          (n === 1 && g.cells.find((p) => swapped.some((q) => q.x === p.x && q.y === p.y))) ||
          g.cells[Math.floor(g.cells.length / 2)];
        pendingSpecials.push({ id: 0, x: anchor.x, y: anchor.y, special, type: g.type });
      }
    }
    const activated = expandActivations(s, clear, new Set());
    const hits = hitObstacles(s, clear);
    const cleared = collectCleared(s, clear);
    removeCleared(s, clear);
    const created = pendingSpecials
      .filter((p) => !get(b, p.x, p.y)) // the anchor cell kept its (covered) crystal
      .map((p) => {
        const c = newCrystal(s, p.type, p.special);
        set(b, p.x, p.y, c);
        return { ...p, id: c.id };
      });
    steps.push({
      kind: "clear",
      cascade: n,
      groups: groups.map((g) => ({ size: g.cells.length, longest: g.longest, type: g.type })),
      cleared,
      created,
      activated,
      score: (cleared.length * POINTS_PER_CRYSTAL + created.length * POINTS_PER_SPECIAL + hits.length * POINTS_PER_HIT) * n,
      ...(hits.length ? { hits } : {}),
    });
    settle(s, steps);
  }
  if (!hasValidMove(b)) {
    // sparse masked boards can run out of material: top up sheltered pockets, then reshuffle
    if (b.cells.filter(Boolean).length < b.cells.length * 0.6) steps.push(fillAllEmpty(s));
    steps.push({ kind: "shuffle", placements: reshuffle(s) });
  }
}

/** After crystals vanish outside a match (a thief), let the board fall, refill and resolve. Mutates `s`. */
export function refillAfterRemoval(s: EngineState, steps: ResolveStep[]) {
  settle(s, steps);
  cascade(s, steps, 1, []);
}

/** Special + special (or prism + anything) swaps fire immediately, without needing a match. */
function comboClear(s: EngineState, a: Pos, bPos: Pos): ResolveStep | null {
  const b = s.board;
  const ca = get(b, a.x, a.y)!, cb = get(b, bPos.x, bPos.y)!;
  if (ca.special === "relic" || cb.special === "relic") return null;
  const isSurge = (c: Crystal) => c.special === "surgeH" || c.special === "surgeV";
  let combo: ComboKind | null = null;
  const clear = new Set<number>([idx(b, a.x, a.y), idx(b, bPos.x, bPos.y)]);
  const pre = new Set<number>(clear);
  const activated: ActivatedSpecial[] = [];
  const addAll = (pred: (c: Crystal) => boolean) =>
    b.cells.forEach((c, k) => {
      if (c && pred(c)) clear.add(k);
    });

  if (ca.special === "prism" && cb.special === "prism") {
    combo = "prism+prism";
    addAll(() => true);
    activated.push({ id: ca.id, ...a, special: "prism" }, { id: cb.id, ...bPos, special: "prism" });
  } else if (ca.special === "prism" || cb.special === "prism") {
    const [prism, pp, other] = ca.special === "prism" ? [ca, a, cb] : [cb, bPos, ca];
    if (isSurge(other)) {
      combo = "prism+surge";
      // every crystal of the surge's kind becomes a surge and fires, including the swapped one
      pre.delete(idx(b, (pp === a ? bPos : a).x, (pp === a ? bPos : a).y));
      let flip = false;
      b.cells.forEach((c, k) => {
        if (matchable(c) && !c.cover && c.type === other.type) {
          if (c.special === "none") {
            b.cells[k] = { ...c, special: (flip = !flip) ? "surgeH" : "surgeV" };
          }
          clear.add(k);
        }
      });
    } else {
      combo = "prism+crystal";
      addAll((c) => matchable(c) && c.type === other.type);
    }
    activated.push({ id: prism.id, ...pp, special: "prism", targetType: other.type });
  } else if (isSurge(ca) && isSurge(cb)) {
    combo = "surge+surge";
    for (let x = 0; x < b.width; x++) clear.add(idx(b, x, bPos.y));
    for (let y = 0; y < b.height; y++) clear.add(idx(b, bPos.x, y));
    activated.push({ id: ca.id, ...a, special: ca.special }, { id: cb.id, ...bPos, special: cb.special });
  }
  if (!combo) return null;

  activated.push(...expandActivations(s, clear, pre));
  const hits = hitObstacles(s, clear);
  const cleared = collectCleared(s, clear);
  removeCleared(s, clear);
  return {
    kind: "clear",
    cascade: 1,
    groups: [],
    cleared,
    created: [],
    activated,
    combo,
    score: cleared.length * POINTS_PER_CRYSTAL * 2 + hits.length * POINTS_PER_HIT,
    ...(hits.length ? { hits } : {}),
  };
}

/** Deadlock recovery for masked boards: every empty playable cell receives a crystal where it is. */
function fillAllEmpty(s: EngineState): ResolveStep {
  const b = s.board;
  const spawned: Spawned[] = [];
  for (let y = 0; y < b.height; y++)
    for (let x = 0; x < b.width; x++) {
      if (isSolid(b, x, y) || get(b, x, y)) continue;
      const c = newCrystal(s, randomType(s));
      set(b, x, y, c);
      spawned.push({ ...c, x, y, fromX: x, fromY: y });
    }
  return { kind: "fall", moves: [], spawned };
}

export const GRAVITY_ORDER: Gravity[] = ["left", "down", "right"];
/** Next gravity when the tabletop is turned one step (-1 = counter-clockwise, +1 = clockwise). */
export function rotatedGravity(g: Gravity, turn: -1 | 1): Gravity | null {
  const i = GRAVITY_ORDER.indexOf(g) + turn;
  return i < 0 || i >= GRAVITY_ORDER.length ? null : GRAVITY_ORDER[i];
}

/**
 * GRAVITY SHIFT: changes the gravity vector, lets unsupported crystals slide, refills from the new
 * upstream edge, then resolves any matches/cascades the shift created. Never mutates the input.
 */
export function shiftGravity(input: EngineState, to: Gravity): SwapResult {
  if (to === input.gravity) return { valid: false, state: input, steps: [] };
  const s = cloneState(input);
  const steps: ResolveStep[] = [{ kind: "gravity", from: s.gravity, to }];
  s.gravity = to;
  settle(s, steps);
  cascade(s, steps, 1, []);
  return { valid: true, state: s, steps };
}

/**
 * Attempts to swap two adjacent crystals. Never mutates the input state.
 * Invalid swaps return `valid: false` with swap + revert steps so the renderer can animate the bounce.
 */
export function trySwap(input: EngineState, a: Pos, bPos: Pos): SwapResult {
  const s = cloneState(input);
  const b = s.board;
  const ca = get(b, a.x, a.y), cb = get(b, bPos.x, bPos.y);
  if (!inBounds(b, a.x, a.y) || !inBounds(b, bPos.x, bPos.y) || !isAdjacent(a, bPos) || !ca || !cb || ca.cover || cb.cover) {
    return { valid: false, state: input, steps: [] };
  }
  const swapStep: ResolveStep = { kind: "swap", a, b: bPos, aId: ca.id, bId: cb.id };

  set(b, a.x, a.y, cb);
  set(b, bPos.x, bPos.y, ca);

  // Combos are evaluated with the crystals in their swapped positions.
  const combo = comboClear(s, bPos, a);
  if (combo) {
    const steps: ResolveStep[] = [swapStep, combo];
    settle(s, steps);
    cascade(s, steps, 2, []);
    return { valid: true, state: s, steps };
  }

  if (findMatches(b).length === 0) {
    return {
      valid: false,
      state: input,
      steps: [swapStep, { kind: "revert", a, b: bPos, aId: ca.id, bId: cb.id }],
    };
  }
  const steps: ResolveStep[] = [swapStep];
  cascade(s, steps, 1, [a, bPos]);
  return { valid: true, state: s, steps };
}

/**
 * Embers and vines creep: one uncovered crystal next to an existing cover of `kind` catches it.
 * Deterministic (engine RNG). Returns null when nothing can spread. Never mutates the input.
 */
export function spreadCover(input: EngineState, kind: CoverKind): SwapResult | null {
  const s = cloneState(input);
  const b = s.board;
  const cands: number[] = [];
  b.cells.forEach((c, i) => {
    if (!c || c.cover || c.special !== "none") return;
    const x = i % b.width, y = Math.floor(i / b.width);
    const near = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => get(b, x + dx, y + dy)?.cover?.kind === kind);
    if (near) cands.push(i);
  });
  if (!cands.length) return null;
  const i = cands[Math.floor(nextFloat(s.rng) * cands.length)];
  const c = b.cells[i]!;
  b.cells[i] = { ...c, cover: { kind, hp: 1 } };
  const steps: ResolveStep[] = [{ kind: "spread", cells: [{ id: c.id, x: i % b.width, y: Math.floor(i / b.width), cover: kind }] }];
  if (!hasValidMove(b)) steps.push({ kind: "shuffle", placements: reshuffle(s) });
  return { valid: true, state: s, steps };
}
