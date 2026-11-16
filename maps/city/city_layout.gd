class_name CityLayout
extends RefCounted
## Tharsis Gate, the protected city (THE HUNT): a walled plaza of about
## 100 x 100 m. North: the Kasei Freight Union office (contract board).
## West: the market row (stalls, the market terminal). East: the outfitter
## (armoury hangar, its terminal). South: the city gate; through it, the
## deploy pad to the lawless zone. Habitats, tanks and a mast fill the
## corners; lamps and crates line the walks. Both the gameplay scene
## (collision) and the presentation (Blender kit pieces) read this data.

## Where the city stands in Kasei Valley (on its plateau; WorldTerrain.CITY).
const ORIGIN := Vector3(-220.0, 14.0, 20.0)
const HALF := 50.0
const GATE_Z := 40.0

## Each piece: [kit piece, position, yaw degrees, scale, collision box size
## (Vector3.ZERO: none)]. The box is centred over the position, floor up.
static func pieces() -> Array:
	var out := [
		# North: the Kasei office and its neighbours.
		["shopfront", Vector3(0, 0, -32), 0.0, 1.3, Vector3.ZERO],
		["shopfront", Vector3(-20, 0, -33), 0.0, 1.0, Vector3.ZERO],
		["shopfront", Vector3(20, 0, -33), 0.0, 1.0, Vector3.ZERO],
		# West: the market row (stalls face east, into the plaza).
		["shopfront", Vector3(-36, 0, -8), 90.0, 1.0, Vector3.ZERO],
		["shopfront", Vector3(-36, 0, 12), 90.0, 1.0, Vector3.ZERO],
		# South, by the gate: the Red Lantern (a bar), its door on the plaza.
		["shopfront", Vector3(-8, 0, 26), 180.0, 1.0, Vector3.ZERO],
		["market_stall", Vector3(-24, 0, -10), 90.0, 1.0, Vector3(1.6, 1.2, 3.8)],
		["market_stall", Vector3(-24, 0, -3), 90.0, 1.0, Vector3(1.6, 1.2, 3.8)],
		["market_stall", Vector3(-24, 0, 8), 90.0, 1.0, Vector3(1.6, 1.2, 3.8)],
		["market_stall", Vector3(-24, 0, 15), 90.0, 1.0, Vector3(1.6, 1.2, 3.8)],
		# East: the outfitter's armoury hangar.
		["hangar", Vector3(36, 0, 2), 90.0, 1.4, Vector3.ZERO],
		["crate_stack", Vector3(26, 0, -10), 30.0, 1.0, Vector3(3.6, 3, 2)],
		["crate_stack", Vector3(27, 0, 14), -20.0, 1.0, Vector3(3.6, 3, 2)],
		# Corners: homes, tanks, the mast.
		["life/hab_open", Vector3(-36, 0, -36), 45.0, 1.0, Vector3.ZERO],
		["life/hab_open", Vector3(-38, 0, 32), 135.0, 1.0, Vector3.ZERO],
		["tank_cluster", Vector3(36, 0, -34), 0.0, 1.0, Vector3(8.5, 7, 5)],
		["comms_tower", Vector3(38, 0, 30), 0.0, 1.0, Vector3(2, 18, 2)],
		["life/hab_open", Vector3(24, 0, 33), -135.0, 1.0, Vector3.ZERO],
		# South: the gate.
		["gate_arch", Vector3(0, 0, GATE_Z), 90.0, 1.0, Vector3.ZERO],
	]
	# The gate towers' collision (the arch itself is open).
	out.append(["", Vector3(-7, 0, GATE_Z), 0.0, 1.0, Vector3(3.2, 12, 3.2)])
	out.append(["", Vector3(7, 0, GATE_Z), 0.0, 1.0, Vector3(3.2, 12, 3.2)])
	# The city wall: segments around the plaza, a gap at the gate.
	for i in 10:
		var x := -HALF + 5.0 + i * 10.0
		out.append(["wall_segment", Vector3(x, 0, -HALF), 0.0, 1.0, Vector3(10, 7, 1.2)])
		out.append(["wall_segment", Vector3(-HALF, 0, x), 90.0, 1.0, Vector3(1.2, 7, 10)])
		out.append(["wall_segment", Vector3(HALF, 0, x), -90.0, 1.0, Vector3(1.2, 7, 10)])
		if absf(x) > 8.0:
			out.append(["wall_segment", Vector3(x, 0, GATE_Z), 180.0, 1.0, Vector3(10, 7, 1.2)])
	# Lamps along the walks.
	for p: Vector3 in [Vector3(-10, 0, -18), Vector3(10, 0, -18), Vector3(-14, 0, 4), Vector3(14, 0, 4),
			Vector3(-10, 0, 26), Vector3(10, 0, 26), Vector3(-5, 0, 37), Vector3(5, 0, 37)]:
		out.append(["street_lamp", p, 0.0 if p.x < 0 else 180.0, 1.0, Vector3(0.3, 5, 0.3)])
	for p: Array in out:
		p[1] = (p[1] as Vector3) + ORIGIN
	return out


## The terminals (kiosks) and who stands at them: [id, position, yaw,
## vendor name key, the CityScreen tab].
static func terminals() -> Array:
	return [
		["contracts", ORIGIN + Vector3(0, 0, -22), 0.0, "CITY_NPC_BROKER", "contracts"],
		["market", ORIGIN + Vector3(-19, 0, 2.5), 90.0, "CITY_NPC_TRADER", "market"],
		["outfitter", ORIGIN + Vector3(24, 0, 2), -90.0, "CITY_NPC_ARMOURER", "outfitter"],
	]


## Pieces whose collision is their own mesh (walk-in): everything else in
## pieces() with a ZERO box and a piece name.
const WALK_IN := ["life/hab_open", "shopfront", "hangar", "life/greenhouse", "life/mining_rig", "life/lift_head", "life/farm_hall",
		"life/factory", "districts/galleria", "districts/pod_a", "districts/pod_b", "districts/pod_c"]

## The city's parks (green is wealth on Mars): lawn rectangles [centre,
## size] and the trees, shrubs and benches on them [piece, position, yaw].
static func lawns() -> Array:
	return [[ORIGIN + Vector3(-8, 0, -6), Vector2(9, 11)], [ORIGIN + Vector3(8, 0, -6), Vector2(9, 11)],
			[ORIGIN + Vector3(-8, 0, 13), Vector2(9, 10)], [ORIGIN + Vector3(8, 0, 13), Vector2(9, 10)],
			[ORIGIN + Vector3(0, 0, -42), Vector2(70, 8)], [ORIGIN + Vector3(-43, 0, 0), Vector2(8, 50)]]


static func plants() -> Array:
	var out := []
	for p: Vector3 in [Vector3(-9, 0, -8), Vector3(-7, 0, -3), Vector3(9, 0, -9), Vector3(7, 0, -2), Vector3(-9, 0, 15),
			Vector3(9, 0, 12), Vector3(-25, 0, -42), Vector3(-10, 0, -43), Vector3(10, 0, -42), Vector3(26, 0, -43),
			Vector3(-43, 0, -18), Vector3(-43, 0, 18)]:
		out.append(["life/tree", ORIGIN + p, p.x * 7.0])
	for p: Vector3 in [Vector3(-6, 0, -10), Vector3(6, 0, -10), Vector3(-6, 0, 10), Vector3(6, 0, 16), Vector3(-17, 0, -42),
			Vector3(18, 0, -42)]:
		out.append(["life/shrub", ORIGIN + p, p.z * 11.0])
	for p: Array in [[Vector3(-4, 0, -6), 90.0], [Vector3(4, 0, -6), -90.0], [Vector3(-4, 0, 13), 90.0], [Vector3(4, 0, 13), -90.0]]:
		out.append(["life/bench", ORIGIN + p[0], p[1]])
	return out


## Residents' walking loops (presentation only).
static func walks() -> Array:
	return _offset([
		[Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(12, 0, 16), Vector3(-12, 0, 16)],
		[Vector3(-20, 0, -14), Vector3(-20, 0, 20)],
		[Vector3(4, 0, 30), Vector3(4, 0, -16)],
		[Vector3(18, 0, -6), Vector3(18, 0, 18), Vector3(6, 0, 6)],
		# More of the city about its day: shoppers on the market row, people
		# crossing to the bar and the hangar, a loop round the north lawns.
		[Vector3(-28, 0, -20), Vector3(-28, 0, 22), Vector3(-16, 0, 22)],
		[Vector3(-2, 0, 20), Vector3(-2, 0, -26), Vector3(14, 0, -26)],
		[Vector3(24, 0, 20), Vector3(24, 0, -22), Vector3(30, 0, -26)],
		[Vector3(-20, 0, -22), Vector3(20, 0, -22), Vector3(16, 0, 4)],
		[Vector3(-30, 0, 4), Vector3(-14, 0, 4), Vector3(-14, 0, -18)],
	])


## The Marshals' beats (police on patrol).
static func patrols() -> Array:
	return _offset([
		[Vector3(-26, 0, -24), Vector3(26, 0, -24), Vector3(26, 0, 26), Vector3(-26, 0, 26)],
		[Vector3(10, 0, 34), Vector3(-10, 0, 34), Vector3(-6, 0, 2), Vector3(8, 0, 2)],
	])


static func _offset(paths: Array) -> Array:
	for path: Array in paths:
		for i in path.size():
			path[i] = (path[i] as Vector3) + ORIGIN
	return paths


static func spawn_points() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for x in [-3.0, 0.0, 3.0]:
		out.append(Transform3D(Basis.IDENTITY, ORIGIN + Vector3(x, 0.05, 30)))  # facing north (-Z)
	return out
