extends GutTest
## Kasei Valley: the game's height function matches the one Blender built
## the visible terrain from (tools/blender/world_terrain.py), and the
## places sit where the layout says.

## [x, z, height] computed by tools/blender/world_terrain.py.
const PYTHON_SAMPLES := [[0, 0, 3.6027], [-220, 20, 14.0], [60, -60, 2.0], [238, 161.83249824996986, -21.1647],
		[150, -240, -11.2001], [-60, -230, 31.8974], [390, -390, 10.2049], [123.4, -56.7, 2.1644], [-300, 150, -0.6022],
		[-150, 80, 12.8548], [-290, -60, 9.2059], [-520, -470, 18.0], [470, 430, 6.0], [-330, 400, -16.8883],
		[760, -760, 56.2079], [640, -60, 43.6121], [-450, 300, -3.2202], [300, 520, -2.5724]]


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


## The outlands: each district stands on its own flat, named, under the law.
func test_districts_on_flat_ground() -> void:
	for d: Array in [[WorldLayout.HELIOS, WorldTerrain.HELIOS, "helios"], [WorldLayout.GALLERIA, WorldTerrain.GALLERIA, "galleria"],
			[WorldLayout.TERRACE, WorldTerrain.TERRACE, "terrace"], [WorldLayout.SKYPORT, WorldTerrain.SKYPORT, "skyport"]]:
		var c: Vector2 = d[0]
		var site: Array = d[1]
		assert_eq(Vector2(site[0], site[1]), c, "the layout and the terrain agree on %s" % d[2])
		assert_eq(WorldLayout.region_at(c.x, c.y), d[2])
		assert_true(d[2] in WorldLayout.LAWFUL)
		for off: Vector2 in [Vector2(60, 0), Vector2(0, -60), Vector2(-50, 50)]:
			assert_almost_eq(WorldTerrain.height(c.x + off.x, c.y + off.y), float(site[2]), 0.01, "%s is level" % d[2])
	# Inside the Galleria there's air; Terrace homes are sealed; each has a locker to break.
	var g := WorldTerrain.at(WorldLayout.GALLERIA.x, WorldLayout.GALLERIA.y)
	assert_eq(WorldLayout.room_at(g + Vector3(20, 1, 0)), WorldLayout.ROOM_AIR, "the mall is pressurised")
	assert_eq(WorldLayout.room_at(g + Vector3(80, 1, 0)), WorldLayout.NO_ROOM, "its forecourt is outside")
	var terrace_homes := WorldLayout.residences().filter(func(r: Array) -> bool: return str(r[2]).begins_with("Terrace"))
	assert_gt(terrace_homes.size(), 15, "Nova Terrace's homes can be broken into")
	# The mall's shops are real shops, at counters inside it.
	var mall := WorldLayout.shops().filter(func(sh: Array) -> bool: return Career.SHOPS.has(sh[0]) and sh[0] in ["tech", "foodcourt"])
	assert_eq(mall.size(), 2)
	for sh: Array in mall:
		assert_eq(WorldLayout.room_at((sh[1] as Vector3) + Vector3(0, 1, 0)), WorldLayout.ROOM_AIR)


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
