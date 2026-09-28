// Pure game-logic types. Nothing in src/game may import React, Viro or any renderer.

/** Abstract crystal kinds. Visual identity lives in src/render. */
export const CRYSTAL_TYPES = ["RED", "BLUE", "GREEN", "PURPLE", "GOLD"] as const;
export type CrystalType = 0 | 1 | 2 | 3 | 4;

/**
 * none   – ordinary crystal
 * surgeH – from a horizontal 4-match; releases energy along its row
 * surgeV – from a vertical 4-match; releases energy along its column
 * prism  – from a 5-match (straight or L/T); consumes every crystal of one kind
 */
export type Special = "none" | "surgeH" | "surgeV" | "prism";

export interface Crystal {
  id: number;
  type: CrystalType;
  special: Special;
}

export interface Pos {
  x: number;
  y: number;
}

/** Row-major board. y = 0 is the far (top) row; crystals fall toward y = height - 1. */
export interface Board {
  width: number;
  height: number;
  cells: (Crystal | null)[];
  /** level mask: true = void (terrain gap). Voids never hold crystals and block falling. */
  void?: boolean[];
}

/** Direction crystals fall. "down" = toward row height-1 (the player). */
export type Gravity = "down" | "left" | "right";

export interface MatchGroup {
  cells: Pos[];
  type: CrystalType;
  /** longest straight run inside the group */
  longest: number;
  horizontal: boolean;
  vertical: boolean;
}

export interface ClearedCrystal extends Crystal, Pos {}

export interface CreatedSpecial extends Pos {
  id: number;
  special: Special;
  type: CrystalType;
}

export interface ActivatedSpecial extends Pos {
  id: number;
  special: Special;
  /** for prism activations: the kind that was consumed */
  targetType?: CrystalType;
}

export interface FallMove {
  id: number;
  fromX: number;
  fromY: number;
  toX: number;
  toY: number;
}

export interface Spawned extends Crystal, Pos {
  /** virtual cell beyond the upstream edge the crystal enters from */
  fromX: number;
  fromY: number;
}

export type ResolveStep =
  | { kind: "swap"; a: Pos; b: Pos; aId: number; bId: number }
  | { kind: "revert"; a: Pos; b: Pos; aId: number; bId: number }
  | {
      kind: "clear";
      cascade: number;
      groups: { size: number; longest: number; type: CrystalType }[];
      cleared: ClearedCrystal[];
      created: CreatedSpecial[];
      activated: ActivatedSpecial[];
      combo?: ComboKind;
      score: number;
    }
  | { kind: "fall"; moves: FallMove[]; spawned: Spawned[] }
  | { kind: "gravity"; from: Gravity; to: Gravity }
  | { kind: "shuffle"; placements: { id: number; x: number; y: number }[] };

export type ComboKind =
  | "surge+surge"
  | "prism+crystal"
  | "prism+surge"
  | "prism+prism";

export interface Rng {
  state: number;
}
