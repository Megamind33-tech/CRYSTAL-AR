// Dash layout of the dais rune trim (pure, so it is unit-tested; the renderer is DaisTrim.tsx).
import { DAIS } from "./buildIsland.ts";

const INSET = 0.02;

export interface Dash { x: number; z: number; w: number; h: number }

/** Dash layout for the dais top (pure, so it is unit-tested): the front edge and both sides, plus the four corners. */
export function trimDashes(): { dashes: Dash[]; studs: [number, number][] } {
  const { halfX, zMin, zMax } = DAIS;
  const dashes: Dash[] = [];
  const front = zMax - INSET, sideX = halfX - INSET;
  const long = 0.034, thick = 0.009, gap = 0.014;
  // front: centred row across the width
  const n = Math.floor((sideX * 2 - 0.05) / (long + gap));
  for (let i = 0; i < n; i++) dashes.push({ x: -((n - 1) / 2) * (long + gap) + i * (long + gap), z: front, w: long, h: thick });
  // sides: from the front corner back toward the portal
  const m = Math.floor((front - (zMin + 0.12)) / (long + gap));
  for (const s of [-1, 1]) for (let i = 0; i < m; i++) dashes.push({ x: s * sideX, z: front - 0.03 - i * (long + gap), w: thick, h: long });
  return { dashes, studs: [[-sideX, front], [sideX, front], [-sideX, zMin + 0.14], [sideX, zMin + 0.14]] };
}

