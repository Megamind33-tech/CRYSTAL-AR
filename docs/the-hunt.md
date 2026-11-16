# THE HUNT: solo-first MVP

THE HUNT is a treasure-hunting first-person shooter built on IONFALL. You
and five AI rival hunters drop into **Rustwood Yard**, a 150 × 150 m
salvage yard. In 12 minutes, find your treasures, raid the vault for the
grand treasure, steal from whoever is carrying one, and get out through an
extraction pad. The most points wins.

This milestone is single player against AI. The rules live in the
simulation layer, the same way Capture the Flag does, so a later multiplayer
milestone only has to replicate their state (see *Toward multiplayer*).

## Rules

| Rule | Value |
|---|---|
| Hunters | You + 5 AI rivals (`GameMode.HUNT_BOTS`) |
| Match | 12 minutes (`GameMode.HUNT_MINUTES`); only the clock ends it |
| Personal assignments | 2 per hunter, placed at random treasure spots (inside the 8 sheds and at 8 yard caches) |
| Grand treasure | 1, in the vault at the centre; returns 60 s after it is banked |
| Take | Touch a treasure (hands free) |
| Carry | One at a time; it floats above the carrier for everyone to see |
| Drop | Death drops it where you fell; **interact** drops it on purpose. A dropped treasure goes home after 45 s |
| Steal | A **melee** hit on a carrier takes their treasure (if your hands are free) |
| Extract | Stand on an extraction pad for 3 s while carrying; leaving resets the count |
| Points | Own assignment **100**, a rival's assignment **50**, grand treasure **300**, kill **10** |
| Ammunition | Limited: every life starts with one spare magazine per weapon; ammo caches (pistol and rifle pickups) refill |
| Alarm trap | Inside the vault's south door: whoever steps on it is revealed to every hunter for 10 s; re-arms after 20 s |
| Movement & combat | IONFALL's own: sprint, slide, double jump, mantle, **crouch**, melee, grenades, Android touch controls |

All numbers are constants in `sim/hunt_rules.gd` and `modes/game_mode.gd`.

## How it is built (what changed in IONFALL)

| Piece | Where | What |
|---|---|---|
| Rules | `sim/hunt_rules.gd` (new) | Treasures, assignments, pickup/carry/drop/steal/extract, scoring, the alarm trap, the ammo cap. Server-authoritative state, like CTF flags |
| Hooks | `sim/sim_world.gd` | `var hunt: HuntRules`; 6 one-line hooks (add/remove player, reset, step, kill, melee hit, spawn). Every other mode leaves `hunt` null |
| Limited ammo | `sim/weapon_sim.gd` | `WeaponSim.limited_ammo` switch: loadout weapons run their reserve down. Off in every other mode |
| Mode | `modes/game_mode.gd` | `GameMode.HUNT` (appended: the index is on the wire), its bot count, clock and map; `networkable()` keeps it out of Host Game for now |
| Server | `net/server_session.gd` | Creates the rules for the hunt, forwards hunt events to the presentation and the alarm to bots |
| AI rivals | `bots/bot_brain.gd` | The existing utility brain gets a hunt objective (`_hunt_objective`): **extract** what it carries, grab dropped treasure, chase a carrier to **steal** (melee), **collect** its assignments, raid the vault; otherwise **explore** (roam). **Attack** and **retreat** are IONFALL's. Distant enemies are ignored unless they carry treasure or shoot at it |
| Map | `maps/hunt/` (new) | `HuntLayout` data → collision (`gameplay.gd`) and meshes (`presentation.gd`), built at load time from existing textures; the navmesh is baked at runtime from the collision |
| Presentation | `presentation/hunt_visuals.gd` (new), `game/match.gd` | Treasure cases (gold grand, green yours, blue rivals'), beams over your treasures and the grand one, extraction rings, the trap; objective line and kill-feed notes |
| Menu | `ui/main_menu`, `game/match_config.gd` | "The Hunt" is a mode chip in Single Player (remembered once picked); it sets its own map, rivals and clock |

**Humans and AI play by the same rules.** `HuntRules` only reads
`SimPlayer` state and the actions executed from each player's
`PlayerCommand`. Bots press the same buttons through `BotBrain` (melee to
steal, interact to drop), and `is_bot` is never read by the rules. A unit
test plays the same moves as a human and as a bot and compares the results.

## Run it

```sh
godot --headless --import                       # once
godot                                            # Single Player → The Hunt → Start
# Headless: a full 12-minute match of six AI hunters, faster than real time
godot --headless --fixed-fps 60 res://tools/hunt_check.tscn [-- --minutes N]
# Tests (the hunt's are tests/unit/test_hunt.gd)
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit
# Android debug APK (SDK platform 36, build-tools 36.1.0, NDK 29; see docs/toolchain.md)
godot --headless --install-android-build-template --export-debug "Android" build/android/thehunt.apk
```

## Toward multiplayer

Already in place: the rules are server-side simulation, events are emitted
with unique IDs, bots and humans share the command path, and the mode index
is on the wire. Still to do: replicate `HuntRules` state in snapshots (the
way `client.flags` are), send `hunt` events to clients (they are already
queued as reliable on the server), give clients a HUD fed from that state,
and then let `GameMode.networkable()` accept the hunt.
