// What lives on each realm's island. Pure data + helpers (no Viro), so it is unit-tested. The renderer is Life.tsx (kept as lifeData.ts so it never clashes with Life.tsx on case-insensitive disks).
//
// Every creature is one flat or billboarded sprite on a node that a native loop animation turns around the island, so
// motion is smooth and costs no JS per frame. Only a few near creatures flap (a shared 240 ms toggle, see Life.tsx);
// birds and mantas glide.

export type Sprite = "bird" | "butterfly" | "manta" | "jelly" | "wisp" | "shard";
export interface Critter {
  sprite: Sprite;
  n: number;
  /** orbit radius range (m) around the island centre, and flight height range above the sea (m) */
  r: [number, number];
  y: [number, number];
  /** sprite size (m) */
  size: number;
  /** index into TINTS */
  tint: number;
  /** one of ORBIT_MS: how long one full lap takes */
  lap: number;
  /** wings flap / bell pulses (butterflies, jellies) */
  flap?: boolean;
}

/** Tints (rgba, alpha included); each (sprite, tint) pair used below becomes one material, registered at boot. */
export const TINTS = ["#ffd0ea", "#fff0a0", "#c8f4ff", "#b6ffc4", "#ffffff", "#d8bcff", "#ffb070", "#7fe7ff", "#2a2040", "#ffe08a"] as const;

/** Laps that have a registered native animation (registry.ts). */
export const ORBIT_MS = [16000, 24000, 36000, 54000, 80000] as const;
/** Faster laps used while the world is excited by a big cascade, keyed by the calm lap. */
export const EXCITED_MS: Record<number, number> = { 16000: 16000, 24000: 16000, 36000: 24000, 54000: 36000, 80000: 54000 };

export const LIFE: Record<string, Critter[]> = {
  verdant: [
    { sprite: "butterfly", n: 5, r: [0.12, 0.34], y: [0.09, 0.17], size: 0.05, tint: 0, lap: 16000, flap: true },
    { sprite: "butterfly", n: 3, r: [0.16, 0.3], y: [0.1, 0.18], size: 0.046, tint: 1, lap: 24000, flap: true },
    { sprite: "bird", n: 3, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.080, tint: 4, lap: 54000 },
  ],
  canyon: [
    { sprite: "bird", n: 3, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.136, tint: 6, lap: 54000 },
    { sprite: "bird", n: 2, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.080, tint: 9, lap: 36000 },
  ],
  tide: [
    { sprite: "manta", n: 3, r: [0.3, 0.46], y: [0.02, 0.12], size: 0.12, tint: 7, lap: 80000 },
    { sprite: "jelly", n: 6, r: [0.2, 0.5], y: [0.06, 0.2], size: 0.063, tint: 2, lap: 36000, flap: true },
    { sprite: "bird", n: 3, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.072, tint: 4, lap: 54000 },
  ],
  sky: [
    { sprite: "bird", n: 6, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.080, tint: 4, lap: 36000 },
    { sprite: "bird", n: 3, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.064, tint: 9, lap: 24000 },
  ],
  hollow: [
    { sprite: "wisp", n: 8, r: [0.1, 0.4], y: [0.08, 0.22], size: 0.058, tint: 5, lap: 36000, flap: true },
    { sprite: "jelly", n: 3, r: [0.25, 0.5], y: [0.1, 0.24], size: 0.070, tint: 5, lap: 54000, flap: true },
  ],
  caverns: [
    { sprite: "wisp", n: 8, r: [0.1, 0.42], y: [0.06, 0.2], size: 0.051, tint: 7, lap: 36000, flap: true },
    { sprite: "bird", n: 3, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.080, tint: 8, lap: 24000 },
  ],
  frozen: [
    { sprite: "bird", n: 4, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.088, tint: 4, lap: 54000 },
    { sprite: "wisp", n: 6, r: [0.12, 0.4], y: [0.08, 0.22], size: 0.051, tint: 2, lap: 54000, flap: true },
  ],
  solar: [
    { sprite: "bird", n: 3, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.112, tint: 9, lap: 36000 },
    { sprite: "wisp", n: 7, r: [0.1, 0.42], y: [0.08, 0.24], size: 0.054, tint: 1, lap: 36000, flap: true },
  ],
  ember: [
    { sprite: "bird", n: 3, r: [0.34, 0.47], y: [0.18, 0.32], size: 0.104, tint: 6, lap: 24000 },
    { sprite: "wisp", n: 7, r: [0.1, 0.38], y: [0.06, 0.24], size: 0.051, tint: 6, lap: 16000, flap: true },
  ],
  void: [
    { sprite: "shard", n: 7, r: [0.2, 0.5], y: [0.1, 0.3], size: 0.051, tint: 5, lap: 54000 },
    { sprite: "wisp", n: 5, r: [0.1, 0.34], y: [0.08, 0.2], size: 0.054, tint: 5, lap: 36000, flap: true },
  ],
};

export interface Placed { sprite: Sprite; r: number; y: number; size: number; tint: number; lap: number; flap: boolean; delay: number; key: string }

/** Deterministic spread of a realm's critters (stable across renders; different lanes so they do not stack). */
export function placeCritters(realm: string): Placed[] {
  const out: Placed[] = [];
  (LIFE[realm] ?? []).forEach((c, ci) => {
    for (let i = 0; i < c.n; i++) {
      const f = c.n === 1 ? 0.5 : i / (c.n - 1);
      const jitter = ((i * 37 + ci * 17) % 10) / 10;
      out.push({
        sprite: c.sprite, tint: c.tint, size: c.size * (0.85 + jitter * 0.3), flap: !!c.flap,
        r: c.r[0] + (c.r[1] - c.r[0]) * ((f + jitter * 0.5) % 1),
        y: c.y[0] + (c.y[1] - c.y[0]) * ((f * 0.7 + jitter) % 1),
        lap: c.lap,
        // the animation `delay` staggers where each one starts along its lap
        delay: Math.round((i / c.n) * c.lap * 0.9 + ci * 700),
        key: `${realm}_${ci}_${i}`,
      });
    }
  });
  return out;
}

/** Every (sprite, tint) material name the renderer will use; registered once at boot. */
export const lifeMaterial = (sprite: Sprite, tint: number) => `life_${sprite}_${tint}`;
export function lifeMaterialSet(): { sprite: Sprite; tint: number }[] {
  const seen = new Set<string>(), out: { sprite: Sprite; tint: number }[] = [];
  for (const list of Object.values(LIFE)) for (const c of list) {
    const k = lifeMaterial(c.sprite, c.tint);
    if (!seen.has(k)) { seen.add(k); out.push({ sprite: c.sprite, tint: c.tint }); }
  }
  return out;
}
