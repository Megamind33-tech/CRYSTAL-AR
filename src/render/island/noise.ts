// Small seeded noise helpers for island generation. Pure, deterministic, no allocation per sample.

/** mulberry32 – fast seeded PRNG returning [0, 1). */
export function prng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** 2D value noise in [-1, 1] with smooth interpolation, seeded by a lattice hash. */
export function valueNoise(seed: number): (x: number, y: number) => number {
  const hash = (ix: number, iy: number) => {
    let h = (Math.imul(ix, 374761393) + Math.imul(iy, 668265263) + Math.imul(seed, 2147483647)) | 0;
    h = Math.imul(h ^ (h >>> 13), 1274126177);
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
  };
  const fade = (t: number) => t * t * (3 - 2 * t);
  return (x, y) => {
    const ix = Math.floor(x), iy = Math.floor(y);
    const fx = fade(x - ix), fy = fade(y - iy);
    const a = hash(ix, iy), b = hash(ix + 1, iy), c = hash(ix, iy + 1), d = hash(ix + 1, iy + 1);
    return (a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy) * 2 - 1;
  };
}

/** Fractal (fbm) value noise, roughly in [-1, 1]. */
export function fbm(seed: number, octaves = 3): (x: number, y: number) => number {
  const layers = Array.from({ length: octaves }, (_, i) => valueNoise(seed + i * 1013));
  return (x, y) => {
    let sum = 0, amp = 0.5, f = 1, norm = 0;
    for (const n of layers) {
      sum += n(x * f, y * f) * amp;
      norm += amp;
      amp *= 0.5;
      f *= 2.03;
    }
    return sum / norm;
  };
}

/** Periodic 1D noise around a circle (coastlines): sum of seeded sine waves. */
export function ringNoise(seed: number): (a: number) => number {
  const r = prng(seed);
  const waves = [2, 3, 5, 7, 11].map((k) => ({ k, p: r() * Math.PI * 2, amp: 1 / k }));
  const norm = waves.reduce((s, w) => s + w.amp, 0);
  return (a) => waves.reduce((s, w) => s + Math.sin(a * w.k + w.p) * w.amp, 0) / norm;
}
