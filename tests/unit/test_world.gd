extends GutTest
## Kasei Valley: the ground keeps its shape, the places sit where the
## layout says, and the layout holds together (roads clear of buildings,
## buildings level and apart).

## [x, z, height]: the terrain at the places that matter (the districts'
## flats, the yards, the canyon floor, the craters, the Anvil, the rim). A
## change here moves the ground under everything placed on it: re-check
## the layout tests and the map (tools/plot_world_map.py) when you update it.
const PINNED := [[0, 0, 3.6027], [-220, 20, 14.0], [60, -60, 2.0], [238, 161.83249824997, -21.1647],
		[150, -240, -11.2001], [-60, -230, 31.8974], [390, -390, 15.4081], [123.4, -56.7, 2.1644], [-300, 150, -0.6022],
		[-150, 80, 12.8548], [-290, -60, 9.2059], [-400, -250, 18.0], [-170, 330, 6.0], [-460, 330, -18.3174],
		[580, -580, 76.3311], [420, -300, 44.7178], [-450, 300, -19.0679], [300, 520, 15.5758], [-180, -250, 37.973],
		[-95, 28, 3.0]]


func test_terrain_keeps_its_shape() -> void:
	for p: Array in PINNED:
		assert_almost_eq(WorldTerrain.height(p[0], p[1]), float(p[2]), 0.001, "height at %s, %s" % [p[0], p[1]])


## The ground you stand on and see (the physics height map and the mesh,
## both triangles split on the same diagonal) is WorldTerrain.surface: it
## meets the height function at the grid's corners and is flat in between.
func test_surface_is_the_walked_ground() -> void:
	var step := WorldTerrain.STEP
	for corner: Vector2 in [Vector2(300, -100), Vector2(-455, 0), Vector2(0, 0)]:
		assert_almost_eq(WorldTerrain.surface(corner.x, corner.y), WorldTerrain.height(corner.x, corner.y), 0.0001)
	# Inside a cell: on the plane through its triangle's corners.
	var x0 := 300.0
	var z0 := -100.0
	var h10 := WorldTerrain.height(x0 + step, z0)
	var h01 := WorldTerrain.height(x0, z0 + step)
	var h00 := WorldTerrain.height(x0, z0)
	assert_almost_eq(WorldTerrain.surface(x0 + 1.0, z0 + 1.0), h00 + (h10 - h00) * 0.2 + (h01 - h00) * 0.2, 0.0001)


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
		assert_almost_eq(p.y, WorldTerrain.surface(p.x, p.z), 0.25, "on the ground at %s" % p)
		assert_true(area.has_point(p), "inside the bots' navigation at %s" % p)
	assert_lt((data.vault as Vector3).y, -15.0, "the relic vault is down in the canyon")
	var c := MatchConfig.for_place(GameMode.HUNT, "You")
	assert_eq(c.map, GameMode.CITY_MAP, "a run happens in Kasei Valley")
	assert_eq(c.bots, GameMode.HUNT_BOTS)


## A kit piece's footprint on the ground: its model's bounds, scaled and
## turned, as the four corners (x, z). Cached per piece.
var _bounds := {}


func _footprint(piece: String, x: float, z: float, yaw: float, sc: float, col: Vector3) -> PackedVector2Array:
	var box: AABB
	if piece.is_empty() or col != Vector3.ZERO:
		box = AABB(Vector3(-col.x * 0.5, 0, -col.z * 0.5), col)
	else:
		if not _bounds.has(piece):
			var path := ("res://art/environment/%s.glb" % piece) if piece.contains("/") else "res://art/environment/kit/%s.glb" % piece
			var scene: Node3D = (load(path) as PackedScene).instantiate()
			var b := AABB()
			var first := true
			for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
				var xf := Transform3D.IDENTITY
				var n: Node = mi
				while n != null and n != scene:
					xf = (n as Node3D).transform * xf
					n = n.get_parent()
				var mb := xf * mi.mesh.get_aabb()
				b = mb if first else b.merge(mb)
				first = false
			scene.free()
			_bounds[piece] = b
		box = _bounds[piece]
		box = AABB(box.position * sc, box.size * sc)
	var r := Transform2D(-deg_to_rad(yaw), Vector2(x, z))
	var out := PackedVector2Array()
	for c: Vector2 in [Vector2(box.position.x, box.position.z), Vector2(box.end.x, box.position.z),
			Vector2(box.end.x, box.end.z), Vector2(box.position.x, box.end.z)]:
		out.append(r * c)
	return out


## Street furniture the roads may pass close to (it stands on the kerb).
const KERBSIDE := ["districts/lamp_neo", "districts/solar_tree", "districts/holo_sign", "districts/planter", "street_lamp",
		"kiosk", "districts/landing_pad"]
const ROAD_HALF := 4.5


## The roads run clear of every building: traffic drives them, and a road
## that runs into a wall is a road nobody can use.
func test_roads_clear_of_buildings() -> void:
	var feet := []
	for p: Array in WorldLayout.pieces():
		if p[0] in KERBSIDE:
			continue
		feet.append([p[0], _footprint(p[0], p[1], p[2], p[3], p[4], p[5])])
	for p: Array in CityLayout.pieces():
		# The gatehouse is the gate: the road runs through its airlock.
		if p[0] in KERBSIDE or p[0] in ["wall_segment", "titan/gatehouse"]:
			continue
		var at: Vector3 = p[1]
		feet.append([p[0], _footprint(p[0], at.x, at.z, p[2], p[3], p[4])])
	var hits := []
	for road: Array in WorldLayout.roads():
		for s: Array in WorldLayout.road_samples(road, 2.0):
			var q: Vector2 = s[0]
			for f: Array in feet:
				var poly: PackedVector2Array = f[1]
				if Geometry2D.is_point_in_polygon(q, poly) or _poly_distance(q, poly) < ROAD_HALF:
					hits.append("%s at %s" % [f[0], q.round()])
					break
	assert_true(hits.is_empty(), "roads run into buildings:\n" + "\n".join(hits))


func _poly_distance(q: Vector2, poly: PackedVector2Array) -> float:
	var d := INF
	for i in poly.size():
		d = minf(d, q.distance_to(Geometry2D.get_closest_point_to_segment(q, poly[i], poly[(i + 1) % poly.size()])))
	return d


## Every building stands on level ground (the districts' flats), so none
## floats over a slope or sinks into one.
func test_buildings_on_level_ground() -> void:
	var tilted := []
	for p: Array in WorldLayout.pieces():
		if str(p[0]).is_empty() or p[0] in KERBSIDE or p[0] in ["world/freighter_wreck", "crate_stack", "comms_tower", "hab_dome"]:
			# (the wreck lies where it crashed; the dome sits on the Anvil's top)
			continue
		var hs := []
		for c: Vector2 in _footprint(p[0], p[1], p[2], p[3], p[4], p[5]):
			hs.append(WorldTerrain.height(c.x, c.y))
		hs.append(WorldTerrain.height(p[1], p[2]))
		if hs.max() - hs.min() > 2.25:  # what a kit piece bedded in the dust hides
			tilted.append("%s at (%d, %d): %.1f m" % [p[0], p[1], p[2], hs.max() - hs.min()])
	assert_true(tilted.is_empty(), "buildings on slopes:\n" + "\n".join(tilted))


## Buildings don't stand in one another.
func test_buildings_apart() -> void:
	var feet := []
	for p: Array in WorldLayout.pieces():
		if str(p[0]).is_empty() or p[0] in KERBSIDE or p[0] == "crate_stack":
			continue
		feet.append(["%s (%d, %d)" % [p[0], p[1], p[2]], _footprint(p[0], p[1], p[2], p[3], p[4], p[5])])
	var clashes := []
	for i in feet.size():
		for j in range(i + 1, feet.size()):
			if not Geometry2D.intersect_polygons(feet[i][1], feet[j][1]).is_empty():
				clashes.append("%s / %s" % [feet[i][0], feet[j][0]])
	assert_true(clashes.is_empty(), "buildings overlap:\n" + "\n".join(clashes))
