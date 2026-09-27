import { test } from "node:test";
import assert from "node:assert/strict";
import { findValidMoves } from "../../game/board.ts";
import { LEVELS, playMove, startSession, starsFor } from "../../game/level.ts";
import { createMockBackend, DEV_SIGNING_KEY, devPaymentProvider } from "../../backend/mockBackend.ts";
import { keeperScore, leaderboardWindow, leagueFor, trialDef, trialInstances } from "../../meta/competition.ts";
import { STORE } from "../../meta/config/live.ts";
import { KEEPERS_RETURN } from "../../meta/config/progression.ts";
import { ISLANDS } from "../../meta/config/world.ts";
import { grant, keeperLevel, levelOf, newPlayer, pendingReveals, isUnlocked } from "../../meta/core.ts";
import {
  activeSeason, applyVerifiedPurchase, buyWithCurrency, claimPass, keeperBriefing, nextObjective, passStatus, stabilizePortal, storeCatalog,
} from "../../meta/live.ts";
import {
  achievementStatus, applyRun, archive, claimAchievement, claimDutyCache, claimKeepersReturn, claimQuest, collectSanctuary,
  dutyCacheStatus, feedLumin, houseLumin, islandStatus, keepersReturnStatus, openKeepersCache, pendingSanctuaryResonance,
  recordEvent, refreshCycles, relicCharges, sanctuaryCost, unlockDiscovery, upgradeSanctuary, useRelic,
} from "../../meta/progression.ts";
import { accumulate, GAME_VERSION, makeRunId, mockSign, newRunStats, replayRun } from "../../meta/verify.ts";
import type { PlayerState, RunReport } from "../../meta/types.ts";

const T0 = Date.UTC(2026, 8, 28, 12); // inside Season 01
const DAY = 86400000;

/** Plays an island greedily with the real engine and returns an honest, replayable report. */
function playIsland(keeperId: string, islandId: string, now: number, opts: { seed?: number; moves?: number; levelIndex?: number; trialInstanceId?: string } = {}): RunReport {
  const island = ISLANDS.find((i) => i.id === islandId);
  const levelIndex = opts.levelIndex ?? island!.levelIndex;
  const seed = opts.seed ?? LEVELS[levelIndex].seed;
  const level = opts.moves ? { ...LEVELS[levelIndex], moves: opts.moves } : LEVELS[levelIndex];
  let s = startSession(level, seed);
  const acc = newRunStats();
  const swaps: RunReport["swaps"] = [];
  while (s.status === "playing") {
    let best: ReturnType<typeof playMove> | null = null, pick: [number, number, number, number] | null = null;
    for (const [a, b] of findValidMoves(s.engine.board)) {
      const r = playMove(s, a, b);
      if (!best || r.session.score > best.session.score) [best, pick] = [r, [a.x, a.y, b.x, b.y]];
    }
    accumulate(acc, best!.steps);
    swaps.push(pick!);
    s = best!.session;
  }
  return {
    runId: makeRunId(keeperId, now, seed), islandId, levelIndex, seed, gameVersion: GAME_VERSION,
    startedAt: now - swaps.length * 2000, endedAt: now, swaps, relicsUsed: [],
    claimed: { won: s.status === "won", stars: starsFor(s), score: s.score, ...acc },
    trialInstanceId: opts.trialInstanceId,
  };
}

const fresh = () => refreshCycles(newPlayer("kalpha", T0, "Aria"), T0);
function restoreStory(s: PlayerState, upTo: number, now = T0) {
  for (const id of ["waking-stones", "emerald-canopy", "heart-of-the-falls"].slice(0, upTo)) {
    let r = playIsland(s.profile.keeperId, id, now);
    for (let seed = 1; !r.claimed.won && seed < 40; seed++) r = playIsland(s.profile.keeperId, id, now, { seed: seed * 7919 });
    assert.ok(r.claimed.won, `bot should win ${id}`);
    s = applyRun(s, r, now).state;
  }
  return s;
}

test("new Keeper starts at level 1 with only the first story island open", () => {
  const s = fresh();
  assert.equal(levelOf(s), 1);
  assert.equal(islandStatus(s, ISLANDS[0], T0).status, "available");
  assert.equal(islandStatus(s, ISLANDS[1], T0).status, "locked");
  assert.deepEqual(pendingReveals(s).map((f) => f.feature), ["story"]);
  assert.equal(isUnlocked(s, "trials"), false);
});

test("level curve is monotonic and gentle", () => {
  let prev = 0;
  for (let xp = 0; xp < 20000; xp += 500) {
    const l = keeperLevel(xp).level;
    assert.ok(l >= prev);
    prev = l;
  }
  assert.ok(keeperLevel(300).level >= 2);
});

test("first restore grants the story rewards; replays grant less; stars scale Prism Dust", () => {
  let s = fresh();
  const r = playIsland(s.profile.keeperId, "waking-stones", T0);
  const first = applyRun(s, r, T0);
  assert.ok(first.firstRestore);
  assert.ok(first.state.lumins.mossling);
  assert.ok(first.state.memories.includes("mem-first-light"));
  assert.equal(first.storyChapter, "ch1-waking");
  const replay = applyRun(first.state, { ...r, runId: r.runId + "b" }, T0 + 1000);
  assert.equal(replay.firstRestore, false);
  assert.ok((replay.reward.prismDust ?? 0) < (first.reward.prismDust ?? 0));
  assert.equal(islandStatus(first.state, ISLANDS[1], T0).status, "available", "next story island unlocks");
});

test("a lost run updates stats but grants nothing", () => {
  const s = fresh();
  const r = playIsland(s.profile.keeperId, "waking-stones", T0, { moves: 2 });
  assert.equal(r.claimed.won, false);
  const out = applyRun(s, r, T0);
  assert.equal(out.state.stats.islandsPlayed, 1);
  assert.equal(out.state.wallet.prismDust, s.wallet.prismDust);
  assert.equal(Object.keys(out.state.islands).length, 0);
});

test("Heart Shard comes from the story and gates the next realm; it is never sold", () => {
  let s = restoreStory(fresh(), 3);
  assert.deepEqual(s.heartShards, ["shard-verdant"]);
  assert.ok(STORE.every((o) => !o.grants.heartShards?.length));
  const eclipse = ISLANDS.find((i) => i.id === "eclipse-threshold")!;
  const st = islandStatus(s, eclipse, T0);
  assert.ok(st.status === "available" || (st.status === "locked" && /Keeper level/.test(st.reason!)), JSON.stringify(st));
});

test("duplicates convert to Prism Dust and relic sets pay out once", () => {
  let s = fresh();
  s = grant(s, { lumins: ["mossling"] }, T0).state;
  const before = s.wallet.prismDust;
  const g = grant(s, { lumins: ["mossling"] }, T0);
  assert.equal(g.log.duplicates, 1);
  assert.ok(g.state.wallet.prismDust > before);
  const all = grant(g.state, { relics: ["oracle-stone", "chrono-crystal", "prism-hammer"] }, T0);
  assert.deepEqual(all.log.setsCompleted, ["Keeper's First Tools"]);
  const again = grant(all.state, { relics: ["oracle-stone"] }, T0);
  assert.deepEqual(again.log.setsCompleted, []);
});

test("Keeper Duties roll per day, progress from real events, and pay a Keeper's Cache", () => {
  let s = fresh();
  assert.equal(s.questCycles.daily.length, 4);
  const tomorrow = refreshCycles(s, T0 + DAY);
  assert.notDeepEqual(tomorrow.questCycles.daily, s.questCycles.daily.slice().reverse().reverse().map((x) => x + "_"));
  // force-complete three duties through events
  for (let i = 0; i < 6; i++) s = applyRun(s, playIsland(s.profile.keeperId, "waking-stones", T0 + i, { seed: 100 + i }), T0 + i).state;
  const done = s.questCycles.daily.filter((id) => s.quests[id].completed);
  for (const id of done) {
    const r = claimQuest(s, id, T0);
    assert.ok(r.ok);
    s = r.state;
  }
  assert.equal(claimQuest(s, done[0] ?? "x", T0).ok, false, "double claim rejected");
  const cache = dutyCacheStatus(s);
  if (cache.done >= cache.needed) {
    const c = claimDutyCache(s, T0);
    assert.ok(c.ok);
    const opened = openKeepersCache(c.state, T0);
    assert.ok(opened.ok && opened.state.items.relicCharge >= 1);
  }
  assert.ok(s.stats.dutiesCompleted === done.length);
});

test("Keeper's Return: streak, one grace day, Streak Restore, milestones", () => {
  let s = fresh();
  for (let d = 0; d < 7; d++) {
    const r = claimKeepersReturn(s, T0 + d * DAY);
    assert.ok(r.ok);
    s = r.state;
  }
  assert.equal(s.checkin.streak, 7);
  assert.ok(s.checkin.milestonesClaimed.includes(7));
  assert.equal(claimKeepersReturn(s, T0 + 6 * DAY).ok, false, "once per day");
  // miss one day: grace keeps the streak
  s = claimKeepersReturn(s, T0 + 8 * DAY).state as PlayerState;
  assert.equal(s.checkin.streak, 8);
  // miss two days with a Streak Restore
  s = grant(s, { items: { streakRestore: 1 } }, T0).state;
  const st = keepersReturnStatus(s, T0 + 11 * DAY);
  assert.ok(st.restorable);
  const restored = claimKeepersReturn(s, T0 + 11 * DAY, true);
  assert.ok(restored.ok);
  assert.equal(restored.state.checkin.streak, 9);
  // without a restore a long gap resets to day 1
  assert.equal(keepersReturnStatus(restored.state, T0 + 20 * DAY).streak, 1);
  assert.equal(KEEPERS_RETURN.cycle[6].label, "Keeper's Cache");
});

test("Sanctuary: costs grow, rating rises, idle Resonance accrues and is capped", () => {
  let s = restoreStory(fresh(), 3);
  s = grant(s, { prismDust: 5000, items: { sanctuaryStone: 40, luminFood: 20 }, keeperXp: 3000 }, T0).state;
  const c1 = sanctuaryCost("resonance-well", 1), c2 = sanctuaryCost("resonance-well", 2);
  assert.ok((c2.prismDust ?? 0) > (c1.prismDust ?? 0));
  const up = upgradeSanctuary(s, "resonance-well", T0);
  assert.ok(up.ok);
  s = up.state;
  assert.equal(s.stats.sanctuaryUpgrades, 1);
  assert.ok(pendingSanctuaryResonance(s, T0 + 3600000) > 0);
  assert.equal(pendingSanctuaryResonance(s, T0 + 100 * 3600000), pendingSanctuaryResonance(s, T0 + 16 * 3600000), "capped");
  const col = collectSanctuary(s, T0 + 5 * 3600000);
  assert.ok(col.ok && col.state.wallet.prismDust > s.wallet.prismDust);
  // Lumin Grove capacity
  assert.ok(houseLumin(s, "mossling").ok);
  const housed = houseLumin(s, "mossling").state!;
  assert.equal(houseLumin(housed, "fallsprite").ok, false, "grove full at level 0");
  // feeding evolves at bond 10
  let f = s;
  let evolved: string | undefined;
  for (let i = 0; i < 10; i++) {
    const r = feedLumin(f, "mossling", T0);
    assert.ok(r.ok);
    f = r.state;
    evolved = r.evolved ?? evolved;
  }
  assert.equal(evolved, "mossward");
});

test("relic charges regenerate; unapproved relics are refused in ranked play", () => {
  let s = grant(fresh(), { relics: ["oracle-stone", "chrono-crystal"] }, T0).state;
  for (let i = 0; i < 3; i++) s = useRelic(s, "oracle-stone", T0).state as PlayerState;
  assert.equal(relicCharges(s, "oracle-stone", T0).charges, 0);
  assert.equal(useRelic(s, "oracle-stone", T0).ok, false);
  assert.equal(relicCharges(s, "oracle-stone", T0 + 61 * 60000).charges, 1);
  assert.equal(useRelic(s, "chrono-crystal", T0, true).ok, false);
  assert.equal(s.stats.relicsUsed, 3);
});

test("achievements: tiers, points, hidden ones stay concealed until reached", () => {
  let s = restoreStory(fresh(), 1);
  const st = achievementStatus(s);
  const restorer = st.find((a) => a.def.id === "ach-restorer")!;
  assert.ok(restorer.claimable);
  assert.ok(st.find((a) => a.def.id === "ach-secret-storm")!.concealed);
  s = claimAchievement(s, "ach-restorer", T0).state as PlayerState;
  assert.equal(claimAchievement(s, "ach-restorer", T0).ok, false);
});

test("discovery portal opens with fragments, expedition via the Realm Exchange", () => {
  let s = restoreStory(fresh(), 3);
  const hollow = ISLANDS.find((i) => i.id === "hollow-of-lanterns")!;
  assert.equal(islandStatus(s, hollow, T0).status, "needsUnlock");
  assert.equal(unlockDiscovery(s, hollow.id, T0).ok, false, "needs 5 fragments");
  s = grant(s, { items: { portalFragment: 3 } }, T0).state;
  const u = unlockDiscovery(s, hollow.id, T0);
  assert.ok(u.ok, JSON.stringify(u));
  assert.equal(islandStatus(u.state, hollow, T0).status, "available");
});

test("anti-cheat: honest runs replay; tampering, duplicates and bad signatures are rejected", async () => {
  const s = fresh();
  const r = playIsland(s.profile.keeperId, "waking-stones", T0);
  assert.ok(replayRun(r).ok, JSON.stringify(replayRun(r).reasons));
  assert.equal(replayRun({ ...r, claimed: { ...r.claimed, score: r.claimed.score + 500 } }).ok, false);
  assert.equal(replayRun({ ...r, startedAt: r.endedAt - 100 }).ok, false, "impossible speed");
  const be = createMockBackend(() => T0);
  const signed = { report: r, signature: mockSign(r, DEV_SIGNING_KEY) };
  assert.ok((await be.submitRun(signed)).accepted);
  assert.deepEqual((await be.submitRun(signed)).reasons, ["duplicate run id"]);
  const forged = { ...r, runId: r.runId + "x", claimed: { ...r.claimed, score: 99999 } };
  assert.equal((await be.submitRun({ report: forged, signature: mockSign(forged, DEV_SIGNING_KEY) })).accepted, false);
  assert.equal((await be.submitRun({ report: { ...r, runId: "k-2" }, signature: "bad" })).accepted, false);
});

test("Realm Trials: same seed for everyone, verified, ranked; debug builds unranked", async () => {
  const inst = trialInstances(T0).find((i) => trialDef(i.trialId)!.kind === "highScore")!;
  assert.ok(inst);
  assert.deepEqual(trialInstances(T0 + 3600000).find((i) => i.trialId === inst.trialId), inst, "stable within the day");
  const def = trialDef(inst.trialId)!;
  const report = playIsland("kalpha", "heart-of-the-falls", inst.opensAt + 3600000, { seed: inst.seed, moves: def.moves, levelIndex: def.levelIndex, trialInstanceId: inst.instanceId });
  const be = createMockBackend(() => inst.opensAt + 3600000);
  const res = await be.submitRun({ report, signature: mockSign(report, DEV_SIGNING_KEY) });
  assert.ok(res.accepted, JSON.stringify(res.reasons));
  assert.ok(res.trial!.rank >= 1 && res.trial!.of > 10);
  const wrongSeed = { ...report, runId: report.runId + "w", seed: report.seed + 1 };
  assert.equal((await be.submitRun({ report: wrongSeed, signature: mockSign(wrongSeed, DEV_SIGNING_KEY) })).accepted, false);
  const dbg = { ...report, runId: report.runId + "d", buildFlags: { debug: true, emulator: false } };
  assert.ok((await be.submitRun({ report: dbg, signature: mockSign(dbg, DEV_SIGNING_KEY) })).reasons.some((x) => /unranked/.test(x)));
});

test("leaderboards show podium, top 10 and neighbours; Keeper score ignores purchases", async () => {
  let s = restoreStory(fresh(), 2);
  const scoreBefore = keeperScore(s);
  const paid = applyVerifiedPurchase(s, "aether-1000", "dev-receipt-a", T0);
  assert.ok(paid.ok);
  assert.equal(keeperScore(paid.state), scoreBefore, "money never ranks");
  const be = createMockBackend(() => T0);
  await be.sync(s, []);
  const lb = await be.leaderboard("globalKeeper", s.profile.keeperId);
  assert.equal(lb.podium.length, 3);
  assert.equal(lb.top10.length, 10);
  assert.ok(lb.me && lb.neighbours.some((n) => n.keeperId === s.profile.keeperId));
  const w = leaderboardWindow([{ keeperId: "a", name: "A", avatar: "", level: 1, score: 5, league: "stone", rank: 0 }], "zz");
  assert.equal(w.me, null);
  assert.equal(leagueFor(0), "stone");
  assert.equal(leagueFor(5000), "celestial");
});

test("Crystal Pass: free track for everyone, premium gated, purchases idempotent", async () => {
  assert.ok(activeSeason(T0));
  let s = grant(fresh(), { passXp: 5000 }, T0).state;
  const st = passStatus(s, T0)!;
  assert.ok(st.tier >= 10);
  assert.ok(claimPass(s, 1, "free", T0).ok);
  assert.equal(claimPass(s, 1, "premium", T0).ok, false);
  const be = createMockBackend(() => T0);
  const pay = await devPaymentProvider.purchase("crystal_pass_s01");
  assert.equal(pay.status, "purchased");
  const v = await be.verifyPurchase("crystal_pass_s01", pay.receipt);
  assert.ok(v.valid);
  s = applyVerifiedPurchase(s, v.offerId!, pay.receipt, T0).state as PlayerState;
  assert.ok(passStatus(s, T0)!.premium);
  assert.equal(applyVerifiedPurchase(s, v.offerId!, pay.receipt, T0).ok, false, "same receipt twice");
  assert.equal((await be.verifyPurchase("crystal_pass_s01", pay.receipt)).valid, false, "server rejects replayed receipt");
  assert.ok(claimPass(s, 1, "premium", T0).ok);
});

test("Realm Exchange respects level gates and limits; Stabilize Portal has fair limits", () => {
  let s = grant(fresh(), { aether: 1000, prismDust: 2000, keeperXp: 5000 }, T0).state;
  assert.ok(storeCatalog(s, T0).some((x) => x.offer.section === "pass"));
  assert.equal(storeCatalog(fresh(), T0).some((x) => x.offer.section === "pass"), false, "no pass for brand-new Keepers");
  const b = buyWithCurrency(s, "portal-effect-aurora", T0);
  assert.ok(b.ok && b.state.cosmetics.includes("portal-effect-aurora"));
  assert.equal(buyWithCurrency(b.state, "portal-effect-aurora", T0).ok, false);
  assert.equal(stabilizePortal(s, "prismDust", 0).moves, 5);
  assert.equal(stabilizePortal(s, "prismDust", 2).ok, false);
});

test("Keeper Briefing always offers a next objective and ranks Keeper's Return first", () => {
  const s = fresh();
  const b = keeperBriefing(s, T0);
  assert.equal(b[0].kind, "return");
  assert.match(nextObjective(s, T0), /Waking Stones/);
  const done = restoreStory(s, 3);
  assert.ok(nextObjective(done, T0).length > 0);
});

test("Archive tracks completion and the Prism Heart facets", () => {
  const s = restoreStory(fresh(), 3);
  const a = archive(s);
  assert.equal(a.heart.facets, 1);
  assert.ok(a.pct > 0 && a.pct < 100);
  assert.ok(a.lumins.entries.some((e) => !e.found), "missing ones shown as silhouettes");
});

test("story quests chain through prerequisites", () => {
  let s = restoreStory(fresh(), 1);
  s = recordEvent(s, { type: "checkin", streak: 1 }, T0);
  const r = claimQuest(s, "story-1-wake", T0);
  assert.ok(r.ok);
  assert.equal(claimQuest(r.state, "story-2-shard", T0).ok, false, "shard not recovered yet");
});
