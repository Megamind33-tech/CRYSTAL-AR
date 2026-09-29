// New crystals must come out of a visible gate on the upstream edge (render/layout.ts spawnGate), not appear mid-air.
import { test } from "node:test";
import assert from "node:assert/strict";
import { BOARD_SIZE, spawnGate } from "../../render/layout.ts";
import { findValidMoves, set } from "../../game/board.ts";
import { LEVELS, startSession } from "../../game/level.ts";
import { shiftGravity, trySwap } from "../../game/resolve.ts";

test("gravity down: the gate is the row just above the board, in the crystal's own column", () => {
  // three crystals queued above column 2 fall into rows 0..2
  for (const y of [0, 1, 2]) {
    const g = spawnGate(2, y - 3, 2, y)!;
    assert.deepEqual([g.gx, g.gy], [2, -1]);
    assert.equal(g.len, 3);
    assert.equal(g.lead, 2 - y, `row ${y}: distance from the queue's start down to the gate`);
  }
});

test("the crystal nearest the edge starts AT the gate; deeper ones wait in the chute (lead)", () => {
  assert.equal(spawnGate(0, -1, 0, 0)!.lead, 0);
  assert.equal(spawnGate(0, -3, 0, 0)!.lead, 2);
  assert.equal(spawnGate(4, -7, 4, 3)!.lead, 6); // level-start entrance: 7 rows behind
});

test("gravity left/right: gates are the columns just outside the side edges", () => {
  const left = spawnGate(BOARD_SIZE + 2, 3, BOARD_SIZE - 1, 3)!; // falls toward -x, enters from the right edge
  assert.deepEqual([left.gx, left.gy], [BOARD_SIZE, 3]);
  const right = spawnGate(-2, 1, 0, 1)!;
  assert.deepEqual([right.gx, right.gy], [-1, 1]);
});

test("a crystal that appears in place (no flow) has no gate", () => {
  assert.equal(spawnGate(3, 2, 3, 2), null);
});

test("the timing budget is preserved: hidden time + visible time = the original fall", () => {
  for (const [fx, fy, x, y] of [[1, -5, 1, 2], [0, -1, 0, 0], [3, -7, 3, 5]] as const) {
    const g = spawnGate(fx, fy, x, y)!;
    const ms = 600, lead = Math.round((ms * g.lead) / g.len);
    assert.ok(lead >= 0 && lead <= ms);
    assert.equal(lead + (ms - lead), ms);
  }
});

test("every spawn the real engine produces enters through a gate just outside the board", () => {
  const level = LEVELS.find((l) => (l.gravityCharges ?? 0) > 0)!;
  const seen = { down: 0, left: 0, right: 0 };
  for (const seed of [3, 5, 8]) {
    // a real match under normal gravity
    const s0 = startSession(level, seed);
    const [a, b] = findValidMoves(s0.engine.board)[0];
    const played = trySwap(s0.engine, a, b);
    assert.ok(played.valid);
    // and a real Gravity Shift each way (down -> left, down -> right)
    // (open some gaps first: a full board has nothing to refill)
    const gappy = structuredClone(s0.engine);
    for (const [x, y] of [[1, 1], [2, 1], [4, 3], [3, 4], [0, 2]]) set(gappy.board, x, y, null);
    const shifts = (["left", "right"] as const).map((to) => shiftGravity(gappy, to));
    const runs = [{ g: "down" as const, steps: played.steps }, { g: "left" as const, steps: shifts[0].steps }, { g: "right" as const, steps: shifts[1].steps }];
    for (const run of runs) {
      for (const st of run.steps) {
        if (st.kind !== "fall") continue;
        for (const sp of st.spawned) {
          const g = spawnGate(sp.fromX, sp.fromY, sp.x, sp.y);
          assert.ok(g, `spawn (${sp.x},${sp.y}) from (${sp.fromX},${sp.fromY}) has no gate`);
          const outside = g.gx < 0 || g.gx >= BOARD_SIZE || g.gy < 0 || g.gy >= BOARD_SIZE;
          assert.ok(outside, `gate (${g.gx},${g.gy}) must lie just outside the board`);
          assert.ok(g.lead >= 0 && g.lead <= g.len, "lead within the path");
          // the gate is on the upstream edge for this gravity
          if (run.g === "left") assert.equal(g.gx, BOARD_SIZE);
          if (run.g === "right") assert.equal(g.gx, -1);
          if (run.g === "down") assert.equal(g.gy, -1);
          seen[run.g]++;
        }
      }
    }
  }
  assert.ok(seen.down > 0 && seen.left > 0 && seen.right > 0, `expected spawns under every gravity, saw ${JSON.stringify(seen)}`);
});
