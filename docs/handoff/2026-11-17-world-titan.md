# Handoff: the open world's layout, roads, aircraft and Titan look (2026-11-17)

What changed in THE HUNT's open world (the valley around Huygens Gate), why,
where it lives, and what is still open. The layout itself is described in
`docs/maps/kasei-valley.md`.

## What changed

1. **The valley is a hub.** The districts used to sit in the corners of a
   1.6 km map with empty desert between them. They now ring the city 220–330 m
   out (Helios NW, Galleria W, Skyport N, Nova Terrace S; Dust Hollow and the
   dig E), and the basin is 1.2 km. Each district is laid out on streets that
   the roads run into.
2. **The ground is built in Godot, not Blender.** `TerrainMesh` builds the
   visible ground at load from `WorldTerrain`'s grid, the same grid as the
   physics height map. `terrain.glb` and the Python copy of the height function
   are gone, so the layout is changed in code only, with no asset to rebuild.
3. **Roads run on road beds.** `WorldTerrain.height` is the land
   (`natural()`) with each road's bed cut and filled in:
   - a smoothed profile, held to 14%, banked back to the land at 1 in 3;
   - junctions meet at one height and their beds blend;
   - a district's flat is never changed (inside it, the bed is the flat).

   There are 12 roads, curved through their waypoints (`WorldLayout.curve`),
   with a pale packed-gravel surface and inked edges.
4. **No sinking.** The road surface is cut along the ground grid's triangles
   (`presentation.gd` `_strip`), so it lies exactly on the walked ground.
   `WorldTerrain.surface` reads the cached grid.
5. **Aircraft.** The jet is retired; the Skyhopper rotorcraft is the only
   aircraft. Saves that owned the jet are migrated with a refund
   (`Career.normalize`). Road traffic uses ground vehicles only.
   `SkyTraffic` (`game/sky_traffic.gd`) flies Skyhoppers on clock-timed routes
   from the Skyport's pads over the districts.
6. **Titan, not Mars.**
   - Look: `TitanLighting` (was `MarsLighting`) gives a golden-amber haze;
     `TerrainMesh` gives dark dunes and pale ice bedrock.
   - Features: a methane lake in Sinlap crater; methane squalls with rain
     (`DustStorms`, the class name is kept) instead of dust storms; the dust
     devils are removed.
   - Names: Kasei → Xanadu, Red Dust → Tholin, Tharsis Mining Concern →
     Kraken Mining Concern, Lowell → Sinlap. The gangs are named after Titan
     places. The duplicate `MAP_CITY` string is removed, so the city is
     "Huygens Gate" everywhere.
7. **Blender.** All 8 scripts in `tools/blender/` run on Blender 4.x; two
   guarded API renames made them work.

## Guards (tests/unit/test_world.gd)

- `test_terrain_keeps_its_shape`: pinned heights. They move when roads or
  sites move; refresh them from `WorldTerrain.height` on purpose, after
  checking the map.
- `test_roads_clear_of_buildings`: every road against each building's real
  model footprint.
- `test_buildings_on_level_ground`, `test_buildings_apart`.
- `test_roads_drivable`: at most 16% grade, no bump over 14% per 4 m, level
  across.
- `test_tarmac_on_the_walked_ground`: the road surface is within 1 cm of the
  walked ground.
- `test_gameplay_scene_builds`: the world's physics scene loads. A broken
  `gameplay.gd` once got past every other test.
- `test_estates.gd` `test_retired_jet_becomes_the_rotorcraft`: the save
  migration.

## Tools

- `godot --headless -s tools/dump_world_layout.gd -- out.json`, then
  `python3 tools/plot_world_map.py out.json map.png "title"`: a top-down map.
- `city_walk.tscn -- --districts`: street, aerial and road views.
  Without a GPU, run it under `xvfb-run` with
  `--rendering-driver opengl3 --rendering-method gl_compatibility`.
- `city_walk.tscn -- --ground-probe`: drops the player at about 1,265 spots
  and reports any that don't stand on the drawn ground. Two known artefacts:
  a spot by the gate puts the player into a parked rover, and Helios's centre
  is inside the Ring's core column.

## How to change the layout

- **Move a district:** change its centre in `WorldLayout` and its site in
  `WorldTerrain.SITES`/`DISTRICTS`. Almost everything in a district is placed
  relative to its centre.
- **Change a road:** edit `WorldLayout.roads()`. Order matters: a road that
  starts or ends on another must come after it. A junction must be one of
  the other road's waypoints, so the curve passes through it.
- **After any change:** run the test suite, check the map plot, and run the
  ground probe.

## Open / next

- "sol" (the Mars day) is still used in strings. Rustwood Dig/Yard keep
  their names.
- The building and vehicle models keep their colours; no new art assets
  were made. **LFS uploads are refused from the cloud sessions**, so new or
  changed GLBs and PNGs must be pushed from a local machine.
- In the 1.2 km basin, the north-east and south-east outback is still
  sparse (groves and mesas only).
- The Skyhopper's rotors don't spin. SkyTraffic flyers don't avoid each
  other; their routes are set far enough apart.
- The visuals were checked under software OpenGL only. Check on a real GPU
  and a phone (`--phone-lod`): haze strength, the lake's sheen, and the
  rain's cost.
- Load time: building the ground grid with road beds takes about 0.65 s, and
  the road surface about 0.15 s. Measure on a phone.
- Cloud environment: Blender is the `bpy` wheel from PyPI (Python 3.11) with
  a `blender` shim script. download.blender.org is blocked. The Godot editor
  is 4.7.2, installed from GitHub releases. Neither is saved as a setup script
  yet.
