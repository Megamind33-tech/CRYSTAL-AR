// Local, in-memory implementation of the Backend contract for development and offline play.
// It enforces the same rules a real server must (replay verification, duplicate run IDs, trial
// windows, receipt idempotency) – but it runs on the client, so it is NOT a security boundary.
import { leaderboardWindow, keeperScore, leagueFor, restorationScore, trialDef, trialInstances, trialPoints, trialScore, type LeaderboardRow } from "../meta/competition.ts";
import { hash, levelOf } from "../meta/core.ts";
import { STORE } from "../meta/config/live.ts";
import { mockSign, replayRun, verifyTrialRun } from "../meta/verify.ts";
import type { LeaderboardId, LeagueId, PlayerState } from "../meta/types.ts";
import type { AnalyticsEvent, AnalyticsProps, AnalyticsSink, Backend, LeaderboardResponse, SignedRun, SubmitRunResponse } from "./contracts.ts";

export const DEV_SIGNING_KEY = "dev-only-not-secret";

const NAMES = ["Aria", "Bram", "Cael", "Dessa", "Eamon", "Fen", "Galen", "Hesper", "Isolde", "Joren", "Kestrel", "Lior", "Maren", "Nyx", "Orrin", "Perrin", "Quill", "Rowan", "Sable", "Tamsin", "Ulric", "Vesper", "Wren", "Xan", "Yara", "Zephyr"];
const AVATARS = ["avatar-mossling", "avatar-fallsprite", "avatar-lanternmoth", "avatar-rimeback"];

/** Deterministic rival Keepers so rankings look alive offline (clearly marked as simulated in the UI). */
function rivals(board: LeaderboardId, count: number): LeaderboardRow[] {
  return Array.from({ length: count }, (_, i) => {
    const h = hash(board + i);
    const skill = Math.pow((h % 1000) / 1000, 2.2);
    const score = Math.round(
      board === "weeklyResonance" ? 2000 + skill * 90000
      : board === "combo" ? 2 + Math.round(skill * 8)
      : board === "portalMaster" ? Math.round(skill * 180)
      : board === "trials" ? Math.round(skill * 4000)
      : board === "restoration" ? Math.round(skill * 30) * 180
      : 500 + skill * 24000,
    );
    const league: LeagueId = leagueFor(board === "trials" ? score : Math.round(skill * 4000));
    return { keeperId: `sim-${board}-${i}`, name: `${NAMES[h % NAMES.length]} ${NAMES[(h >>> 8) % NAMES.length][0]}.`, avatar: AVATARS[h % AVATARS.length], level: 1 + Math.round(skill * 45), score, league, rank: 0 };
  });
}

export function metricFor(board: LeaderboardId, s: PlayerState): number {
  switch (board) {
    case "weeklyResonance": return s.stats.weeklyResonance;
    case "portalMaster": return s.stats.portalsOpened;
    case "restoration": return restorationScore(s);
    case "combo": return s.stats.bestCascade;
    case "trials": return s.stats.trialPoints;
    default: return keeperScore(s);
  }
}

export function createMockBackend(now: () => number = Date.now): Backend & { lastState: PlayerState | null } {
  const seenRuns = new Set<string>();
  const receipts = new Set<string>();
  const trialBoards = new Map<string, { keeperId: string; score: number }[]>();
  let lastState: PlayerState | null = null;

  const submitRun = async (run: SignedRun): Promise<SubmitRunResponse> => {
    const r = run.report;
    if (seenRuns.has(r.runId)) return { accepted: false, reasons: ["duplicate run id"] };
    if (mockSign(r, DEV_SIGNING_KEY) !== run.signature) return { accepted: false, reasons: ["bad signature"] };
    const verdict = r.trialInstanceId ? verifyTrialRun(r, now()) : replayRun(r);
    if (!verdict.ok) return { accepted: false, reasons: verdict.reasons, truth: verdict.truth };
    seenRuns.add(r.runId);
    if (!r.trialInstanceId) return { accepted: true, reasons: [], truth: verdict.truth };

    const inst = trialInstances(r.endedAt).find((i) => i.instanceId === r.trialInstanceId)!;
    const def = trialDef(inst.trialId)!;
    const board = trialBoards.get(inst.instanceId) ?? rivalsForTrial(inst.instanceId, def.kind);
    const keeperId = r.runId.split("-")[0];
    const score = trialScore(def, r);
    const existing = board.find((e) => e.keeperId === keeperId);
    if (existing) existing.score = Math.max(existing.score, score);
    else board.push({ keeperId, score });
    board.sort((a, b) => b.score - a.score);
    trialBoards.set(inst.instanceId, board);
    const rank = board.findIndex((e) => e.keeperId === keeperId) + 1;
    return { accepted: true, reasons: [], truth: verdict.truth, trial: { rank, of: board.length, points: trialPoints(rank, board.length) } };
  };

  return {
    get lastState() {
      return lastState;
    },
    async signIn(deviceId) {
      return { keeperId: "k" + (hash(deviceId) >>> 0).toString(36), serverTime: now() };
    },
    async sync(state, pending) {
      const results: SubmitRunResponse[] = [];
      for (const p of pending) results.push(await submitRun(p));
      lastState = state;
      return { state, results };
    },
    submitRun,
    async leaderboard(id, keeperId): Promise<LeaderboardResponse> {
      const me = lastState;
      let rows = id === "friends" ? rivals(id, 6) : rivals(id, 240);
      if (id === "regional") rows = rows.slice(0, 60);
      if (me) rows = [...rows, { keeperId, name: me.profile.keeperName, avatar: me.profile.avatar, level: levelOf(me), score: metricFor(id, me), league: me.league.id, rank: 0 }];
      return { id, ...leaderboardWindow(rows, keeperId), updatedAt: now() };
    },
    async verifyPurchase(sku, receipt) {
      if (receipts.has(receipt) || !receipt.startsWith("dev-receipt-")) return { valid: false };
      const offer = STORE.find((o) => o.price.kind === "iap" && o.price.sku === sku);
      if (!offer) return { valid: false };
      receipts.add(receipt);
      return { valid: true, offerId: offer.id };
    },
    async configVersion() {
      return "local-1";
    },
  };
}

function rivalsForTrial(instanceId: string, kind: string) {
  return Array.from({ length: 48 }, (_, i) => {
    const skill = Math.pow((hash(instanceId + i) % 1000) / 1000, 1.8);
    const score = kind === "cascade" ? Math.round(2 + skill * 6) * 1000 + Math.round(skill * 300) : Math.round(900 + skill * 7000);
    return { keeperId: `sim-trial-${i}`, score };
  });
}

// ---- dev implementations of device services -------------------------------------------------------------------
/** Development payment provider: never charges; returns receipts the mock backend accepts. */
export const devPaymentProvider = {
  async purchase(sku: string) {
    return { status: "purchased" as const, receipt: `dev-receipt-${sku}-${Date.now().toString(36)}` };
  },
};
/** Development ad provider: completes instantly. A real SDK replaces this – ads remain player-initiated. */
export const devAdProvider = {
  async showRewarded() {
    return { completed: true };
  },
};

/** Analytics sink that just buffers (inspect in Diagnostics). No personal data is recorded. */
export function createBufferedAnalytics(limit = 200): AnalyticsSink & { events: { event: AnalyticsEvent; props?: AnalyticsProps; t: number }[] } {
  const events: { event: AnalyticsEvent; props?: AnalyticsProps; t: number }[] = [];
  return {
    events,
    track(event, props) {
      events.push({ event, props, t: Date.now() });
      if (events.length > limit) events.shift();
    },
  };
}
