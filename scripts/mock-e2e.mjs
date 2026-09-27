// Level-3 test (DEV_AR_MOCK): boots the exported web build headless, places the world, taps a
// crystal through real Viro hit-testing, plays moves, and captures screenshots + a JSON report.
// Usage: node scripts/mock-e2e.mjs [baseUrl] [outDir]
import { mkdirSync, writeFileSync } from "node:fs";
import { launch, openPage } from "./mock-shot.mjs";

const base = process.argv[2] ?? "http://localhost:8090";
const outDir = process.argv[3] ?? "e2e-out";
mkdirSync(outDir, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const report = { steps: [], logs: [] };
const step = (name, pass, detail = "") => {
  report.steps.push({ name, pass, detail });
  console.log(`${pass ? "PASS" : "FAIL"}  ${name}${detail ? "  – " + detail : ""}`);
};

const browser = await launch();
try {
  const page = await openPage(browser, `${base}/play?level=0&autoplace=1&seed=1101`, report.logs);
  await page.waitForFunction(() => globalThis.__crystals?.gameStore.get().crystals.length === 36, { timeout: 60000 });
  step("boot + place world + 36 crystals", true);
  await sleep(2500);
  await page.screenshot({ path: `${outDir}/01-placed.png` });

  const st = () => page.evaluate(() => {
    const s = globalThis.__crystals.gameStore.get();
    return { selected: s.selected, moves: s.hud.movesLeft, score: s.hud.score, busy: s.busy, progress: s.progress, stage: s.stage, result: s.result, crystals: s.crystals.length, bursts: s.bursts.length, lastMatch: s.lastMatch, moveCount: s.moveCount };
  });

  // Every cell must be reachable by a real pointer tap at its projected screen position.
  const { w, h } = await page.evaluate(() => ({ w: innerWidth, h: innerHeight }));
  const screenOf = (x, y) => page.evaluate((x, y, w, h) => globalThis.__crystals.cellToScreen(x, y, w, h), x, y, w, h);
  const misses = [];
  for (let y = 0; y < 6; y++)
    for (let x = 0; x < 6; x++) {
      const [sx, sy] = await screenOf(x, y);
      await page.mouse.click(sx, sy);
      const sel = await page.evaluate(() => { const c = globalThis.__crystals.gameStore; const s = c.get().selected; c.set({ selected: null }); return s; });
      if (!sel || sel.x !== x || sel.y !== y) misses.push(x + ',' + y + '->' + JSON.stringify(sel));
    }
  step('every cell selectable by tap (36/36)', misses.length === 0, misses.join(' '));

  // Real input path: tap a crystal → selected.
  const t = await screenOf(2, 3);
  await page.mouse.click(t[0], t[1]);
  await sleep(200);
  let s0 = await st();
  step('tap selects the crystal under the finger', s0.selected?.x === 2 && s0.selected?.y === 3, JSON.stringify(s0.selected));
  await page.screenshot({ path: `${outDir}/02-selected.png` });
  await page.evaluate(() => globalThis.__crystals.gameStore.set({ selected: null }));

  // Swipe: press on a crystal that has a valid move, drag onto its partner, release.
  const move = await page.evaluate(() => {
    const c = globalThis.__crystals;
    return c.findValidMoves(c.gameStore.get().session.engine.board)[0];
  });
  const [ax, ay] = await screenOf(move[0].x, move[0].y);
  const [bx, by] = await screenOf(move[1].x, move[1].y);
  await page.mouse.move(ax, ay);
  await page.mouse.down();
  await page.mouse.move(bx, by, { steps: 6 });
  await page.mouse.up();
  await sleep(250);
  await page.screenshot({ path: `${outDir}/03-matching.png` });
  await page.waitForFunction(() => !globalThis.__crystals.gameStore.get().busy, { timeout: 15000 });
  let s = await st();
  step('swipe swap → match → refill', s.moveCount === 1 && s.crystals === 36, JSON.stringify({ move, moveCount: s.moveCount, score: s.score, last: s.lastMatch }));

  // Invalid swipe returns and costs nothing.
  const bad = await page.evaluate(() => {
    const c = globalThis.__crystals;
    const b = c.gameStore.get().session.engine.board;
    const ok = new Set(c.findValidMoves(b).map(([p, q]) => p.x + ',' + p.y + '-' + q.x + ',' + q.y));
    for (let y = 0; y < 6; y++) for (let x = 0; x < 5; x++) if (!ok.has(x + ',' + y + '-' + (x + 1) + ',' + y)) return [{ x, y }, { x: x + 1, y }];
    return null;
  });
  if (bad) {
    const [px, py] = await screenOf(bad[0].x, bad[0].y), [qx, qy] = await screenOf(bad[1].x, bad[1].y);
    await page.mouse.move(px, py); await page.mouse.down(); await page.mouse.move(qx, qy, { steps: 6 }); await page.mouse.up();
    await sleep(700);
    const s2 = await st();
    step('invalid swipe reverts without spending a move', s2.moveCount === 1 && s2.moves === s.moves, JSON.stringify({ bad, moves: s2.moves }));
  }

  // Play on through the controller (same code path after input) and capture the world evolving.
  for (let i = 0; i < 40 && !(await st()).result; i++) {
    await page.evaluate(async () => {
      const c = globalThis.__crystals;
      const [a, b] = c.findValidMoves(c.gameStore.get().session.engine.board)[0];
      await c.attemptSwap(a, b);
    });
    s = await st();
    if (i === 5) await page.screenshot({ path: `${outDir}/04-midgame.png` });
  }
  s = await st();
  step("level reaches an end state", !!s.result, JSON.stringify(s));
  await sleep(2200);
  await page.screenshot({ path: `${outDir}/05-result.png` });
  const errors = report.logs.filter((l) => /\[(error|pageerror)\]/.test(l));
  step("no runtime errors in console", errors.length === 0, errors.slice(0, 5).join(" | "));
} catch (e) {
  step("e2e run", false, String(e));
} finally {
  writeFileSync(`${outDir}/report.json`, JSON.stringify(report, null, 2));
  await browser.close();
}
process.exit(report.steps.every((x) => x.pass) ? 0 : 1);
