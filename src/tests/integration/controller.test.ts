// Level 2/3 of the testing pyramid, headless: the same controller the renderers use,
// with the animation clock stubbed. Covers start → swap → match → cascade → win → restart.
import { test } from "node:test";
import assert from "node:assert/strict";
import { findValidMoves } from "../../game/board.ts";
import { LEVELS } from "../../game/level.ts";
import { boardToWorld, BOARD_SIZE, cellToLocal, localToCell, neighbourToward } from "../../render/layout.ts";
import { attemptSwap, gameEvents, gameStore, pressCell, releaseCell, restartLevel, setSleep, startLevel } from "../../state/game.ts";

setSleep(() => Promise.resolve());
const settle = () => new Promise((r) => setImmediate(r));

test("layout maps every cell to a unique, reversible board-local position", () => {
  const seen = new Set<string>();
  for (let y = 0; y < BOARD_SIZE; y++)
    for (let x = 0; x < BOARD_SIZE; x++) {
      const p = cellToLocal(x, y);
      seen.add(p.join());
      assert.deepEqual(localToCell(p[0], p[2]), { x, y });
    }
  assert.equal(seen.size, 36);
  assert.equal(localToCell(1, 1), null);
  // far row sits higher than near row after the tilt (board faces the player)
  assert.ok(boardToWorld(cellToLocal(0, 0))[1] > boardToWorld(cellToLocal(0, 5))[1]);
});

test("swipe resolution picks the adjacent neighbour along the dominant axis", () => {
  assert.deepEqual(neighbourToward({ x: 2, y: 2 }, { x: 5, y: 3 }), { x: 3, y: 2 });
  assert.deepEqual(neighbourToward({ x: 2, y: 2 }, { x: 2, y: 0 }), { x: 2, y: 1 });
  assert.equal(neighbourToward({ x: 2, y: 2 }, { x: 2, y: 2 }), null);
});

test("view model mirrors the engine board after every move", async () => {
  startLevel(0);
  for (let i = 0; i < 5; i++) {
    const s = gameStore.get();
    const [a, b] = findValidMoves(s.session!.engine.board)[0];
    await attemptSwap(a, b);
    const after = gameStore.get();
    const board = after.session!.engine.board;
    assert.equal(after.crystals.length, 36);
    for (const c of after.crystals) {
      assert.equal(board.cells[c.y * 6 + c.x]?.id, c.id, "renderer crystal sits on its logical cell");
    }
    assert.equal(after.busy, false);
  }
});

test("swipe via press + release performs a swap and emits audio events", async () => {
  startLevel(0);
  const sfx: string[] = [];
  const off = gameEvents.on((e) => e.type === "sfx" && sfx.push(e.name));
  const [a, b] = findValidMoves(gameStore.get().session!.engine.board)[0];
  pressCell(a);
  assert.deepEqual(gameStore.get().selected, a);
  releaseCell({ x: b.x + (b.x - a.x), y: b.y + (b.y - a.y) }); // overshoot: still resolves to the neighbour
  await settle();
  while (gameStore.get().busy) await settle();
  off();
  assert.equal(gameStore.get().moveCount, 1);
  assert.ok(sfx.includes("select") && sfx.includes("swap") && sfx.some((n) => n.startsWith("match")));
});

test("invalid swap reverts without spending a move", async () => {
  startLevel(0);
  const s = gameStore.get();
  const board = s.session!.engine.board;
  let pair: [{ x: number; y: number }, { x: number; y: number }] | null = null;
  const valid = new Set(findValidMoves(board).map(([p, q]) => `${p.x},${p.y}-${q.x},${q.y}`));
  for (let y = 0; y < 6 && !pair; y++)
    for (let x = 0; x < 5 && !pair; x++) if (!valid.has(`${x},${y}-${x + 1},${y}`)) pair = [{ x, y }, { x: x + 1, y }];
  assert.ok(pair);
  await attemptSwap(pair[0], pair[1]);
  assert.equal(gameStore.get().hud.movesLeft, LEVELS[0].moves);
  assert.equal(gameStore.get().moveCount, 0);
});

test("playing level 1 to completion wins, then restart resets", async () => {
  startLevel(0);
  let ended: { won: boolean } | null = null;
  const off = gameEvents.on((e) => {
    if (e.type === "levelEnd") ended = e;
  });
  // greedy bot: prefer moves that clear the most
  for (let guard = 0; guard < 60 && !gameStore.get().result; guard++) {
    const board = gameStore.get().session!.engine.board;
    const [a, b] = findValidMoves(board)[0];
    await attemptSwap(a, b);
  }
  off();
  const s = gameStore.get();
  assert.ok(s.result, "level reached an end state");
  assert.ok(ended);
  if (s.result!.won) {
    assert.equal(s.stage, 4, "world fully evolved on win");
    assert.ok(s.reactions.LEVEL_COMPLETE >= 1);
  }
  restartLevel();
  const r = gameStore.get();
  assert.equal(r.result, null);
  assert.equal(r.hud.score, 0);
  assert.equal(r.hud.movesLeft, LEVELS[0].moves);
  assert.equal(r.stage, 0);
});
