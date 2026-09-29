// One entry per Armory item. `gem` is a shipped Meshy model (assets/models/meshy/*.glb). To give an item bespoke art,
// generate a model for it with Meshy (fetch-meshy.mjs), bake it, and point `gem` at it: nothing else changes.
const RARITY = {
  common: { glow: "#4df0a8", bg: ["#0f3a34", "#0a1a2c"] },
  uncommon: { glow: "#58b8ff", bg: ["#123a72", "#0a1330"] },
  rare: { glow: "#ffc25c", bg: ["#6a3d10", "#1c1024"] },
};
const item = (id, rarity, o) => ({ id, ...RARITY[rarity], ...o });

export const ICONS = [
  item("moves_plus_3", "common", { gem: "gem_blue", count: 1, gemScale: 1.2, label: "+3", gemGlow: "#3fb0ff", gemTint: "#7fd0ff", seed: 3 }),
  item("moves_plus_5", "common", { gem: "gem_blue", count: 2, label: "+5", gemGlow: "#3fb0ff", gemTint: "#7fd0ff", seed: 5 }),
  item("moves_plus_10", "uncommon", { gem: "gem_blue", count: 3, label: "+10", gemGlow: "#3fb0ff", gemTint: "#7fd0ff", seed: 10, bloom: 0.85 }),
  item("gem_multiplier", "uncommon", { gem: "gem_gold", count: 2, label: "×1.25", gemGlow: "#ffb020", gemTint: "#ffd880", seed: 12, plaqueGlow: "#ffd060" }),
  item("score_x15", "rare", { gem: "gem_gold", count: 4, label: "×1.5", gemGlow: "#ffb020", gemTint: "#ffd880", seed: 15, bloom: 0.9, plaqueGlow: "#ffd060" }),
  item("charge_start", "common", { gem: "gem_prism", count: 1, label: "+25", gemGlow: "#ff7ad9", gemTint: "#ffd0f4", mote: "#ffffff", seed: 25, mat: { irid: 1, emit: 0.35 }, gemScale: 1.05 }),
  item("surge_rate_up", "uncommon", { gem: "gem_purple", count: 1, gemScale: 1.15, aura: 2, label: "2", gemGlow: "#a05cff", gemTint: "#d8b0ff", seed: 2 }),
  item("surge_four", "rare", { gem: "gem_purple", count: 2, aura: 2, auraScale: 0.85, label: "4", gemGlow: "#a05cff", gemTint: "#d8b0ff", seed: 4, bloom: 0.9 }),
  item("starting_clears", "uncommon", { gem: "gem_green", count: 2, shards: 10, label: "2", gemGlow: "#3fe08a", gemTint: "#a8ffd0", seed: 22 }),
  item("prep_four", "rare", { gem: "gem_green", count: 4, shards: 18, label: "4", gemGlow: "#3fe08a", gemTint: "#a8ffd0", seed: 44, bloom: 0.9 }),
];
