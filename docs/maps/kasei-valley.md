# Kasei Valley (THE HUNT's open world)

A 1.2 × 1.2 km basin laid out as a **hub**: Tharsis Gate, the walled city on
its plateau, in the middle of the west, with the districts in a ring round
it 220–330 m out and the mining country to the east. North is −Z.

| Place | Centre (x, z) | Where | What it is |
|---|---|---|---|
| Tharsis Gate | (−220, 20) | hub | Walled plaza; one gate (south) where the roads leave |
| Prism Galleria | (−440, 60) | west | Walk-in mall on a boulevard; road arrives at the east forecourt |
| Helios Arcology | (−400, −250) | north-west | Towers on a cross of avenues round the Ring; road in from the east and south |
| Kasei Skyport | (−100, −430) | north | Street between the terminal side (tower, hangars) and the apron (three pads) |
| Nova Terrace | (−170, 330) | south | Two rings of homes round a plaza; a street in from the north, east and west |
| Dust Hollow | (60, −60) | east | Mining camp inside a loop street; the eastern roads meet the loop |
| Rustwood Dig | canyon, x ≈ 238 | south-east | The lawless extraction run on the canyon floor |

Landmarks: the Anvil mesa (Deep Furrow's lift at its foot, north of the
city), the freighter wreck, the ice crater, the relay, Lowell crater (west,
past the Galleria), the far mesa (north-east).

## Roads

- **The loop:** city gate → Galleria → Helios → Skyport → Dust Hollow → city.
- **Spokes from the gate:** east to the Hollow, north to the lift and the
  Anvil, south to Nova Terrace.
- **The canyon road:** from the Hollow into the canyon at its shallow west
  mouth, then down the floor to the dig; the Terrace road turns off at the mouth.
- **District streets:** a street round Helios's Ring joins its avenue and its
  south street; a ring street round Nova Terrace's plaza joins its three roads.
- **The monorail:** elevated, round the city's west side, from the Skyport
  past Helios and the Galleria to Nova Terrace.

Every road runs on a **road bed** (`WorldTerrain` road beds). The ground
is cut and filled along the road to a smoothed profile held to 12% (the
steepest is about 17%, where roads meet). The bed is level across, with
banks back to the land. Where one road starts or ends on another, its bed
meets that road's at the same height, and the beds blend into one surface.
Roads are therefore laid in order: a road that joins another comes after
it in `WorldLayout.roads()`.

Every road ends in a district's street or on the Hollow's loop. None of
them run through buildings: `test_world.gd` checks this against each
building's real footprint. It also checks that buildings stand on level
ground and don't overlap, and `test_roads_drivable` holds every road
to 18% and level across.

## Where it lives

- `maps/world/world_terrain.gd`: the height function and the flats
  (`SITES`), mesas and craters. It is the only definition of the ground.
- `maps/world/terrain_mesh.gd`: the visible ground, built at load from the
  same grid as the physics height map. Nothing is baked, so changing the
  layout needs no asset rebuild.
- `maps/world/world_layout.gd`: districts, roads, monorail, buildings
  (`pieces()`, `district_pieces()`), landmarks, and everything people use.
  Most things are placed relative to their district's centre, so moving a
  district means changing its centre here and its site in `world_terrain.gd`.
- `maps/city/city_layout.gd`: the city itself.

## Seeing the layout

    godot --headless -s tools/dump_world_layout.gd -- /tmp/layout.json
    python3 tools/plot_world_map.py /tmp/layout.json /tmp/map.png "Kasei Valley"

This draws a top-down map: terrain relief, districts, roads, monorail,
buildings, shops, homes and trees. In-engine views (street level and
aerial) come from:

    xvfb-run -a godot --rendering-driver opengl3 --rendering-method gl_compatibility \
        res://tools/city_walk.tscn -- --districts --out /tmp/shots
