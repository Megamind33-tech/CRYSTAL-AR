import {
  cloneState,
  findMatches,
  get,
  hasValidMove,
  idx,
  inBounds,
  isAdjacent,
  newCrystal,
  randomType,
  reshuffle,
  set,
  specialForGroup,
  type EngineState,
} from "./board.ts";
import type {
  ActivatedSpecial,
  ClearedCrystal,
  ComboKind,
  CreatedSpecial,
  Crystal,
  CrystalType,
  FallMove,
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

/** Kind of ordinary crystal most common on the board – the target of a prism triggered by a match. */
function dominantType(s: EngineState): CrystalType {
  const counts = new Array(s.typeCount).fill(0);
  for (const c of s.board.cells) if (c && c.special !== "prism") counts[c.type]++;
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
    if (!c || c.special === "none" || fired.has(i)) continue;
    fired.add(i);
    const x = i % b.width, y = Math.floor(i / b.width);
    const add = (cx: number, cy: number) => {
      if (!inBounds(b, cx, cy)) return;
      const k = idx(b, cx, cy);
      if (!b.cells[k] || clear.has(k)) return;
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
        if (o && o.special !== "prism" && o.type === target) add(k % b.width, Math.floor(k / b.width));
      });
      activated.push({ id: c.id, x, y, special: c.special, targetType: target });
    }
  }
  return activated;
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

/** Gravity toward y = height-1, then spawn new crystals into the gaps at the top. */
function applyGravity(s: EngineState): ResolveStep {
  const b = s.board;
  const moves: FallMove[] = [];
  const spawned: Spawned[] = [];
  for (let x = 0; x < b.width; x++) {
    let write = b.height - 1;
    for (let y = b.height - 1; y >= 0; y--) {
      const c = get(b, x, y);
      if (!c) continue;
      if (write !== y) {
        set(b, x, write, c);
        set(b, x, y, null);
        moves.push({ id: c.id, x, fromY: y, toY: write });
      }
      write--;
    }
    const gaps = write + 1;
    for (let y = 0; y < gaps; y++) {
      const c = newCrystal(s, randomType(s));
      set(b, x, y, c);
      spawned.push({ ...c, x, y, fromY: y - gaps });
    }
  }
  return { kind: "fall", moves, spawned };
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
    const cleared = collectCleared(s, clear);
    removeCleared(s, clear);
    const created = pendingSpecials.map((p) => {
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
      score: (cleared.length * POINTS_PER_CRYSTAL + created.length * POINTS_PER_SPECIAL) * n,
    });
    steps.push(applyGravity(s));
  }
  if (!hasValidMove(b)) steps.push({ kind: "shuffle", placements: reshuffle(s) });
}

/** Special + special (or prism + anything) swaps fire immediately, without needing a match. */
function comboClear(s: EngineState, a: Pos, bPos: Pos): ResolveStep | null {
  const b = s.board;
  const ca = get(b, a.x, a.y)!, cb = get(b, bPos.x, bPos.y)!;
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
        if (c && c.special !== "prism" && c.type === other.type) {
          if (c.special === "none") {
            b.cells[k] = { ...c, special: (flip = !flip) ? "surgeH" : "surgeV" };
          }
          clear.add(k);
        }
      });
    } else {
      combo = "prism+crystal";
      addAll((c) => c.special !== "prism" && c.type === other.type);
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
    score: cleared.length * POINTS_PER_CRYSTAL * 2,
  };
}

/**
 * Attempts to swap two adjacent crystals. Never mutates the input state.
 * Invalid swaps return `valid: false` with swap + revert steps so the renderer can animate the bounce.
 */
export function trySwap(input: EngineState, a: Pos, bPos: Pos): SwapResult {
  const s = cloneState(input);
  const b = s.board;
  const ca = get(b, a.x, a.y), cb = get(b, bPos.x, bPos.y);
  if (!inBounds(b, a.x, a.y) || !inBounds(b, bPos.x, bPos.y) || !isAdjacent(a, bPos) || !ca || !cb) {
    return { valid: false, state: input, steps: [] };
  }
  const swapStep: ResolveStep = { kind: "swap", a, b: bPos, aId: ca.id, bId: cb.id };

  set(b, a.x, a.y, cb);
  set(b, bPos.x, bPos.y, ca);

  // Combos are evaluated with the crystals in their swapped positions.
  const combo = comboClear(s, bPos, a);
  if (combo) {
    const steps: ResolveStep[] = [swapStep, combo, applyGravity(s)];
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
