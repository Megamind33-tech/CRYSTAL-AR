// One biome per realm: which CC0 surfaces the island is made of, its props, light and particles.
// Pure data (no Viro), so the geometry builder and tests can use it.
import type { PbrId } from "../assets";

export type PropKind =
  | "pine" | "broadleaf" | "bush" | "rock" | "boulder" | "spire" | "arch" | "column" | "brokenColumn"
  | "mushroom" | "stalagmite" | "iceSpike" | "snowPine" | "coral" | "kelp" | "obelisk" | "dune"
  | "lavaPool" | "vent" | "deadTree" | "voidShard" | "pool";

/** Where a prop may stand: behind the board, beside it, or anywhere (low props only in front). */
export type Zone = "back" | "side" | "any";

export interface PropSpec {
  kind: PropKind;
  weight: number;
  zone: Zone;
  /** size multiplier range */
  size: [number, number];
}

export interface Surface {
  tex: PbrId;
  /** multiplies the texture colour */
  tint: string;
  /** texture repeats per metre */
  tile: number;
  roughness?: number;
}

export interface Biome {
  id: string;
  top: Surface;
  cliff: Surface;
  /** rock props and the portal arch */
  stone: Surface;
  /** flat colours for foliage, caps, coral, glowing bits */
  leaf: string;
  leafDark: string;
  accent: string;
  /** glowing accent (mushroom caps, void shards, vents) */
  glow: string;
  /** hill height multiplier and a raised back ridge */
  hills: number;
  backRise: number;
  /** island underside depth (m) */
  depth: number;
  props: PropSpec[];
  propCount: [number, number];
  light: { ambient: string; sun: string; sunScale: number };
  particles: { colors: [string, string]; rise: number; rate: number };
  /** show the realm's reactive blooms (flowers) */
  blooms: boolean;
}

export const BIOMES: Record<string, Biome> = {
  verdant: {
    id: "verdant",
    top: { tex: "grass", tint: "#c9e0a8", tile: 5 },
    cliff: { tex: "rockMoss", tint: "#d8d8cc", tile: 7 },
    stone: { tex: "rock", tint: "#e6e1d6", tile: 18 },
    leaf: "#4f8f3a", leafDark: "#2f5f2a", accent: "#ffe07a", glow: "#bff7ff",
    hills: 1, backRise: 1, depth: 0.24,
    props: [
      { kind: "pine", weight: 3, zone: "back", size: [0.8, 1.25] },
      { kind: "broadleaf", weight: 3, zone: "side", size: [0.8, 1.2] },
      { kind: "bush", weight: 3, zone: "any", size: [0.7, 1.2] },
      { kind: "rock", weight: 3, zone: "any", size: [0.6, 1.3] },
      { kind: "boulder", weight: 1, zone: "side", size: [0.8, 1.1] },
      { kind: "brokenColumn", weight: 1, zone: "back", size: [0.8, 1.1] },
    ],
    propCount: [22, 28],
    light: { ambient: "#fff4e0", sun: "#fff1d8", sunScale: 1 },
    particles: { colors: ["#fff6b0", "#c8ffd8"], rise: 0.01, rate: 1 },
    blooms: true,
  },
  canyon: {
    id: "canyon",
    top: { tex: "dirt", tint: "#e8b98c", tile: 6 },
    cliff: { tex: "cliff", tint: "#e3a578", tile: 6 },
    stone: { tex: "cliff", tint: "#e8b088", tile: 14 },
    leaf: "#6f8f3a", leafDark: "#4c6a2a", accent: "#ffcf7a", glow: "#a8ffcf",
    hills: 1.3, backRise: 1.8, depth: 0.3,
    props: [
      { kind: "spire", weight: 4, zone: "back", size: [0.8, 1.4] },
      { kind: "arch", weight: 1, zone: "side", size: [0.8, 1] },
      { kind: "boulder", weight: 3, zone: "side", size: [0.7, 1.2] },
      { kind: "rock", weight: 3, zone: "any", size: [0.6, 1.2] },
      { kind: "bush", weight: 2, zone: "any", size: [0.6, 0.9] },
      { kind: "pine", weight: 1, zone: "back", size: [0.7, 1] },
    ],
    propCount: [18, 24],
    light: { ambient: "#ffe6cc", sun: "#ffd9a8", sunScale: 1.1 },
    particles: { colors: ["#ffe0b0", "#fff4d8"], rise: 0.004, rate: 0.6 },
    blooms: false,
  },
  tide: {
    id: "tide",
    top: { tex: "sand", tint: "#f2e3c4", tile: 6 },
    cliff: { tex: "rockDark", tint: "#9fb4bd", tile: 7 },
    stone: { tex: "rockDark", tint: "#b9c9cf", tile: 16 },
    leaf: "#2f8f7a", leafDark: "#1f5f58", accent: "#ff8fa3", glow: "#9ff0ff",
    hills: 0.6, backRise: 0.8, depth: 0.22,
    props: [
      { kind: "coral", weight: 4, zone: "any", size: [0.7, 1.3] },
      { kind: "kelp", weight: 3, zone: "back", size: [0.8, 1.3] },
      { kind: "pool", weight: 2, zone: "side", size: [0.8, 1.3] },
      { kind: "rock", weight: 3, zone: "any", size: [0.6, 1.2] },
      { kind: "boulder", weight: 1, zone: "side", size: [0.7, 1] },
    ],
    propCount: [20, 26],
    light: { ambient: "#dff6ff", sun: "#e8f8ff", sunScale: 0.95 },
    particles: { colors: ["#dffaff", "#9fe8ff"], rise: 0.03, rate: 1.2 },
    blooms: false,
  },
  sky: {
    id: "sky",
    top: { tex: "paving", tint: "#efe8da", tile: 9 },
    cliff: { tex: "rock", tint: "#e4e2dc", tile: 7 },
    stone: { tex: "paving", tint: "#f4efe4", tile: 20 },
    leaf: "#6aa04a", leafDark: "#467a34", accent: "#ffe9a8", glow: "#fff6c8",
    hills: 0.35, backRise: 0.6, depth: 0.2,
    props: [
      { kind: "column", weight: 4, zone: "back", size: [0.9, 1.25] },
      { kind: "brokenColumn", weight: 3, zone: "side", size: [0.8, 1.1] },
      { kind: "arch", weight: 1, zone: "side", size: [0.9, 1.1] },
      { kind: "bush", weight: 2, zone: "any", size: [0.6, 0.9] },
      { kind: "rock", weight: 1, zone: "any", size: [0.5, 0.9] },
    ],
    propCount: [16, 22],
    light: { ambient: "#ffffff", sun: "#fff8e8", sunScale: 1.15 },
    particles: { colors: ["#ffffff", "#fff4d0"], rise: 0.006, rate: 0.7 },
    blooms: true,
  },
  hollow: {
    id: "hollow",
    top: { tex: "moss", tint: "#b8c9a0", tile: 6 },
    cliff: { tex: "dirt", tint: "#a89080", tile: 6 },
    stone: { tex: "rockMoss", tint: "#c8c8b8", tile: 16 },
    leaf: "#5a7f3a", leafDark: "#34502a", accent: "#ff7ad9", glow: "#c9a0ff",
    hills: 1.1, backRise: 1.2, depth: 0.25,
    props: [
      { kind: "mushroom", weight: 5, zone: "any", size: [0.7, 1.5] },
      { kind: "bush", weight: 2, zone: "any", size: [0.6, 1] },
      { kind: "rock", weight: 2, zone: "any", size: [0.6, 1.1] },
      { kind: "deadTree", weight: 1, zone: "back", size: [0.8, 1.1] },
    ],
    propCount: [22, 30],
    light: { ambient: "#e8dcff", sun: "#f0e0ff", sunScale: 0.8 },
    particles: { colors: ["#e0b8ff", "#a8fff0"], rise: 0.012, rate: 1.6 },
    blooms: false,
  },
  caverns: {
    id: "caverns",
    top: { tex: "gravel", tint: "#c8c4c8", tile: 8 },
    cliff: { tex: "rockDark", tint: "#a8a0b0", tile: 7 },
    stone: { tex: "rockDark", tint: "#b8b0c8", tile: 16 },
    leaf: "#6a6a88", leafDark: "#48485a", accent: "#9ff0ff", glow: "#9fd8ff",
    hills: 1.2, backRise: 1.4, depth: 0.26,
    props: [
      { kind: "stalagmite", weight: 4, zone: "any", size: [0.7, 1.4] },
      { kind: "boulder", weight: 2, zone: "side", size: [0.7, 1.2] },
      { kind: "rock", weight: 3, zone: "any", size: [0.6, 1.2] },
      { kind: "voidShard", weight: 1, zone: "back", size: [0.6, 0.9] },
    ],
    propCount: [20, 26],
    light: { ambient: "#dfe8ff", sun: "#d8e4ff", sunScale: 0.85 },
    particles: { colors: ["#9ff0ff", "#d0c0ff"], rise: 0.008, rate: 1 },
    blooms: false,
  },
  frozen: {
    id: "frozen",
    top: { tex: "snow", tint: "#f4f8ff", tile: 5 },
    cliff: { tex: "ice", tint: "#cfe6f5", tile: 6 },
    stone: { tex: "rockDark", tint: "#dfe8f2", tile: 16 },
    leaf: "#3f6f5a", leafDark: "#2a4a40", accent: "#dff6ff", glow: "#bff0ff",
    hills: 0.9, backRise: 1.3, depth: 0.24,
    props: [
      { kind: "iceSpike", weight: 4, zone: "any", size: [0.7, 1.4] },
      { kind: "snowPine", weight: 3, zone: "back", size: [0.8, 1.2] },
      { kind: "boulder", weight: 2, zone: "side", size: [0.7, 1.1] },
      { kind: "rock", weight: 2, zone: "any", size: [0.6, 1] },
    ],
    propCount: [20, 26],
    light: { ambient: "#e6f2ff", sun: "#eef6ff", sunScale: 1 },
    particles: { colors: ["#ffffff", "#e0f4ff"], rise: -0.02, rate: 1.6 },
    blooms: false,
  },
  solar: {
    id: "solar",
    top: { tex: "sand", tint: "#f7d7a0", tile: 5 },
    cliff: { tex: "cliff", tint: "#f0c890", tile: 6 },
    stone: { tex: "paving", tint: "#f5dcac", tile: 18 },
    leaf: "#7a8f3a", leafDark: "#56682a", accent: "#ffd35a", glow: "#fff0a0",
    hills: 0.7, backRise: 1, depth: 0.24,
    props: [
      { kind: "obelisk", weight: 3, zone: "back", size: [0.8, 1.25] },
      { kind: "dune", weight: 3, zone: "any", size: [0.8, 1.4] },
      { kind: "column", weight: 2, zone: "side", size: [0.7, 1] },
      { kind: "rock", weight: 2, zone: "any", size: [0.5, 1] },
    ],
    propCount: [16, 22],
    light: { ambient: "#fff0d8", sun: "#ffe7b8", sunScale: 1.2 },
    particles: { colors: ["#ffe6a0", "#fff8e0"], rise: 0.004, rate: 0.8 },
    blooms: false,
  },
  ember: {
    id: "ember",
    top: { tex: "rockDark", tint: "#8a7a74", tile: 7 },
    cliff: { tex: "rockDark", tint: "#6a5a54", tile: 6 },
    stone: { tex: "rockDark", tint: "#9a8a84", tile: 16 },
    leaf: "#3a2a24", leafDark: "#241a16", accent: "#ff7a2a", glow: "#ff8a3a",
    hills: 1.2, backRise: 1.6, depth: 0.28,
    props: [
      { kind: "lavaPool", weight: 3, zone: "side", size: [0.8, 1.3] },
      { kind: "vent", weight: 3, zone: "any", size: [0.7, 1.2] },
      { kind: "deadTree", weight: 2, zone: "back", size: [0.8, 1.2] },
      { kind: "spire", weight: 2, zone: "back", size: [0.7, 1.1] },
      { kind: "rock", weight: 3, zone: "any", size: [0.6, 1.2] },
    ],
    propCount: [18, 24],
    light: { ambient: "#ffd8c0", sun: "#ffc090", sunScale: 0.9 },
    particles: { colors: ["#ff9a3a", "#ffd080"], rise: 0.04, rate: 1.8 },
    blooms: false,
  },
  void: {
    id: "void",
    top: { tex: "rockDark", tint: "#8a80a0", tile: 7 },
    cliff: { tex: "rockDark", tint: "#6a6080", tile: 6 },
    stone: { tex: "rockDark", tint: "#a098c0", tile: 16 },
    leaf: "#4a3a6a", leafDark: "#2a2040", accent: "#c08aff", glow: "#b07aff",
    hills: 1, backRise: 1.5, depth: 0.3,
    props: [
      { kind: "voidShard", weight: 4, zone: "any", size: [0.8, 1.5] },
      { kind: "spire", weight: 2, zone: "back", size: [0.8, 1.2] },
      { kind: "brokenColumn", weight: 2, zone: "side", size: [0.8, 1.1] },
      { kind: "rock", weight: 2, zone: "any", size: [0.6, 1.1] },
    ],
    propCount: [18, 24],
    light: { ambient: "#e0d0ff", sun: "#d8c8ff", sunScale: 0.85 },
    particles: { colors: ["#c08aff", "#80e0ff"], rise: 0.02, rate: 1.4 },
    blooms: false,
  },
};

export const biomeFor = (realm: string | undefined): Biome => BIOMES[realm ?? "verdant"] ?? BIOMES.verdant;

/**
 * Weather over each realm: particles falling or drifting across the whole island (on top of the
 * realm's ambient motes), and whether storms throw lightning.
 * velocity is [min, max] m/s; size in metres.
 */
export interface Weather {
  colors: [string, string];
  rate: number;
  size: number;
  life: [number, number];
  velocity: [[number, number, number], [number, number, number]];
  lightning: boolean;
}

export const WEATHER: Record<string, Weather> = {
  verdant: { colors: ["#8fbf5a", "#c8a84a"], rate: 6, size: 0.007, life: [4000, 6000], velocity: [[-0.03, -0.05, -0.02], [0.03, -0.03, 0.02]], lightning: false }, // falling leaves
  canyon: { colors: ["#e8c39a", "#c89a70"], rate: 18, size: 0.005, life: [2500, 4000], velocity: [[0.12, -0.01, -0.01], [0.2, 0.01, 0.01]], lightning: true }, // blowing dust
  tide: { colors: ["#e8fbff", "#bfefff"], rate: 12, size: 0.004, life: [2000, 3500], velocity: [[-0.02, 0.02, -0.02], [0.02, 0.06, 0.02]], lightning: false }, // sea spray
  sky: { colors: ["#ffffff", "#e0f0ff"], rate: 10, size: 0.004, life: [1200, 2000], velocity: [[0.3, -0.01, -0.02], [0.45, 0.01, 0.02]], lightning: true }, // wind streaks
  hollow: { colors: ["#e0b8ff", "#a8fff0"], rate: 14, size: 0.004, life: [4000, 6500], velocity: [[-0.01, 0.005, -0.01], [0.01, 0.02, 0.01]], lightning: false }, // spores
  caverns: { colors: ["#9ff0ff", "#d0c0ff"], rate: 8, size: 0.003, life: [3000, 5000], velocity: [[-0.005, -0.01, -0.005], [0.005, 0.005, 0.005]], lightning: false }, // motes
  frozen: { colors: ["#ffffff", "#e8f4ff"], rate: 40, size: 0.005, life: [4000, 6000], velocity: [[-0.02, -0.07, -0.01], [0.02, -0.04, 0.01]], lightning: false }, // snowfall
  solar: { colors: ["#ffe6a0", "#fff8e0"], rate: 10, size: 0.003, life: [3000, 5000], velocity: [[0.03, 0.005, -0.01], [0.06, 0.02, 0.01]], lightning: false }, // heat dust
  ember: { colors: ["#6a5a54", "#3a2a24"], rate: 30, size: 0.005, life: [4000, 6000], velocity: [[-0.02, -0.05, -0.01], [0.02, -0.025, 0.01]], lightning: false }, // ash fall
  void: { colors: ["#c08aff", "#6040a0"], rate: 12, size: 0.004, life: [3000, 5000], velocity: [[-0.01, -0.01, -0.01], [0.01, 0.01, 0.01]], lightning: true }, // violet motes
};
