// Lumins (living crystal creatures) and Relics (ancient tools with charges).
import type { Lumin, Relic } from "../types.ts";

export const LUMINS: Lumin[] = [
  { id: "mossling", name: "Mossling", species: "Mossling", realm: "verdant", rarity: "common", animationSet: "hop",
    sanctuaryBehaviour: "Naps in sunny patches and hums when you match crystals nearby.",
    discovery: "Tumbled out of the first portal you opened, dim and frightened.",
    bonus: { kind: "dustPct", value: 5 }, skins: ["mossling-autumn"], evolvesTo: { lumin: "mossward", bond: 10 } },
  { id: "mossward", name: "Mossward", species: "Mossling", realm: "verdant", rarity: "rare", animationSet: "hop",
    sanctuaryBehaviour: "Patrols the Sanctuary paths, tidying fallen leaves.",
    discovery: "A Mossling that learned to trust its Keeper.",
    bonus: { kind: "dustPct", value: 10 } },
  { id: "fallsprite", name: "Fallsprite", species: "Sprite", realm: "verdant", rarity: "rare", animationSet: "glide",
    sanctuaryBehaviour: "Rides the spray of any water feature, leaving tiny rainbows.",
    discovery: "Circled the Heart Shard beneath the falls, guarding it until you came.",
    bonus: { kind: "startResonance", value: 5 } },
  { id: "lanternmoth", name: "Lanternmoth", species: "Moth", realm: "verdant", rarity: "epic", animationSet: "glide",
    sanctuaryBehaviour: "Gathers at relic displays after dark, lighting them from within.",
    discovery: "Its wings hold the last light of a fallen Realm Gate.",
    bonus: { kind: "relicRegenPct", value: 15 } },
  { id: "umbrafin", name: "Umbrafin", species: "Finling", realm: "eclipse", rarity: "mythic", animationSet: "swim",
    sanctuaryBehaviour: "Swims through the air as if it were water, and hides from bright light.",
    discovery: "Surfaced from the Eclipse Threshold as the portal stabilised.",
    bonus: { kind: "xpPct", value: 10 }, skins: ["umbrafin-corona"] },
  { id: "rimeback", name: "Rimeback", species: "Burrower", realm: "frozen", rarity: "epic", animationSet: "burrow",
    sanctuaryBehaviour: "Digs little frost burrows and sleeps in them.",
    discovery: "Answered the Frostbound Signal from under the ice.",
    bonus: { kind: "dustPct", value: 8 } },
  { id: "heartwarden", name: "Heartwarden", species: "Warden", realm: "verdant", rarity: "ancient", animationSet: "hover",
    sanctuaryBehaviour: "Stands beside the Heart Altar, turning slowly with the reassembled facets.",
    discovery: "Said to wake only when a Keeper restores every island of a realm at three stars.",
    bonus: { kind: "xpPct", value: 15 } },
];

export const RELICS: Relic[] = [
  { id: "oracle-stone", name: "Oracle Stone", rarity: "common", set: "Keeper's First Tools", effect: "hint", effectValue: 1,
    maxCharges: 3, regenMinutes: 60, trialApproved: true, lore: "Warm to the touch when a good move is near." },
  { id: "chrono-crystal", name: "Chrono Crystal", rarity: "rare", set: "Keeper's First Tools", effect: "addMoves", effectValue: 3,
    maxCharges: 2, regenMinutes: 240, trialApproved: false, lore: "Slows the portal's collapse for three heartbeats." },
  { id: "prism-hammer", name: "Prism Hammer", rarity: "rare", set: "Keeper's First Tools", effect: "shatterTile", effectValue: 1,
    maxCharges: 2, regenMinutes: 180, trialApproved: false, lore: "Strikes one crystal free of the pattern." },
  { id: "realm-compass", name: "Realm Compass", rarity: "epic", set: "Wayfinder's Kit", effect: "reshuffle", effectValue: 1,
    maxCharges: 1, regenMinutes: 360, trialApproved: false, lore: "Spins until the realm rearranges itself around it." },
  { id: "star-key", name: "Star Key", rarity: "epic", set: "Wayfinder's Kit", effect: "openHiddenGate", effectValue: 1,
    maxCharges: 1, regenMinutes: 1440, trialApproved: false, lore: "Fits no lock anyone has ever seen." },
  { id: "keepers-lens", name: "Keeper's Lens", rarity: "mythic", set: "Wayfinder's Kit", effect: "revealSecrets", effectValue: 1,
    maxCharges: 1, regenMinutes: 720, trialApproved: true, lore: "Shows what the island is hiding from you." },
];

export const RELIC_SETS: Record<string, { reward: { aether: number; keeperXp: number; title: string } }> = {
  "Keeper's First Tools": { reward: { aether: 40, keeperXp: 200, title: "Toolbearer" } },
  "Wayfinder's Kit": { reward: { aether: 60, keeperXp: 300, title: "Wayfinder" } },
};

export const RARITY_ORDER = ["common", "rare", "epic", "mythic", "ancient"] as const;
