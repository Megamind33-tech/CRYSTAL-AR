class_name Battlegrounds
extends RefCounted
## Where THE HUNT's runs and wars are fought: the Rustwood Dig and five more
## sites round the valley's lawless country, so runs don't all happen in
## one canyon. Each site gives what a run needs (HuntRules map data: cargo
## spots, extraction pads, the vault; for wars a control point and up to
## four camps), the spawns, weapon pickups and the bots' navigation area.
## The sites past Rustwood are laid out from their centre on rings and
## checked: level enough to stand on, outside every lawful district.

## [id, centre (x, z), radius (m)]. Rustwood's data is the dig's own.
const SITES := [
	["rustwood", Vector2(238, 165), 0.0],
	["crater", Vector2(150, -240), 85.0],
	["far_mesa", Vector2(395, -285), 80.0],
	["outback", Vector2(320, 390), 95.0],
	["sinlap", Vector2(-445, 330), 90.0],
	["north_dunes", Vector2(250, -455), 70.0],
	["anvil", Vector2(-180, -250), 26.0],  # on the Anvil's flat top
	["wreck_field", Vector2(-340, -40), 70.0],
	["deep_furrow", Vector2.ZERO, 0.0],  # underground: hand-placed in the farm's halls
]
const IDS := ["rustwood", "crater", "far_mesa", "outback", "sinlap", "north_dunes", "anvil", "wreck_field", "deep_furrow"]
## The site the coming run is fought at (the match sets it before the world
## loads: the gameplay scene, the navigation and the spawns read it).
static var current: String = "rustwood"
static var _cache: Dictionary = {}


## The site for a run: they come round in turn (the run's number picks).
static func for_run(run: int) -> String:
	return IDS[posmod(run, IDS.size())]


static func site(id: String) -> Array:
	for s: Array in SITES:
		if s[0] == id:
			return s
	return SITES[0]


## HuntRules map data for `id` (with "war_point" and "war_camps").
static func hunt_data(id: String = current) -> Dictionary:
	if id == "rustwood":
		var d := WorldLayout.dig_hunt_data()
		d["war_point"] = WorldLayout.canyon(238.0, -6.0)
		d["war_camps"] = [WorldLayout.canyon(105.0), WorldLayout.canyon(355.0), WorldTerrain.at(200.0, 112.0),
				WorldTerrain.at(260.0, 232.0)]
		d["war"] = true
		return d
	if id == "deep_furrow":
		return _furrow().data
	return _layout(id).data


static func spawns(id: String = current) -> Array[Transform3D]:
	if id == "rustwood":
		return WorldLayout.dig_spawns()
	if id == "deep_furrow":
		return _furrow().spawns
	return _layout(id).spawns


static func pickups(id: String = current) -> Array:
	if id == "rustwood":
		return WorldLayout.dig_pickups()
	if id == "deep_furrow":
		return _furrow().pickups
	return _layout(id).pickups


## Where a run arrives (you, and your rover beside you): the dig's pad at
## Rustwood, else the edge of the site by its first camp.
static func arrival(id: String = current) -> Vector3:
	if id == "rustwood":
		return WorldLayout.dig_pad()
	return (spawns(id)[0] as Transform3D).origin


static func nav_area(id: String = current) -> AABB:
	if id == "rustwood":
		return WorldLayout.dig_nav_area()
	if id == "deep_furrow":
		return WorldLayout.farm_nav_area()
	var s := site(id)
	var c: Vector2 = s[1]
	var r: float = float(s[2]) + 45.0
	return AABB(Vector3(c.x - r, -60.0, c.y - r), Vector3(r * 2.0, 160.0, r * 2.0))


## Deep Furrow, 200 m under the Anvil: a close-quarters duel in the farm's
## long hall. Cargo among the beds, pads at both ends and the middle, a camp
## in each corner; you come down the lift (its bottom is the arrival).
static func _furrow() -> Dictionary:
	if _cache.has("deep_furrow"):
		return _cache["deep_furrow"]
	var o := WorldLayout.farm_origin()
	var f := func(x: float, z: float) -> Vector3: return o + Vector3(x, 0.0, z)
	var spots: Array[Vector3] = []
	for z in [-24.0, -14.0, -4.0, 6.0]:
		spots.append(f.call(-4.0, z))
		spots.append(f.call(4.0, z + 4.0))
	var zones: Array[Vector3] = [f.call(0.0, -28.0), f.call(0.0, 2.0), f.call(0.0, 30.0)]
	var camps: Array[Vector3] = [f.call(-8.0, -27.0), f.call(8.0, -27.0), f.call(-8.0, 31.0), f.call(8.0, 31.0)]
	var spawn_list: Array[Transform3D] = []
	for camp in camps:
		for k in 2:
			var at: Vector3 = camp + Vector3(0.0, 0.3, (2.0 if k == 0 else -2.0) * signf(camp.z - o.z) * -1.0)
			var face := 0.0 if camp.z > o.z else PI
			spawn_list.append(Transform3D(Basis(Vector3.UP, face), at))
	var out := {
		"data": {"treasure_spots": spots, "extraction_zones": zones, "vault": f.call(0.0, -10.0), "pit_rules": true,
				"war": true, "duel": true, "war_point": f.call(0.0, 0.0), "war_camps": camps},
		"spawns": spawn_list,
		"pickups": [
			{"weapon": &"mag_pistol", "position": spots[2], "respawn_ticks": 2400},
			{"weapon": &"grenade", "position": spots[5], "respawn_ticks": 1800},
		],
	}
	_cache["deep_furrow"] = out
	return out


## The site laid out: rings of cargo spots, pads further out, camps furthest,
## the vault and the control point near the middle; every point moved round
## its ring until it stands on level, lawless ground.
static func _layout(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var s := site(id)
	var c: Vector2 = s[1]
	var r: float = s[2]
	var spots: Array[Vector3] = []
	# The mining: in no man's land between the camps (inner rings), so a
	# load has to be carried home across open ground to your camp's pad.
	for k in 8:
		spots.append(_place(c, r * 0.22, k * TAU / 8.0 + 0.2))
	for k in 8:
		spots.append(_place(c, r * 0.5, k * TAU / 8.0 + 0.6))
	var zones: Array[Vector3] = []
	for k in 3:
		zones.append(_place(c, r * 1.05, k * TAU / 3.0 + 0.9))
	var camps: Array[Vector3] = []
	for k in 4:
		camps.append(_place(c, r * 1.25, k * TAU / 4.0 + PI * 0.25))
	var middle := _place(c, 0.0, 0.0)
	var vault := _place(c, r * 0.18, 2.4)
	var spawn_list: Array[Transform3D] = []
	for camp in camps:
		for k in 2:
			var a := float(k) * PI + 0.7
			var at := WorldTerrain.at(camp.x + cos(a) * 4.0, camp.z + sin(a) * 4.0) + Vector3(0, 0.3, 0)
			var face := atan2(-(middle.x - at.x), -(middle.z - at.z))  # facing the middle
			spawn_list.append(Transform3D(Basis(Vector3.UP, face), at))
	var picks := [
		{"weapon": &"pulse_rifle", "position": spots[1], "respawn_ticks": 2400},
		{"weapon": &"mag_pistol", "position": spots[5], "respawn_ticks": 2400},
		{"weapon": &"grenade", "position": spots[11], "respawn_ticks": 1800},
		{"weapon": &"rail_sniper", "position": spots[14], "respawn_ticks": 7200},
	]
	var out := {
		"data": {"treasure_spots": spots, "extraction_zones": zones, "vault": vault, "pit_rules": true, "war": true,
				"war_point": middle, "war_camps": camps},
		"spawns": spawn_list,
		"pickups": picks,
	}
	_cache[id] = out
	return out


## A point on the ring of radius `r` round `c` at angle `a`, turned round
## the ring (and then pulled in) until the ground there is level enough and
## outside the lawful districts; on the ground.
static func _place(c: Vector2, r: float, a: float) -> Vector3:
	for pull in [1.0, 0.8, 0.6]:
		for k in 24:
			var t: float = a
			if k > 0:
				t = a + float(k / 2 + 1) * 0.13 * (1.0 if k % 2 == 0 else -1.0)
			var q: Vector2 = c + Vector2(cos(t), sin(t)) * r * float(pull)
			if _good(q):
				return WorldTerrain.at(q.x, q.y)
	return WorldTerrain.at(c.x, c.y)


static func _good(q: Vector2) -> bool:
	if WorldLayout.region_at(q.x, q.y) in WorldLayout.LAWFUL:
		return false
	var h := WorldTerrain.height(q.x, q.y)
	for d: Vector2 in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		if absf(WorldTerrain.height(q.x + d.x, q.y + d.y) - h) > 1.2:
			return false
	return absf(q.x) < 520.0 and absf(q.y) < 520.0  # inside the basin's rim
