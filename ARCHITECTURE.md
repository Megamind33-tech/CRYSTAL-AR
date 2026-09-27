# Architecture

```
            ┌──────────── AR / mock render (Viro) ────────────┐
 swipe ───► │ BoardView · CrystalNode · ForestWorld · GameWorld │
            └───────────────▲──────────────────────────────────┘
                            │ view state
 src/game (pure engine) ◄── src/state/game.ts (controller: plays steps, records the run)
                            │ levelEnd { seed, swaps, stats }
                            ▼
 src/state/meta.ts ── replayRun() ──► applyRun() ──► PlayerState ──► AsyncStorage
        │                                  (src/meta: pure reducers over config)
        └─► offline queue ──► Backend (src/backend/contracts.ts; mockBackend today)
```

## Layers

| Layer | Path | Rule |
|---|---|---|
| Match engine | `src/game/` | Pure, deterministic, seeded. The source of truth for scores. |
| Meta config | `src/meta/config/` | Data only, stable IDs. Designed to arrive from remote config later. |
| Meta rules | `src/meta/*.ts` | Pure `(state, input, now) → state` reducers. Same code for client and server. |
| Backend contract | `src/backend/contracts.ts` | The only API the app calls. `mockBackend.ts` implements it locally. |
| App state | `src/state/` | Stores, persistence, analytics, event bridges. |
| UI | `app/`, `src/ui/` | Reads stores, calls reducers via `act()`. No game rules in screens. |

## Meta-game model (Shattered Realms)

- **Currencies**: Prism Dust (earned), Aether Crystals (premium; earnable slowly). Everything else is an item
  (Relic Charge, Portal Fragment, Lumin Food, Sanctuary Stone, Streak Restore, Keeper's Cache, Star Key).
- **Collectibles**: Heart Shards (story only, never sold), Lumins (5 rarities, evolutions, Sanctuary
  bonuses), Relics (gameplay effects with regenerating charges; trial approval flags), Memory Crystals (lore).
- **Portals**: story (always free), discovery (Portal Fragments / Star Keys), expedition (time-limited
  signal, Aether via the Realm Exchange).
- **One event stream**: `recordEvent(MetaEvent)` updates stats; quests, duties, missions, achievements and
  leaderboards all read from stats — no UI text is disconnected from state.
- **Progressive reveal**: `FEATURE_UNLOCKS` gates Sanctuary (2), Duties (3), Archive (4), Chronicles (5),
  Rankings (6), Trials (7), Season/Exchange (8). The home screen shows only unlocked destinations.
- **Keeper Briefing**: `keeperBriefing()` ranks what's waiting into one list — no launch pop-ups.

## Fair competition & anti-cheat

- Runs carry `runId, seed, gameVersion, timestamps, swap list, relics, stabilizations`.
- `replayRun()` re-simulates the run and must reproduce every claimed number; impossible speed, too many
  swaps and mismatches are rejected. `verifyTrialRun()` adds trial seed/window/relic/time-limit rules and
  marks debug/emulator builds unranked.
- Duplicate run IDs and replayed receipts are rejected by the backend.
- **Local verification is not security.** `mockSign` is a placeholder; the real server must hold the key,
  add Play Integrity attestation, and be the only writer of leaderboards, trials and purchases.
- Keeper score and leagues use play only; purchases never contribute.

## Backend dependencies (not built yet)

Account/auth, cloud save merge, run submission + replay service, leaderboards, trial scheduling, receipt
verification (Google Play Developer API), remote config for seasons/events/trials, push notifications,
analytics ingestion. All are behind `Backend` / `PaymentProvider` / `AdProvider` / `AnalyticsSink`.

## Android integration points

- `expo-audio`, `expo-haptics`, AsyncStorage are the only native modules added.
- Purchases: implement `PaymentProvider` with Google Play Billing; ads: `AdProvider` with a rewarded-only SDK.
- Relic effects (hint, add moves, shatter, reshuffle) need engine hooks in `src/game` before they can be
  used in play; the meta layer already tracks charges and ranked approval.
