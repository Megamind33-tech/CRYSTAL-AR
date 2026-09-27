// Competition: Keeper score, leaderboard windows, leagues, Realm Trial schedule & scoring.
// Scores come from play only – money spent never contributes.
import { LEAGUES, TRIALS } from "./config/live.ts";
import { achievementScore, sanctuaryRating } from "./progression.ts";
import { hash, levelOf } from "./core.ts";
import type { LeagueId, PlayerState, RunReport, TrialDef, TrialInstance } from "./types.ts";

/** Global Keeper Ranking: breadth of progress, mastery and prestige – capped per component so no one axis dominates. */
export function keeperScore(s: PlayerState) {
  const restoration = Object.values(s.islands).reduce((a, i) => a + 100 + i.stars * 40, 0);
  const collection = Object.keys(s.lumins).length * 60 + Object.keys(s.relics).length * 50 + s.memories.length * 30 + s.heartShards.length * 250;
  const mastery = Math.min(2000, s.stats.bestCascade * 80 + s.stats.perfectRestores * 25);
  const prestige = achievementScore(s) * 5 + Math.min(3000, s.stats.trialPoints);
  return levelOf(s) * 50 + restoration + collection + mastery + prestige + sanctuaryRating(s).rating * 3;
}
export const restorationScore = (s: PlayerState) => Object.values(s.islands).reduce((a, i) => a + 100 + i.stars * 40, 0);

export interface LeaderboardRow {
  keeperId: string;
  name: string;
  avatar: string;
  level: number;
  score: number;
  league: LeagueId;
  rank: number;
}

/** What the UI shows: podium, top 10, and the window around the player – never the full list. */
export function leaderboardWindow(rows: LeaderboardRow[], me: string, around = 2) {
  const sorted = [...rows].sort((a, b) => b.score - a.score || a.keeperId.localeCompare(b.keeperId)).map((r, i) => ({ ...r, rank: i + 1 }));
  const idx = sorted.findIndex((r) => r.keeperId === me);
  return {
    total: sorted.length,
    podium: sorted.slice(0, 3),
    top10: sorted.slice(0, 10),
    me: idx >= 0 ? sorted[idx] : null,
    neighbours: idx >= 0 ? sorted.slice(Math.max(0, idx - around), idx + around + 1) : [],
  };
}

export function leagueFor(points: number): LeagueId {
  let id: LeagueId = "stone";
  for (const l of LEAGUES) if (points >= l.minPoints) id = l.id;
  return id;
}
export const leagueName = (id: LeagueId) => LEAGUES.find((l) => l.id === id)?.name ?? id;

// ---- Realm Trials ------------------------------------------------------------------------------------------
const DAY = 86400000;
/** Instances are derived from the calendar – every Keeper gets the same seed and window, no manual organisation. */
export function trialInstances(now: number): TrialInstance[] {
  const out: TrialInstance[] = [];
  const d = new Date(now);
  const dayStart = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const weekday = (d.getUTCDay() + 6) % 7; // Mon=0
  const weekStart = dayStart - weekday * DAY;
  for (const t of TRIALS) {
    let opensAt: number, closesAt: number;
    if (t.schedule === "daily") [opensAt, closesAt] = [dayStart, dayStart + DAY];
    else if (t.schedule === "weekend") [opensAt, closesAt] = [weekStart + 4 * DAY + 16 * 3600000, weekStart + 7 * DAY];
    else if (t.schedule === "weekly") [opensAt, closesAt] = [weekStart, weekStart + 7 * DAY];
    else [opensAt, closesAt] = [weekStart + 5 * DAY, weekStart + 7 * DAY]; // championship: final weekend
    if (now < opensAt || now >= closesAt) continue;
    const instanceId = `${t.id}@${new Date(opensAt).toISOString().slice(0, 10)}`;
    out.push({ trialId: t.id, instanceId, seed: hash(instanceId) % 1_000_000, opensAt, closesAt });
  }
  return out;
}
export const trialDef = (id: string) => TRIALS.find((t) => t.id === id);

/** Trial scoring by kind. Uses only verified run data. */
export function trialScore(def: TrialDef, r: RunReport): number {
  const c = r.claimed;
  switch (def.kind) {
    case "highScore":
    case "limitedMoves":
      return c.score;
    case "resonanceRush":
      return c.resonance;
    case "cascade":
      return c.bestCascade * 1000 + c.cascades * 10;
    case "portal":
      return (c.won ? 10000 : 0) + c.score - r.swaps.length * 50;
  }
}

/** Season trial points for a finishing position (feeds leagues). */
export function trialPoints(rank: number, of: number) {
  if (rank === 1) return 120;
  if (rank <= 3) return 90;
  if (rank <= 10) return 60;
  const pct = rank / Math.max(1, of);
  return pct <= 0.25 ? 35 : pct <= 0.5 ? 20 : 10;
}

export function trialRewardFor(def: TrialDef, rank: number, of: number) {
  for (const tier of def.rewards) {
    if (tier.top >= 1 ? rank <= tier.top : rank / Math.max(1, of) <= tier.top) return tier.reward;
  }
  return def.participation;
}
