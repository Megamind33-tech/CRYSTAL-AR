// Deterministic mapping between logical board cells and the miniature world's local space.
// Pure math: no React / Viro, so it is unit-tested and shared by AR and mock renderers.
//
// Hierarchy:  AR plane anchor → world root (yaw + scale) → board group (offset + tilt) → crystals
// World-local frame: origin = island centre on the table, +Y up, +Z toward the player.

export const BOARD_SIZE = 6;
export const CELL = 0.052; // metres between crystal centres (keep in sync with scripts/gen-models.mjs)
export const SURFACE_Y = 0.04; // top of the island terrain
export const BOARD_TILT_DEG = 10;
/** sideways roll of the tabletop while gravity points left/right */
export const GRAVITY_ROLL_DEG = 8;
export const rollFor = (g: "down" | "left" | "right") => (g === "left" ? GRAVITY_ROLL_DEG : g === "right" ? -GRAVITY_ROLL_DEG : 0); // far edge raised so the board faces the player
export const BOARD_OFFSET: [number, number, number] = [0, SURFACE_Y + 0.05, 0.05]; // clears the terrain at full tilt + roll
export const GEM_LIFT = 0.018; // crystal centre height above the tiles
export const GEM_SCALE = 0.036;
export const GEM_TILT_DEG = -28; // lean gems back so their faces look up toward the player

/** Board-local position of a cell centre. Row y = 0 is the far edge; rows beyond it (y < 0) are spawn lanes. */
export function cellToLocal(x: number, y: number): [number, number, number] {
  const half = (BOARD_SIZE - 1) / 2;
  const outside = Math.max(0, -y, y - (BOARD_SIZE - 1), -x, x - (BOARD_SIZE - 1));
  const h = GEM_LIFT + outside * 0.012; // spawn lanes beyond any edge arc slightly upward
  return [round((x - half) * CELL), round(h), round((y - half) * CELL)];
}

/** Board-local (x, z) back to the nearest cell, or null if outside the board. */
export function localToCell(lx: number, lz: number): { x: number; y: number } | null {
  const half = (BOARD_SIZE - 1) / 2;
  const x = Math.round(lx / CELL + half);
  const y = Math.round(lz / CELL + half);
  return x >= 0 && y >= 0 && x < BOARD_SIZE && y < BOARD_SIZE ? { x, y } : null;
}

/**
 * Where a newly spawned crystal comes from. The engine refills each line from its upstream board edge (the
 * spawn point is the target minus the flow direction times the queue length), so every new crystal enters
 * through the row/column just outside that edge: the "gate". `lead` is how far the spawn point is behind the
 * gate and `len` the whole path, so a crystal stays hidden in the chute for lead/len of its fall and then
 * materialises at the gate with its timing unchanged. Null for a crystal that appears in place (no flow).
 */
export function spawnGate(fromX: number, fromY: number, x: number, y: number): { gx: number; gy: number; lead: number; len: number } | null {
  const dx = Math.sign(x - fromX), dy = Math.sign(y - fromY);
  let gx: number, gy: number;
  if (dy > 0) [gx, gy] = [x, -1];
  else if (dx > 0) [gx, gy] = [-1, y];
  else if (dx < 0) [gx, gy] = [BOARD_SIZE, y];
  else return null;
  const len = Math.abs(x - fromX) + Math.abs(y - fromY);
  const lead = Math.max(0, Math.abs(gx - fromX) + Math.abs(gy - fromY));
  return { gx, gy, lead: Math.min(lead, len), len };
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
