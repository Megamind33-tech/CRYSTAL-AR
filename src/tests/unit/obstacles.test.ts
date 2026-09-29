// Realm mechanics: covers (ice / vine / chain / ember), cracked stone, buried runes, Solar relics, creep.
import { test } from "node:test";
import assert from "node:assert/strict";
import { blockHp, createEngine, engineFromRows, findMatches, findValidMoves, floorHp, get, isSolid, type EngineState } from "../../game/board.ts";
import { playMove, startSession, type LevelDef, type Session } from "../../game/level.ts";
import { spreadCover, trySwap } from "../../game/resolve.ts";
import { createRng } from "../../game/rng.ts";
import type { CoverKind, ResolveStep } from "../../game/types.ts";

const rng = () => createRng(5);
const clears = (steps: ResolveStep[]) => steps.filter((s): s is Extract<ResolveStep, { kind: "clear" }> => s.kind === "clear");
function cover(s: EngineState, x: number, y: number, kind: CoverKind, hp: number) {
  const c = get(s.board, x, y)!;
  s.board.cells[y * s.board.width + x] = { ...c, cover: { kind, hp } };
}

test("a covered crystal is locked: it cannot be swapped", () => {
  const s = engineFromRows(["0120", "3401", "2310"], 5, rng());
  cover(s, 0, 0, "ice", 1);
  assert.equal(trySwap(s, { x: 0, y: 0 }, { x: 1, y: 0 }).valid, false);
  assert.ok(!findValidMoves(s.board).some(([a, b]) => (a.x === 0 && a.y === 0) || (b.x === 0 && b.y === 0)));
});

test("matching a covered crystal chips the cover and keeps the crystal", () => {
  // row 0: 0 0 _ 0 → swapping (3,1)=0 up into (2,0) makes 0000 across the ice-locked (0,0)
  const s = engineFromRows(["0010", "2303", "4121"], 5, rng());
  cover(s, 0, 0, "ice", 2);
  const id = get(s.board, 0, 0)!.id;
  const r = trySwap(s, { x: 2, y: 0 }, { x: 2, y: 1 });
  assert.ok(r.valid);
  const hit = clears(r.steps)[0].hits?.find((h) => h.layer === "cover");
  assert.deepEqual(hit && { x: hit.x, y: hit.y, hp: hit.hp, kind: hit.kind }, { x: 0, y: 0, hp: 1, kind: "ice" });
  assert.ok(!clears(r.steps)[0].cleared.some((c) => c.id === id), "the covered crystal was not cleared");
  const still = r.state.board.cells.find((c) => c?.id === id);
  assert.equal(still?.cover?.hp, 1);
  // the input state is untouched
  assert.equal(get(s.board, 0, 0)!.cover!.hp, 2);
});

test("cracked stone is solid, cracks from neighbouring matches, and opens when broken", () => {
  // stone at (1,2); the match on row 1 sits right above it
  const s = engineFromRows(["2340", "0010", "3S41", "4123"], 5, rng());
  assert.ok(isSolid(s.board, 1, 2));
  const r = trySwap(s, { x: 2, y: 0 }, { x: 2, y: 1 }); // 3↔1 … brings 0 row? verify a clear happens
  const valid = r.valid ? r : trySwap(s, { x: 3, y: 1 }, { x: 2, y: 1 });
  assert.ok(valid.valid, "some adjacent match exists");
  const stone = clears(valid.steps).flatMap((c) => c.hits ?? []).find((h) => h.layer === "block");
  assert.ok(stone, "the stone was hit");
  assert.equal(blockHp(valid.state.board, 1, 2), 0);
  assert.ok(get(valid.state.board, 1, 2), "broken stone cell refilled");
});

test("crystals rest on stone instead of falling through it", () => {
  const s = createEngine(6, 6, 5, createRng(11), undefined, undefined, { blocks: [[2, 3, 3]] });
  assert.equal(get(s.board, 2, 3), null);
  for (let i = 0; i < 30; i++) {
    const m = findValidMoves(s.board)[0];
    const r = trySwap(s, m[0], m[1]);
    Object.assign(s, r.state);
    if (blockHp(s.board, 2, 3) > 0) assert.equal(get(s.board, 2, 3), null, "nothing inside the stone");
  }
});

test("runes under a cleared crystal wear down", () => {
  const s = engineFromRows(["0010", "2303", "4121"], 5, rng());
  s.board.floor = new Array(12).fill(0);
  s.board.floor[1] = 2; // under (1,0)
  const r = trySwap(s, { x: 2, y: 0 }, { x: 2, y: 1 });
  assert.ok(r.valid);
  assert.equal(floorHp(r.state.board, 1, 0), 1);
  assert.equal(floorHp(s.board, 1, 0), 2, "input untouched");
});

test("relics never match, ride the fall, and leave at the bottom edge", () => {
  // relic above a column that clears: it drops to the bottom row and is collected
  // column 0 under the relic is 0,0 and a swap brings the third 0 in: the whole column clears
  const s = engineFromRows(["R12", "034", "041", "103"], 5, rng());
  assert.equal(findMatches(engineFromRows(["RRR", "123", "412"], 5, rng()).board).length, 0, "relics do not match");
  const r = trySwap(s, { x: 0, y: 3 }, { x: 1, y: 3 });
  assert.ok(r.valid);
  const got = r.steps.find((x) => x.kind === "relics");
  assert.ok(got, "relic collected");
  assert.ok(!r.state.board.cells.some((c) => c?.special === "relic"));
});

test("relic levels keep feeding relics until the total is reached", () => {
  const level: LevelDef = { id: 999, name: "t", seed: 3, moves: 400, objective: { kind: "relic", target: 3 }, setup: { relics: { total: 3, maxOnBoard: 1 } } };
  let ses: Session = startSession(level);
  assert.equal(ses.engine.board.cells.filter((c) => c?.special === "relic").length, 1);
  for (let i = 0; i < 400 && ses.status === "playing"; i++) {
    const moves = findValidMoves(ses.engine.board);
    // greedy: prefer moves under a relic's column
    const relicX = ses.engine.board.cells.findIndex((c) => c?.special === "relic") % 6;
    const m = moves.find(([a]) => a.x === relicX) ?? moves[i % moves.length];
    ses = playMove(ses, m[0], m[1]).session;
  }
  assert.equal(ses.tally.relic, 3);
  assert.equal(ses.status, "won");
});

test("embers creep when nothing quenches them, deterministically", () => {
  const s = createEngine(6, 6, 5, createRng(21), undefined, undefined, { covers: [[2, 2, "ember", 1]] });
  const a = spreadCover(s, "ember")!, b = spreadCover(s, "ember")!;
  assert.deepEqual(a.steps[0], b.steps[0]);
  const cell = (a.steps[0] as Extract<ResolveStep, { kind: "spread" }>).cells[0];
  assert.equal(Math.abs(cell.x - 2) + Math.abs(cell.y - 2), 1, "spread to a neighbour");
  assert.equal(a.state.board.cells.filter((c) => c?.cover?.kind === "ember").length, 2);
  assert.equal(s.board.cells.filter((c) => c?.cover?.kind === "ember").length, 1, "input untouched");
});

test("sessions count removed obstacles toward the objective", () => {
  const level: LevelDef = {
    id: 998, name: "t", seed: 8, moves: 60, objective: { kind: "cover", cover: "ice", target: 4 },
    setup: { covers: [[0, 5, "ice", 1], [1, 5, "ice", 1], [4, 5, "ice", 1], [5, 5, "ice", 1]] },
  };
  let ses = startSession(level);
  for (let i = 0; i < 60 && ses.status === "playing"; i++) {
    const moves = findValidMoves(ses.engine.board);
    const m = moves.find(([a, b]) => a.y >= 4 || b.y >= 4) ?? moves[0];
    ses = playMove(ses, m[0], m[1]).session;
  }
  assert.ok(ses.tally.cover.ice > 0, "some ice melted");
  assert.equal(ses.tally.cover.ice >= 4, ses.status === "won");
});

test("soak: 300 moves with every obstacle keep the board consistent", () => {
  const level: LevelDef = {
    id: 997, name: "t", seed: 13, moves: 9999, objective: { kind: "score", target: 1e9 },
    mask: ["OOOOOO", "OOXOOO", "OOOOOO", "OOOOXO", "OOOOOO", "OOOOOO"],
    setup: {
      blocks: [[0, 3, 2], [5, 1, 1]],
      floor: [[1, 5, 2], [2, 5, 1], [3, 4, 2]],
      covers: [[2, 0, "ice", 2], [3, 2, "chain", 1], [4, 4, "vine", 1], [1, 1, "ember", 1]],
      relics: { total: 4, maxOnBoard: 2 },
    },
    creep: { cover: "ember", every: 1 },
  };
  let ses = startSession(level);
  const r = createRng(99);
  for (let i = 0; i < 300; i++) {
    const moves = findValidMoves(ses.engine.board);
    assert.ok(moves.length, `deadlock at ${i}`);
    r.state = (r.state * 1103515245 + 12345) >>> 0;
    const m = moves[r.state % moves.length];
    const res = playMove(ses, m[0], m[1]);
    assert.ok(res.valid);
    ses = res.session;
    const b = ses.engine.board;
    const ids = new Set<number>();
    for (let k = 0; k < b.cells.length; k++) {
      const c = b.cells[k];
      const x = k % 6, y = Math.floor(k / 6);
      if (isSolid(b, x, y)) assert.equal(c, null, `crystal inside solid at ${x},${y}`);
      if (c) {
        assert.ok(!ids.has(c.id), "duplicate id");
        ids.add(c.id);
        if (c.cover) assert.ok(c.cover.hp > 0);
      }
    }
    assert.equal(findMatches(b).length, 0);
  }
});
