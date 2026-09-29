// Boost system: pre-match power-ups bought in the Armory and equipped before a level.
// Every effect is deterministic and applied by one shared function, so the replay verifier reproduces it exactly.
import type { LevelDef } from "./level.ts";

export type BoostId = "moves_plus_5" | "moves_plus_10" | "gem_multiplier" | "surge_rate_up" | "starting_clears";

export interface Boost {
  id: BoostId;
  name: string;
  description: string;
  cost: number; // coins
  effect: string; // short summary of what it does
  icon: string; // emoji or glyph
  rarity: "common" | "uncommon" | "rare";
}

export const BOOSTS: Record<BoostId, Boost> = {
  moves_plus_5: {
    id: "moves_plus_5",
    name: "Extra Moves +5",
    description: "Start the level with 5 additional moves.",
    cost: 250,
    effect: "+5 moves",
    icon: "➕",
    rarity: "common",
  },
  moves_plus_10: {
    id: "moves_plus_10",
    name: "Extra Moves +10",
    description: "Start the level with 10 additional moves.",
    cost: 450,
    effect: "+10 moves",
    icon: "➕➕",
    rarity: "uncommon",
  },
  gem_multiplier: {
    id: "gem_multiplier",
    name: "Gem Multiplier ×1.25",
    description: "Every match scores 25% more points.",
    cost: 300,
    effect: "Score ×1.25",
    icon: "✦",
    rarity: "uncommon",
  },
  surge_rate_up: {
    id: "surge_rate_up",
    name: "Surge Rush",
    description: "Begin with 2 Surge crystals already forged on the board.",
    cost: 350,
    effect: "2 starting Surges",
    icon: "⚡",
    rarity: "uncommon",
  },
  starting_clears: {
    id: "starting_clears",
    name: "Board Prep",
    description: "Two free matches are cleared before your first move. They cost no moves.",
    cost: 400,
    effect: "2 free matches",
    icon: "✓✓",
    rarity: "rare",
  },
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
}

export function boostEffects(active: readonly BoostId[]): BoostEffects {
  const effects: BoostEffects = { extraMoves: 0, scoreMultiplier: 1, startSurges: 0, startingClears: 0 };
  for (const id of active) {
    switch (id) {
      case "moves_plus_5": effects.extraMoves += 5; break;
      case "moves_plus_10": effects.extraMoves += 10; break;
      case "gem_multiplier": effects.scoreMultiplier *= 1.25; break;
      case "surge_rate_up": effects.startSurges += 2; break;
      case "starting_clears": effects.startingClears += 2; break;
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
