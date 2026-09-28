// Gravity Shift + level masks. Mirrors the directive's acceptance test for the first task:
// normal match → Rotate Right → crystals move → cascades → refill → objectives → no dupes/overlaps
// → board state intact → rotate back.
import { test } from "node:test";
import assert from "node:assert/strict";
import { boardToRows, engineFromRows, findMatches, findValidMoves, get, hasValidMove, isVoid } from "../../game/board.ts";
import { LEVELS, playMove, playShift, startSession, type Session } from "../../game/level.ts";
import { rotatedGravity, shiftGravity, trySwap } from "../../game/resolve.ts";
import { createRng } from "../../game/rng.ts";
import type { Board, ResolveStep } from "../../game/types.ts";

const rng = () => createRng(9);
const HERO = LEVELS.find((l) => l.name === "Emerald Canyon")!;

function invariants(b: Board, label: string) {
  const ids = new Set<number>();
  for (let y = 0; y < b.height; y++)
    for (let x = 0; x < b.width; x++) {
      const c = get(b, x, y);
      if (isVoid(b, x, y)) assert.equal(c, null, `${label}: crystal inside void at ${x},${y}`);
      if (c) {
        assert.ok(!ids.has(c.id), `${label}: duplicated crystal ${c.id}`);
        ids.add(c.id);
      }
    }
  assert.equal(findMatches(b).length, 0, `${label}: board left with unresolved matches\n${boardToRows(b).join("\n")}`);
}

test("rotation order: left ← down → right, no further", () => {
  assert.equal(rotatedGravity("down", 1), "right");
  assert.equal(rotatedGravity("down", -1), "left");
  assert.equal(rotatedGravity("right", -1), "down");
  assert.equal(rotatedGravity("right", 1), null);
  assert.equal(rotatedGravity("left", -1), null);
});

test("gravity left: crystals slide left, refills enter from the right edge", () => {
  // row 0 has a gap at x=0; row 1 is full
  const s = engineFromRows([".123", "3412"], 5, rng());
  const r = shiftGravity(s, "left");
  assert.ok(r.valid);
  const fall = r.steps.find((x) => x.kind === "fall") as Extract<ResolveStep, { kind: "fall" }>;
  assert.equal(fall.moves.length, 3, "three crystals slid");
  assert.ok(fall.moves.every((m) => m.toX === m.fromX - 1 && m.toY === m.fromY));
  assert.equal(fall.spawned.length, 1);
  assert.equal(fall.spawned[0].x, 3);
  assert.ok(fall.spawned[0].fromX > 3, "spawn enters beyond the right edge");
});

test("voids are solid: crystals rest on them and never enter them", () => {
  // shifting right: row 1 has a void at x=0 that must stay empty; row 2's gap fills from the left edge
  const t = engineFromRows(["12", "#3", ".1"], 5, rng());
  const g = shiftGravity(t, "right");
  assert.ok(g.valid);
  invariants(g.state.board, "void");
  assert.equal(get(g.state.board, 0, 1), null, "void stays empty");
  const fall = g.steps.find((x) => x.kind === "fall") as Extract<ResolveStep, { kind: "fall" }>;
  assert.ok(fall.moves.every((m) => !(m.toX === 0 && m.toY === 1)), "nothing moved into the void");
  assert.ok(fall.spawned.some((c) => c.x === 0 && c.y === 2 && c.fromX < 0), "open cell refilled from the upstream (left) edge");
});

test("sheltered pockets stay empty under down-gravity and fill after a shift", () => {
  // column 1 sits under a void: nothing can enter it from the top edge
  const s = engineFromRows(["1#2", "3.4", "4.1", "213"], 5, rng());
  const down = shiftGravity({ ...s, gravity: "left" }, "down");
  assert.ok(down.valid);
  assert.equal(get(down.state.board, 1, 1), null, "sheltered cell not refilled from the top");
  assert.equal(get(down.state.board, 1, 2), null, "sheltered cell not refilled from the top");
  // turning the tabletop lets crystals pour sideways into the pocket and refills from the side
  const left = shiftGravity(down.state, "left");
  assert.ok(left.valid);
  assert.ok(get(left.state.board, 1, 1) && get(left.state.board, 1, 2), "pocket filled by the shift");
  invariants(left.state.board, "pocket");
});

test("hero level: mask respected, no initial matches, a move exists", () => {
  for (let seed = 1; seed < 80; seed++) {
    const ses = startSession(HERO, seed);
    invariants(ses.engine.board, `seed ${seed}`);
    assert.ok(hasValidMove(ses.engine.board), `seed ${seed} deadlocked`);
    assert.equal(ses.gravityCharges, 2);
  }
});

test("ACCEPTANCE: match → Rotate Right → resolve → objectives → rotate back", () => {
  let s: Session = startSession(HERO);
  // 1-2. normal match
  const [a, b] = findValidMoves(s.engine.board)[0];
  const m = playMove(s, a, b);
  assert.ok(m.valid);
  s = m.session;
  const collectedBefore = s.collected.slice();
  const playable = s.engine.board.void!.filter((v) => !v).length;
  // 3-4. rotate right: gravity changes, a charge is spent, no move is spent
  const r = playShift(s, 1);
  assert.ok(r.valid);
  assert.equal(r.gravity, "right");
  assert.equal(r.session.engine.gravity, "right");
  assert.equal(r.session.gravityCharges, 1);
  assert.equal(r.session.movesLeft, s.movesLeft);
  assert.equal(r.steps[0].kind, "gravity");
  // 5-7. crystals move toward the new gravity; any cascades resolve and holes refill where reachable
  const fall = r.steps.find((x) => x.kind === "fall") as Extract<ResolveStep, { kind: "fall" }>;
  for (const mv of fall.moves) assert.ok(mv.toX > mv.fromX && mv.toY === mv.fromY, "moves go right along rows");
  // 8. objectives still update from any cascade clears
  for (let i = 0; i < 5; i++) assert.ok(r.session.collected[i] >= collectedBefore[i]);
  // 9-11. no duplicates, no overlaps, nothing lost beyond cleared crystals
  invariants(r.session.engine.board, "after shift");
  const count = r.session.engine.board.cells.filter(Boolean).length;
  assert.ok(count <= playable && count >= playable * 0.5, `board keeps its crystals (${count}/${playable})`);
  // 13. rotate back to the original orientation
  const back = playShift(r.session, -1);
  assert.ok(back.valid);
  assert.equal(back.session.engine.gravity, "down");
  assert.equal(back.session.gravityCharges, 0);
  invariants(back.session.engine.board, "rotated back");
  // no charges left → further shifts refused
  assert.equal(playShift(back.session, -1).valid, false);
});

test("soak: 300 random moves and shifts on the hero board keep every invariant", () => {
  let s: Session = { ...startSession(HERO, 77), movesLeft: 9999 };
  const r = createRng(3);
  for (let i = 0; i < 300; i++) {
    s = { ...s, gravityCharges: 3, status: "playing" };
    if (r.state % 5 === 0) {
      const res = playShift(s, r.state % 2 ? 1 : -1);
      if (res.valid) s = res.session;
    } else {
      const moves = findValidMoves(s.engine.board);
      assert.ok(moves.length > 0, `deadlock at step ${i}\n${boardToRows(s.engine.board).join("\n")}`);
      const [a, b] = moves[r.state % moves.length];
      const res = playMove(s, a, b);
      assert.ok(res.valid);
      s = res.session;
    }
    r.state = (r.state * 1103515245 + 12345) >>> 0;
    invariants(s.engine.board, `step ${i}`);
  }
});
