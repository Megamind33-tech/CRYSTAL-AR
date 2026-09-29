// The 200-level campaign: 10 realms × 20 levels. Pure and deterministic – every level (board shape,
// obstacles, objective, island seed) is derived from its number, so nothing here is random at runtime.
// Move budgets come from scripts/tune-campaign.ts (a bot plays each level many times).
import type { BoardSetup } from "./board.ts";
import type { LevelDef, Objective } from "./level.ts";
import { createRng, nextFloat, nextInt } from "./rng.ts";
import type { CoverKind, CrystalType, Rng } from "./types.ts";
import { CAMPAIGN_MOVES } from "./campaignTuning.ts";
import { islandStory } from "./lore.ts";
import { planIsland } from "./twists.ts";

export const LEVELS_PER_REALM = 20;
export const W = 6, H = 6;

export type Mechanic = "basics" | "gravity" | "ice" | "stone" | "vine" | "rune" | "chain" | "relic" | "ember" | "void";

export interface RealmDef {
  id: string;
  name: string;
  mechanic: Mechanic;
  /** what the realm teaches, shown on its gate */
  teaches: string;
  /** crystal kind this realm is rich in (spawn weight bias) */
  richIn: CrystalType;
  names: [string[], string[]];
}

export const CAMPAIGN_REALMS: RealmDef[] = [
  { id: "verdant", name: "The Verdant Reach", mechanic: "basics", teaches: "Match, charge the portal, forge Surges and Prisms.", richIn: 2,
    names: [["Moss", "Fern", "Root", "Glade", "Bramble", "Willow", "Thorn", "Hollow", "Lichen", "Briar"], ["step", "ring", "gate", "well", "crown", "path", "stones", "brook", "rise", "glen"]] },
  { id: "canyon", name: "Emerald Canyon", mechanic: "gravity", teaches: "Turn the tabletop. Gravity Shift fills sheltered pockets.", richIn: 2,
    names: [["Echo", "Ridge", "Cliff", "Mesa", "Gorge", "Chasm", "Ledge", "Spire", "Arch", "Scree"], ["run", "fall", "drop", "cut", "shelf", "pass", "notch", "wall", "bend", "reach"]] },
  { id: "tide", name: "The Tide Grotto", mechanic: "ice", teaches: "Ice locks crystals in place. Match them to melt it.", richIn: 1,
    names: [["Brine", "Pearl", "Kelp", "Shoal", "Current", "Coral", "Surf", "Tidal", "Foam", "Drift"], ["pool", "cave", "hollow", "shelf", "basin", "grotto", "reef", "arch", "spring", "deep"]] },
  { id: "sky", name: "The Sky Ruins", mechanic: "stone", teaches: "Cracked stone blocks the fall. Match beside it to break through.", richIn: 4,
    names: [["Cloud", "Zephyr", "Gale", "High", "Wind", "Aerie", "Nimbus", "Storm", "Halo", "Sun"], ["hall", "tower", "stair", "court", "terrace", "keep", "vault", "bridge", "throne", "altar"]] },
  { id: "hollow", name: "Mushroom Hollow", mechanic: "vine", teaches: "Vines creep every second idle move. Cut them back.", richIn: 3,
    names: [["Spore", "Cap", "Gill", "Puff", "Mycel", "Glow", "Truffle", "Mold", "Morel", "Fungal"], ["ring", "shade", "den", "circle", "grove", "patch", "dell", "mound", "nook", "vale"]] },
  { id: "caverns", name: "The Crystal Caverns", mechanic: "rune", teaches: "Runes lie buried under the board. Clear crystals above them.", richIn: 3,
    names: [["Geode", "Quartz", "Vein", "Drusy", "Lode", "Prism", "Facet", "Shard", "Cluster", "Seam"], ["mine", "shaft", "chamber", "gallery", "pit", "tunnel", "vault", "crypt", "hall", "core"]] },
  { id: "frozen", name: "The Frozen Verge", mechanic: "chain", teaches: "Chains and deep ice. Some take three strikes.", richIn: 1,
    names: [["Rime", "Frost", "Hoar", "Glacier", "Sleet", "Snow", "Floe", "Icicle", "Polar", "Winter"], ["field", "shelf", "crag", "drift", "fang", "watch", "hold", "cairn", "rest", "verge"]] },
  { id: "solar", name: "The Solar Mesa", mechanic: "relic", teaches: "Bring Solar relics down to the edge. Turn the table to steer them.", richIn: 4,
    names: [["Dawn", "Noon", "Amber", "Gilded", "Blaze", "Dune", "Mirage", "Ochre", "Sol", "Helio"], ["plateau", "dial", "steps", "gate", "forum", "obelisk", "sands", "mesa", "court", "crown"]] },
  { id: "ember", name: "The Ember Deep", mechanic: "ember", teaches: "Embers spread every idle move. Quench them before they take the board.", richIn: 0,
    names: [["Cinder", "Ash", "Magma", "Scoria", "Flare", "Char", "Smolder", "Basalt", "Pyre", "Obsidian"], ["vent", "forge", "flow", "crater", "hearth", "fissure", "caldera", "rift", "core", "maw"]] },
  { id: "void", name: "The Void Spire", mechanic: "void", teaches: "Everything the Keepers have learned, all at once.", richIn: 3,
    names: [["Null", "Umbra", "Eclipse", "Hollow", "Rift", "Shade", "Veil", "Abyss", "Omen", "Nether"], ["spire", "gate", "throne", "well", "stair", "crown", "eye", "heart", "path", "end"]] },
];

/** A level built from its campaign number. `n` is 1-based. */
export interface CampaignLevel extends LevelDef {
  /** 1..200 */
  number: number;
  realmIndex: number;
  /** 0..19 inside the realm */
  step: number;
}

const pick = <T,>(r: Rng, xs: readonly T[]): T => xs[nextInt(r, xs.length)];
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** Difficulty inside a realm: a rising sawtooth with a breather every 5th level and a hard finale. */
export function difficulty(step: number): number {
  const base = step / (LEVELS_PER_REALM - 1);
  const breather = step % 5 === 4 && step !== LEVELS_PER_REALM - 1 ? -0.12 : 0;
  const finale = step === LEVELS_PER_REALM - 1 ? 0.08 : 0;
  return Math.max(0, Math.min(1, base + breather + finale));
}

// ------------------------------------------------------------------ shapes --
/**
 * Board shapes whose voids stand on the bottom edge (every void has only voids beneath it), so every
 * playable cell has an open path to the top edge and refills normally under downward gravity.
 * Values: void cells per column, counted from the bottom.
 */
const GROUNDED: number[][] = [
  [0, 0, 0, 0, 0, 0],
  [1, 0, 0, 0, 0, 1],
  [2, 1, 0, 0, 1, 2],
  [0, 1, 2, 2, 1, 0],
  [1, 0, 1, 1, 0, 1],
  [2, 0, 0, 0, 0, 2],
  [0, 0, 1, 1, 0, 0],
  [1, 1, 0, 0, 1, 1],
  [2, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 2],
  [0, 2, 0, 0, 2, 0],
  [1, 0, 2, 2, 0, 1],
];

function groundedMask(cols: number[]): string[] {
  const rows: string[] = [];
  for (let y = 0; y < H; y++) rows.push(cols.map((v) => (y >= H - v ? "X" : "O")).join(""));
  return rows;
}

/** Canyon-style masks: floating ledges that shelter pockets only a Gravity Shift will fill. */
function canyonMask(r: Rng, d: number): string[] {
  const g = pick(r, GROUNDED.slice(0, 6));
  const rows = groundedMask(g).map((row) => [...row]);
  const ledges = 1 + Math.round(d * 3);
  for (let i = 0, guard = 0; i < ledges && guard < 40; guard++) {
    const x = nextInt(r, W), y = 1 + nextInt(r, H - 3);
    if (rows[y][x] === "X" || rows[y - 1][x] === "X") continue;
    rows[y][x] = "X";
    i++;
  }
  return rows.map((row) => row.join(""));
}

const playableCells = (mask: string[]) => {
  const out: [number, number][] = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (mask[y][x] !== "X") out.push([x, y]);
  return out;
};

function shuffled<T>(r: Rng, xs: T[]): T[] {
  const a = xs.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = nextInt(r, i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// --------------------------------------------------------------- obstacles --
function coversOn(r: Rng, cells: [number, number][], kind: CoverKind, count: number, maxHp: number, d: number): BoardSetup["covers"] {
  return shuffled(r, cells)
    .slice(0, count)
    .map(([x, y]) => [x, y, kind, 1 + (nextFloat(r) < d * 0.8 ? nextInt(r, maxHp) : 0)] as [number, number, CoverKind, number]);
}

/** Stone rises from the ground: each stone stands on the bottom edge, a void, or another stone. */
function groundedStones(r: Rng, mask: string[], count: number, maxHp: number): [number, number, number][] {
  const solid = mask.map((row) => [...row].map((c) => c === "X"));
  const out: [number, number, number][] = [];
  for (let guard = 0; out.length < count && guard < 200; guard++) {
    const x = nextInt(r, W);
    let y = H - 1;
    while (y >= 0 && solid[y][x]) y--;
    if (y < 2) continue; // keep at least two open rows above every stack
    solid[y][x] = true;
    out.push([x, y, 1 + nextInt(r, maxHp)]);
  }
  return out;
}

function runePattern(r: Rng, cells: [number, number][], count: number, d: number): [number, number, number][] {
  // runes gather in a band or ring so they read as a buried carving, not noise
  const cx = 2.5 + (nextFloat(r) - 0.5) * 2, cy = 2.5 + (nextFloat(r) - 0.5) * 2;
  const ranked = cells.slice().sort((a, b) => Math.hypot(a[0] - cx, a[1] - cy) - Math.hypot(b[0] - cx, b[1] - cy));
  return ranked.slice(0, count).map(([x, y]) => [x, y, 1 + (nextFloat(r) < d ? 1 : 0)]);
}

// --------------------------------------------------------------- the build --
function estimateMoves(o: Objective, d: number): number {
  switch (o.kind) {
    case "power": return Math.round(o.target / 9.5);
    case "score": return Math.round(o.target / 300);
    case "collect": return Math.round(o.target / 1.6);
    default: return Math.round(14 + o.target * 1.2 - d * 2);
  }
}

function nameFor(realm: RealmDef, step: number, used: Set<string>, r: Rng): string {
  for (let guard = 0; guard < 200; guard++) {
    const a = pick(r, realm.names[0]), b = pick(r, realm.names[1]);
    const name = `${a}${b}`.replace(/^(.)/, (c) => c.toUpperCase());
    if (!used.has(name)) {
      used.add(name);
      return name;
    }
  }
  return `${realm.names[0][0]}${realm.names[1][step % 10]} ${step + 1}`;
}

const SECONDARY: Mechanic[] = ["ice", "stone", "rune", "chain"];

export function buildCampaignLevel(n: number, usedNames = new Set<string>()): CampaignLevel {
  const realmIndex = Math.floor((n - 1) / LEVELS_PER_REALM);
  const step = (n - 1) % LEVELS_PER_REALM;
  const realm = CAMPAIGN_REALMS[realmIndex];
  const d = difficulty(step);
  const r = createRng(0x9e3779b1 ^ (n * 2654435761));
  const seed = 10007 * n + 17;

  let mechanic: Mechanic = realm.mechanic;
  if (mechanic === "void") mechanic = pick(r, ["gravity", "ice", "stone", "vine", "rune", "chain", "relic", "ember"] as Mechanic[]);

  const gravityRealm = mechanic === "gravity" || mechanic === "relic" || (realm.mechanic === "void" && nextFloat(r) < 0.5);
  const mask = mechanic === "gravity" ? canyonMask(r, d) : groundedMask(step < 2 ? GROUNDED[0] : pick(r, GROUNDED));
  const cells = playableCells(mask);
  const setup: BoardSetup = {};
  let objective: Objective;
  let creep: LevelDef["creep"];
  const weights = [1, 1, 1, 1, 1];
  weights[realm.richIn] = 1.25;

  switch (mechanic) {
    case "basics": {
      const kind = step % 3;
      if (kind === 0) objective = { kind: "power", target: Math.round(lerp(150, 260, d) / 10) * 10 };
      else if (kind === 1) objective = { kind: "score", target: Math.round(lerp(4000, 9000, d) / 100) * 100 };
      else {
        const crystal = ((step / 3) % 5 | 0) as CrystalType;
        weights[crystal] = 1.35;
        objective = { kind: "collect", crystal, target: Math.round(lerp(20, 38, d)) };
      }
      break;
    }
    case "gravity": {
      weights[2] = 1.5;
      objective = step % 2 ? { kind: "power", target: Math.round(lerp(160, 225, d) / 10) * 10 } : { kind: "collect", crystal: 2, target: Math.round(lerp(24, 40, d)) };
      break;
    }
    case "ice": {
      setup.covers = coversOn(r, cells, "ice", Math.round(lerp(4, 14, d)), 2, d);
      objective = { kind: "cover", cover: "ice", target: setup.covers!.length };
      break;
    }
    case "chain": {
      const count = Math.round(lerp(4, 12, d));
      const chains = coversOn(r, cells, "chain", Math.ceil(count / 2), 2, d)!;
      const taken = new Set(chains.map(([x, y]) => `${x},${y}`));
      const ice = coversOn(r, cells.filter(([x, y]) => !taken.has(`${x},${y}`)), "ice", Math.floor(count / 2), 3, d)!;
      setup.covers = [...chains, ...ice];
      objective = { kind: "cover", cover: "chain", target: chains.length };
      break;
    }
    case "stone": {
      setup.blocks = groundedStones(r, mask, Math.round(lerp(3, 9, d)), 1 + Math.round(d * 2));
      objective = { kind: "stone", target: setup.blocks.length };
      break;
    }
    case "vine": {
      setup.covers = coversOn(r, cells, "vine", Math.round(lerp(4, 10, d)), 2, d);
      creep = { cover: "vine", every: 2 };
      objective = { kind: "cover", cover: "vine", target: setup.covers!.length }; // clear them all while they creep
      break;
    }
    case "rune": {
      setup.floor = runePattern(r, cells, Math.round(lerp(6, 18, d)), d);
      objective = { kind: "rune", target: setup.floor.length };
      break;
    }
    case "relic": {
      const total = Math.round(lerp(1.6, 4, d));
      setup.relics = { total, maxOnBoard: d > 0.3 ? 2 : 1 };
      objective = { kind: "relic", target: total };
      break;
    }
    case "ember": {
      setup.covers = coversOn(r, cells.filter(([, y]) => y >= 1), "ember", Math.round(lerp(6, 13, d)), 2, d);
      creep = { cover: "ember", every: 1 };
      objective = { kind: "cover", cover: "ember", target: setup.covers!.length };
      break;
    }
    default:
      objective = { kind: "power", target: 200 };
  }

  // later realms keep earlier lessons alive: a light secondary obstacle past the realm's midpoint
  if (realmIndex >= 3 && d > 0.45) {
    const extra = pick(r, SECONDARY.filter((m) => m !== mechanic));
    const occupied = new Set([...(setup.covers ?? []), ...(setup.blocks ?? [])].map(([x, y]) => `${x},${y}`));
    const free = cells.filter(([x, y]) => !occupied.has(`${x},${y}`));
    if (extra === "stone" && !setup.blocks) setup.blocks = groundedStones(r, mask, 2, 1);
    else if (extra === "rune" && !setup.floor) setup.floor = runePattern(r, free, 4, 0);
    else if ((extra === "ice" || extra === "chain") && mechanic !== "relic") setup.covers = [...(setup.covers ?? []), ...coversOn(r, free, extra as CoverKind, 3, 1, 0)!];
  }
  // stones must not sit on covered cells
  if (setup.blocks && setup.covers) {
    const stone = new Set(setup.blocks.map(([x, y]) => `${x},${y}`));
    const kept = setup.covers.filter(([x, y]) => !stone.has(`${x},${y}`));
    if (objective.kind === "cover") {
      const kind = objective.cover;
      const lost = setup.covers.filter((c) => c[2] === kind).length - kept.filter((c) => c[2] === kind).length;
      objective = { ...objective, target: objective.target - lost };
    }
    setup.covers = kept;
  }

  const gravityCharges = gravityRealm ? (mechanic === "gravity" ? 1 + Math.round(d * 2) : 2) : 0;
  const moves = CAMPAIGN_MOVES[n] ?? Math.max(12, Math.min(40, estimateMoves(objective, d)));
  // hidden twists and a possible secret: the player never knows what this island holds
  const plan = planIsland(seed, realm.id, realmIndex, step, moves);

  return {
    id: n,
    number: n,
    realmIndex,
    step,
    name: nameFor(realm, step, usedNames, r),
    seed,
    moves,
    objective,
    mask: mask.some((row) => row.includes("X")) ? mask : undefined,
    gravityCharges: gravityCharges || undefined,
    spawnWeights: weights.some((w) => w !== 1) ? weights : undefined,
    setup: Object.keys(setup).length ? setup : undefined,
    creep,
    realm: realm.id,
    islandSeed: seed * 31 + 7,
    ...(plan.twists.length ? { twists: plan.twists } : {}),
    ...(plan.secret ? { secret: plan.secret } : {}),
    story: islandStory(realm.id, seed, plan.secret),
  };
}

/** All 200 campaign levels (generated once; names are unique across the campaign). */
export function buildCampaign(): CampaignLevel[] {
  const used = new Set<string>(["Waking Stones", "Emerald Canyon", "Heart of the Falls"]);
  return Array.from({ length: CAMPAIGN_REALMS.length * LEVELS_PER_REALM }, (_, i) => buildCampaignLevel(i + 1, used));
}
