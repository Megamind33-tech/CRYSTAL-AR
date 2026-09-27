// Live game: seasons + Crystal Pass, events, Realm Exchange, purchases, rewarded ads, portal recovery,
// and the Keeper Briefing (one calm summary instead of launch pop-ups).
import { ECONOMY, EVENTS, SEASONS, STORE } from "./config/live.ts";
import { ISLANDS } from "./config/world.ts";
import { clone, dayKey, fail, grant, isUnlocked, levelOf, ok, setSeasonResolver, spend, type Result } from "./core.ts";
import {
  achievementStatus, availableQuests, dutyCacheStatus, islandStatus, keepersReturnStatus, pendingSanctuaryResonance,
  recordEvent, refreshCycles, setSeasonMatcher,
} from "./progression.ts";
import { trialInstances, trialDef } from "./competition.ts";
import type { GameEvent, PlayerState, Reward, Season, StoreOffer } from "./types.ts";

export const activeSeason = (now: number): Season | null => SEASONS.find((s) => now >= s.startsAt && now < s.endsAt) ?? null;
setSeasonResolver((now) => activeSeason(now)?.id ?? null);
setSeasonMatcher((id, now) => activeSeason(now)?.id === id);

export const activeEvents = (now: number): GameEvent[] => EVENTS.filter((e) => now >= e.startsAt && now < e.endsAt);

/** Multipliers an island run gets right now (events are data-driven, never hardcoded in gameplay). */
export function eventModifiers(islandId: string, now: number) {
  const out = { resonanceMultiplier: 1, dustMultiplier: 1, memoryDropBoost: 1 };
  for (const e of activeEvents(now)) {
    if (e.eligibleIslands !== "all" && !e.eligibleIslands.includes(islandId)) continue;
    out.resonanceMultiplier *= e.modifiers.resonanceMultiplier ?? 1;
    out.dustMultiplier *= e.modifiers.dustMultiplier ?? 1;
    out.memoryDropBoost *= e.modifiers.memoryDropBoost ?? 1;
  }
  return out;
}

// ---- Crystal Pass ----------------------------------------------------------------------------------------
export function passStatus(s: PlayerState, now: number) {
  const season = activeSeason(now);
  if (!season) return null;
  const p = s.seasons[season.id] ?? { passXp: 0, premium: false, claimedFree: [], claimedPremium: [] };
  const tier = season.passTiers.filter((t) => p.passXp >= t.passXp).length;
  const next = season.passTiers[tier];
  return {
    season, tier, premium: p.premium, passXp: p.passXp,
    toNext: next ? next.passXp - p.passXp : 0,
    claimableFree: season.passTiers.filter((t) => t.tier <= tier && !p.claimedFree.includes(t.tier)).map((t) => t.tier),
    claimablePremium: p.premium ? season.passTiers.filter((t) => t.tier <= tier && !p.claimedPremium.includes(t.tier)).map((t) => t.tier) : [],
    daysLeft: Math.ceil((season.endsAt - now) / 86400000),
  };
}
export function claimPass(state: PlayerState, tier: number, track: "free" | "premium", now: number): Result {
  const st = passStatus(state, now);
  if (!st) return fail("No season is running");
  if ((track === "free" ? st.claimableFree : st.claimablePremium).indexOf(tier) < 0) {
    return fail(track === "premium" && !st.premium ? "The Crystal Pass is not unlocked" : "Not claimable");
  }
  const def = st.season.passTiers[tier - 1];
  let s = grant(state, def[track], now).state;
  s.seasons[st.season.id] ??= { passXp: 0, premium: false, claimedFree: [], claimedPremium: [] };
  (track === "free" ? s.seasons[st.season.id].claimedFree : s.seasons[st.season.id].claimedPremium).push(tier);
  s = recordEvent(s, { type: "seasonLevel", season: st.season.id, level: st.tier }, now);
  return ok(s);
}

// ---- Realm Exchange -----------------------------------------------------------------------------------------
export function storeCatalog(s: PlayerState, now: number) {
  const bought = (id: string) => s.purchases.filter((p) => p.offer === id).length;
  return STORE.filter((o) => (o.minKeeperLevel ?? 1) <= levelOf(s))
    .filter((o) => o.section !== "pass" || (activeSeason(now) && o.grants.unlockPass === activeSeason(now)!.id))
    .map((o) => ({ offer: o, soldOut: o.limit !== undefined && bought(o.id) >= o.limit }));
}

function applyOffer(state: PlayerState, offer: StoreOffer, receipt: string, now: number): PlayerState {
  let s = grant(state, offer.grants, now).state;
  if (offer.grants.unlockPass) {
    s.seasons[offer.grants.unlockPass] ??= { passXp: 0, premium: false, claimedFree: [], claimedPremium: [] };
    s.seasons[offer.grants.unlockPass].premium = true;
  }
  if (offer.section === "expeditions") {
    const island = ISLANDS.find((i) => i.portal === "expedition" && offer.id.endsWith(i.realm));
    if (island) s.expeditions[island.id] = { unlockedAt: now };
  }
  s.purchases.push({ receipt, offer: offer.id, at: now });
  return s;
}

/** In-game currency purchases (Prism Dust / Aether). Real-money offers go through PaymentProvider. */
export function buyWithCurrency(state: PlayerState, offerId: string, now: number): Result {
  const item = storeCatalog(state, now).find((x) => x.offer.id === offerId);
  if (!item) return fail("Not available");
  if (item.soldOut) return fail("Already owned");
  const price = item.offer.price;
  if (price.kind === "iap") return fail("Real-money offer");
  const r = spend(state, { [price.kind]: price.amount });
  if (!r.ok) return r;
  return ok(applyOffer(r.state, item.offer, `local-${offerId}-${now}`, now));
}

/** Store abstraction – Google Play Billing on device, a scripted fake in development. */
export interface PaymentProvider {
  purchase(sku: string): Promise<{ status: "purchased"; receipt: string } | { status: "cancelled" | "failed"; error?: string }>;
}
/** Applies a real-money purchase only after the backend verified the receipt. Idempotent per receipt. */
export function applyVerifiedPurchase(state: PlayerState, offerId: string, receipt: string, now: number): Result {
  const offer = STORE.find((o) => o.id === offerId);
  if (!offer || offer.price.kind !== "iap") return fail("Unknown offer");
  if (state.purchases.some((p) => p.receipt === receipt)) return fail("Receipt already applied");
  if (offer.limit !== undefined && state.purchases.filter((p) => p.offer === offerId).length >= offer.limit) return fail("Already owned");
  return ok(applyOffer(state, offer, receipt, now));
}

/** Rewarded ads are always player-initiated and never shown during AR play. */
export interface AdProvider {
  showRewarded(placement: AdPlacement): Promise<{ completed: boolean }>;
}
export type AdPlacement = "stabilizePortal" | "doubleReward" | "bonusDust" | "relicCharge";
export const AD_REWARDS: Record<AdPlacement, Reward> = {
  stabilizePortal: {},
  doubleReward: {},
  bonusDust: { prismDust: 60 },
  relicCharge: { items: { relicCharge: 1 } },
};
export const AD_DAILY_LIMIT = 5;

// ---- failure recovery ------------------------------------------------------------------------------------------------
/** "Stabilize Portal": +5 moves after running out. Earned currency first; never required to finish a board. */
export function stabilizePortal(state: PlayerState, via: "prismDust" | "aether" | "ad", usedThisRun: number): Result & { moves?: number } {
  if (usedThisRun >= ECONOMY.stabilize.perRunLimit) return fail("The portal cannot be stabilised again");
  if (via === "ad") return { ok: true, state, moves: ECONOMY.stabilize.moves };
  const r = spend(state, { [via]: ECONOMY.stabilize[via] });
  return r.ok ? { ...r, moves: ECONOMY.stabilize.moves } : r;
}

// ---- Keeper Briefing -------------------------------------------------------------------------------------------------
export interface BriefingItem {
  id: string;
  kind: "return" | "sanctuary" | "duties" | "quest" | "achievement" | "trial" | "event" | "pass" | "portal" | "story";
  text: string;
  priority: number;
}

/** A single ranked summary of what's waiting – the UI shows the top few, never a pop-up cascade. */
export function keeperBriefing(state: PlayerState, now: number): BriefingItem[] {
  const s = refreshCycles(clone(state), now);
  const out: BriefingItem[] = [];
  const ret = keepersReturnStatus(s, now);
  if (!ret.claimedToday) out.push({ id: "return", kind: "return", text: `Keeper's Return: ${ret.slot.label} is waiting (day ${ret.streak})`, priority: 100 });
  if (isUnlocked(s, "sanctuary")) {
    const res = pendingSanctuaryResonance(s, now);
    if (res >= 20) out.push({ id: "sanct", kind: "sanctuary", text: `Your Sanctuary gathered ${res} Resonance while you were away`, priority: 70 });
  }
  const readyQuests = availableQuests(s, now).filter((q) => s.quests[q.id]?.completed && !s.quests[q.id]?.claimed);
  if (readyQuests.length) out.push({ id: "quests", kind: "quest", text: `${readyQuests.length} quest reward${readyQuests.length > 1 ? "s" : ""} ready to claim`, priority: 90 });
  if (isUnlocked(s, "duties")) {
    const cache = dutyCacheStatus(s);
    if (cache.claimable) out.push({ id: "cache", kind: "duties", text: "Keeper's Cache earned from today's duties", priority: 85 });
    else if (!cache.claimed) out.push({ id: "duties", kind: "duties", text: `Keeper Duties: ${cache.done}/${cache.needed} for today's Cache`, priority: 30 });
  }
  if (isUnlocked(s, "achievements")) {
    const ach = achievementStatus(s).filter((a) => a.claimable).length;
    if (ach) out.push({ id: "ach", kind: "achievement", text: `${ach} Chronicle${ach > 1 ? "s" : ""} recorded`, priority: 60 });
  }
  if (isUnlocked(s, "trials")) {
    for (const t of trialInstances(now)) {
      const def = trialDef(t.trialId)!;
      if (def.minKeeperLevel <= levelOf(s) && (def.schedule === "weekend" || def.schedule === "championship")) {
        out.push({ id: "trial-" + t.instanceId, kind: "trial", text: `${def.name} is open`, priority: 55 });
      }
    }
  }
  if (isUnlocked(s, "season")) {
    for (const e of activeEvents(now)) out.push({ id: "ev-" + e.id, kind: "event", text: `${e.title} is underway`, priority: 50 });
    const pass = passStatus(s, now);
    if (pass && (pass.claimableFree.length || pass.claimablePremium.length)) out.push({ id: "pass", kind: "pass", text: "Crystal Pass rewards are ready", priority: 65 });
  }
  const nextIsland = ISLANDS.find((i) => islandStatus(s, i, now).status === "available" && !s.islands[i.id]);
  if (nextIsland) out.push({ id: "next-" + nextIsland.id, kind: "story", text: `A portal waits on ${nextIsland.name}`, priority: 80 });
  else {
    const gate = ISLANDS.find((i) => islandStatus(s, i, now).status === "needsUnlock");
    if (gate) out.push({ id: "gate-" + gate.id, kind: "portal", text: `${gate.name}: a ${gate.portal === "discovery" ? "Discovery" : "Expedition"} Portal is stirring`, priority: 45 });
  }
  return out.sort((a, b) => b.priority - a.priority);
}

/** The one line the home screen always shows. */
export function nextObjective(s: PlayerState, now: number): string {
  const b = keeperBriefing(s, now);
  const story = b.find((x) => x.kind === "story");
  return (story ?? b[0])?.text ?? "Earn three stars on every island";
}

export const todayKey = dayKey;
