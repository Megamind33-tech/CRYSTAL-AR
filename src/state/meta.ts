// App-side meta store: owns the Keeper's PlayerState, persistence, the offline submission queue,
// analytics, and the bridge from finished island runs to rewards.
import AsyncStorage from "@react-native-async-storage/async-storage";
import { Platform } from "react-native";
import type { SignedRun } from "../backend/contracts";
import { createBufferedAnalytics, createMockBackend, DEV_SIGNING_KEY } from "../backend/mockBackend";
import { trialDef, trialInstances, trialPoints, leagueFor } from "../meta/competition";
import { buyBoost, coinsForRun, consumeBoosts, newPlayer, normalizePlayer, grant, markSeen, type Result } from "../meta/core";
import { ISLANDS } from "../meta/config/world";
import { applyRun, recordEvent, refreshCycles, type RunOutcome } from "../meta/progression";
import type { BoostId } from "../game/boosts";
import type { PlayerState, RunReport, Reward } from "../meta/types";
import { GAME_VERSION, makeRunId, mockSign, replayRun } from "../meta/verify";
import { gameEvents, type RunRecord } from "./game";
import { createStore } from "./store";

const KEY = "crystals.keeper.v1";
const QUEUE_KEY = "crystals.queue.v1";

export const backend = createMockBackend();
export const analytics = createBufferedAnalytics();

export interface PlayContext {
  islandId: string | null;
  trialInstanceId: string | null;
}

export interface MetaState {
  player: PlayerState | null;
  loaded: boolean;
  context: PlayContext;
  /** outcome of the last finished run – drives the victory / failure flow */
  lastOutcome: (RunOutcome & { trial?: { rank: number; of: number; points: number } | null; verified: boolean }) | null;
  pending: SignedRun[];
  online: boolean;
  lastSyncError: string | null;
}

export const metaStore = createStore<MetaState>({
  player: null,
  loaded: false,
  context: { islandId: null, trialInstanceId: null },
  lastOutcome: null,
  pending: [],
  online: true,
  lastSyncError: null,
});

const now = () => Date.now();

async function persist() {
  const { player, pending } = metaStore.get();
  if (!player) return;
  try {
    await AsyncStorage.multiSet([[KEY, JSON.stringify(player)], [QUEUE_KEY, JSON.stringify(pending)]]);
  } catch {
    // storage full / unavailable: progress stays in memory for this session
  }
}

let loading: Promise<void> | null = null;
export function loadKeeper() {
  loading ??= (async () => {
    let player: PlayerState | null = null;
    let pending: SignedRun[] = [];
    try {
      const [[, p], [, q]] = await AsyncStorage.multiGet([KEY, QUEUE_KEY]);
      if (p) player = JSON.parse(p);
      if (q) pending = JSON.parse(q);
    } catch {
      // corrupt save: start fresh rather than crash
    }
    if (!player) {
      const { keeperId } = await backend.signIn(`${Platform.OS}-${Math.random().toString(36).slice(2)}`);
      player = newPlayer(keeperId, now());
      analytics.track("game_started", { first: true });
    } else {
      analytics.track("game_started", { first: false });
    }
    metaStore.set({ player: refreshCycles(normalizePlayer(player), now()), pending, loaded: true });
    await persist();
    void flushQueue();
  })();
  return loading;
}

/** Applies a pure meta action; returns the error message (if any) for the UI. */
export function act(fn: (s: PlayerState, t: number) => Result, analyticsEvent?: Parameters<typeof analytics.track>): string | null {
  const s = metaStore.get().player;
  if (!s) return "Still loading";
  const r = fn(refreshCycles(s, now()), now());
  if (!r.ok) return r.error;
  metaStore.set({ player: r.state });
  if (analyticsEvent) analytics.track(...analyticsEvent);
  void persist();
  return null;
}
export function setPlayer(fn: (s: PlayerState) => PlayerState) {
  const s = metaStore.get().player;
  if (!s) return;
  metaStore.set({ player: fn(s) });
  void persist();
}
export const markFeatureSeen = (feature: string) => setPlayer((s) => markSeen(s, feature));

export function setPlayContext(ctx: Partial<PlayContext>) {
  metaStore.set((m) => ({ context: { ...m.context, ...ctx }, lastOutcome: null }));
}

/** Submits queued runs (leaderboards / trials). Offline-safe: failures stay queued. */
export async function flushQueue() {
  const { pending, player } = metaStore.get();
  if (!player || pending.length === 0) return;
  try {
    const { results } = await backend.sync(player, pending);
    metaStore.set({ pending: [], online: true, lastSyncError: null });
    const rejected = results.filter((r) => !r.accepted);
    if (rejected.length) metaStore.set({ lastSyncError: rejected[0].reasons.join(", ") });
    await persist();
  } catch (e) {
    metaStore.set({ online: false, lastSyncError: String(e) });
  }
}

function toReport(rec: RunRecord, keeperId: string, ctx: PlayContext): RunReport {
  const island = ISLANDS.find((i) => i.id === ctx.islandId) ?? ISLANDS.find((i) => i.levelIndex === rec.levelIndex)!;
  return {
    runId: makeRunId(keeperId, rec.startedAt, rec.seed),
    islandId: island.id,
    levelIndex: rec.levelIndex,
    seed: rec.seed,
    gameVersion: GAME_VERSION,
    startedAt: rec.startedAt,
    endedAt: rec.endedAt,
    swaps: rec.swaps,
    relicsUsed: rec.relicsUsed,
    boosts: rec.boosts,
    ...(rec.equipped.length ? { equipped: rec.equipped } : {}),
    claimed: { won: rec.won, stars: rec.stars, score: rec.score, ...rec.stats, ...(rec.secretFound ? { secretFound: true } : {}) },
    trialInstanceId: ctx.trialInstanceId ?? undefined,
    buildFlags: { debug: __DEV__, emulator: false },
  };
}

/** Finished run → verify by replay → rewards / trial standing → queue for the server. */
async function onRunFinished(rec: RunRecord) {
  const { player, context } = metaStore.get();
  if (!player) return;
  const report = toReport(rec, player.profile.keeperId, context);
  const verdict = replayRun(report);
  analytics.track(report.claimed.won ? "island_completed" : "island_failed", { island: report.islandId, stars: report.claimed.stars, score: report.claimed.score });
  if (!verdict.ok) {
    // never grant from an unverifiable run (would indicate a client bug or tampering)
    metaStore.set({ lastOutcome: { state: player, reward: {}, firstRestore: false, log: null, storyChapter: null, verified: false }, lastSyncError: verdict.reasons.join(", ") });
    return;
  }
  const signed: SignedRun = { report, signature: mockSign(report, DEV_SIGNING_KEY) };

  if (context.trialInstanceId) {
    const res = await backend.submitRun(signed);
    let s = player;
    let trial: { rank: number; of: number; points: number } | null = null;
    if (res.accepted && res.trial) {
      trial = res.trial;
      const inst = trialInstances(report.endedAt).find((i) => i.instanceId === context.trialInstanceId);
      s = recordEvent(s, { type: "trialRound", trial: inst?.trialId ?? "", rank: res.trial.rank, of: res.trial.of }, now());
      s = { ...s, stats: { ...s.stats, trialPoints: s.stats.trialPoints + trialPoints(res.trial.rank, res.trial.of) } };
      s = { ...s, league: { id: leagueFor(s.stats.trialPoints), points: s.stats.trialPoints } };
      const def = inst && trialDef(inst.trialId);
      if (def) s = grant(s, def.participation, now()).state;
      analytics.track("tournament_completed", { trial: inst?.trialId ?? "", rank: res.trial.rank });
    }
    metaStore.set({ player: s, lastOutcome: { state: s, reward: {}, firstRestore: false, log: null, storyChapter: null, trial, verified: res.accepted } });
    await persist();
    return;
  }

  const outcome = applyRun(player, report, now());
  outcome.state = { ...outcome.state, wallet: { ...outcome.state.wallet, coins: outcome.state.wallet.coins + coinsForRun(report.claimed.won, report.claimed.stars) } };
  metaStore.set((m) => ({ player: outcome.state, lastOutcome: { ...outcome, verified: true }, pending: [...m.pending, signed] }));
  if (outcome.firstRestore) analytics.track("portal_opened", { island: report.islandId });
  for (const l of outcome.log?.newLumins ?? []) analytics.track("lumin_rescued", { lumin: l });
  for (const r of outcome.log?.newRelics ?? []) analytics.track("relic_found", { relic: r });
  for (const h of outcome.log?.newShards ?? []) analytics.track("heart_shard_recovered", { shard: h });
  await persist();
  void flushQueue();
}

gameEvents.on((e) => {
  if (e.type === "levelEnd") void onRunFinished(e.run);
});

export function rewardTotal(r: Reward) {
  return (r.prismDust ?? 0) + (r.aether ?? 0) * 10;
}

/** Armory purchase. Returns the error message, if any. */
export const buyBoostItem = (id: BoostId) => act((s) => buyBoost(s, id));

/** Spends the equipped boosts as a run starts. Returns the error message, if any. */
export const equipBoosts = (ids: BoostId[]) => (ids.length ? act((s) => consumeBoosts(s, ids)) : null);
