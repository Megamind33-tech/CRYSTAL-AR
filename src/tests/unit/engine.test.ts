import { test } from "node:test";
import assert from "node:assert/strict";
import {
  boardHash,
  boardToRows,
  createEngine,
  engineFromRows,
  findMatches,
  findValidMoves,
  get,
  hasValidMove,
  reshuffle,
  specialForGroup,
} from "../../game/board.ts";
import { trySwap } from "../../game/resolve.ts";
import { createRng } from "../../game/rng.ts";
import type { ResolveStep } from "../../game/types.ts";

const rng = () => createRng(42);
const clears = (steps: ResolveStep[]) => steps.filter((s) => s.kind === "clear") as Extract<ResolveStep, { kind: "clear" }>[];

test("horizontal match of 3 is found", () => {
  const s = engineFromRows(["000", "123", "231"], 5, rng());
  const g = findMatches(s.board);
  assert.equal(g.length, 1);
  assert.equal(g[0].cells.length, 3);
  assert.ok(g[0].horizontal && !g[0].vertical);
});

test("vertical match of 3 is found", () => {
  const s = engineFromRows(["012", "034", "021"], 5, rng());
  const g = findMatches(s.board);
  assert.equal(g.length, 1);
  assert.ok(g[0].vertical && !g[0].horizontal);
});

test("multiple separate matches are found", () => {
  const s = engineFromRows(["111", "234", "222"], 5, rng());
  assert.equal(findMatches(s.board).length, 2);
});

test("L shape merges into one group and yields prism", () => {
  const s = engineFromRows(["0123", "0234", "0004"], 5, rng());
  const g = findMatches(s.board);
  assert.equal(g.length, 1);
  assert.equal(g[0].cells.length, 5);
  assert.equal(specialForGroup(g[0]), "prism");
});

test("special kinds by match length", () => {
  const four = findMatches(engineFromRows(["00001", "12342"], 5, rng()).board)[0];
  assert.equal(specialForGroup(four), "surgeH");
  const fourV = findMatches(engineFromRows(["01", "02", "03", "04", "12"].map((r) => r), 5, rng()).board)[0];
  assert.equal(specialForGroup(fourV), "surgeV");
  const five = findMatches(engineFromRows(["00000", "12341"], 5, rng()).board)[0];
  assert.equal(specialForGroup(five), "prism");
  const three = findMatches(engineFromRows(["000", "123"], 5, rng()).board)[0];
  assert.equal(specialForGroup(three), "none");
});

test("generated boards never start with matches and always have a move", () => {
  for (let seed = 1; seed <= 300; seed++) {
    const s = createEngine(6, 6, 5, createRng(seed));
    assert.equal(findMatches(s.board).length, 0, `seed ${seed} has initial match`);
    assert.ok(hasValidMove(s.board), `seed ${seed} deadlocked`);
    assert.equal(s.board.cells.filter(Boolean).length, 36);
  }
});

test("generation is deterministic per seed", () => {
  assert.equal(boardHash(createEngine(6, 6, 5, createRng(7)).board), boardHash(createEngine(6, 6, 5, createRng(7)).board));
  assert.notEqual(boardHash(createEngine(6, 6, 5, createRng(7)).board), boardHash(createEngine(6, 6, 5, createRng(8)).board));
});

test("invalid swap reverts and does not mutate state", () => {
  const s = engineFromRows(["012", "340", "123"], 5, rng());
  const before = boardHash(s.board);
  const r = trySwap(s, { x: 0, y: 0 }, { x: 1, y: 0 });
  assert.equal(r.valid, false);
  assert.deepEqual(r.steps.map((x) => x.kind), ["swap", "revert"]);
  assert.equal(boardHash(r.state.board), before);
});

test("non-adjacent and out-of-bounds swaps are rejected with no steps", () => {
  const s = createEngine(6, 6, 5, rng());
  assert.equal(trySwap(s, { x: 0, y: 0 }, { x: 2, y: 0 }).steps.length, 0);
  assert.equal(trySwap(s, { x: 0, y: 0 }, { x: 1, y: 1 }).valid, false);
  assert.equal(trySwap(s, { x: 5, y: 5 }, { x: 6, y: 5 }).valid, false);
  assert.equal(trySwap(s, { x: 0, y: 0 }, { x: 0, y: -1 }).valid, false);
});

test("valid swap clears, drops and refills a full board", () => {
  // swapping (2,1)<->(2,0) forms a row of 0s on row 0
  const s = engineFromRows(["001", "230", "342", "412"], 5, rng());
  const r = trySwap(s, { x: 2, y: 0 }, { x: 2, y: 1 });
  assert.ok(r.valid);
  const c = clears(r.steps);
  assert.ok(c.length >= 1);
  assert.equal(c[0].cleared.length, 3);
  assert.ok(c[0].score > 0);
  assert.equal(r.state.board.cells.filter(Boolean).length, 12, "board refilled");
  assert.equal(findMatches(r.state.board).length, 0, "board stable after resolution");
  const fall = r.steps.find((x) => x.kind === "fall");
  assert.ok(fall && fall.kind === "fall" && fall.spawned.length === 3);
  for (const sp of fall.spawned) assert.ok(sp.fromY < 0);
});

test("crystals above a cleared row fall down one row", () => {
  const s = engineFromRows(["123", "231", "004", "410"], 5, rng());
  const r = trySwap(s, { x: 2, y: 2 }, { x: 2, y: 3 });
  assert.ok(r.valid);
  const fall = r.steps.find((x) => x.kind === "fall");
  assert.ok(fall && fall.kind === "fall");
  assert.equal(fall.moves.length, 6);
  assert.ok(fall.moves.every((m) => m.toY === m.fromY + 1));
});

test("cascades are numbered and later cascades score with a multiplier", () => {
  // clearing column 0 drops the top 2 onto row 3, forming 2-2-2
  const s = engineFromRows(["2134", "3041", "0413", "0224"], 5, rng());
  const r = trySwap(s, { x: 0, y: 1 }, { x: 1, y: 1 });
  assert.ok(r.valid);
  const c = clears(r.steps);
  assert.ok(c.length >= 2, "cascade happened");
  assert.equal(c[0].cascade, 1);
  assert.equal(c[1].cascade, 2);
  assert.ok(c[1].cleared.some((x) => x.y === 3 && x.type === 2));
  assert.equal(c[1].score % 2, 0);
});

test("4-match creates surge at swapped position", () => {
  const s = engineFromRows(["00102", "12033", "34343"], 5, rng());
  const r = trySwap(s, { x: 2, y: 0 }, { x: 2, y: 1 });
  assert.ok(r.valid);
  const c = clears(r.steps)[0];
  assert.equal(c.created.length, 1);
  assert.equal(c.created[0].special, "surgeH");
  assert.deepEqual([c.created[0].x, c.created[0].y], [2, 0]);
});

test("5-match creates prism", () => {
  const s = engineFromRows(["00100", "23043", "12121"], 5, rng());
  const r = trySwap(s, { x: 2, y: 0 }, { x: 2, y: 1 });
  assert.ok(r.valid);
  assert.equal(clears(r.steps)[0].created[0].special, "prism");
});

test("surge caught in a match clears its whole row", () => {
  const s = engineFromRows(["12042", "00301", "43214"], 5, rng());
  s.board.cells[5] = { ...s.board.cells[5]!, special: "surgeH" };
  const r = trySwap(s, { x: 2, y: 1 }, { x: 2, y: 0 });
  assert.ok(r.valid);
  const c = clears(r.steps)[0];
  assert.ok(c.activated.some((a) => a.special === "surgeH" && a.y === 1));
  assert.equal(c.cleared.filter((x) => x.y === 1).length, 5);
});

test("prism swapped with a crystal clears every crystal of that kind", () => {
  const s = engineFromRows(["P1203", "34141", "21302"], 5, rng());
  const r = trySwap(s, { x: 0, y: 0 }, { x: 1, y: 0 });
  assert.ok(r.valid);
  const c = clears(r.steps)[0];
  assert.equal(c.combo, "prism+crystal");
  assert.equal(c.cleared.filter((x) => x.type === 1 && x.special === "none").length, 4);
});

test("surge + surge combination fires a cross", () => {
  const s = engineFromRows(["12342", "34120", "21034", "43201"], 5, rng());
  s.board.cells[6] = { ...s.board.cells[6]!, special: "surgeH" }; // (1,1)
  s.board.cells[7] = { ...s.board.cells[7]!, special: "surgeV" }; // (2,1)
  const r = trySwap(s, { x: 1, y: 1 }, { x: 2, y: 1 });
  assert.ok(r.valid);
  const c = clears(r.steps)[0];
  assert.equal(c.combo, "surge+surge");
  assert.ok(c.cleared.length >= 5 + 4 - 1);
});

test("prism + prism clears the entire board", () => {
  const s = engineFromRows(["PP12", "3412", "2130"], 5, rng());
  const r = trySwap(s, { x: 0, y: 0 }, { x: 1, y: 0 });
  assert.equal(clears(r.steps)[0].cleared.length, 12);
  assert.equal(r.state.board.cells.filter(Boolean).length, 12);
});

test("deadlocked board is detected and reshuffle produces a playable board", () => {
  const s = engineFromRows(["012", "340", "123"], 5, rng());
  assert.equal(hasValidMove(s.board), false);
  const ids = s.board.cells.map((c) => c!.id).sort();
  const t = engineFromRows(["0120", "1201", "2012", "0120"], 3, rng());
  assert.equal(hasValidMove(t.board), false, "fixture is deadlocked");
  reshuffle(t);
  assert.equal(findMatches(t.board).length, 0);
  assert.ok(hasValidMove(t.board));
  void ids;
});

test("random play never leaves an unstable or deadlocked board", () => {
  let s = createEngine(6, 6, 5, createRng(99));
  const r = createRng(5);
  for (let i = 0; i < 400; i++) {
    const moves = findValidMoves(s.board);
    assert.ok(moves.length > 0, `deadlock at move ${i}\n${boardToRows(s.board).join("\n")}`);
    const [a, b] = moves[Math.floor((r.state = (r.state * 1103515245 + 12345) >>> 0) / 2 ** 32 * moves.length)];
    const res = trySwap(s, a, b);
    assert.ok(res.valid);
    s = res.state;
    assert.equal(findMatches(s.board).length, 0);
    assert.equal(s.board.cells.filter(Boolean).length, 36);
    const ids = new Set(s.board.cells.map((c) => c!.id));
    assert.equal(ids.size, 36, "crystal ids unique");
  }
});
