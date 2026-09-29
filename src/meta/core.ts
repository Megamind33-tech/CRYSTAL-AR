// Core meta rules: player creation, Keeper level, wallet, grants, unlocks. Pure functions only.
import { LUMINS, RARITY_ORDER, RELICS, RELIC_SETS } from "./config/collection.ts";
import { ECONOMY, NOTIFICATIONS } from "./config/live.ts";
import { FEATURE_UNLOCKS, MAX_KEEPER_LEVEL, SANCTUARY, xpToNext } from "./config/progression.ts";
import { ISLANDS } from "./config/world.ts";
import { BOOSTS, invalidLoadout, type BoostId } from "../game/boosts.ts";
import type { CurrencyId, ItemId, Metric, NotificationClass, PlayerState, Reward } from "./types.ts";

export type Result<T = PlayerState> = { ok: true; state: T } | { ok: false; error: string };
export const ok = (state: PlayerState): Result => ({ ok: true, state });
export const fail = (error: string): Result => ({ ok: false, error });
export const clone = <T>(v: T): T => structuredClone(v);

const METRICS: Metric[] = [
  "resonance", "matches", "cascades", "bestCascade", "specialsCreated", "specialsActivated", "combos", "crystalsCleared",
  "blueCleared", "islandsRestored", "islandsPlayed", "perfectRestores", "portalsOpened", "luminsRescued", "relicsFound",
  "relicsUsed", "memoriesFound", "heartShards", "noBoosterRestores", "sanctuaryUpgrades", "dutiesCompleted", "trialRounds",
  "trialsWon", "checkins", "rareFinds", "stars", "bestScore", "seasonLevels",
];
const ITEMS: ItemId[] = [
  "relicCharge", "portalFragment", "luminFood", "sanctuaryStone", "streakRestore", "keepersCache", "starKey",
  "moves_plus_5", "moves_plus_10", "gem_multiplier", "surge_rate_up", "starting_clears",
];

export function newPlayer(keeperId: string, now: number, keeperName = "Keeper"): PlayerState {
  return {
    schema: 1,
    profile: { keeperId, keeperName, avatar: "avatar-mossling", frame: "frame-novice", title: "Novice Keeper", createdAt: now },
    keeperXp: 0,
    wallet: { ...ECONOMY.startingWallet },
    items: Object.fromEntries(ITEMS.map((i) => [i, 0])) as Record<ItemId, number>,
    lumins: {},
    relics: {},
    memories: [],
    heartShards: [],
    cosmetics: [],
    trophies: [],
    islands: {},
    unlockedIslands: ISLANDS.filter((i) => i.portal === "story" && !i.after).map((i) => i.id),
    expeditions: {},
    currentRealm: "verdant",
    sanctuary: { items: Object.fromEntries(SANCTUARY.map((s) => [s.id, 0])), housed: [], lastCollectedAt: now },
    checkin: { streak: 0, best: 0, lastDay: null, milestonesClaimed: [] },
    quests: {},
    questCycles: { day: "", week: "", daily: [], weekly: [] },
    achievements: {},
    seasons: {},
    stats: { ...(Object.fromEntries(METRICS.map((m) => [m, 0])) as Record<Metric, number>), weeklyResonance: 0, weeklyResonanceWeek: "", trialPoints: 0 },
    league: { id: "stone", points: 0 },
    friends: [],
    purchases: [],
    notifications: Object.fromEntries(Object.entries(NOTIFICATIONS).map(([k, v]) => [k, v.defaultOn])) as Record<NotificationClass, boolean>,
    seenFeatures: [],
  };
}

// ---- time --------------------------------------------------------------------------------------------
export const dayKey = (now: number) => new Date(now).toISOString().slice(0, 10);
export const dayIndex = (key: string) => Math.round(Date.parse(key + "T00:00:00Z") / 86400000);
export function weekKey(now: number) {
  const d = new Date(now);
  const monday = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
  return "W" + new Date(monday).toISOString().slice(0, 10);
}
export function hash(str: string) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) h = Math.imul(h ^ str.charCodeAt(i), 16777619);
  return h >>> 0;
}

// ---- Keeper level ----------------------------------------------------------------------------------------
export function keeperLevel(xp: number) {
  let level = 1, rest = xp;
  while (level < MAX_KEEPER_LEVEL && rest >= xpToNext(level)) {
    rest -= xpToNext(level);
    level++;
  }
  return { level, into: rest, need: xpToNext(level), progress: rest / xpToNext(level) };
}
export const levelOf = (s: PlayerState) => keeperLevel(s.keeperXp).level;

export function isUnlocked(s: PlayerState, feature: string) {
  const f = FEATURE_UNLOCKS.find((x) => x.feature === feature);
  return !!f && levelOf(s) >= f.level;
}
/** Features that unlocked but the player hasn't been introduced to yet (drives one-at-a-time reveals). */
export function pendingReveals(s: PlayerState) {
  return FEATURE_UNLOCKS.filter((f) => levelOf(s) >= f.level && !s.seenFeatures.includes(f.feature));
}
export function markSeen(state: PlayerState, feature: string): PlayerState {
  if (state.seenFeatures.includes(feature)) return state;
  const s = clone(state);
  s.seenFeatures.push(feature);
  return s;
}

// ---- Sanctuary / Lumin bonuses ----------------------------------------------------------------------------
export function bonuses(s: PlayerState) {
  const out = { dustPct: 0, xpPct: 0, startResonance: 0, relicRegenPct: 0, luminSlots: 1, idleResonancePerHour: 0 };
  for (const item of SANCTUARY) {
    const lvl = s.sanctuary.items[item.id] ?? 0;
    if (item.effect && lvl > 0) out[item.effect.kind] += item.effect.perLevel * lvl;
  }
  for (const id of s.sanctuary.housed) {
    const l = LUMINS.find((x) => x.id === id);
    if (l) out[l.bonus.kind] += l.bonus.value;
  }
  return out;
}

// ---- grants ----------------------------------------------------------------------------------------------------
export interface GrantLog {
  newLumins: string[];
  newRelics: string[];
  newMemories: string[];
  newShards: string[];
  duplicates: number;
  levelUps: number[];
  setsCompleted: string[];
}

const rarityIndex = (r: string) => RARITY_ORDER.indexOf(r as (typeof RARITY_ORDER)[number]);

/** Adds a reward. Returns the new state plus what was genuinely new (for reveal animations & events). */
export function grant(state: PlayerState, r: Reward, now: number): { state: PlayerState; log: GrantLog } {
  const s = clone(state);
  const log: GrantLog = { newLumins: [], newRelics: [], newMemories: [], newShards: [], duplicates: 0, levelUps: [], setsCompleted: [] };
  const before = levelOf(s);
  s.wallet.prismDust += r.prismDust ?? 0;
  s.wallet.aether += r.aether ?? 0;
  s.keeperXp += r.keeperXp ?? 0;
  for (const [k, v] of Object.entries(r.items ?? {}) as [ItemId, number][]) s.items[k] += v;
  for (const id of r.lumins ?? []) {
    if (s.lumins[id]) {
      s.wallet.prismDust += ECONOMY.duplicateLumin;
      log.duplicates++;
    } else {
      s.lumins[id] = { bond: 0, rescuedAt: now };
      log.newLumins.push(id);
      s.stats.luminsRescued++;
      const def = LUMINS.find((l) => l.id === id);
      if (def && rarityIndex(def.rarity) >= 1) s.stats.rareFinds++;
    }
  }
  for (const id of r.relics ?? []) {
    const def = RELICS.find((x) => x.id === id);
    if (s.relics[id] || !def) {
      s.wallet.prismDust += ECONOMY.duplicateRelic;
      log.duplicates++;
    } else {
      s.relics[id] = { charges: def.maxCharges, regenFrom: now };
      log.newRelics.push(id);
      s.stats.relicsFound++;
      if (rarityIndex(def.rarity) >= 1) s.stats.rareFinds++;
    }
  }
  for (const id of r.memories ?? []) if (!s.memories.includes(id)) {
    s.memories.push(id);
    log.newMemories.push(id);
    s.stats.memoriesFound++;
  }
  for (const id of r.heartShards ?? []) if (!s.heartShards.includes(id)) {
    s.heartShards.push(id);
    log.newShards.push(id);
    s.stats.heartShards++;
  }
  for (const id of r.cosmetics ?? []) if (!s.cosmetics.includes(id)) s.cosmetics.push(id);
  for (const id of r.trophies ?? []) s.trophies.push(id);
  if (r.passXp) addPassXp(s, r.passXp, now);
  // relic sets complete once
  for (const [set, info] of Object.entries(RELIC_SETS)) {
    const key = "set:" + set;
    if (!s.achievements[key] && RELICS.filter((x) => x.set === set).every((x) => s.relics[x.id])) {
      s.achievements[key] = 1;
      s.wallet.aether += info.reward.aether;
      s.keeperXp += info.reward.keeperXp;
      s.profile.title = info.reward.title;
      log.setsCompleted.push(set);
    }
  }
  const after = levelOf(s);
  for (let l = before + 1; l <= after; l++) {
    log.levelUps.push(l);
    const gift = ECONOMY.levelUpGift(l);
    s.wallet.prismDust += gift.prismDust ?? 0;
    s.wallet.aether += gift.aether ?? 0;
  }
  return { state: s, log };
}

/** Pass XP goes to the active season (created lazily). Kept here so grant() stays self-contained. */
function addPassXp(s: PlayerState, xp: number, now: number) {
  const season = activeSeasonId(now);
  if (!season) return;
  s.seasons[season] ??= { passXp: 0, premium: false, claimedFree: [], claimedPremium: [] };
  s.seasons[season].passXp += xp;
}
let seasonResolver: (now: number) => string | null = () => null;
export const activeSeasonId = (now: number) => seasonResolver(now);
export function setSeasonResolver(fn: (now: number) => string | null) {
  seasonResolver = fn;
}

export function spend(state: PlayerState, cost: Partial<Record<CurrencyId | ItemId, number>>): Result {
  for (const [k, v] of Object.entries(cost)) {
    const have = k in state.wallet ? state.wallet[k as CurrencyId] : state.items[k as ItemId];
    if ((have ?? 0) < (v ?? 0)) return fail(`Not enough ${label(k)}`);
  }
  const s = clone(state);
  for (const [k, v] of Object.entries(cost)) {
    if (k in s.wallet) s.wallet[k as CurrencyId] -= v ?? 0;
    else s.items[k as ItemId] -= v ?? 0;
  }
  return ok(s);
}

export const LABELS: Record<string, string> = {
  coins: "Coins", prismDust: "Prism Dust", aether: "Aether Crystals", relicCharge: "Relic Charge", portalFragment: "Portal Fragment",
  luminFood: "Lumin Food", sanctuaryStone: "Sanctuary Stone", streakRestore: "Streak Restore", keepersCache: "Keeper's Cache", starKey: "Star Key",
};
export const label = (k: string) => LABELS[k] ?? k;

/** Human summary of a reward, e.g. "120 Prism Dust · Mossling". */
export function describeReward(r: Reward): string[] {
  const out: string[] = [];
  if (r.prismDust) out.push(`${r.prismDust} Prism Dust`);
  if (r.aether) out.push(`${r.aether} Aether`);
  if (r.keeperXp) out.push(`${r.keeperXp} Keeper XP`);
  if (r.passXp) out.push(`${r.passXp} Season XP`);
  for (const [k, v] of Object.entries(r.items ?? {})) out.push(`${v} ${label(k)}`);
  for (const id of r.lumins ?? []) out.push(LUMINS.find((l) => l.id === id)?.name ?? id);
  for (const id of r.relics ?? []) out.push(RELICS.find((l) => l.id === id)?.name ?? id);
  if (r.memories?.length) out.push(`${r.memories.length} Memory Crystal${r.memories.length > 1 ? "s" : ""}`);
  if (r.heartShards?.length) out.push("Heart Shard");
  if (r.cosmetics?.length) out.push(`${r.cosmetics.length} cosmetic${r.cosmetics.length > 1 ? "s" : ""}`);
  return out;
}

// ---- Armory boosts ------------------------------------------------------------------------------------------
/** Saves from before the Armory lack coins and boost counts: fill them in without touching anything else. */
export function normalizePlayer(state: PlayerState): PlayerState {
  const missingItems = ITEMS.some((i) => typeof state.items[i] !== "number");
  if (typeof state.wallet.coins === "number" && !missingItems) return state;
  const s = clone(state);
  s.wallet.coins ??= ECONOMY.startingWallet.coins;
  for (const i of ITEMS) s.items[i] ??= 0;
  return s;
}

/** Buys one boost with coins. */
export function buyBoost(state: PlayerState, id: BoostId): Result {
  const boost = BOOSTS[id];
  if (!boost) return fail("Unknown boost");
  const paid = spend(state, { coins: boost.cost });
  if (!paid.ok) return paid;
  const s = clone(paid.state);
  s.items[id] += 1;
  return ok(s);
}

/** Uses up one of each equipped boost when a run starts. */
export function consumeBoosts(state: PlayerState, ids: readonly BoostId[]): Result {
  const bad = invalidLoadout(ids);
  if (bad) return fail(bad);
  const paid = spend(state, Object.fromEntries(ids.map((id) => [id, 1])));
  return paid.ok ? paid : fail("You do not own that boost");
}

/** Coins earned by a finished, verified run. */
export function coinsForRun(won: boolean, stars: number): number {
  return won ? 40 + stars * 20 : 10;
}
