# Crystals AR

*Turn the real world into your puzzle board.*

Scan a table, tap it, and a miniature **Forest Ruins** diorama rises from the surface with a 6×6
crystal puzzle built into it. Swipe crystals to match; every match makes the world react — flowers
pulse and bloom, vines grow, the waterfall surges, shockwaves roll across the terrain and the portal
charges until it opens.

Android first (ARCore). Built on the ReactVision ViroReact Expo TypeScript starter.

## Layout

```
app/                 expo-router screens: menu (index), play, settings, dev/viro (renderer smoke test)
src/game/            pure match engine – no React/Viro (board, resolve, level, reactions, rng)
src/state/           controller that plays engine steps as timed view states; stores; persistence
src/render/          Viro scene: GameWorld, BoardView, CrystalNode, ForestWorld, layout math
src/ar/              production AR scene (plane selector → anchored world)
src/dev/             DEV_AR_MOCK scene, web picking, diagnostics overlay
src/audio/           expo-audio SFX pool + ambient loop, haptics
src/ui/              HUD, placement guide, pause, results, settings
scripts/             asset generators, web-mock server, headless e2e
src/tests/           unit (engine) + integration (controller/layout)
```

## Gameplay rules (v1)

- 6×6 board, 5 crystal kinds with distinct silhouettes: heart, diamond, leaf, spiral, star.
- Swap adjacent crystals; invalid swaps bounce back and cost nothing.
- 4 in a line → **Surge** crystal (clears its row/column when matched).
- 5 in a line or an L/T → **Prism** crystal (swap it with any crystal to clear every crystal of that kind).
- Combos: Surge+Surge = cross blast · Prism+Surge = every crystal of that kind becomes a Surge and fires · Prism+Prism = whole board.
- Boards never start with a match, always have a move, and reshuffle when deadlocked.
- Levels: *Waking Stones* (charge the portal), *Emerald Canopy* (gather leaf emeralds), *Heart of the Falls* (score).

## The wider game (meta layer)

The Prism Heart shattered into the Shattered Realms; you are a Keeper restoring them.

- **Loop**: enter an island → match to generate Resonance → open its portal → a Lumin, relic, Memory
  Crystal or Heart Shard emerges → return to the Sanctuary → upgrade, collect, compete → next realm.
- **Currencies**: Prism Dust (earned) and Aether Crystals (premium, also earnable). Heart Shards are never sold.
- **Systems**: Keeper levels with progressive feature unlocks, Sanctuary (idle Resonance, Lumin Grove,
  Heart Altar), Keeper Archive, Keeper's Return (streak with grace day + Streak Restores), Keeper Duties
  and Realm Missions, Chronicles (incl. hidden), relics with charges usable in play, Realm Trials on shared
  seeded boards, leagues (Stone → Celestial), 8 leaderboards, Season 01 *The Eclipse Realm* with a 40-tier
  Crystal Pass, data-driven events, Realm Exchange, Stabilize Portal recovery, rewarded-ad and payment
  abstractions, analytics hooks, offline queue, replay-verified anti-cheat.
- Everything is data in `src/meta/config/` and pure rules in `src/meta/`. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Quick start

See [BUILD.md](BUILD.md). Short version:

```bash
yarn install
yarn test                       # engine + controller tests
npx expo export -p web && node scripts/serve-dist.mjs   # DEV_AR_MOCK in a browser at :8090
npx expo prebuild -p android && cd android && ./gradlew assembleDebug   # real AR build
```

Status and evidence: [TEST_STATUS.md](TEST_STATUS.md). Licenses: [ASSET_LICENSES.md](ASSET_LICENSES.md), [DEPENDENCY_AUDIT.md](DEPENDENCY_AUDIT.md).
