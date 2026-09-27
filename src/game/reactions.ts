import type { ResolveStep } from "./types.ts";

export type WorldEvent =
  | "MATCH_3"
  | "MATCH_4"
  | "MATCH_5"
  | "CASCADE_2"
  | "CASCADE_3"
  | "CASCADE_4_PLUS"
  | "SPECIAL_CREATED"
  | "SPECIAL_ACTIVATED"
  | "COMBO"
  | "LEVEL_COMPLETE";

/** Translates one clear step into the world events the diorama should react to. */
export function eventsForStep(step: ResolveStep): WorldEvent[] {
  if (step.kind !== "clear") return [];
  const ev: WorldEvent[] = [];
  const biggest = step.groups.reduce((m, g) => Math.max(m, g.longest, g.size >= 5 ? 5 : 0), 0);
  if (biggest >= 5) ev.push("MATCH_5");
  else if (biggest === 4) ev.push("MATCH_4");
  else if (biggest === 3) ev.push("MATCH_3");
  if (step.cascade === 2) ev.push("CASCADE_2");
  else if (step.cascade === 3) ev.push("CASCADE_3");
  else if (step.cascade >= 4) ev.push("CASCADE_4_PLUS");
  if (step.created.length) ev.push("SPECIAL_CREATED");
  if (step.activated.length) ev.push("SPECIAL_ACTIVATED");
  if (step.combo) ev.push("COMBO");
  return ev;
}

/** Forest Ruins evolution stage from objective progress (0..1). */
export type WorldStage = 0 | 1 | 2 | 3 | 4;
export function stageForProgress(p: number): WorldStage {
  if (p >= 1) return 4; // portal opens / celebration
  if (p >= 0.75) return 3; // portal strongly active
  if (p >= 0.5) return 2; // water & energy rise
  if (p >= 0.25) return 1; // plants awaken
  return 0; // portal dormant
}
