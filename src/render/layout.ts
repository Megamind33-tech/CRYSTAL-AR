// Deterministic mapping between logical board cells and the miniature world's local space.
// Pure math: no React / Viro, so it is unit-tested and shared by AR and mock renderers.
//
// Hierarchy:  AR plane anchor → world root (yaw + scale) → board group (offset + tilt) → crystals
// World-local frame: origin = island centre on the table, +Y up, +Z toward the player.

export const BOARD_SIZE = 6;
export const CELL = 0.052; // metres between crystal centres (keep in sync with scripts/gen-models.mjs)
export const SURFACE_Y = 0.04; // top of the island terrain
export const BOARD_TILT_DEG = 10; // far edge raised so the board faces the player
export const BOARD_OFFSET: [number, number, number] = [0, SURFACE_Y + 0.034, 0.05];
export const GEM_LIFT = 0.018; // crystal centre height above the tiles
export const GEM_SCALE = 0.036;
export const GEM_TILT_DEG = -28; // lean gems back so their faces look up toward the player

/** Board-local position of a cell centre. Row y = 0 is the far edge; rows beyond it (y < 0) are spawn lanes. */
export function cellToLocal(x: number, y: number): [number, number, number] {
  const half = (BOARD_SIZE - 1) / 2;
  const h = y < 0 ? GEM_LIFT - y * 0.012 : GEM_LIFT; // spawn lanes arc slightly upward
  return [round((x - half) * CELL), round(h), round((y - half) * CELL)];
}

/** Board-local (x, z) back to the nearest cell, or null if outside the board. */
export function localToCell(lx: number, lz: number): { x: number; y: number } | null {
  const half = (BOARD_SIZE - 1) / 2;
  const x = Math.round(lx / CELL + half);
  const y = Math.round(lz / CELL + half);
  return x >= 0 && y >= 0 && x < BOARD_SIZE && y < BOARD_SIZE ? { x, y } : null;
}

/** Position of a board-local point in world-local space (applies the board tilt and offset). */
export function boardToWorld(p: [number, number, number]): [number, number, number] {
  const a = (BOARD_TILT_DEG * Math.PI) / 180;
  // Board group rotation is [BOARD_TILT_DEG, 0, 0]: a positive X rotation lifts -Z (the far edge).
  const y = p[1] * Math.cos(a) - p[2] * Math.sin(a);
  const z = p[1] * Math.sin(a) + p[2] * Math.cos(a);
  return [round(p[0] + BOARD_OFFSET[0]), round(y + BOARD_OFFSET[1]), round(z + BOARD_OFFSET[2])];
}

/** Grid direction from cell a toward a (possibly distant) cell b: the adjacent neighbour to swap with. */
export function neighbourToward(a: { x: number; y: number }, b: { x: number; y: number }): { x: number; y: number } | null {
  const dx = b.x - a.x, dy = b.y - a.y;
  if (dx === 0 && dy === 0) return null;
  if (Math.abs(dx) >= Math.abs(dy)) return { x: a.x + Math.sign(dx), y: a.y };
  return { x: a.x, y: a.y + Math.sign(dy) };
}

const round = (v: number) => Math.round(v * 1e5) / 1e5;
