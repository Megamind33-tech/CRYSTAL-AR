// Boost system: pre-match power-ups that players can buy or equip before a level.
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
    description: "Start with 5 additional moves",
    cost: 250,
    effect: "Gain 5 moves",
    icon: "➕",
    rarity: "common",
  },
  moves_plus_10: {
    id: "moves_plus_10",
    name: "Extra Moves +10",
    description: "Start with 10 additional moves",
    cost: 450,
    effect: "Gain 10 moves",
    icon: "➕➕",
    rarity: "uncommon",
  },
  gem_multiplier: {
    id: "gem_multiplier",
    name: "Gem Multiplier ×1.25",
    description: "All gem matches worth 25% more points",
    cost: 300,
    effect: "Gem points × 1.25",
    icon: "✦",
    rarity: "uncommon",
  },
  surge_rate_up: {
    id: "surge_rate_up",
    name: "Surge Rush",
    description: "Surge gems spawn 30% more frequently",
    cost: 350,
    effect: "Surges spawn faster",
    icon: "⚡",
    rarity: "uncommon",
  },
  starting_clears: {
    id: "starting_clears",
    name: "Board Prep",
    description: "Start with 2 random moves pre-matched",
    cost: 400,
    effect: "2 free matches",
    icon: "✓✓",
    rarity: "rare",
  },
};

/** Boost effects: how they modify the game engine when active. */
export interface BoostEffects {
  extraMoves: number;
  gemPointsMultiplier: number;
  surgeSpawnRate: number; // 1.0 = normal, 1.3 = 30% faster
  startingClears: number;
}

export function boostEffects(active: BoostId[]): BoostEffects {
  const effects: BoostEffects = {
    extraMoves: 0,
    gemPointsMultiplier: 1,
    surgeSpawnRate: 1,
    startingClears: 0,
  };
  for (const id of active) {
    switch (id) {
      case "moves_plus_5":
        effects.extraMoves += 5;
        break;
      case "moves_plus_10":
        effects.extraMoves += 10;
        break;
      case "gem_multiplier":
        effects.gemPointsMultiplier *= 1.25;
        break;
      case "surge_rate_up":
        effects.surgeSpawnRate *= 1.3;
        break;
      case "starting_clears":
        effects.startingClears += 2;
        break;
    }
  }
  return effects;
}
