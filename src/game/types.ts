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
export type Special = "none" | "surgeH" | "surgeV" | "prism" | "relic";

/**
 * Covers ride on a crystal (they fall with it). A covered crystal cannot be swapped; a match or
 * special that includes it chips one layer off the cover instead of clearing the crystal.
 *   ice   – Tide Grotto / Frozen Verge
 *   vine  – Mushroom Hollow; creeps onto a neighbour every 2 moves in which no vine was cut
 *   chain – Frozen Verge
 *   ember – Ember Deep; spreads every move in which no ember was quenched
 */
export type CoverKind = "ice" | "vine" | "chain" | "ember";
export interface Cover {
  kind: CoverKind;
  hp: number;
}

export interface Crystal {
  id: number;
  type: CrystalType;
  special: Special;
  cover?: Cover;
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
  /** cracked stone: hit points per cell (0 = none). Solid like a void until broken by adjacent matches. */
  block?: number[];
  /** buried runes: layers under a cell (0 = none), worn down each time a crystal clears on top. */
  floor?: number[];
}

/** Damage dealt to an obstacle during a clear step (hp = what remains). */
export interface ObstacleHit extends Pos {
  layer: "cover" | "block" | "floor";
  kind: CoverKind | "stone" | "rune";
  hp: number;
  /** crystal id for cover hits */
  id?: number;
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
      /** obstacles damaged by this clear (covers chipped, stones cracked, runes worn) */
      hits?: ObstacleHit[];
    }
  | { kind: "fall"; moves: FallMove[]; spawned: Spawned[] }
  /** relics that reached the downstream edge and left the board */
  | { kind: "relics"; collected: { id: number; x: number; y: number }[] }
  /** embers / vines creeping onto neighbouring crystals (also: frost, fire and vines from twists) */
  | { kind: "spread"; cells: { id: number; x: number; y: number; cover: CoverKind }[] }
  /** a hidden island twist strikes (announcement; its effects follow as ordinary steps) */
  | { kind: "twist"; twist: string; moves?: number }
  /** rocks crash down: these crystals become cracked stone */
  | { kind: "blocks"; cells: { id: number; x: number; y: number; hp: number }[] }
  /** lightning turns crystals into surges */
  | { kind: "empower"; cells: { id: number; x: number; y: number; special: "surgeH" | "surgeV" }[] }
  /** a crystal thief snatches these crystals */
  | { kind: "steal"; cells: { id: number; x: number; y: number }[] }
  /** the island's buried secret was found */
  | { kind: "secret"; x: number; y: number }
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
