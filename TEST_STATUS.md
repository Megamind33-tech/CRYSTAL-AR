# Test status

Last updated: 2026-09-27. Legend: PASS · FAIL · BLOCKED · NOT DEVICE VERIFIED

## Level 1 – unit (pure engine) · `yarn test`

20 tests, all PASS: horizontal / vertical / multiple / L-shape matches, special kinds by length,
300 seeds with no initial matches and ≥1 move, deterministic generation, invalid swap reverts without
mutation, bounds/adjacency rejection, clear + gravity + refill, cascade numbering and multiplier,
Surge / Prism creation, Surge row clear, Prism+crystal, Surge+Surge cross, Prism+Prism board clear,
deadlock detection + reshuffle, 400-move random soak (never unstable, deadlocked, or duplicate ids).

## Level 1b – meta-game rules · `yarn test`

21 tests, all PASS (`src/tests/unit/meta.test.ts`): new-Keeper gating, level curve, first-restore vs replay rewards,
lost runs grant nothing, Heart Shards story-only and never sold, duplicate conversion + relic set bonus,
Keeper Duties roll/progress/claim/Keeper's Cache, Keeper's Return streak + grace + Streak Restore +
milestones, Sanctuary costs/idle cap/Lumin Grove/evolution, relic charges + ranked restriction,
achievements incl. hidden, discovery portal unlock, anti-cheat (replay, tamper, speed, duplicate run id,
bad signature), Realm Trials (shared seed, ranking, debug builds unranked), leaderboard windows and
purchases never affecting rank, Crystal Pass gating + receipt idempotency, Realm Exchange limits,
Stabilize Portal limits, Keeper Briefing, Archive, quest prerequisites, boost-log replay (stabilize,
relic +moves, relic reshuffle; forged boosts rejected). Real games are played by a bot, not faked.

## Level 2 – integration (controller + layout) · `yarn test`

6 tests, all PASS: cell↔board-local mapping is unique and reversible and the far row sits higher
(tilt), swipe neighbour resolution, renderer view model matches engine board after every move,
press+release swipe emits select/swap/match audio events, invalid swap costs no move, full level
played to an end state then restart resets.

## Level 3 – mock gameplay (DEV_AR_MOCK, real Viro renderer in headless Edge) · `scripts/mock-e2e.mjs`

Latest run: 16/18 PASS on the static web export; the 2 failures were case-sensitive text checks in the
test itself (fixed). Covered:
boot + place world + 36 crystals · idle hint · pause/resume via UI · 36/36 cells selectable by real
pointer taps · tap selects crystal under finger · swipe → match → cascade → refill · invalid swipe
reverts free · level reaches an end state (win, stage 4 world)
· Keeper save records the restored island + rescued Lumin · home offers the next island ·
Realms, Sanctuary, Archive, Profile, Duties, Trials, Crystal Pass and Realm Exchange render from real state ·
no console errors.

Known web-mock-only issues (do not affect Android):
- Viro web renderer 1.0.0 mis-unprojects touch Y, so the web mock picks cells in JS
  (`src/dev/mockPicking.ts`); Android uses Viro's native `onClickState`.
- Web renderer draws a small gaze reticle at screen centre; skybox colour and `fieldOfView` are ignored.

## Level 4 – native Android build

See bottom of this file for the latest result.

## Level 5 – physical AR device: **NOT DEVICE VERIFIED**

No ARCore phone was available to the agent (the Viro renderer has no x86_64 libs, so emulators can't
run it). Nothing about real AR — plane detection, anchoring, drift, touch hit-testing, FPS — has been
observed yet.

### Device test script

Setup: ARCore-supported arm64 phone, USB debugging on.

```bash
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
npx expo start --dev-client            # debug APK loads JS from Metro
adb logcat -s ReactNativeJS | grep CrystalsAR
```

Turn on Settings › Diagnostics before starting. Record device model, Android version, build commit.

| # | Step | Expected | Record |
|---|---|---|---|
| 1 | Cold launch | Title "CRYSTALS AR", PLAY / SETTINGS, no red box | pass/fail |
| 2 | PLAY, grant camera | Camera feed, "Find a table or floor" card, pulsing reticle | time to camera |
| 3 | Sweep phone over a textured table | Glowing overlay appears; log `planeFound` | seconds to first plane |
| 4 | Tap overlay | Place chime; diorama grows from the table facing you; log `placed` with yaw | scale ok? faces you? |
| 5 | Walk around 1 m, return | World stays on the table (note drift in cm) | drift, tracking state |
| 6 | Tap a crystal | Lifts + spins, cell glows, select chime, light haptic | hit accuracy |
| 7 | Swipe crystal to a neighbour that matches | Swap, match chime, sparks, refill; flowers pulse | latency feel |
| 8 | Swipe to a non-matching neighbour | Bounces back, low tone, moves unchanged | |
| 9 | Make a 4-match / 5-match | Surge (gold ring) / Prism (rainbow) forged | |
| 10 | Pause › Reset World Position, re-tap | Board keeps state; crystals re-rise | |
| 11 | Win level 1 | Portal opens, shockwave, fanfare, result card; NEXT LEVEL works | |
| 12 | Kill + relaunch app | Waking Stones restored, Mossling in Archive, Emerald Canopy enterable | |
| 13 | Diagnostics overlay during play | Note js-fps, tracking, planes; watch for `error` lines | FPS, errors |

Also note: lighting match with the room, whether planes merge and cause `planeRemoved selected:true`
(world would need re-placing), and any crash (`adb logcat *:E`).

## Native build log

- 2026-09-27: `./gradlew assembleDebug` **BUILD SUCCESSFUL** (arm64-v8a, 101 MB). APK contains
  libviro_renderer / libviro_arcore / libarcore_sdk_c / Hermes. Required: OS trust store for the JVM and the
  oversized RN/Hermes AARs pre-fetched into ~/.m2 (`CRYSTALS_MAVEN_LOCAL=1`), see BUILD.md.
- Not yet installed on any device.
