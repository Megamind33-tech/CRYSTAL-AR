// Web DEV_AR_MOCK input: pick board cells in JS with the mock camera's exact math.
// Why: @reactvision/viro-web-renderer 1.0.0 unprojects touches with a mirrored/mis-scaled Y
// (measured with scripts/mock-e2e.mjs), so Viro's onClickState is unusable on web. Native AR keeps
// Viro's own hit-testing; both paths call the same controller (pressCell / releaseCell).
import { arSession } from "../state/arSession";
import { gameStore, pressCell, releaseCell } from "../state/game";
import { BOARD_OFFSET, BOARD_TILT_DEG, cellToLocal, localToCell, rollFor } from "../render/layout";

/** Mock camera – MockScene renders with exactly these values. The web renderer's FOV is fixed at 90° vertical. */
export const MOCK_CAMERA = { position: [0, 0.46, 0.4] as [number, number, number], pitchDeg: -48, fovYDeg: 90 };
const PAD_Y = 0.016;
const rad = (d: number) => (d * Math.PI) / 180;

type V3 = [number, number, number];
const rotX = ([x, y, z]: V3, a: number): V3 => [x, y * Math.cos(a) - z * Math.sin(a), y * Math.sin(a) + z * Math.cos(a)];
const rotZ = ([x, y, z]: V3, a: number): V3 => [x * Math.cos(a) - y * Math.sin(a), x * Math.sin(a) + y * Math.cos(a), z];
const roll = () => rad(rollFor(gameStore.get().gravity));
const rotY = ([x, y, z]: V3, a: number): V3 => [x * Math.cos(a) + z * Math.sin(a), y, -x * Math.sin(a) + z * Math.cos(a)];

/** World-space point → board-local, undoing world yaw/scale and the board's offset + tilt. */
function worldToBoard(p: V3): V3 {
  const { yaw, worldScale } = arSession.get();
  let q = rotY(p, -rad(yaw));
  q = [q[0] / worldScale, q[1] / worldScale, q[2] / worldScale];
  q = [q[0] - BOARD_OFFSET[0], q[1] - BOARD_OFFSET[1], q[2] - BOARD_OFFSET[2]];
  // board group rotation is Rx·Rz (tilt toward the player, roll toward gravity)
  return rotZ(rotX(q, -rad(BOARD_TILT_DEG)), -roll());
}
function boardToWorld(p: V3): V3 {
  const { yaw, worldScale } = arSession.get();
  let q = rotX(rotZ(p, roll()), rad(BOARD_TILT_DEG));
  q = [q[0] + BOARD_OFFSET[0], q[1] + BOARD_OFFSET[1], q[2] + BOARD_OFFSET[2]];
  q = [q[0] * worldScale, q[1] * worldScale, q[2] * worldScale];
  return rotY(q, rad(yaw));
}

/** Screen point (relative to the canvas rect) → board cell, by intersecting the camera ray with the pad plane. */
export function pickCell(sx: number, sy: number, w: number, h: number) {
  const t = Math.tan(rad(MOCK_CAMERA.fovYDeg / 2));
  const ndcX = (sx / w) * 2 - 1, ndcY = 1 - (sy / h) * 2;
  const dirCam: V3 = [ndcX * t * (w / h), ndcY * t, -1];
  const dirWorld = rotX(dirCam, rad(MOCK_CAMERA.pitchDeg));
  const o = worldToBoard(MOCK_CAMERA.position);
  const far = worldToBoard([MOCK_CAMERA.position[0] + dirWorld[0], MOCK_CAMERA.position[1] + dirWorld[1], MOCK_CAMERA.position[2] + dirWorld[2]]);
  const d: V3 = [far[0] - o[0], far[1] - o[1], far[2] - o[2]];
  if (Math.abs(d[1]) < 1e-6) return null;
  const k = (PAD_Y - o[1]) / d[1];
  if (k <= 0) return null;
  return localToCell(o[0] + d[0] * k, o[2] + d[2] * k);
}

/** Inverse of pickCell: screen position of a cell centre (automation / tests). */
export function cellToScreen(x: number, y: number, w: number, h: number): [number, number] {
  const [lx, , lz] = cellToLocal(x, y);
  const p = boardToWorld([lx, PAD_Y, lz]);
  const rel: V3 = [p[0] - MOCK_CAMERA.position[0], p[1] - MOCK_CAMERA.position[1], p[2] - MOCK_CAMERA.position[2]];
  const c = rotX(rel, -rad(MOCK_CAMERA.pitchDeg));
  const t = Math.tan(rad(MOCK_CAMERA.fovYDeg / 2));
  const ndcX = c[0] / (-c[2] * t * (w / h)), ndcY = c[1] / (-c[2] * t);
  return [((ndcX + 1) / 2) * w, ((1 - ndcY) / 2) * h];
}

/**
 * Pointer handling on the mock canvas: press selects, and the swipe commits the moment the
 * finger crosses into another cell (no need to lift), mirroring a responsive touch game.
 */
export function installMockPicking(): () => void {
  if (typeof window === "undefined") return () => {};
  let down: { x: number; y: number } | null = null;
  const cellAt = (e: PointerEvent) => {
    const el = e.target as HTMLElement | null;
    if (!el || el.tagName !== "CANVAS") return null;
    const r = el.getBoundingClientRect();
    return pickCell(e.clientX - r.left, e.clientY - r.top, r.width, r.height);
  };
  const onDown = (e: PointerEvent) => {
    if (arSession.get().phase !== "placed") return;
    const c = cellAt(e);
    down = c;
    if (c) pressCell(c);
  };
  const onMove = (e: PointerEvent) => {
    if (!down) return;
    const c = cellAt(e);
    if (c && (c.x !== down.x || c.y !== down.y)) {
      releaseCell(c);
      down = null;
    }
  };
  const onUp = (e: PointerEvent) => {
    if (!down) return;
    const c = cellAt(e);
    if (c) releaseCell(c);
    down = null;
  };
  window.addEventListener("pointerdown", onDown);
  window.addEventListener("pointermove", onMove);
  window.addEventListener("pointerup", onUp);
  return () => {
    window.removeEventListener("pointerdown", onDown);
    window.removeEventListener("pointermove", onMove);
    window.removeEventListener("pointerup", onUp);
  };
}

export const mockDebug = { pickCell, cellToScreen, getSelected: () => gameStore.get().selected };
