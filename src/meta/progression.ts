// Event-driven progression: stats → quests / duties / realm missions / achievements.
// Island runs, portals, Keeper's Return, Sanctuary, relic charges, Archive.
import { LUMINS, RELICS } from "./config/collection.ts";
import { ECONOMY, SEASON_QUESTS } from "./config/live.ts";
import {
  ACHIEVEMENTS, DUTIES, DUTIES_PER_DAY, DUTY_CACHE_THRESHOLD, KEEPERS_CACHE, KEEPERS_RETURN, QUESTS,
  REALM_MISSIONS, REALM_MISSIONS_PER_WEEK, SANCTUARY,
} from "./config/progression.ts";
import { HEART_FACETS, HEART_SHARDS, ISLANDS, MEMORIES, REALMS } from "./config/world.ts";
import { bonuses, clone, dayIndex, dayKey, fail, grant, hash, levelOf, ok, spend, weekKey, type GrantLog, type Result } from "./core.ts";
import type { Island, MetaEvent, Metric, PlayerState, Quest, Reward, RunReport } from "./types.ts";

export const ALL_QUESTS: Quest[] = [...QUESTS, ...DUTIES, ...REALM_MISSIONS, ...(SEASON_QUESTS as Quest[])];
export const questDef = (id: string) => ALL_QUESTS.find((q) => q.id === id);

// ---- quest cycles --------------------------------------------------------------------------------------
function pick(pool: Quest[], n: number, seed: string, level: number) {
  return pool
    .filter((q) => (q.minKeeperLevel ?? 1) <= level)
    .map((q) => ({ q, k: hash(seed + q.id) }))
    .sort((a, b) => a.k - b.k)
    .slice(0, n)
    .map(({ q }) => q.id);
}

/** Rolls today's Keeper Duties and this week's Realm Missions (deterministic per Keeper + date). */
export function refreshCycles(state: PlayerState, now: number): PlayerState {
  const day = dayKey(now), week = weekKey(now);
  if (state.questCycles.day === day && state.questCycles.week === week && state.stats.weeklyResonanceWeek === week) return state;
  const s = clone(state);
  const lvl = levelOf(s);
  if (s.questCycles.day !== day) {
    for (const id of s.questCycles.daily) delete s.quests[id];
    s.questCycles.day = day;
    s.questCycles.daily = pick(DUTIES, DUTIES_PER_DAY, s.profile.keeperId + day, lvl);
    for (const id of s.questCycles.daily) s.quests[id] = { id, progress: 0, completed: false, claimed: false };
    delete s.quests["duty-cache"];
  }
  if (s.questCycles.week !== week) {
    for (const id of s.questCycles.weekly) delete s.quests[id];
    s.questCycles.week = week;
    s.questCycles.weekly = pick(REALM_MISSIONS, REALM_MISSIONS_PER_WEEK, s.profile.keeperId + week, lvl);
    for (const id of s.questCycles.weekly) s.quests[id] = { id, progress: 0, completed: false, claimed: false };
  }
  if (s.stats.weeklyResonanceWeek !== week) {
    s.stats.weeklyResonanceWeek = week;
    s.stats.weeklyResonance = 0;
  }
  return s;
}

/** Story, realm and season quests available now (prerequisites met). */
export function availableQuests(s: PlayerState, now: number) {
  const lvl = levelOf(s);
  return ALL_QUESTS.filter((q) => {
    if (q.cadence === "daily") return s.questCycles.daily.includes(q.id);
    if (q.cadence === "weekly") return s.questCycles.weekly.includes(q.id);
    if ((q.minKeeperLevel ?? 1) > lvl) return false;
    if (q.cadence === "season" && q.season && !activeSeasonMatches(q.season, now)) return false;
    return (q.prerequisites ?? []).every((p) => s.quests[p]?.claimed);
  });
}
let seasonMatcher: (season: string, now: number) => boolean = () => false;
const activeSeasonMatches = (season: string, now: number) => seasonMatcher(season, now);
export function setSeasonMatcher(fn: (season: string, now: number) => boolean) {
  seasonMatcher = fn;
}

/** Applies stat deltas to cycle quests; cumulative quests read totals directly. */
function syncQuests(s: PlayerState, deltas: Partial<Record<Metric, number>>, now: number) {
  for (const q of availableQuests(s, now)) {
    const p = (s.quests[q.id] ??= { id: q.id, progress: 0, completed: false, claimed: false });
    if (p.completed) continue;
    if (q.cadence === "daily" || q.cadence === "weekly") p.progress = Math.min(q.target, p.progress + (deltas[q.metric] ?? 0));
    else p.progress = Math.min(q.target, s.stats[q.metric] ?? 0);
    if (p.progress >= q.target) p.completed = true;
  }
}

// ---- events ---------------------------------------------------------------------------------------------
/** The single entry point for progress. Returns the new state; callers forward the event to analytics. */
export function recordEvent(state: PlayerState, e: MetaEvent, now: number): PlayerState {
  const s = refreshCycles(clone(state), now);
  const before = { ...s.stats };
  const st = s.stats;
  switch (e.type) {
    case "runCompleted": {
      const c = e.report.claimed;
      st.islandsPlayed++;
      st.resonance += c.resonance;
      st.weeklyResonance += c.resonance;
      st.matches += c.matches;
      st.cascades += c.cascades;
      st.bestCascade = Math.max(st.bestCascade, c.bestCascade);
      st.specialsCreated += c.specialsCreated;
      st.specialsActivated += c.specialsActivated;
      st.combos += c.combos;
      st.crystalsCleared += c.crystalsCleared;
      st.blueCleared += c.blueCleared;
      st.bestScore = Math.max(st.bestScore, c.score);
      if (c.won) {
        st.islandsRestored++;
        if (c.stars === 3) st.perfectRestores++;
        if (e.report.relicsUsed.length === 0) st.noBoosterRestores++;
      }
      break;
    }
    case "portalOpened": st.portalsOpened++; break;
    case "relicUsed": st.relicsUsed++; break;
    case "sanctuaryUpgrade": st.sanctuaryUpgrades++; break;
    case "dutyCompleted": st.dutiesCompleted++; break;
    case "checkin": st.checkins++; break;
    case "trialRound": {
      st.trialRounds++;
      if (e.rank === 1) st.trialsWon++;
      break;
    }
    case "seasonLevel": st.seasonLevels = Math.max(st.seasonLevels, e.level); break;
    default: break; // collectible counters are maintained by grant()
  }
  st.stars = Object.values(s.islands).reduce((a, i) => a + i.stars, 0);
  const deltas: Partial<Record<Metric, number>> = {};
  for (const k of Object.keys(before) as Metric[]) if (typeof st[k] === "number" && st[k] !== before[k]) deltas[k] = st[k] - before[k];
  syncQuests(s, deltas, now);
  return s;
}

export function claimQuest(state: PlayerState, id: string, now: number): Result & { log?: GrantLog } {
  const s0 = refreshCycles(state, now);
  const q = questDef(id);
  const p = s0.quests[id];
  if (!q || !p) return fail("Unknown quest");
  if (!p.completed) return fail("Not complete yet");
  if (p.claimed) return fail("Already claimed");
  const { state: s, log } = grant(s0, q.reward, now);
  s.quests[id].claimed = true;
  let next = q.cadence === "daily" ? recordEvent(s, { type: "dutyCompleted", quest: id }, now) : s;
  return { ok: true, state: next, log };
}

/** Keeper's Cache for finishing enough of today's duties. */
export function dutyCacheStatus(s: PlayerState) {
  const done = s.questCycles.daily.filter((id) => s.quests[id]?.claimed).length;
  return { done, needed: DUTY_CACHE_THRESHOLD, claimable: done >= DUTY_CACHE_THRESHOLD && !s.quests["duty-cache"]?.claimed, claimed: !!s.quests["duty-cache"]?.claimed };
}
export function claimDutyCache(state: PlayerState, now: number): Result {
  const st = dutyCacheStatus(state);
  if (!st.claimable) return fail(st.claimed ? "Already claimed" : `Complete ${st.needed} duties first`);
  const { state: s } = grant(state, { items: { keepersCache: 1 } }, now);
  s.quests["duty-cache"] = { id: "duty-cache", progress: 1, completed: true, claimed: true };
  return ok(s);
}
/** A Keeper's Cache always contains the same displayed bundle – never a random draw. */
export function openKeepersCache(state: PlayerState, now: number): Result {
  const r = spend(state, { keepersCache: 1 });
  if (!r.ok) return r;
  return ok(grant(r.state, KEEPERS_CACHE, now).state);
}

// ---- islands, portals and runs --------------------------------------------------------------------------------
export const islandDef = (id: string) => ISLANDS.find((i) => i.id === id);

export type IslandStatus = "locked" | "available" | "needsUnlock" | "restored";
export function islandStatus(s: PlayerState, island: Island, now: number): { status: IslandStatus; reason?: string } {
  if (s.islands[island.id]) return { status: "restored" };
  const realm = REALMS.find((r) => r.id === island.realm)!;
  if (levelOf(s) < realm.minKeeperLevel) return { status: "locked", reason: `Keeper level ${realm.minKeeperLevel}` };
  if (s.heartShards.length < realm.requiresShards) return { status: "locked", reason: `${realm.requiresShards} Heart Shard${realm.requiresShards > 1 ? "s" : ""}` };
  if (island.after && !s.islands[island.after]) return { status: "locked", reason: `Restore ${islandDef(island.after)?.name}` };
  if (island.portal === "story" || s.unlockedIslands.includes(island.id)) return { status: "available" };
  if (island.portal === "expedition") {
    const exp = s.expeditions[island.id];
    if (exp && now - exp.unlockedAt < (island.expedition?.signalHours ?? 0) * 3600000) return { status: "available" };
  }
  return { status: "needsUnlock" };
}

/** Discovery portals open with gameplay items (fragments / keys). Expeditions are opened via the Realm Exchange. */
export function unlockDiscovery(state: PlayerState, islandId: string, now: number): Result {
  const island = islandDef(islandId);
  if (!island || island.portal !== "discovery") return fail("Not a Discovery Portal");
  if (islandStatus(state, island, now).status !== "needsUnlock") return fail("Portal is not ready");
  const r = spend(state, island.unlockCost ?? {});
  if (!r.ok) return r;
  r.state.unlockedIslands.push(islandId);
  return r;
}

export interface RunOutcome {
  state: PlayerState;
  reward: Reward;
  firstRestore: boolean;
  log: GrantLog | null;
  storyChapter: string | null;
}

/** Applies a (verified) run. Stats/quests always update; rewards only on a win. */
export function applyRun(state: PlayerState, report: RunReport, now: number): RunOutcome {
  let s = recordEvent(state, { type: "runCompleted", report }, now);
  const island = islandDef(report.islandId);
  const c = report.claimed;
  if (!c.won || !island) return { state: s, reward: {}, firstRestore: false, log: null, storyChapter: null };
  const firstRestore = !s.islands[island.id];
  const prev = s.islands[island.id];
  s.islands[island.id] = { stars: Math.max(prev?.stars ?? 0, c.stars), bestScore: Math.max(prev?.bestScore ?? 0, c.score), restoredAt: prev?.restoredAt ?? now };
  const base = firstRestore ? island.firstRestore : island.replay;
  const b = bonuses(s);
  const reward: Reward = {
    ...base,
    prismDust: Math.round((base.prismDust ?? 0) * ECONOMY.starMultiplier[c.stars] * (1 + b.dustPct / 100)),
    keeperXp: Math.round((base.keeperXp ?? 0) * (1 + b.xpPct / 100)),
  };
  const g = grant(s, reward, now);
  s = recordEvent(g.state, { type: "portalOpened", island: island.id, portal: island.portal }, now);
  // unlock follow-on story islands happens implicitly via islandStatus(); record realm progress
  s.currentRealm = island.realm;
  return { state: s, reward, firstRestore, log: g.log, storyChapter: firstRestore ? (island.storyChapter ?? null) : null };
}

// ---- Keeper's Return ------------------------------------------------------------------------------------------------
export function keepersReturnStatus(s: PlayerState, now: number) {
  const today = dayKey(now);
  if (s.checkin.lastDay === today) return { claimedToday: true, streak: s.checkin.streak, gap: 0, restorable: false, slot: slotFor(s.checkin.streak) };
  const gap = s.checkin.lastDay ? dayIndex(today) - dayIndex(s.checkin.lastDay) - 1 : 0; // missed days
  const within = gap <= KEEPERS_RETURN.graceDays;
  const restorable = !within && gap === KEEPERS_RETURN.graceDays + 1 && s.items.streakRestore > 0;
  const streak = within ? s.checkin.streak + 1 : 1;
  return { claimedToday: false, streak, gap, restorable, slot: slotFor(streak) };
}
const slotFor = (streak: number) => KEEPERS_RETURN.cycle[(Math.max(1, streak) - 1) % KEEPERS_RETURN.cycle.length];

/** Collect today's Keeper's Return. `useRestore` spends a Streak Restore to bridge one extra missed day. */
export function claimKeepersReturn(state: PlayerState, now: number, useRestore = false): Result & { milestone?: number } {
  const st = keepersReturnStatus(state, now);
  if (st.claimedToday) return fail("Already collected today");
  let s = state;
  let streak = st.streak;
  if (useRestore && st.restorable) {
    const r = spend(s, { streakRestore: 1 });
    if (!r.ok) return r;
    s = r.state;
    streak = s.checkin.streak + 1;
  }
  const slot = slotFor(streak);
  s = grant(s, slot.reward, now).state;
  s.checkin = { ...s.checkin, streak, best: Math.max(s.checkin.best, streak), lastDay: dayKey(now) };
  let milestone: number | undefined;
  for (const m of KEEPERS_RETURN.milestones) {
    if (streak >= m.streak && !s.checkin.milestonesClaimed.includes(m.streak)) {
      s = grant(s, m.reward, now).state;
      s.checkin.milestonesClaimed.push(m.streak);
      milestone = m.streak;
    }
  }
  s = recordEvent(s, { type: "checkin", streak }, now);
  return { ok: true, state: s, milestone };
}

// ---- achievements ---------------------------------------------------------------------------------------------------------
export function achievementStatus(s: PlayerState) {
  return ACHIEVEMENTS.map((a) => {
    const value = s.stats[a.metric] ?? 0;
    const claimed = s.achievements[a.id] ?? 0;
    const reached = a.tiers.filter((t) => value >= t.target).length;
    const concealed = !!a.hidden && reached === 0;
    return { def: a, value, claimed, reached, concealed, claimable: reached > claimed, next: a.tiers[claimed]?.target ?? null };
  });
}
export function achievementScore(s: PlayerState) {
  return ACHIEVEMENTS.reduce((sum, a) => sum + a.tiers.slice(0, s.achievements[a.id] ?? 0).reduce((x, t) => x + t.points, 0), 0);
}
export function claimAchievement(state: PlayerState, id: string, now: number): Result {
  const st = achievementStatus(state).find((a) => a.def.id === id);
  if (!st || !st.claimable) return fail("Nothing to claim");
  const tier = st.def.tiers[st.claimed];
  const s = grant(state, tier.reward, now).state;
  s.achievements[id] = st.claimed + 1;
  return ok(s);
}

// ---- Sanctuary ------------------------------------------------------------------------------------------------------------
export function sanctuaryCost(itemId: string, targetLevel: number) {
  const def = SANCTUARY.find((x) => x.id === itemId)!;
  const mul = Math.pow(def.cost.growth, targetLevel - 1);
  return Object.fromEntries(Object.entries(def.cost.base).map(([k, v]) => [k, Math.round((v ?? 0) * mul)]));
}
export function upgradeSanctuary(state: PlayerState, itemId: string, now: number): Result {
  const def = SANCTUARY.find((x) => x.id === itemId);
  if (!def) return fail("Unknown Sanctuary item");
  const lvl = state.sanctuary.items[itemId] ?? 0;
  if (lvl >= def.maxLevel) return fail("Fully restored");
  if (levelOf(state) < def.minKeeperLevel) return fail(`Requires Keeper level ${def.minKeeperLevel}`);
  const r = spend(state, sanctuaryCost(itemId, lvl + 1));
  if (!r.ok) return r;
  r.state.sanctuary.items[itemId] = lvl + 1;
  const s = grant(r.state, { keeperXp: 30 * (lvl + 1) }, now).state;
  return ok(recordEvent(s, { type: "sanctuaryUpgrade", item: itemId, level: lvl + 1 }, now));
}
export function sanctuaryRating(s: PlayerState) {
  const max = SANCTUARY.reduce((a, d) => a + d.rating * d.maxLevel, 0);
  const have = SANCTUARY.reduce((a, d) => a + d.rating * (s.sanctuary.items[d.id] ?? 0), 0);
  return { rating: have, max, pct: Math.round((have / max) * 100) };
}
/** Resonance the Sanctuary gathered while the Keeper was away (capped), paid out as Prism Dust. */
export function pendingSanctuaryResonance(s: PlayerState, now: number) {
  const perHour = bonuses(s).idleResonancePerHour;
  const hours = Math.min(ECONOMY.sanctuaryIdleCapHours, Math.max(0, (now - s.sanctuary.lastCollectedAt) / 3600000));
  return Math.floor(perHour * hours);
}
export function collectSanctuary(state: PlayerState, now: number): Result {
  const amount = pendingSanctuaryResonance(state, now);
  if (amount <= 0) return fail("Nothing gathered yet");
  const s = grant(state, { prismDust: amount }, now).state;
  s.sanctuary.lastCollectedAt = now;
  return ok(s);
}
export function houseLumin(state: PlayerState, luminId: string): Result {
  if (!state.lumins[luminId]) return fail("Not rescued yet");
  const s = clone(state);
  if (s.sanctuary.housed.includes(luminId)) {
    s.sanctuary.housed = s.sanctuary.housed.filter((x) => x !== luminId);
    return ok(s);
  }
  if (s.sanctuary.housed.length >= bonuses(s).luminSlots) return fail("The Lumin Grove is full");
  s.sanctuary.housed.push(luminId);
  return ok(s);
}
export function feedLumin(state: PlayerState, luminId: string, now: number): Result & { evolved?: string } {
  if (!state.lumins[luminId]) return fail("Not rescued yet");
  const r = spend(state, { luminFood: 1 });
  if (!r.ok) return r;
  const s = r.state;
  s.lumins[luminId].bond++;
  const def = LUMINS.find((l) => l.id === luminId);
  if (def?.evolvesTo && s.lumins[luminId].bond >= def.evolvesTo.bond && !s.lumins[def.evolvesTo.lumin]) {
    const g = grant(s, { lumins: [def.evolvesTo.lumin] }, now);
    return { ok: true, state: g.state, evolved: def.evolvesTo.lumin };
  }
  return ok(s);
}

// ---- relics ----------------------------------------------------------------------------------------------------------------
export function relicCharges(s: PlayerState, relicId: string, now: number) {
  const def = RELICS.find((r) => r.id === relicId);
  const st = s.relics[relicId];
  if (!def || !st) return { charges: 0, max: 0, nextInMs: null as number | null };
  const regen = def.regenMinutes * 60000 / (1 + bonuses(s).relicRegenPct / 100);
  const gained = Math.floor((now - st.regenFrom) / regen);
  const charges = Math.min(def.maxCharges, st.charges + gained);
  const nextInMs = charges >= def.maxCharges ? null : regen - ((now - st.regenFrom) % regen);
  return { charges, max: def.maxCharges, nextInMs };
}
export function activateRelic(state: PlayerState, relicId: string, now: number, ranked = false): Result {
  const def = RELICS.find((r) => r.id === relicId);
  if (!def || !state.relics[relicId]) return fail("Relic not found");
  if (ranked && !def.trialApproved) return fail("Not approved for ranked Trials");
  const { charges } = relicCharges(state, relicId, now);
  let s = clone(state);
  if (charges > 0) {
    s.relics[relicId] = { charges: charges - 1, regenFrom: charges >= def.maxCharges ? now : s.relics[relicId].regenFrom };
  } else {
    const r = spend(s, { relicCharge: 1 });
    if (!r.ok) return fail("No charges left");
    s = r.state;
  }
  return ok(recordEvent(s, { type: "relicUsed", relic: relicId }, now));
}

// ---- Keeper Archive -------------------------------------------------------------------------------------------------------------
export function archive(s: PlayerState) {
  const section = <T extends { id: string }>(all: T[], has: (id: string) => boolean) => ({
    entries: all.map((x) => ({ def: x, found: has(x.id) })),
    found: all.filter((x) => has(x.id)).length,
    total: all.length,
  });
  const lumins = section(LUMINS, (id) => !!s.lumins[id]);
  const relics = section(RELICS, (id) => !!s.relics[id]);
  const memories = section(MEMORIES, (id) => s.memories.includes(id));
  const shards = section(HEART_SHARDS, (id) => s.heartShards.includes(id));
  const realms = section(REALMS, (id) => ISLANDS.some((i) => i.realm === id && s.islands[i.id]));
  const total = lumins.total + relics.total + memories.total + shards.total + realms.total;
  const found = lumins.found + relics.found + memories.found + shards.found + realms.found;
  return { lumins, relics, memories, shards, realms, heart: { facets: s.heartShards.length, of: HEART_FACETS }, pct: Math.round((found / total) * 100) };
}
