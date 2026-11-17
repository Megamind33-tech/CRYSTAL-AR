# Agents: who owns what, and the rules (read this first, then only your files)

THE HUNT (Godot 4.7.2, GDScript, Android first). The design is
docs/game-plan.md (sections 9 and 10). The director integrates.

## Rules for every agent

- **Read little.** Only this file, the plan sections named in your brief, and
  the files you own or must call. Grep for what you need. Never read the whole
  repo, never dump big files.
- **Touch only the files you own** (table below) and new files you create in
  your own area. If you need a change in a file you don't own (CityMode,
  Match, another agent's file), don't make it: put the exact snippet in your
  report under "Wiring for the director".
- **Strings:** new player-facing text goes at the END of `locale/strings.csv`
  in one block headed by a comment row `# <your area>` (CSV: `key,en`; quote
  values with commas). Never edit existing rows except your own area's.
- **Look:** keep the comic style (cel shaders, ink outlines, palette). Phones
  first: mind draw calls (budget 86 incl. HUD), triangles (100k), video
  memory; no heavy assets.
- **Tests:** add unit tests for your logic (`tests/unit/test_<area>.gd`, GUT).
  Run only yours while working:
  `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gselect=test_<area>.gd -gexit`
  New `class_name` files need `godot --headless --import` once first. Before
  you finish, run the full suite once (all must pass; `test_netcode` can flake
  under load: rerun it alone). Rendering checks (if any) with
  `xvfb-run -a -s "-screen 0 1200x540x24" godot --rendering-driver vulkan --resolution 1200x540 res://tools/city_walk.tscn -- --out <dir> <mode>`
  are slow (minutes): one at a time, only when needed.
- **AI hunters:** if you touch bots or the dig, run
  `godot --headless --fixed-fps 60 res://tools/playtest.tscn -- --runs 6 --minutes 12`
  and it must PASS.
- **Commit** on your worktree branch with clear messages, ending with the
  attribution lines the session uses. Don't push to main.
- **Report** (short): what you built, how you tested it (results), files
  changed, "Wiring for the director" snippets, and what's left. No essays.
- Take your time: build it properly and test it. Token-economy: no
  re-reading, no exploratory dumps.

## Ownership

| Agent | Owns (edit freely) | Must not touch |
|---|---|---|
| A. Controls and HUD | presentation/input/*, ui/hud/*, ui/match/nameplates.gd, ui/theme/* | game/*, sim/* |
| B. Bots that move like people | bots/*, maps/world/world_layout.gd (dig data only), tools/playtest.gd | sim/hunt_*.gd except via report |
| C. Solid world and security | sim/player_movement.gd, sim/vehicle_sim.gd, maps/world/gameplay.gd, maps/world/kit_collision.gd, maps/city/city_layout.gd, presentation/titan_settlement.gd | bots/*, ui/* |
| D. Footsteps and sound | presentation/audio/*, audio/*, tools/make_world_sounds.py | everything else |
| E. Pickups into the pack | sim/sim_world.gd (pickups only), sim/robbery.gd, presentation/pickup_visuals.gd | core/career.gd (report the API you need) |
| F. Economy: rubies | core/career.gd, ui/city/shelf_panel.gd, game/city_trade.gd | ui/city/city_screen.gd |
| G. Boards and onboarding | ui/city/city_screen.gd, core/guide.gd, game/city_bounty.gd (board UI parts) | core/career.gd |
| H. Arrival: nation, flag, colony | core/nations.gd, ui/city/nation_pick.gd, ui/main_menu/*, game/match_config.gd | game/city_mode.gd |
| I. People: talk, memory, allies | game/city_social.gd, ui/city/talk_panel.gd (or the talk UI file), maps/city/city_npcs.gd, bots/merc_brain.gd is B's (report) | core/career.gd (report) |
| J. Fight club | new files game/fight_club.gd, ui/city/fight_club_panel.gd, sim/melee*.gd (new) | sim/sim_world.gd (report) |
| K. Land, building, renting | game/city_estate.gd, new files for building | core/career.gd (report) |
| L. Comic weather and looks | presentation/mars_lighting.gd, presentation/dust_storms.gd, presentation/comic/*, presentation/color_grade.gd | everything else |

The director alone edits: game/city_mode.gd, game/match.gd, project.godot,
docs/game-plan.md, and integrates everyone's wiring.
