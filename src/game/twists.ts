// Island twists and secrets: hidden, seeded events that make every island its own challenge.
// Twists fire at an unannounced move and change the board (a dragon scorches a row, frost locks
// crystals, rocks fall…). Secrets are buried in one cell and only answer a particular kind of clear.
// Everything is deterministic in (level, player moves) so runs stay replay-verifiable.
import { cloneState, hasValidMove, reshuffle, type EngineState } from "./board.ts";
import { refillAfterRemoval, shiftGravity } from "./resolve.ts";
import { createRng, nextFloat, nextInt } from "./rng.ts";
import type { CoverKind, CrystalType, ResolveStep, Rng } from "./types.ts";

export type TwistKind = "dragonFire" | "frostBreath" | "vineBloom" | "rockfall" | "lightning" | "thief" | "tremor" | "blessing";

export interface Twist {
  kind: TwistKind;
  /** fires right after the player's Nth move */
  atMove: number;
}

export type SecretNeed = "cascade" | "special" | "five";
export interface Secret {
  x: number;
  y: number;
  need: SecretNeed;
}

/** Player-facing line shown when a twist strikes. */
export const TWIST_TEXT: Record<TwistKind, string> = {
  dragonFire: "A dragon passes overhead — fire rains on the stones!",
  frostBreath: "A freezing wind sweeps the island.",
  vineBloom: "The vines stir and reach for the crystals.",
  rockfall: "The ruins shudder. Rocks crash onto the board!",
  lightning: "Lightning strikes — crystals surge with power!",
  thief: "Something small and quick steals from the board…",
  tremor: "The island lurches. Gravity shifts!",
  blessing: "The island remembers you. +3 moves.",
};

/** Which twists each realm can throw at the player. */
const POOLS: Record<string, TwistKind[]> = {
  verdant: ["lightning", "vineBloom", "blessing", "thief", "rockfall"],
  canyon: ["tremor", "rockfall", "lightning", "thief"],
  tide: ["frostBreath", "tremor", "blessing", "thief"],
  sky: ["rockfall", "lightning", "tremor", "dragonFire"],
  hollow: ["vineBloom", "thief", "blessing", "lightning"],
  caverns: ["rockfall", "thief", "lightning", "frostBreath"],
  frozen: ["frostBreath", "rockfall", "blessing", "dragonFire"],
  solar: ["tremor", "lightning", "dragonFire", "blessing"],
  ember: ["dragonFire", "rockfall", "lightning", "thief"],
  void: ["dragonFire", "frostBreath", "vineBloom", "rockfall", "lightning", "thief", "tremor", "blessing"],
};

/**
 * Plans an island's hidden twists and secret. Early islands are gentle; later ones may hold two
 * twists. Roughly 45% of islands hide a secret — and nothing tells the player which ones.
 */
export function planIsland(seed: number, realm: string, realmIndex: number, step: number, moves: number): { twists: Twist[]; secret?: Secret } {
  const r = createRng((seed * 2246822519) ^ 0x7f4a7c15);
  const d = step / 19;
  const twists: Twist[] = [];
  const pool = POOLS[realm] ?? POOLS.verdant;
  const gentle = realmIndex === 0 && step < 4;
  if (!gentle && nextFloat(r) < 0.4 + 0.35 * d + realmIndex * 0.02) {
    twists.push({ kind: pool[nextInt(r, pool.length)], atMove: Math.max(2, Math.round(moves * (0.2 + nextFloat(r) * 0.35))) });
    if (realmIndex >= 3 && nextFloat(r) < 0.15 + 0.3 * d) {
      const kind = pool[nextInt(r, pool.length)];
      const at = Math.round(moves * (0.6 + nextFloat(r) * 0.2));
      if (at > twists[0].atMove + 1) twists.push({ kind, atMove: at });
    }
  }
  const secret = nextFloat(r) < 0.45 ? { x: nextInt(r, 6), y: nextInt(r, 6), need: (["cascade", "special", "five"] as SecretNeed[])[nextInt(r, 3)] } : undefined;
  return { twists, ...(secret ? { secret } : {}) };
}

const freeCrystals = (s: EngineState) => {
  const out: number[] = [];
  s.board.cells.forEach((c, i) => {
    if (c && !c.cover && c.special === "none") out.push(i);
  });
  return out;
};

function pick<T>(r: Rng, xs: T[], n: number): T[] {
  const a = xs.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = nextInt(r, i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a.slice(0, n);
}

/**
 * Applies a twist to the board. Never mutates the input. `target` is the objective's crystal kind
 * (the thief goes for it). Blessing has no board effect; the session adds the moves.
 */
export function applyTwist(input: EngineState, kind: TwistKind, target?: CrystalType): { state: EngineState; steps: ResolveStep[] } {
  if (kind === "tremor") {
    const to = input.gravity === "down" ? (nextFloat(createRng(input.rng.state)) < 0.5 ? "left" : "right") : "down";
    const r = shiftGravity(input, to);
    return { state: r.state, steps: r.steps };
  }
  const s = cloneState(input);
  const b = s.board;
  const steps: ResolveStep[] = [];
  const cover = (idxs: number[], k: CoverKind) => {
    const cells = idxs.map((i) => {
      const c = b.cells[i]!;
      b.cells[i] = { ...c, cover: { kind: k, hp: 1 } };
      return { id: c.id, x: i % b.width, y: Math.floor(i / b.width), cover: k };
    });
    if (cells.length) steps.push({ kind: "spread", cells });
  };
  switch (kind) {
    case "dragonFire": {
      // a line of fire across one row
      const rows = [1, 2, 3, 4].filter((y) => freeCrystals(s).some((i) => Math.floor(i / b.width) === y));
      const y = rows.length ? rows[nextInt(s.rng, rows.length)] : 2;
      const start = nextInt(s.rng, 3);
      cover(freeCrystals(s).filter((i) => Math.floor(i / b.width) === y && i % b.width >= start && i % b.width < start + 4), "ember");
      break;
    }
    case "frostBreath":
      cover(pick(s.rng, freeCrystals(s), 4), "ice");
      break;
    case "vineBloom":
      cover(pick(s.rng, freeCrystals(s), 3), "vine");
      break;
    case "lightning": {
      const cells = pick(s.rng, freeCrystals(s), 2).map((i, k) => {
        const c = b.cells[i]!;
        const special = k % 2 ? "surgeV" : "surgeH";
        b.cells[i] = { ...c, special };
        return { id: c.id, x: i % b.width, y: Math.floor(i / b.width), special: special as "surgeH" | "surgeV" };
      });
      steps.push({ kind: "empower", cells });
      break;
    }
    case "rockfall": {
      const spots = pick(s.rng, freeCrystals(s).filter((i) => {
        const y = Math.floor(i / b.width);
        return y >= 1 && y <= 3;
      }), 2);
      if (!b.block) b.block = new Array(b.width * b.height).fill(0);
      const cells = spots.map((i) => {
        const c = b.cells[i]!;
        b.cells[i] = null;
        b.block![i] = 1;
        return { id: c.id, x: i % b.width, y: Math.floor(i / b.width), hp: 1 };
      });
      steps.push({ kind: "blocks", cells });
      break;
    }
    case "thief": {
      const kinds = target ?? (nextInt(s.rng, s.typeCount) as CrystalType);
      const loot = pick(s.rng, freeCrystals(s).filter((i) => b.cells[i]!.type === kinds), 3);
      const cells = loot.map((i) => {
        const c = b.cells[i]!;
        b.cells[i] = null;
        return { id: c.id, x: i % b.width, y: Math.floor(i / b.width) };
      });
      steps.push({ kind: "steal", cells });
      refillAfterRemoval(s, steps);
      break;
    }
    case "blessing":
      break;
  }
  if (!hasValidMove(b)) steps.push({ kind: "shuffle", placements: reshuffle(s) });
  return { state: s, steps };
}

/** Does this clear step uncover the island's secret? */
export function revealsSecret(step: ResolveStep, secret: Secret): boolean {
  if (step.kind !== "clear") return false;
  if (!step.cleared.some((c) => c.x === secret.x && c.y === secret.y)) return false;
  if (secret.need === "cascade") return step.cascade >= 2;
  if (secret.need === "special") return step.activated.length > 0;
  return step.groups.some((g) => g.size >= 5) || step.created.some((c) => c.special === "prism");
}
