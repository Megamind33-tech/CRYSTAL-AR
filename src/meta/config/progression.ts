// Progression content: Keeper levels & unlocks, Sanctuary, quests (story/realm/keeper), achievements,
// and the Keeper's Return calendar.
import type { Achievement, CheckInCalendar, Quest, SanctuaryItem } from "../types.ts";

/** XP from level n to n+1. Gentle early, then flattening – levels mark milestones, not grind. */
export const xpToNext = (level: number) => Math.round(120 + 80 * Math.pow(level - 1, 1.15));
export const MAX_KEEPER_LEVEL = 60;

/** Progressive reveal: nothing competitive or commercial during the first session. */
export const FEATURE_UNLOCKS: { feature: string; level: number; name: string; blurb: string }[] = [
  { feature: "story", level: 1, name: "Realms", blurb: "Restore islands and open their portals." },
  { feature: "sanctuary", level: 2, name: "Sanctuary", blurb: "Your home island has begun to wake." },
  { feature: "duties", level: 3, name: "Keeper Duties", blurb: "Small daily tasks the realms ask of you." },
  { feature: "archive", level: 4, name: "Keeper Archive", blurb: "Everything you have recovered, remembered and rescued." },
  { feature: "achievements", level: 5, name: "Chronicles", blurb: "Your deeds, recorded." },
  { feature: "leaderboards", level: 6, name: "Rankings", blurb: "See how other Keepers are faring." },
  { feature: "trials", level: 7, name: "Realm Trials", blurb: "Fair, fixed-board competitions between Keepers." },
  { feature: "season", level: 8, name: "Season & Events", blurb: "The Eclipse Realm drifts closer." },
  { feature: "exchange", level: 8, name: "Realm Exchange", blurb: "Trade for cosmetics, expeditions and Aether." },
];

export const SANCTUARY: SanctuaryItem[] = [
  { id: "heart-altar", name: "Heart Altar", kind: "display", minKeeperLevel: 2, maxLevel: 5,
    cost: { base: { prismDust: 150, sanctuaryStone: 3 }, growth: 1.8 }, effect: { kind: "dustPct", perLevel: 4 }, rating: 20 },
  { id: "lumin-grove", name: "Lumin Grove", kind: "structure", minKeeperLevel: 2, maxLevel: 5,
    cost: { base: { prismDust: 120, sanctuaryStone: 2 }, growth: 1.7 }, effect: { kind: "luminSlots", perLevel: 1 }, rating: 15 },
  { id: "resonance-well", name: "Resonance Well", kind: "structure", minKeeperLevel: 3, maxLevel: 5,
    cost: { base: { prismDust: 180, sanctuaryStone: 3 }, growth: 1.8 }, effect: { kind: "idleResonancePerHour", perLevel: 6 }, rating: 15 },
  { id: "relic-hall", name: "Relic Hall", kind: "display", minKeeperLevel: 4, maxLevel: 4,
    cost: { base: { prismDust: 220, sanctuaryStone: 4 }, growth: 1.9 }, effect: { kind: "relicRegenPct", perLevel: 10 }, rating: 15 },
  { id: "keepers-study", name: "Keeper's Study", kind: "structure", minKeeperLevel: 5, maxLevel: 5,
    cost: { base: { prismDust: 260, sanctuaryStone: 4 }, growth: 1.8 }, effect: { kind: "xpPct", perLevel: 5 }, rating: 15 },
  { id: "moonpetal-garden", name: "Moonpetal Garden", kind: "decoration", minKeeperLevel: 2, maxLevel: 3,
    cost: { base: { prismDust: 80, luminFood: 2 }, growth: 1.6 }, rating: 10 },
  { id: "trophy-plinth", name: "Trophy Plinth", kind: "trophy", minKeeperLevel: 7, maxLevel: 3,
    cost: { base: { prismDust: 300, sanctuaryStone: 5 }, growth: 1.7 }, rating: 10 },
];

// ---- quests ----------------------------------------------------------------------------------
const q = (x: Quest) => x;

/** Story + realm quests: fixed, prerequisite-ordered, tied to real game state. */
export const QUESTS: Quest[] = [
  q({ id: "story-1-wake", category: "story", cadence: "once", title: "Restore the Waking Stones", metric: "islandsRestored", target: 1, reward: { prismDust: 50, keeperXp: 40 } }),
  q({ id: "story-2-shard", category: "story", cadence: "once", title: "Recover the Verdant Heart Shard", metric: "heartShards", target: 1, prerequisites: ["story-1-wake"], reward: { aether: 10, keeperXp: 80 } }),
  q({ id: "story-3-sanctuary", category: "story", cadence: "once", title: "Raise the Heart Altar in your Sanctuary", metric: "sanctuaryUpgrades", target: 1, prerequisites: ["story-2-shard"], reward: { prismDust: 100, keeperXp: 60, items: { luminFood: 3 } } }),
  q({ id: "story-4-eclipse", category: "story", cadence: "once", title: "Answer the Eclipse signal", metric: "portalsOpened", target: 4, prerequisites: ["story-3-sanctuary"], reward: { aether: 15, keeperXp: 120 } }),
  q({ id: "realm-verdant-stars", category: "realm", cadence: "once", realm: "verdant", title: "Earn 9 stars in the Verdant Reach", metric: "stars", target: 9, reward: { prismDust: 200, cosmetics: ["frame-verdant"] } }),
  q({ id: "realm-verdant-lumins", category: "realm", cadence: "once", realm: "verdant", title: "Rescue 3 Verdant Lumins", metric: "luminsRescued", target: 3, reward: { items: { luminFood: 5 }, keeperXp: 100 } }),
  q({ id: "realm-verdant-memories", category: "realm", cadence: "once", realm: "verdant", title: "Recover 3 Memory Crystals", metric: "memoriesFound", target: 3, reward: { aether: 10, keeperXp: 80 } }),
];

/** Keeper Duties (3-5 per day, rolled deterministically) and Realm Missions (weekly). */
export const DUTIES: Quest[] = [
  q({ id: "duty-cascades", category: "keeper", cadence: "daily", title: "Create 8 crystal cascades", metric: "cascades", target: 8, reward: { prismDust: 60, passXp: 40 } }),
  q({ id: "duty-restore", category: "keeper", cadence: "daily", title: "Restore 3 islands", metric: "islandsRestored", target: 3, reward: { prismDust: 70, passXp: 50 } }),
  q({ id: "duty-portals", category: "keeper", cadence: "daily", title: "Open 2 portals", metric: "portalsOpened", target: 2, reward: { prismDust: 60, passXp: 40 } }),
  q({ id: "duty-blue", category: "keeper", cadence: "daily", title: "Match 100 Deep Diamonds", metric: "blueCleared", target: 100, reward: { prismDust: 60, passXp: 40 } }),
  q({ id: "duty-resonance", category: "keeper", cadence: "daily", title: "Generate 2,500 Resonance", metric: "resonance", target: 2500, reward: { prismDust: 70, passXp: 50 } }),
  q({ id: "duty-relic", category: "keeper", cadence: "daily", title: "Use a relic", metric: "relicsUsed", target: 1, minKeeperLevel: 3, reward: { items: { relicCharge: 1 }, passXp: 30 } }),
  q({ id: "duty-nobooster", category: "keeper", cadence: "daily", title: "Restore an island without relics", metric: "noBoosterRestores", target: 1, reward: { prismDust: 80, passXp: 50 } }),
  q({ id: "duty-specials", category: "keeper", cadence: "daily", title: "Forge 4 Surge or Prism crystals", metric: "specialsCreated", target: 4, reward: { prismDust: 60, passXp: 40 } }),
];
export const DUTIES_PER_DAY = 4;
/** Completing this many duties in a day awards a Keeper's Cache. */
export const DUTY_CACHE_THRESHOLD = 3;
export const KEEPERS_CACHE: { prismDust: number; aether: number; items: { relicCharge: number; sanctuaryStone: number } } = {
  prismDust: 150, aether: 5, items: { relicCharge: 1, sanctuaryStone: 2 },
};

export const REALM_MISSIONS: Quest[] = [
  q({ id: "rm-restore-15", category: "keeper", cadence: "weekly", title: "Restore 15 islands", metric: "islandsRestored", target: 15, reward: { prismDust: 300, passXp: 250 } }),
  q({ id: "rm-memories-3", category: "keeper", cadence: "weekly", title: "Recover 3 Memory Crystals", metric: "memoriesFound", target: 3, reward: { aether: 15, passXp: 250 } }),
  q({ id: "rm-trials-5", category: "keeper", cadence: "weekly", title: "Complete 5 Realm Trial rounds", metric: "trialRounds", target: 5, minKeeperLevel: 7, reward: { prismDust: 250, passXp: 250 } }),
  q({ id: "rm-resonance-50k", category: "keeper", cadence: "weekly", title: "Generate 50,000 Resonance", metric: "resonance", target: 50000, reward: { prismDust: 350, passXp: 300 } }),
  q({ id: "rm-duties-20", category: "keeper", cadence: "weekly", title: "Complete 20 Keeper Duties", metric: "dutiesCompleted", target: 20, reward: { aether: 20, passXp: 300 } }),
  q({ id: "rm-rare-find", category: "keeper", cadence: "weekly", title: "Find a Rare-or-better collectible", metric: "rareFinds", target: 1, reward: { items: { portalFragment: 2 }, passXp: 200 } }),
  q({ id: "rm-perfect-5", category: "keeper", cadence: "weekly", title: "Earn 5 three-star restorations", metric: "perfectRestores", target: 5, reward: { prismDust: 300, passXp: 250 } }),
];
export const REALM_MISSIONS_PER_WEEK = 3;

// ---- achievements (Chronicles) -------------------------------------------------------------------
const tiers = (targets: number[], dust: number, points: number, extra: (i: number) => Partial<Achievement["tiers"][0]["reward"]> = () => ({})) =>
  targets.map((target, i) => ({ target, points: points * (i + 1), reward: { prismDust: dust * (i + 1), ...extra(i) } }));

export const ACHIEVEMENTS: Achievement[] = [
  { id: "ach-explorer", category: "explorer", name: "Pathfinder", description: "Open portals", metric: "portalsOpened", tiers: tiers([1, 10, 50, 200], 50, 10, (i) => (i === 3 ? { cosmetics: ["title-pathfinder"] } : {})) },
  { id: "ach-restorer", category: "restorer", name: "Restorer", description: "Restore islands", metric: "islandsRestored", tiers: tiers([1, 25, 100, 500], 60, 10, (i) => (i === 2 ? { cosmetics: ["frame-restorer"] } : {})) },
  { id: "ach-perfect", category: "restorer", name: "Flawless Keeper", description: "Three-star restorations", metric: "perfectRestores", tiers: tiers([1, 10, 50], 80, 15) },
  { id: "ach-lumins", category: "collector", name: "Lumin Friend", description: "Rescue Lumins", metric: "luminsRescued", tiers: tiers([1, 5, 10], 80, 15, (i) => (i === 2 ? { cosmetics: ["badge-lumin-friend"] } : {})) },
  { id: "ach-relics", category: "collector", name: "Relic Seeker", description: "Find relics", metric: "relicsFound", tiers: tiers([1, 3, 6], 80, 15) },
  { id: "ach-memories", category: "collector", name: "Rememberer", description: "Recover Memory Crystals", metric: "memoriesFound", tiers: tiers([1, 5, 10], 70, 15) },
  { id: "ach-cascade", category: "master", name: "Chain of Light", description: "Reach a cascade depth", metric: "bestCascade", tiers: tiers([3, 5, 7], 60, 20, (i) => (i === 2 ? { aether: 10 } : {})) },
  { id: "ach-combos", category: "master", name: "Resonant Fusion", description: "Fuse special crystals", metric: "combos", tiers: tiers([1, 20, 100], 60, 15) },
  { id: "ach-score", category: "master", name: "Radiant", description: "Score in a single restoration", metric: "bestScore", tiers: tiers([3000, 6000, 10000], 60, 20) },
  { id: "ach-shards", category: "keeper", name: "Heartmender", description: "Recover Heart Shards", metric: "heartShards", tiers: tiers([1, 4, 12], 100, 25, (i) => (i === 2 ? { cosmetics: ["title-heartmender"] } : {})) },
  { id: "ach-trials", category: "champion", name: "Trialborn", description: "Complete Realm Trial rounds", metric: "trialRounds", tiers: tiers([1, 10, 50], 70, 15) },
  { id: "ach-trial-wins", category: "champion", name: "Champion of the Realms", description: "Finish first in a Realm Trial", metric: "trialsWon", tiers: tiers([1, 5, 20], 150, 30, () => ({ cosmetics: ["trophy-trial-champion"] })) },
  { id: "ach-loyal", category: "loyalty", name: "Faithful Keeper", description: "Keeper's Return days", metric: "checkins", tiers: tiers([7, 30, 100, 365], 60, 15, (i) => (i >= 2 ? { cosmetics: [`frame-faithful-${i}`] } : {})) },
  { id: "ach-secret-quiet", category: "secrets", name: "The Quiet Board", description: "Restore an island using no special crystals", metric: "noBoosterRestores", hidden: true, tiers: tiers([1], 100, 25, () => ({ cosmetics: ["badge-quiet-board"] })) },
  { id: "ach-secret-storm", category: "secrets", name: "Crystal Storm", description: "Reach a cascade of 9", metric: "bestCascade", hidden: true, tiers: tiers([9], 200, 40, () => ({ cosmetics: ["portal-effect-storm"] })) },
];

// ---- Keeper's Return -----------------------------------------------------------------------------------
export const KEEPERS_RETURN: CheckInCalendar = {
  id: "keepers-return-v1",
  cycle: [
    { day: 1, label: "Prism Dust", reward: { prismDust: 60 } },
    { day: 2, label: "Relic Charge", reward: { items: { relicCharge: 1 } } },
    { day: 3, label: "Portal Fragment", reward: { items: { portalFragment: 1 } } },
    { day: 4, label: "Prism Dust", reward: { prismDust: 90 } },
    { day: 5, label: "Lumin Food", reward: { items: { luminFood: 2, sanctuaryStone: 1 } } },
    { day: 6, label: "Aether Crystal", reward: { aether: 5 } },
    { day: 7, label: "Keeper's Cache", reward: { items: { keepersCache: 1 } } },
  ],
  milestones: [
    { streak: 7, reward: { aether: 10, cosmetics: ["badge-return-7"] } },
    { streak: 14, reward: { items: { streakRestore: 1, portalFragment: 2 } } },
    { streak: 30, reward: { aether: 30, cosmetics: ["frame-return-30"] } },
    { streak: 60, reward: { items: { streakRestore: 1 }, cosmetics: ["sanctuary-lantern-arch"] } },
    { streak: 100, reward: { aether: 60, cosmetics: ["title-ever-returning"] } },
  ],
  graceDays: 1,
};
