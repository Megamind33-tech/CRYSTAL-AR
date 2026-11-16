extends GutTest
## Kasei Valley: the game's height function matches the one Blender built
## the visible terrain from (tools/blender/world_terrain.py), and the
## places sit where the layout says.

## [x, z, height] computed by tools/blender/world_terrain.py.
const PYTHON_SAMPLES := [[0, 0, 3.6027], [-220, 20, 14.0], [60, -60, 2.0], [238, 161.83249824996986, -21.1647],
		[150, -240, -11.2001], [-60, -230, 31.8974], [390, -390, 54.1351], [123.4, -56.7, 2.1644], [-300, 150, -0.6022],
		[-150, 80, 12.8548], [-290, -60, 9.2059]]


func test_terrain_matches_blender() -> void:
	for p: Array in PYTHON_SAMPLES:
		assert_almost_eq(WorldTerrain.height(p[0], p[1]), float(p[2]), 0.001, "height at %s, %s" % [p[0], p[1]])


func test_places_on_flat_ground() -> void:
	assert_almost_eq(WorldTerrain.height(CityLayout.ORIGIN.x, CityLayout.ORIGIN.z), CityLayout.ORIGIN.y, 0.01, "city plateau")
	for c: Vector3 in [Vector3(-40, 0, -40), Vector3(40, 0, 40), Vector3(0, 0, 30)]:
		var at := CityLayout.ORIGIN + c
		assert_almost_eq(WorldTerrain.height(at.x, at.z), CityLayout.ORIGIN.y, 0.6, "city stays level at %s" % c)
	assert_eq(WorldLayout.region_at(CityLayout.ORIGIN.x, CityLayout.ORIGIN.z), "city")
	assert_eq(WorldLayout.region_at(WorldLayout.HOLLOW.x, WorldLayout.HOLLOW.z), "hollow")
	var pad := WorldLayout.dig_pad()
	assert_eq(WorldLayout.region_at(pad.x, pad.z), "dig", "the deploy pad is in the dig")
	assert_lt(pad.y, -15.0, "down in the canyon")
	for t: Array in CityLayout.terminals():
		assert_eq(WorldLayout.region_at((t[1] as Vector3).x, (t[1] as Vector3).z), "city")


func test_world_map_registered_for_city_mode() -> void:
	var c := MatchConfig.for_place(GameMode.CITY, "You")
	assert_eq(c.map, GameMode.CITY_MAP)
	assert_eq(c.bots, 0, "no rivals: the open world starts peaceful")
	assert_true(Maps.has(c.map))
	assert_eq(c.max_combatants(), 1)


## The run at the dig: enough cargo spots for six hunters, everything on
## the ground and inside the bots' navigation area, the run uses this map.
func test_dig_run_layout() -> void:
	var data := WorldLayout.dig_hunt_data()
	assert_gte(data.treasure_spots.size(), 2 * (GameMode.HUNT_BOTS + 1), "two cargo cases per hunter")
	assert_eq(data.extraction_zones.size(), 3)
	var area := WorldLayout.dig_nav_area()
	var points: Array = data.treasure_spots + data.extraction_zones + [data.vault]
	for t: Transform3D in WorldLayout.dig_spawns():
		points.append(t.origin)
	for p: Vector3 in points:
		assert_almost_eq(p.y, WorldTerrain.height(p.x, p.z), 0.25, "on the ground at %s" % p)
		assert_true(area.has_point(p), "inside the bots' navigation at %s" % p)
	assert_lt((data.vault as Vector3).y, -15.0, "the relic vault is down in the canyon")
	var c := MatchConfig.for_place(GameMode.HUNT, "You")
	assert_eq(c.map, GameMode.CITY_MAP, "a run happens in Kasei Valley")
	assert_eq(c.bots, GameMode.HUNT_BOTS)
