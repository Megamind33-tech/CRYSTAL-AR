// Island twists, secrets and stories: unpredictable per island, deterministic per run.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createEngine, findMatches, findValidMoves, isSolid } from "../../game/board.ts";
import { buildCampaign } from "../../game/campaign.ts";
import { playMove, startSession, type LevelDef, type Session } from "../../game/level.ts";
import { createRng } from "../../game/rng.ts";
import { applyTwist, revealsSecret, type TwistKind } from "../../game/twists.ts";

const KINDS: TwistKind[] = ["dragonFire", "frostBreath", "vineBloom", "rockfall", "lightning", "thief", "tremor", "blessing"];

test("every twist leaves a consistent, playable board", () => {
  for (const kind of KINDS)
    for (let seed = 1; seed < 25; seed++) {
      const s = createEngine(6, 6, 5, createRng(seed));
      const r = applyTwist(s, kind, 2);
      const b = r.state.board;
      assert.equal(findMatches(b).length, 0, `${kind}/${seed} left a match`);
      assert.ok(findValidMoves(b).length > 0, `${kind}/${seed} deadlocked`);
      const ids = new Set<number>();
      b.cells.forEach((c, i) => {
        if (isSolid(b, i % 6, Math.floor(i / 6))) assert.equal(c, null);
        if (c) {
          assert.ok(!ids.has(c.id));
          ids.add(c.id);
        }
      });
      assert.ok(s.board.cells.every((c) => !c?.cover), "input untouched");
    }
});

test("a twist fires exactly on its move and is announced", () => {
  const level: LevelDef = { id: 900, name: "t", seed: 5, moves: 30, objective: { kind: "score", target: 1e9 }, twists: [{ kind: "frostBreath", atMove: 3 }] };
  let s: Session = startSession(level);
  const announced: number[] = [];
  for (let i = 1; i <= 6; i++) {
    const [a, b] = findValidMoves(s.engine.board)[0];
    const r = playMove(s, a, b);
    if (r.steps.some((st) => st.kind === "twist")) announced.push(i);
    s = r.session;
  }
  assert.deepEqual(announced, [3]);
  assert.equal(s.twistsFired, 1);
});

test("blessing adds three moves", () => {
  const level: LevelDef = { id: 901, name: "t", seed: 5, moves: 30, objective: { kind: "score", target: 1e9 }, twists: [{ kind: "blessing", atMove: 1 }] };
  const s = startSession(level);
  const [a, b] = findValidMoves(s.engine.board)[0];
  assert.equal(playMove(s, a, b).session.movesLeft, 30 - 1 + 3);
});

test("secrets answer only their kind of clear", () => {
  const clear = (x: number, y: number, cascade: number, activated = 0, size = 3) => ({
    kind: "clear" as const, cascade, groups: [{ size, longest: size, type: 0 as const }], cleared: [{ id: 1, type: 0 as const, special: "none" as const, x, y }],
    created: [], activated: Array.from({ length: activated }, () => ({ id: 2, x: 0, y: 0, special: "surgeH" as const })), score: 0,
  });
  assert.ok(revealsSecret(clear(2, 3, 2), { x: 2, y: 3, need: "cascade" }));
  assert.ok(!revealsSecret(clear(2, 3, 1), { x: 2, y: 3, need: "cascade" }));
  assert.ok(!revealsSecret(clear(1, 3, 3), { x: 2, y: 3, need: "cascade" }));
  assert.ok(revealsSecret(clear(2, 3, 1, 1), { x: 2, y: 3, need: "special" }));
  assert.ok(revealsSecret(clear(2, 3, 1, 0, 5), { x: 2, y: 3, need: "five" }));
});

test("the campaign mixes twists, secrets and stories unpredictably", () => {
  const all = buildCampaign();
  const withTwist = all.filter((l) => l.twists?.length).length;
  const withSecret = all.filter((l) => l.secret).length;
  assert.ok(withTwist > 60 && withTwist < 190, `twists on ${withTwist} islands`);
  assert.ok(withSecret > 60 && withSecret < 130, `secrets on ${withSecret} islands`);
  assert.ok(all.slice(0, 4).every((l) => !l.twists), "the first islands are gentle");
  const kinds = new Set(all.flatMap((l) => l.twists?.map((t) => t.kind) ?? []));
  assert.equal(kinds.size, 8, "every twist appears somewhere");
  assert.ok(new Set(all.map((l) => l.story)).size > 150, "stories rarely repeat");
  for (const l of all) for (const t of l.twists ?? []) assert.ok(t.atMove >= 2 && t.atMove < l.moves, `level ${l.number} twist at ${t.atMove}/${l.moves}`);
});
