import { nextInt } from "./rng.ts";
import type { Board, Crystal, CrystalType, MatchGroup, Pos, Rng, Special } from "./types.ts";

export interface EngineState {
  board: Board;
  rng: Rng;
  nextId: number;
  typeCount: number;
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
  return { width: b.width, height: b.height, cells: b.cells.slice() };
}

export function cloneState(s: EngineState): EngineState {
  return { board: cloneBoard(s.board), rng: { state: s.rng.state }, nextId: s.nextId, typeCount: s.typeCount };
}

export function newCrystal(s: EngineState, type: CrystalType, special: Special = "none"): Crystal {
  return { id: s.nextId++, type, special };
}

export function randomType(s: EngineState): CrystalType {
  return nextInt(s.rng, s.typeCount) as CrystalType;
}

/** Would placing `type` at (x,y) complete a run of 3 with the two cells left or above? */
function makesRunBackward(b: Board, x: number, y: number, type: CrystalType): boolean {
  const l1 = get(b, x - 1, y), l2 = get(b, x - 2, y);
  if (l1 && l2 && l1.type === type && l2.type === type) return true;
  const u1 = get(b, x, y - 1), u2 = get(b, x, y - 2);
  return !!(u1 && u2 && u1.type === type && u2.type === type);
}

/** Creates a board with no pre-existing matches and at least one valid move. */
export function createEngine(width: number, height: number, typeCount: number, rng: Rng): EngineState {
  const s: EngineState = {
    board: { width, height, cells: new Array(width * height).fill(null) },
    rng,
    nextId: 1,
    typeCount,
  };
  for (let attempt = 0; attempt < 100; attempt++) {
    s.nextId = 1;
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        let type = randomType(s);
        for (let guard = 0; makesRunBackward(s.board, x, y, type) && guard < 20; guard++) {
          type = randomType(s);
        }
        set(s.board, x, y, newCrystal(s, type));
      }
    }
    if (findMatches(s.board).length === 0 && hasValidMove(s.board)) return s;
  }
  throw new Error("createEngine: could not generate a playable board");
}

/** Build a board from explicit type rows (tests / authored levels). Row strings use digits 0-4. */
export function engineFromRows(rows: string[], typeCount: number, rng: Rng): EngineState {
  const height = rows.length;
  const width = rows[0].length;
  const s: EngineState = { board: { width, height, cells: [] }, rng, nextId: 1, typeCount };
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const ch = rows[y][x];
      if (ch === ".") {
        s.board.cells.push(null);
        continue;
      }
      const special: Special = ch === "P" ? "prism" : "none";
      s.board.cells.push(newCrystal(s, (special === "prism" ? 0 : Number(ch)) as CrystalType, special));
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
        const same = cur && first && cur.special !== "prism" && first.special !== "prism" && cur.type === first.type;
        if (!same) {
          if (first && first.special !== "prism" && i - start >= 3) {
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
    if (!c || c.special === "prism" || c.type !== type) return n;
    n++;
  }
}

/** True if the crystal at (x,y) is part of a horizontal or vertical run of 3+. */
export function matchAt(b: Board, x: number, y: number): boolean {
  const c = get(b, x, y);
  if (!c || c.special === "prism") return false;
  const h = 1 + lineLength(b, x, y, -1, 0, c.type) + lineLength(b, x, y, 1, 0, c.type);
  const v = 1 + lineLength(b, x, y, 0, -1, c.type) + lineLength(b, x, y, 0, 1, c.type);
  return h >= 3 || v >= 3;
}

/** A swap is productive if it creates a match or triggers a special combination. */
export function isProductiveSwap(b: Board, a: Pos, c: Pos): boolean {
  if (!inBounds(b, a.x, a.y) || !inBounds(b, c.x, c.y) || !isAdjacent(a, c)) return false;
  const ca = get(b, a.x, a.y), cc = get(b, c.x, c.y);
  if (!ca || !cc) return false;
  if (ca.special === "prism" || cc.special === "prism") return true;
  if (ca.special !== "none" && cc.special !== "none") return true;
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
  const crystals = b.cells.filter((c): c is Crystal => !!c);
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
    for (let i = 0; i < b.cells.length; i++) if (b.cells[i]) b.cells[i] = pool[k++];
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
      r += !c ? "." : c.special === "prism" ? "P" : String(c.type);
    }
    rows.push(r);
  }
  return rows;
}
