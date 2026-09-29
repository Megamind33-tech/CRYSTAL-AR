// Crystals AR meta-game domain model. Pure data: no React, no Viro, no I/O.
// Fiction: the Prism Heart shattered into the Shattered Realms; the player is a Keeper restoring them.
// All content is referenced by stable string IDs so it can later come from remote config.

// ---------------------------------------------------------------- economy ---
/** Prism Dust: main earned currency. Aether Crystals: premium (earnable slowly, purchasable). */
export type CurrencyId = "prismDust" | "aether";

/** Consumable world items (not currencies). */
export type ItemId =
  | "relicCharge"      // refills one relic charge
  | "portalFragment"   // 5 fragments open a Discovery Portal
  | "luminFood"        // Sanctuary resource: raises Lumin bond
  | "sanctuaryStone"   // Sanctuary construction resource
  | "streakRestore"    // repairs a missed Keeper's Return day (earned only)
  | "keepersCache"     // opens to a fixed, displayed bundle (never random)
  | "starKey";         // opens hidden Realm Gates

export type Rarity = "common" | "rare" | "epic" | "mythic" | "ancient";

export interface Reward {
  prismDust?: number;
  aether?: number;
  keeperXp?: number;
  passXp?: number;
  items?: Partial<Record<ItemId, number>>;
  lumins?: string[];
  relics?: string[];
  memories?: string[];
  heartShards?: string[];
  cosmetics?: string[];   // titles, frames, badges, Sanctuary decorations, portal effects
  trophies?: string[];
}

// ------------------------------------------------------------------- world ---
export type PortalClass = "story" | "discovery" | "expedition";

export interface Realm {
  id: string;
  name: string;
  blurb: string;
  order: number;
  /** Keeper level required to see the Realm Gate */
  minKeeperLevel: number;
  /** Heart Shards that must be recovered before the gate opens (earned only, never sold) */
  requiresShards: number;
  islands: string[];
  seasonal?: string;
}

export interface Island {
  id: string;
  realm: string;
  name: string;
  portal: PortalClass;
  /** index into the match engine's LEVELS */
  levelIndex: number;
  /** island that must be restored first (story order) */
  after?: string;
  /** Discovery portals: cost in portalFragments / starKeys */
  unlockCost?: Partial<Record<ItemId, number>>;
  /** Expedition portals: Aether cost and signal lifetime */
  expedition?: { aether: number; signalHours: number };
  firstRestore: Reward;
  replay: Reward;
  storyChapter?: string;
}

export interface StoryChapter {
  id: string;
  title: string;
  realm: string;
  /** text shown when the island's portal opens */
  beats: string[];
}

// ------------------------------------------------------------- collection ---
export interface Lumin {
  id: string;
  name: string;
  species: string;
  realm: string;
  rarity: Rarity;
  animationSet: "hover" | "hop" | "swim" | "glide" | "burrow";
  sanctuaryBehaviour: string;
  discovery: string;
  /** passive effect while housed in the Lumin Grove */
  bonus: { kind: "dustPct" | "xpPct" | "startResonance" | "relicRegenPct"; value: number };
  skins?: string[];
  evolvesTo?: { lumin: string; bond: number };
}

export type RelicEffect = "hint" | "addMoves" | "shatterTile" | "reshuffle" | "openHiddenGate" | "revealSecrets";

export interface Relic {
  id: string;
  name: string;
  rarity: Rarity;
  set: string;
  effect: RelicEffect;
  effectValue: number;
  maxCharges: number;
  /** minutes to regenerate one charge naturally */
  regenMinutes: number;
  /** allowed in ranked Realm Trials? */
  trialApproved: boolean;
  lore: string;
}

export interface MemoryCrystal {
  id: string;
  title: string;
  chapter: "realms" | "heart" | "keepers" | "architect" | "shattering" | "imprisoned";
  text: string;
  seasonal?: string;
}

export interface HeartShard {
  id: string;
  name: string;
  realm: string;
  /** position in the Prism Heart reconstruction (0..n) */
  facet: number;
}

// -------------------------------------------------------------- sanctuary ---
export interface SanctuaryItem {
  id: string;
  name: string;
  kind: "structure" | "decoration" | "display" | "portal" | "trophy";
  minKeeperLevel: number;
  maxLevel: number;
  /** cost to reach level n (1-based) */
  cost: { base: Partial<Record<CurrencyId | ItemId, number>>; growth: number };
  effect?: { kind: "dustPct" | "xpPct" | "luminSlots" | "relicRegenPct" | "idleResonancePerHour"; perLevel: number };
  rating: number; // contributes to Sanctuary rating per level
}

// ------------------------------------------------------------------ quests ---
export type QuestCategory = "story" | "realm" | "keeper";
export type QuestCadence = "once" | "daily" | "weekly" | "season";

/** Every countable thing a quest / achievement / leaderboard can track. */
export type Metric =
  | "resonance" | "matches" | "cascades" | "bestCascade" | "specialsCreated" | "specialsActivated" | "combos"
  | "crystalsCleared" | "blueCleared" | "islandsRestored" | "islandsPlayed" | "perfectRestores" | "portalsOpened"
  | "luminsRescued" | "relicsFound" | "relicsUsed" | "memoriesFound" | "heartShards" | "noBoosterRestores"
  | "sanctuaryUpgrades" | "dutiesCompleted" | "trialRounds" | "trialsWon" | "checkins" | "rareFinds" | "stars"
  | "bestScore" | "seasonLevels";

export interface Quest {
  id: string;
  category: QuestCategory;
  cadence: QuestCadence;
  title: string;
  metric: Metric;
  target: number;
  prerequisites?: string[];
  minKeeperLevel?: number;
  realm?: string;
  season?: string;
  reward: Reward;
}

export interface QuestProgress {
  id: string;
  progress: number;
  completed: boolean;
  claimed: boolean;
}

// ------------------------------------------------------------ achievements ---
export type AchievementCategory = "explorer" | "restorer" | "collector" | "master" | "keeper" | "champion" | "loyalty" | "secrets";

export interface Achievement {
  id: string;
  category: AchievementCategory;
  name: string;
  description: string;
  metric: Metric;
  tiers: { target: number; reward: Reward; points: number }[];
  hidden?: boolean;
}

// --------------------------------------------------------------- check-in ---
export interface CheckInCalendar {
  id: string;
  cycle: { day: number; label: string; reward: Reward }[];
  milestones: { streak: number; reward: Reward }[];
  /** days that may be missed before a streak breaks (a Streak Restore covers one more) */
  graceDays: number;
}

// ------------------------------------------------------------- live game ---
export interface PassTier {
  tier: number;
  passXp: number; // cumulative
  free: Reward;
  premium: Reward;
}

export interface Season {
  id: string;
  number: number;
  name: string;
  theme: string;
  startsAt: number;
  endsAt: number;
  realm?: string;
  passTiers: PassTier[];
  quests: string[];
  memories: string[];
  exclusiveLumins: string[];
  trialSeries: string[];
}

export interface GameEvent {
  id: string;
  title: string;
  theme: string;
  startsAt: number;
  endsAt: number;
  eligibleIslands: string[] | "all";
  modifiers: { resonanceMultiplier?: number; dustMultiplier?: number; memoryDropBoost?: number };
  quests: string[];
  rewards: Reward;
  leaderboard?: string;
  trial?: string;
}

// ------------------------------------------------------------ competition ---
export type LeagueId = "stone" | "bronze" | "silver" | "gold" | "prism" | "celestial";

export type LeaderboardId = "globalKeeper" | "weeklyResonance" | "portalMaster" | "restoration" | "combo" | "trials" | "friends" | "regional";

export interface LeaderboardDef {
  id: LeaderboardId;
  name: string;
  metric: string;
  resets: "never" | "weekly" | "season";
  scope: "global" | "friends" | "country";
}

export type TrialKind = "highScore" | "resonanceRush" | "limitedMoves" | "cascade" | "portal";

export interface TrialDef {
  id: string;
  name: string;
  kind: TrialKind;
  schedule: "daily" | "weekend" | "weekly" | "championship";
  /** fixed engine config: identical for every entrant */
  levelIndex: number;
  moves: number;
  timeLimitSec?: number;
  attempts: number;
  approvedRelics: string[];
  minKeeperLevel: number;
  rewards: { top: number; reward: Reward }[]; // "top" = rank threshold (1, 3, 10, 100) or percentile when < 1
  participation: Reward;
}

export interface TrialInstance {
  trialId: string;
  instanceId: string;
  seed: number;
  opensAt: number;
  closesAt: number;
}

// --------------------------------------------------------------- commerce ---
export interface StoreOffer {
  id: string;
  section: "pass" | "aether" | "sanctuary" | "lumins" | "portalEffects" | "relics" | "expeditions";
  name: string;
  description: string;
  price: { kind: "iap"; sku: string; displayUsd: number } | { kind: "aether"; amount: number } | { kind: "prismDust"; amount: number };
  grants: Reward & { unlockPass?: string };
  limit?: number; // per account
  minKeeperLevel?: number;
}

// ------------------------------------------------------------ player state ---
export interface PlayerProfile {
  keeperId: string;
  keeperName: string;
  avatar: string;
  frame: string;
  title: string;
  country?: string; // from account settings only – never GPS
  createdAt: number;
}

export interface RelicState {
  charges: number;
  /** timestamp the next charge started regenerating */
  regenFrom: number;
}

export interface PlayerState {
  schema: 1;
  profile: PlayerProfile;
  keeperXp: number;
  wallet: Record<CurrencyId, number>;
  items: Record<ItemId, number>;
  lumins: Record<string, { bond: number; skin?: string; rescuedAt: number }>;
  relics: Record<string, RelicState>;
  memories: string[];
  heartShards: string[];
  cosmetics: string[];
  trophies: string[];
  islands: Record<string, { stars: number; bestScore: number; restoredAt: number }>;
  unlockedIslands: string[];
  expeditions: Record<string, { unlockedAt: number }>;
  currentRealm: string;
  sanctuary: { items: Record<string, number>; housed: string[]; lastCollectedAt: number };
  checkin: { streak: number; best: number; lastDay: string | null; milestonesClaimed: number[] };
  quests: Record<string, QuestProgress>;
  questCycles: { day: string; week: string; daily: string[]; weekly: string[] };
  achievements: Record<string, number>; // tiers claimed
  seasons: Record<string, { passXp: number; premium: boolean; claimedFree: number[]; claimedPremium: number[] }>;
  stats: Record<Metric, number> & { weeklyResonance: number; weeklyResonanceWeek: string; trialPoints: number };
  league: { id: LeagueId; points: number };
  friends: string[];
  purchases: { receipt: string; offer: string; at: number }[];
  notifications: Record<NotificationClass, boolean>;
  seenFeatures: string[];
  /** islands whose buried secret this Keeper has uncovered (absent on older saves) */
  secrets?: string[];
}

export type NotificationClass = "sanctuaryResonance" | "realmGate" | "trialOpen" | "expeditionReturn" | "keepersReturn" | "eventStart";

// ------------------------------------------------------------- run reports ---
/** A finished island run as reported by the game controller. Contains everything needed to replay it. */
export interface RunReport {
  runId: string;
  islandId: string;
  levelIndex: number;
  seed: number;
  gameVersion: string;
  startedAt: number;
  endedAt: number;
  swaps: [number, number, number, number][];
  relicsUsed: string[];
  /** in-run effects in order, applied before swap #atSwap on replay (Stabilize Portal, relics) */
  boosts?: RunBoost[];
  claimed: {
    won: boolean;
    stars: number;
    score: number;
    resonance: number;
    matches: number;
    cascades: number;
    bestCascade: number;
    specialsCreated: number;
    specialsActivated: number;
    combos: number;
    crystalsCleared: number;
    blueCleared: number;
    /** the island's secret was found (optional: older clients never claim it) */
    secretFound?: boolean;
  };
  trialInstanceId?: string;
  buildFlags?: { debug: boolean; emulator: boolean };
}

/** Everything that can happen in the meta layer; drives quests, achievements, stats and analytics. */
export type MetaEvent =
  | { type: "runCompleted"; report: RunReport }
  | { type: "luminRescued"; lumin: string }
  | { type: "relicFound"; relic: string }
  | { type: "relicUsed"; relic: string }
  | { type: "memoryFound"; memory: string }
  | { type: "heartShard"; shard: string }
  | { type: "portalOpened"; island: string; portal: PortalClass }
  | { type: "sanctuaryUpgrade"; item: string; level: number }
  | { type: "dutyCompleted"; quest: string }
  | { type: "checkin"; streak: number }
  | { type: "trialRound"; trial: string; rank: number; of: number }
  | { type: "seasonLevel"; season: string; level: number };

export interface RunBoost {
  atSwap: number;
  kind: "moves" | "reshuffle" | "hint" | "gravity";
  /** gravity: turn direction (-1 counter-clockwise, +1 clockwise) */
  value: number;
  source: "stabilize" | "relic" | "gravity";
  relic?: string;
}
