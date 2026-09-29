// Boost system: pre-match power-ups bought in the Armory and equipped before a level.
// Every effect is deterministic and applied by one shared function, so the replay verifier reproduces it exactly.
import type { LevelDef } from "./level.ts";

export type BoostId =
  | "moves_plus_3" | "moves_plus_5" | "moves_plus_10"
  | "gem_multiplier" | "score_x15"
  | "surge_rate_up" | "surge_four" | "starting_clears" | "prep_four" | "charge_start";

export type BoostCategory = "moves" | "score" | "power";
/** Which emblem the Armory draws for the boost. */
export type BoostArt = "moves" | "score" | "surge" | "prep" | "charge";

export interface Boost {
  id: BoostId;
  name: string;
  description: string;
  cost: number; // coins
  effect: string; // short summary of what it does
  rarity: "common" | "uncommon" | "rare";
  category: BoostCategory;
  art: BoostArt;
  /** 1-3: how strong this is within its family (drawn as pips) */
  tier: 1 | 2 | 3;
}

export const CATEGORIES: { id: BoostCategory; name: string }[] = [
  { id: "moves", name: "Moves" },
  { id: "score", name: "Score" },
  { id: "power", name: "Power" },
];

export const BOOSTS: Record<BoostId, Boost> = {
  moves_plus_3: { id: "moves_plus_3", name: "Spare Moves", description: "Start the level with 3 additional moves.", cost: 120, effect: "+3 moves", rarity: "common", category: "moves", art: "moves", tier: 1 },
  moves_plus_5: { id: "moves_plus_5", name: "Extra Moves +5", description: "Start the level with 5 additional moves.", cost: 250, effect: "+5 moves", rarity: "common", category: "moves", art: "moves", tier: 2 },
  moves_plus_10: { id: "moves_plus_10", name: "Extra Moves +10", description: "Start the level with 10 additional moves.", cost: 450, effect: "+10 moves", rarity: "uncommon", category: "moves", art: "moves", tier: 3 },
  gem_multiplier: { id: "gem_multiplier", name: "Gem Multiplier", description: "Every match scores 25% more points.", cost: 300, effect: "Score ×1.25", rarity: "uncommon", category: "score", art: "score", tier: 1 },
  score_x15: { id: "score_x15", name: "Radiant Multiplier", description: "Every match scores 50% more points.", cost: 600, effect: "Score ×1.5", rarity: "rare", category: "score", art: "score", tier: 3 },
  charge_start: { id: "charge_start", name: "Portal Spark", description: "The portal begins with 25 energy already stored.", cost: 200, effect: "+25 portal energy", rarity: "common", category: "power", art: "charge", tier: 1 },
  surge_rate_up: { id: "surge_rate_up", name: "Surge Rush", description: "Begin with 2 Surge crystals already forged on the board.", cost: 350, effect: "2 starting Surges", rarity: "uncommon", category: "power", art: "surge", tier: 1 },
  surge_four: { id: "surge_four", name: "Storm Cache", description: "Begin with 4 Surge crystals already forged on the board.", cost: 650, effect: "4 starting Surges", rarity: "rare", category: "power", art: "surge", tier: 3 },
  starting_clears: { id: "starting_clears", name: "Board Prep", description: "Two free matches are cleared before your first move. They cost no moves.", cost: 400, effect: "2 free matches", rarity: "uncommon", category: "power", art: "prep", tier: 1 },
  prep_four: { id: "prep_four", name: "Grand Prep", description: "Four free matches are cleared before your first move. They cost no moves.", cost: 750, effect: "4 free matches", rarity: "rare", category: "power", art: "prep", tier: 3 },
};

export const BOOST_IDS = Object.keys(BOOSTS) as BoostId[];
/** How many boosts can be equipped for a single run. */
export const BOOST_SLOTS = 3;

/** Boost effects: how they modify a run when active. */
export interface BoostEffects {
  extraMoves: number;
  scoreMultiplier: number;
  startSurges: number;
  startingClears: number;
  startCharge: number;
}

export function boostEffects(active: readonly BoostId[]): BoostEffects {
  const effects: BoostEffects = { extraMoves: 0, scoreMultiplier: 1, startSurges: 0, startingClears: 0, startCharge: 0 };
  for (const id of active) {
    switch (id) {
      case "moves_plus_3": effects.extraMoves += 3; break;
      case "moves_plus_5": effects.extraMoves += 5; break;
      case "moves_plus_10": effects.extraMoves += 10; break;
      case "gem_multiplier": effects.scoreMultiplier *= 1.25; break;
      case "score_x15": effects.scoreMultiplier *= 1.5; break;
      case "surge_rate_up": effects.startSurges += 2; break;
      case "surge_four": effects.startSurges += 4; break;
      case "starting_clears": effects.startingClears += 2; break;
      case "prep_four": effects.startingClears += 4; break;
      case "charge_start": effects.startCharge += 25; break;
    }
  }
  return effects;
}

/** Returns the reason an equipped list is not allowed, or null when it is fine. */
export function invalidLoadout(ids: readonly string[] | undefined): string | null {
  if (!ids || ids.length === 0) return null;
  if (ids.length > BOOST_SLOTS) return "too many boosts equipped";
  if (new Set(ids).size !== ids.length) return "duplicate boosts equipped";
  if (ids.some((id) => !(id in BOOSTS))) return "unknown boost equipped";
  return null;
}

/** The level a run is played on once the equipped boosts are applied (shared by the game and the verifier). */
export function applyBoostsToLevel(level: LevelDef, active: readonly BoostId[]): LevelDef {
  const e = boostEffects(active);
  if (e.extraMoves === 0 && e.scoreMultiplier === 1) return level;
  return { ...level, moves: level.moves + e.extraMoves, scoreMultiplier: e.scoreMultiplier };
}
