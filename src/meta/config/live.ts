// Live-game configuration: seasons + Crystal Pass, events, leaderboards, leagues, Realm Trials, the
// Realm Exchange, notifications and economy balance. All data – swap for remote config later.
import type { GameEvent, LeaderboardDef, LeagueId, NotificationClass, PassTier, Reward, Season, StoreOffer, TrialDef } from "../types.ts";

// ---- economy balance -----------------------------------------------------------------------------
export const ECONOMY = {
  startingWallet: { prismDust: 150, aether: 0, coins: 500 },
  /** Prism Dust per star multiplier on island replays */
  starMultiplier: [1, 1, 1.2, 1.4],
  /** duplicate collectibles convert to Prism Dust */
  duplicateLumin: 60,
  duplicateRelic: 40,
  /** "Stabilize Portal" on failure (+5 moves) */
  stabilize: { moves: 5, prismDust: 120, aether: 15, perRunLimit: 2 },
  levelUpGift: (level: number): Reward => ({ prismDust: 40 + level * 10, ...(level % 5 === 0 ? { aether: 10 } : {}) }),
  /** Aether per day that can be *earned* – keeps premium currency meaningful but reachable. */
  aetherEarnSoftCapPerDay: 25,
  sanctuaryIdleCapHours: 16,
};

// ---- seasons -----------------------------------------------------------------------------------------
const passTiers = (): PassTier[] =>
  Array.from({ length: 40 }, (_, i) => {
    const tier = i + 1;
    const five = tier % 5 === 0;
    const free: Reward = five ? { prismDust: 150, items: { portalFragment: 1 } } : tier % 2 ? { prismDust: 50 + tier * 2 } : { items: { relicCharge: 1 } };
    if (tier === 20) free.items = { ...free.items, streakRestore: 1 };
    const premium: Reward =
      tier === 40 ? { lumins: ["umbrafin"], cosmetics: ["skin-umbrafin-corona", "title-eclipse-keeper"] }
      : tier === 25 ? { cosmetics: ["portal-effect-eclipse"], aether: 30 }
      : tier === 15 ? { cosmetics: ["sanctuary-eclipse-arch"], memories: ["mem-what-waits"] }
      : five ? { aether: 25, cosmetics: [`frame-eclipse-${tier}`] }
      : tier % 3 === 0 ? { items: { luminFood: 3, sanctuaryStone: 2 } }
      : { prismDust: 120 + tier * 4 };
    return { tier, passXp: Math.round(200 * tier + 6 * tier * tier), free, premium };
  });

export const SEASONS: Season[] = [
  {
    id: "s01-eclipse",
    number: 1,
    name: "The Eclipse Realm",
    theme: "A strange temporary realm begins intersecting with the others.",
    startsAt: Date.UTC(2026, 8, 21),
    endsAt: Date.UTC(2026, 10, 2), // 6 weeks
    realm: "eclipse",
    passTiers: passTiers(),
    quests: ["season-eclipse-open", "season-eclipse-memories"],
    memories: ["mem-borrowed-light", "mem-what-waits"],
    exclusiveLumins: ["umbrafin"],
    trialSeries: ["trial-weekly-eclipse", "trial-championship"],
  },
];

export const SEASON_QUESTS = [
  { id: "season-eclipse-open", category: "realm" as const, cadence: "season" as const, season: "s01-eclipse", title: "Stabilise the Eclipse Threshold", metric: "portalsOpened" as const, target: 5, reward: { passXp: 400, aether: 10 } },
  { id: "season-eclipse-memories", category: "realm" as const, cadence: "season" as const, season: "s01-eclipse", title: "Recover the Eclipse memories", metric: "memoriesFound" as const, target: 6, reward: { passXp: 500, cosmetics: ["badge-eclipse-archivist"] } },
];

// ---- events ----------------------------------------------------------------------------------------------
export const EVENTS: GameEvent[] = [
  {
    id: "ev-storm-surge-1", title: "Storm Surge", theme: "storm",
    startsAt: Date.UTC(2026, 8, 25, 16), endsAt: Date.UTC(2026, 8, 28, 16),
    eligibleIslands: "all", modifiers: { resonanceMultiplier: 1.5 },
    quests: ["duty-cascades"], rewards: { prismDust: 200, cosmetics: ["badge-storm-surge"] }, leaderboard: "weeklyResonance",
  },
  {
    id: "ev-memory-hunt-1", title: "Memory Crystal Hunt", theme: "archive",
    startsAt: Date.UTC(2026, 9, 2, 16), endsAt: Date.UTC(2026, 9, 5, 16),
    eligibleIslands: ["hollow-of-lanterns", "eclipse-threshold"], modifiers: { memoryDropBoost: 2 },
    quests: ["rm-memories-3"], rewards: { aether: 15 },
  },
  {
    id: "ev-double-resonance-1", title: "Double Resonance Weekend", theme: "radiant",
    startsAt: Date.UTC(2026, 9, 9, 16), endsAt: Date.UTC(2026, 9, 12, 16),
    eligibleIslands: "all", modifiers: { resonanceMultiplier: 2, dustMultiplier: 1.25 },
    quests: [], rewards: {}, trial: "trial-weekend-resonance",
  },
];

// ---- competition ------------------------------------------------------------------------------------------
export const LEADERBOARDS: LeaderboardDef[] = [
  { id: "globalKeeper", name: "Keeper Ranking", metric: "keeperScore", resets: "never", scope: "global" },
  { id: "weeklyResonance", name: "Weekly Resonance", metric: "weeklyResonance", resets: "weekly", scope: "global" },
  { id: "portalMaster", name: "Portal Master", metric: "portalsOpened", resets: "season", scope: "global" },
  { id: "restoration", name: "Restoration", metric: "restorationScore", resets: "never", scope: "global" },
  { id: "combo", name: "Longest Chain", metric: "bestCascade", resets: "season", scope: "global" },
  { id: "trials", name: "Trial Standings", metric: "trialPoints", resets: "season", scope: "global" },
  { id: "friends", name: "Friends", metric: "keeperScore", resets: "never", scope: "friends" },
  { id: "regional", name: "Regional", metric: "keeperScore", resets: "never", scope: "country" },
];

/** League thresholds use season trial points only – never spend. */
export const LEAGUES: { id: LeagueId; name: string; minPoints: number }[] = [
  { id: "stone", name: "Stone Keeper", minPoints: 0 },
  { id: "bronze", name: "Bronze Keeper", minPoints: 150 },
  { id: "silver", name: "Silver Keeper", minPoints: 400 },
  { id: "gold", name: "Gold Keeper", minPoints: 900 },
  { id: "prism", name: "Prism Keeper", minPoints: 1800 },
  { id: "celestial", name: "Celestial Keeper", minPoints: 3500 },
];

const trialRewards = (scale: number) => [
  { top: 1, reward: { aether: 30 * scale, trophies: ["trophy-trial-gold"], passXp: 300 * scale } },
  { top: 3, reward: { aether: 20 * scale, trophies: ["trophy-trial-silver"], passXp: 220 * scale } },
  { top: 10, reward: { aether: 10 * scale, passXp: 160 * scale } },
  { top: 0.25, reward: { prismDust: 200 * scale, passXp: 100 * scale } },
];

export const TRIALS: TrialDef[] = [
  { id: "trial-daily-highscore", name: "Daily High-Score Trial", kind: "highScore", schedule: "daily", levelIndex: 2, moves: 18, attempts: 3, approvedRelics: ["oracle-stone"], minKeeperLevel: 7, rewards: trialRewards(1), participation: { prismDust: 60, passXp: 60 } },
  { id: "trial-weekend-resonance", name: "Weekend Resonance Rush", kind: "resonanceRush", schedule: "weekend", levelIndex: 0, moves: 40, timeLimitSec: 120, attempts: 5, approvedRelics: [], minKeeperLevel: 7, rewards: trialRewards(2), participation: { prismDust: 100, passXp: 100 } },
  { id: "trial-weekly-eclipse", name: "Eclipse Limited-Moves Trial", kind: "limitedMoves", schedule: "weekly", levelIndex: 4, moves: 14, attempts: 5, approvedRelics: ["oracle-stone", "keepers-lens"], minKeeperLevel: 7, rewards: trialRewards(2), participation: { prismDust: 120, passXp: 120 } },
  { id: "trial-cascade", name: "Cascade Trial", kind: "cascade", schedule: "daily", levelIndex: 1, moves: 15, attempts: 3, approvedRelics: [], minKeeperLevel: 7, rewards: trialRewards(1), participation: { prismDust: 60, passXp: 60 } },
  { id: "trial-championship", name: "Season Championship", kind: "portal", schedule: "championship", levelIndex: 5, moves: 16, attempts: 1, approvedRelics: [], minKeeperLevel: 10, rewards: trialRewards(5), participation: { prismDust: 300, passXp: 300 } },
];

// ---- Realm Exchange ---------------------------------------------------------------------------------------------
/** IAP prices are placeholders pending Play Console setup. Heart Shards are never sold. */
export const STORE: StoreOffer[] = [
  { id: "pass-s01", section: "pass", name: "Crystal Pass: The Eclipse Realm", description: "Premium track for Season 01 – cosmetics, the Umbrafin Lumin, side-story memories.", price: { kind: "iap", sku: "crystal_pass_s01", displayUsd: 4.99 }, grants: { unlockPass: "s01-eclipse" }, limit: 1, minKeeperLevel: 8 },
  { id: "aether-80", section: "aether", name: "Aether Vial", description: "80 Aether Crystals", price: { kind: "iap", sku: "aether_80", displayUsd: 0.99 }, grants: { aether: 80 } },
  { id: "aether-450", section: "aether", name: "Aether Flask", description: "450 Aether Crystals", price: { kind: "iap", sku: "aether_450", displayUsd: 4.99 }, grants: { aether: 450 } },
  { id: "aether-1000", section: "aether", name: "Aether Reservoir", description: "1,000 Aether Crystals", price: { kind: "iap", sku: "aether_1000", displayUsd: 9.99 }, grants: { aether: 1000 } },
  { id: "sanct-moon-arch", section: "sanctuary", name: "Moonstone Arch", description: "A Sanctuary archway that glows at dusk.", price: { kind: "aether", amount: 120 }, grants: { cosmetics: ["sanctuary-moon-arch"] }, limit: 1 },
  { id: "sanct-stone-bundle", section: "sanctuary", name: "Mason's Bundle", description: "10 Sanctuary Stone", price: { kind: "prismDust", amount: 400 }, grants: { items: { sanctuaryStone: 10 } } },
  { id: "lumin-skin-autumn", section: "lumins", name: "Autumn Mossling", description: "Cosmetic skin for your Mossling.", price: { kind: "aether", amount: 90 }, grants: { cosmetics: ["mossling-autumn"] }, limit: 1 },
  { id: "portal-effect-aurora", section: "portalEffects", name: "Aurora Portal", description: "Your portals open in ribbons of aurora.", price: { kind: "aether", amount: 150 }, grants: { cosmetics: ["portal-effect-aurora"] }, limit: 1 },
  { id: "relic-charges", section: "relics", name: "Relic Recharge", description: "3 relic charges (not usable in ranked Trials).", price: { kind: "prismDust", amount: 250 }, grants: { items: { relicCharge: 3 } } },
  { id: "expedition-frozen", section: "expeditions", name: "Frostbound Signal", description: "Open the Frozen Verge expedition while the signal lasts.", price: { kind: "aether", amount: 120 }, grants: {}, limit: 1, minKeeperLevel: 5 },
];

// ---- notifications ---------------------------------------------------------------------------------------------
export const NOTIFICATIONS: Record<NotificationClass, { title: string; body: string; defaultOn: boolean }> = {
  sanctuaryResonance: { title: "Sanctuary", body: "Your Sanctuary has gathered Resonance while you were away.", defaultOn: true },
  realmGate: { title: "Realm Gate", body: "A Realm Gate has become active.", defaultOn: true },
  trialOpen: { title: "Realm Trials", body: "The Weekend Realm Trial has opened.", defaultOn: true },
  expeditionReturn: { title: "Expedition", body: "An expedition signal is fading – it closes soon.", defaultOn: false },
  keepersReturn: { title: "Keeper's Return", body: "Your Keeper's Return is ready.", defaultOn: true },
  eventStart: { title: "Event", body: "Something is stirring in the Shattered Realms.", defaultOn: true },
};
