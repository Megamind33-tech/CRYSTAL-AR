// Backend API contracts. The client talks only to this interface; `mockBackend` implements it locally
// for development/offline, a real HTTP client implements it later. Server is authoritative for
// purchases, leaderboards, trials and time-limited events.
import type { LeaderboardRow } from "../meta/competition.ts";
import type { LeaderboardId, PlayerState, RunReport } from "../meta/types.ts";

export interface SignedRun {
  report: RunReport;
  /** placeholder until Play Integrity / server-issued run tokens exist */
  signature: string;
}

export interface SubmitRunResponse {
  accepted: boolean;
  reasons: string[];
  /** authoritative numbers (replayed) */
  truth?: { won: boolean; stars: number; score: number };
  trial?: { rank: number; of: number; points: number };
}

export interface LeaderboardResponse {
  id: LeaderboardId;
  total: number;
  podium: LeaderboardRow[];
  top10: LeaderboardRow[];
  me: LeaderboardRow | null;
  neighbours: LeaderboardRow[];
  updatedAt: number;
}

export interface Backend {
  /** create or resume a Keeper account */
  signIn(deviceId: string): Promise<{ keeperId: string; serverTime: number }>;
  /** push local progress; server merges and returns the canonical state */
  sync(state: PlayerState, pending: SignedRun[]): Promise<{ state: PlayerState; results: SubmitRunResponse[] }>;
  submitRun(run: SignedRun): Promise<SubmitRunResponse>;
  leaderboard(id: LeaderboardId, keeperId: string): Promise<LeaderboardResponse>;
  verifyPurchase(sku: string, receipt: string): Promise<{ valid: boolean; offerId?: string }>;
  /** remote config version – lets seasons/events/tournaments change without an app update */
  configVersion(): Promise<string>;
}

// ---- analytics -------------------------------------------------------------------------------------------
export type AnalyticsEvent =
  | "game_started" | "tutorial_started" | "tutorial_completed" | "island_started" | "island_completed" | "island_failed"
  | "portal_opened" | "collectible_received" | "lumin_rescued" | "relic_found" | "heart_shard_recovered" | "sanctuary_upgrade"
  | "daily_checkin" | "mission_completed" | "tournament_joined" | "tournament_completed" | "store_opened" | "purchase_started"
  | "purchase_completed" | "rewarded_ad_started" | "rewarded_ad_completed" | "season_level_up";

/** Only gameplay facts – no names, contacts, location or device identifiers beyond the pseudonymous keeperId. */
export type AnalyticsProps = Record<string, string | number | boolean>;

export interface AnalyticsSink {
  track(event: AnalyticsEvent, props?: AnalyticsProps): void;
}
