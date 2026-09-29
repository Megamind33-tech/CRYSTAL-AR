// KEEPER RANK: a record of mastery across the whole game, not of hours played.
// Eight dimensions each score 0–1 on a saturating curve; the weighted total picks the rank, and the
// upper ranks also demand breadth (several dimensions strong at once), so no single activity – XP,
// grinding one island, or tournaments alone – can carry a Keeper to the top.
// PvP, Colonies and bosses will feed the "competition" and "craft" dimensions when they arrive.
import { LUMINS, RELICS } from "./config/collection.ts";
import { ISLANDS } from "./config/world.ts";
import { levelOf } from "./core.ts";
import { MAX_KEEPER_LEVEL } from "./config/progression.ts";
import type { PlayerState } from "./types.ts";

export const RANKS = ["Seeker", "Pathfinder", "Warden", "Rift Keeper", "Crystal Guardian", "Realm Keeper", "Ascendant", "Eternal Keeper"] as const;
export type RankName = (typeof RANKS)[number];

export type Dimension = "story" | "mastery" | "discovery" | "collection" | "competition" | "dedication" | "craft" | "experience";

export const DIMENSION_LABEL: Record<Dimension, string> = {
  story: "Islands restored",
  mastery: "Stars earned",
  discovery: "Secrets & Heart Shards",
  collection: "Lumins & relics",
  competition: "Trials & battles",
  dedication: "Duties & returns",
  craft: "Crystal craft",
  experience: "Keeper experience",
};

const WEIGHT: Record<Dimension, number> = {
  story: 0.2, mastery: 0.12, discovery: 0.14, collection: 0.12, competition: 0.14, dedication: 0.08, craft: 0.12, experience: 0.08,
};

/** Total needed for each rank. */
const THRESHOLD = [0, 0.04, 0.1, 0.2, 0.33, 0.48, 0.66, 0.85];
/** Breadth gates: [how many dimensions, at what level] each upper rank also requires. */
const BREADTH: Record<number, [number, number]> = { 4: [3, 0.3], 5: [4, 0.45], 6: [5, 0.6], 7: [7, 0.8] };

/** 0 → 0, `full` → ~0.95, never quite 1 by volume alone. */
const sat = (v: number, full: number) => 1 - Math.exp((-3 * Math.max(0, v)) / full);

const CAMPAIGN_ISLANDS = ISLANDS.filter((i) => i.portal === "story").length;
const SECRET_ISLANDS = 90;

export function rankDimensions(s: PlayerState): Record<Dimension, number> {
  const st = s.stats;
  const restored = Object.keys(s.islands).length;
  const stars = Object.values(s.islands).reduce((a, i) => a + i.stars, 0);
  return {
    story: sat(restored, CAMPAIGN_ISLANDS),
    mastery: sat(stars, CAMPAIGN_ISLANDS * 3),
    discovery: 0.5 * sat((s.secrets ?? []).length, SECRET_ISLANDS) + 0.35 * sat(s.heartShards.length, 11) + 0.15 * sat(s.memories.length, 12),
    collection: 0.6 * sat(Object.keys(s.lumins).length, LUMINS.length) + 0.4 * sat(Object.keys(s.relics).length, RELICS.length),
    competition: 0.5 * sat(st.trialPoints ?? 0, 4000) + 0.5 * sat(st.trialsWon ?? 0, 40),
    dedication: 0.5 * sat(st.checkins ?? 0, 150) + 0.5 * sat(st.dutiesCompleted ?? 0, 400),
    craft: (sat(st.bestCascade ?? 0, 9) + sat(st.combos ?? 0, 400) + sat(st.specialsActivated ?? 0, 2500)) / 3,
    experience: sat(levelOf(s), MAX_KEEPER_LEVEL),
  };
}

export interface KeeperRank {
  index: number;
  name: RankName;
  /** weighted total 0..1 */
  score: number;
  dimensions: Record<Dimension, number>;
  /** what stands between the Keeper and the next rank (empty at the top) */
  next: string;
}

export function keeperRank(s: PlayerState): KeeperRank {
  const d = rankDimensions(s);
  const score = (Object.keys(WEIGHT) as Dimension[]).reduce((a, k) => a + WEIGHT[k] * d[k], 0);
  const meetsBreadth = (r: number) => {
    const g = BREADTH[r];
    return !g || Object.values(d).filter((v) => v >= g[1]).length >= g[0];
  };
  let index = 0;
  for (let r = 1; r < RANKS.length; r++) if (score >= THRESHOLD[r] && meetsBreadth(r)) index = r;
  let next = "";
  if (index < RANKS.length - 1) {
    const r = index + 1;
    const need = THRESHOLD[r] - score;
    const g = BREADTH[r];
    if (need > 0) {
      const weakest = (Object.keys(d) as Dimension[]).sort((a, b) => d[a] * WEIGHT[a] - d[b] * WEIGHT[b])[0];
      next = `${RANKS[r]}: ${Math.ceil(need * 100)}% more mastery — ${DIMENSION_LABEL[weakest].toLowerCase()} would help most.`;
    } else if (g) {
      next = `${RANKS[r]}: be strong (${Math.round(g[1] * 100)}%+) in ${g[0]} different paths.`;
    }
  }
  return { index, name: RANKS[index], score, dimensions: d, next };
}
