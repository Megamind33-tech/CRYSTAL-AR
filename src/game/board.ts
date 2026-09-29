import { nextFloat, nextInt } from "./rng.ts";
import type { Board, CoverKind, Crystal, CrystalType, Gravity, MatchGroup, Pos, Rng, Special } from "./types.ts";

export interface EngineState {
  board: Board;
  rng: Rng;
  nextId: number;
  typeCount: number;
  gravity: Gravity;
  /** optional spawn weights per crystal kind (e.g. an emerald-rich canyon) */
  weights?: number[];
  /** Solar relics still to enter the board, and how many may be on it at once */
  relics?: { pending: number; maxOnBoard: number };
}

/** Level obstacles placed when the board is created (all coordinates board cells). */
export interface BoardSetup {
  /** cracked stone [x, y, hp] */
  blocks?: [number, number, number][];
  /** buried runes [x, y, layers] */
  floor?: [number, number, number][];
  /** covers on the starting crystals [x, y, kind, hp] */
  covers?: [number, number, CoverKind, number][];
  /** Solar relics to bring down to the bottom edge */
  relics?: { total: number; maxOnBoard: number };
}

/** Relics and prisms never form part of a match. */
export const matchable = (c: Crystal | null): c is Crystal => !!c && c.special !== "prism" && c.special !== "relic";

export const isVoid = (b: Board, x: number, y: number) => !!b.void?.[idx(b, x, y)];
export const blockHp = (b: Board, x: number, y: number) => b.block?.[idx(b, x, y)] ?? 0;
export const floorHp = (b: Board, x: number, y: number) => b.floor?.[idx(b, x, y)] ?? 0;
/** Void terrain or unbroken stone: holds no crystal and stops falling crystals. */
export const isSolid = (b: Board, x: number, y: number) => isVoid(b, x, y) || blockHp(b, x, y) > 0;

/** Parse a level mask: rows of "O" (playable) / "X" (void). */
export function parseMask(rows: string[] | undefined, width: number, height: number): boolean[] | undefined {
  if (!rows) return undefined;
  const m: boolean[] = [];
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) m.push((rows[y]?.[x] ?? "O").toUpperCase() === "X");
  return m;
}

export const idx = (b: Board, x: number, y: number) => y * b.width + x;
export const inBounds = (b: Board, x: number, y: number) =>
  x >= 0 && y >= 0 && x < b.width && y < b.height;
export const get = (b: Board, x: number, y: number): Crystal | null =>
  inBounds(b, x, y) ? b.cells[idx(b, x, y)] : null;
export const set = (b: Board, x: number, y: number, c: Crystal | null) => {
  b.cells[idx(b, x, y)] = c;
};
export const isAdjacent = (a: Pos, b: Pos) => Math.abs(a.x - b.x) + Math.abs(a.y - b.y) === 1;

export function cloneBoard(b: Board): Board {
  return { width: b.width, height: b.height, cells: b.cells.slice(), void: b.void, block: b.block?.slice(), floor: b.floor?.slice() };
}

export function cloneState(s: EngineState): EngineState {
  return { board: cloneBoard(s.board), rng: { state: s.rng.state }, nextId: s.nextId, typeCount: s.typeCount, gravity: s.gravity, weights: s.weights, relics: s.relics && { ...s.relics } };
}

export function newCrystal(s: EngineState, type: CrystalType, special: Special = "none"): Crystal {
  return { id: s.nextId++, type, special };
}

export function randomType(s: EngineState): CrystalType {
  if (!s.weights) return nextInt(s.rng, s.typeCount) as CrystalType;
  const total = s.weights.reduce((a, b) => a + b, 0);
  let r = nextFloat(s.rng) * total;
  for (let t = 0; t < s.typeCount; t++) {
    r -= s.weights[t] ?? 1;
    if (r < 0) return t as CrystalType;
  }
  return (s.typeCount - 1) as CrystalType;
}

/** Would placing `type` at (x,y) complete a run of 3 with the two cells left or above? */
function makesRunBackward(b: Board, x: number, y: number, type: CrystalType): boolean {
  const l1 = get(b, x - 1, y), l2 = get(b, x - 2, y);
  if (l1 && l2 && l1.type === type && l2.type === type) return true;
  const u1 = get(b, x, y - 1), u2 = get(b, x, y - 2);
  return !!(u1 && u2 && u1.type === type && u2.type === type);
}

/** Creates a board with no pre-existing matches and at least one valid move. Void cells stay empty. */
export function createEngine(width: number, height: number, typeCount: number, rng: Rng, mask?: boolean[], weights?: number[], setup?: BoardSetup): EngineState {
  const block = setup?.blocks?.length ? new Array(width * height).fill(0) : undefined;
  for (const [x, y, hp] of setup?.blocks ?? []) block![y * width + x] = hp;
  const floor = setup?.floor?.length ? new Array(width * height).fill(0) : undefined;
  for (const [x, y, hp] of setup?.floor ?? []) floor![y * width + x] = hp;
  const s: EngineState = {
    board: { width, height, cells: new Array(width * height).fill(null), void: mask, block, floor },
    rng,
    nextId: 1,
    typeCount,
    gravity: "down",
    weights,
  };
  for (let attempt = 0; attempt < 100; attempt++) {
    s.nextId = 1;
    s.board.cells.fill(null);
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (isSolid(s.board, x, y)) continue;
        let type = randomType(s);
        for (let guard = 0; makesRunBackward(s.board, x, y, type) && guard < 20; guard++) {
          type = randomType(s);
        }
        set(s.board, x, y, newCrystal(s, type));
      }
    }
    applySetup(s, setup);
    if (findMatches(s.board).length === 0 && hasValidMove(s.board)) return s;
  }
  throw new Error("createEngine: could not generate a playable board");
}

function applySetup(s: EngineState, setup?: BoardSetup) {
  const b = s.board;
  for (const [x, y, kind, hp] of setup?.covers ?? []) {
    const c = get(b, x, y);
    if (c) set(b, x, y, { ...c, cover: { kind, hp } });
  }
  if (setup?.relics && setup.relics.total > 0) {
    // starting relics sit on the far row, spread across the columns that can carry them down
    const open: number[] = [];
    for (let x = 0; x < b.width; x++) if (get(b, x, 0)) open.push(x);
    const first = Math.min(setup.relics.maxOnBoard, setup.relics.total, open.length);
    for (let i = 0; i < first; i++) {
      const x = open[Math.floor(((i + 0.5) * open.length) / first)];
      const c = get(b, x, 0)!;
      set(b, x, 0, { id: c.id, type: c.type, special: "relic" });
    }
    s.relics = { pending: setup.relics.total - first, maxOnBoard: setup.relics.maxOnBoard };
  }
}

/** Build a board from explicit type rows (tests / authored levels). Row strings use digits 0-4. */
export function engineFromRows(rows: string[], typeCount: number, rng: Rng): EngineState {
  const height = rows.length;
  const width = rows[0].length;
  const s: EngineState = { board: { width, height, cells: [] }, rng, nextId: 1, typeCount, gravity: "down" };
  const mask = rows.join("").includes("#") ? rows.flatMap((r) => [...r].map((c) => c === "#")) : undefined;
  s.board.void = mask;
  // "S" = cracked stone (1 hp), "R" = Solar relic
  if (rows.join("").includes("S")) s.board.block = rows.flatMap((r) => [...r].map((c) => (c === "S" ? 1 : 0)));
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const ch = rows[y][x];
      if (ch === "." || ch === "#" || ch === "S") {
        s.board.cells.push(null);
        continue;
      }
      const special: Special = ch === "P" ? "prism" : ch === "R" ? "relic" : "none";
      s.board.cells.push(newCrystal(s, (special === "none" ? Number(ch) : 0) as CrystalType, special));
    }
  }
  return s;
}

interface Run {
  cells: Pos[];
  horizontal: boolean;
  type: CrystalType;
}

/** Finds all runs of 3+ and merges runs that share a cell (L / T shapes) into one group. */
export function findMatches(b: Board): MatchGroup[] {
  const runs: Run[] = [];
  const scan = (horizontal: boolean) => {
    const outer = horizontal ? b.height : b.width;
    const inner = horizontal ? b.width : b.height;
    for (let o = 0; o < outer; o++) {
      let start = 0;
      for (let i = 1; i <= inner; i++) {
        const at = (k: number) => (horizontal ? get(b, k, o) : get(b, o, k));
        const cur = i < inner ? at(i) : null;
        const first = at(start);
        const same = matchable(cur) && matchable(first) && cur.type === first.type;
        if (!same) {
          if (matchable(first) && i - start >= 3) {
            const cells: Pos[] = [];
            for (let k = start; k < i; k++) cells.push(horizontal ? { x: k, y: o } : { x: o, y: k });
            runs.push({ cells, horizontal, type: first.type });
          }
          start = i;
        }
      }
    }
  };
  scan(true);
  scan(false);

  // union runs sharing any cell
  const parent = runs.map((_, i) => i);
  const find = (i: number): number => (parent[i] === i ? i : (parent[i] = find(parent[i])));
  const owner = new Map<number, number>();
  runs.forEach((run, ri) => {
    for (const p of run.cells) {
      const key = idx(b, p.x, p.y);
      const prev = owner.get(key);
      if (prev !== undefined) parent[find(ri)] = find(prev);
      else owner.set(key, ri);
    }
  });

  const groups = new Map<number, MatchGroup>();
  runs.forEach((run, ri) => {
    const root = find(ri);
    let g = groups.get(root);
    if (!g) {
      g = { cells: [], type: run.type, longest: 0, horizontal: false, vertical: false };
      groups.set(root, g);
    }
    for (const p of run.cells) {
      if (!g.cells.some((c) => c.x === p.x && c.y === p.y)) g.cells.push(p);
    }
    g.longest = Math.max(g.longest, run.cells.length);
    if (run.horizontal) g.horizontal = true;
    else g.vertical = true;
  });
  return [...groups.values()];
}

/** Special produced by a match group, if any. */
export function specialForGroup(g: MatchGroup): Special {
  if (g.longest >= 5) return "prism";
  if (g.horizontal && g.vertical && g.cells.length >= 5) return "prism";
  if (g.longest === 4) return g.horizontal ? "surgeH" : "surgeV";
  return "none";
}

function lineLength(b: Board, x: number, y: number, dx: number, dy: number, type: CrystalType): number {
  let n = 0;
  for (let cx = x + dx, cy = y + dy; ; cx += dx, cy += dy) {
    const c = get(b, cx, cy);
    if (!matchable(c) || c.type !== type) return n;
    n++;
  }
}

/** True if the crystal at (x,y) is part of a horizontal or vertical run of 3+. */
export function matchAt(b: Board, x: number, y: number): boolean {
  const c = get(b, x, y);
  if (!matchable(c)) return false;
  const h = 1 + lineLength(b, x, y, -1, 0, c.type) + lineLength(b, x, y, 1, 0, c.type);
  const v = 1 + lineLength(b, x, y, 0, -1, c.type) + lineLength(b, x, y, 0, 1, c.type);
  return h >= 3 || v >= 3;
}

/** A swap is productive if it creates a match or triggers a special combination. */
export function isProductiveSwap(b: Board, a: Pos, c: Pos): boolean {
  if (!inBounds(b, a.x, a.y) || !inBounds(b, c.x, c.y) || !isAdjacent(a, c)) return false;
  const ca = get(b, a.x, a.y), cc = get(b, c.x, c.y);
  if (!ca || !cc || ca.cover || cc.cover) return false; // covered crystals are locked in place
  const relic = ca.special === "relic" || cc.special === "relic";
  if (!relic && (ca.special === "prism" || cc.special === "prism")) return true;
  if (!relic && ca.special !== "none" && cc.special !== "none") return true;
  set(b, a.x, a.y, cc);
  set(b, c.x, c.y, ca);
  const ok = matchAt(b, a.x, a.y) || matchAt(b, c.x, c.y);
  set(b, a.x, a.y, ca);
  set(b, c.x, c.y, cc);
  return ok;
}

export function findValidMoves(b: Board): [Pos, Pos][] {
  const moves: [Pos, Pos][] = [];
  for (let y = 0; y < b.height; y++) {
    for (let x = 0; x < b.width; x++) {
      if (x + 1 < b.width && isProductiveSwap(b, { x, y }, { x: x + 1, y })) moves.push([{ x, y }, { x: x + 1, y }]);
      if (y + 1 < b.height && isProductiveSwap(b, { x, y }, { x, y: y + 1 })) moves.push([{ x, y }, { x, y: y + 1 }]);
    }
  }
  return moves;
}

export function hasValidMove(b: Board): boolean {
  for (let y = 0; y < b.height; y++) {
    for (let x = 0; x < b.width; x++) {
      if (x + 1 < b.width && isProductiveSwap(b, { x, y }, { x: x + 1, y })) return true;
      if (y + 1 < b.height && isProductiveSwap(b, { x, y }, { x, y: y + 1 })) return true;
    }
  }
  return false;
}

/**
 * Rearranges existing crystals (ids preserved) into a match-free, playable layout.
 * Falls back to re-rolling ordinary crystal kinds if permutation alone fails.
 */
export function reshuffle(s: EngineState): { id: number; x: number; y: number }[] {
  const b = s.board;
  const free = (c: Crystal | null): c is Crystal => !!c && !c.cover && c.special !== "relic";
  const crystals = b.cells.filter(free);
  for (let attempt = 0; attempt < 200; attempt++) {
    const pool = crystals.slice();
    if (attempt >= 100) {
      for (let i = 0; i < pool.length; i++) {
        if (pool[i].special === "none") pool[i] = { ...pool[i], type: randomType(s) };
      }
    }
    for (let i = pool.length - 1; i > 0; i--) {
      const j = nextInt(s.rng, i + 1);
      [pool[i], pool[j]] = [pool[j], pool[i]];
    }
    let k = 0;
    for (let i = 0; i < b.cells.length; i++) if (free(b.cells[i])) b.cells[i] = pool[k++];
    if (findMatches(b).length === 0 && hasValidMove(b)) break;
  }
  const out: { id: number; x: number; y: number }[] = [];
  for (let y = 0; y < b.height; y++)
    for (let x = 0; x < b.width; x++) {
      const c = get(b, x, y);
      if (c) out.push({ id: c.id, x, y });
    }
  return out;
}

/** Short stable hash of the board (diagnostics / determinism tests). */
export function boardHash(b: Board): string {
  let h = 2166136261;
  for (const c of b.cells) {
    const v = c ? c.type * 4 + ["none", "surgeH", "surgeV", "prism"].indexOf(c.special) + 1 : 0;
    h = Math.imul(h ^ v, 16777619);
  }
  return (h >>> 0).toString(16).padStart(8, "0");
}

export function boardToRows(b: Board): string[] {
  const rows: string[] = [];
  for (let y = 0; y < b.height; y++) {
    let r = "";
    for (let x = 0; x < b.width; x++) {
      const c = get(b, x, y);
      r += isVoid(b, x, y) ? "#" : blockHp(b, x, y) ? "S" : !c ? "." : c.special === "prism" ? "P" : c.special === "relic" ? "R" : String(c.type);
    }
    rows.push(r);
  }
  return rows;
}
