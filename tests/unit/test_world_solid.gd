extends GutTest
## Kasei Valley is solid: a person walking and a rover (and the biggest
## body, the hauler) driving into every building and prop of the city and
## the valley are stopped at its walls; the city's wall is closed but for
## the gatehouse, whose secured doors open for people and vehicles they
## let through and stay shut on the wanted (SecuredGate).

const GAMEPLAY := preload("res://maps/world/gameplay.tscn")
const WALKER := 1
const DRIVER := 2

var world: SimWorld
var input: Variant
var walker: SimPlayer
var driver: SimPlayer


func before_all() -> void:
	add_child(GAMEPLAY.instantiate())
	world = SimWorld.new()
	world.configure(7, SimHarness.MOVEMENT, CityLayout.spawn_points())
	world.kill_y = -600.0
	add_child(world)
	await wait_physics_frames(2)
	walker = world.add_player(WALKER, SimHarness.loadout(), "walker", false)
	driver = world.add_player(DRIVER, SimHarness.loadout(), "driver", false)
	for d: Array in CityLayout.gate_doors():
		SecuredGate.add(world, d[0], d[1], d[2], d[3])
	await wait_physics_frames(2)
	input = SimHarness.CommandScript.new()


func after_all() -> void:
	for c in get_children():
		c.queue_free()


## Every solid thing as [name, centre (foot), yaw, half size (x, z, local),
## sides to come at it from (local directions), tight (a plain box)].
func _targets() -> Array:
	var out := []
	for p: Array in CityLayout.pieces():
		_add(out, p[0], p[1], p[2], p[3], p[4])
	for p: Array in WorldLayout.pieces():
		_add(out, p[0], WorldTerrain.at(p[1], p[2]), p[3], p[4], p[5])
	return out


func _add(out: Array, piece: String, at: Vector3, yaw: float, sc: float, box: Vector3) -> void:
	if piece in ["districts/landing_pad", "districts/arc_towers", "titan/gatehouse", "wall_segment"]:
		return  # flat, a street through it, or the city wall (tested below)
	var centre := at
	var half := Vector2(box.x, box.z) * 0.5
	var tight := box != Vector3.ZERO
	if tight and absf(fmod(yaw, 90.0)) <= 0.1:
		yaw = 0.0  # a quarter-turned box is given in the world's axes
	if not tight:
		var a := KitCollision.bounds(piece) if not (piece in CityLayout.WALK_IN) else _faces_aabb(piece)
		half = Vector2(a.size.x, a.size.z) * 0.5 * sc
		centre = at + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(a.get_center().x * sc, 0, a.get_center().z * sc)
	if minf(half.x, half.y) < 0.9:
		return  # lamps, signs: posts, not buildings
	# A walk-in's front (+Z) has its door: come at the back and the sides. A
	# hangar is long along X and open at its -X end: you walk in there.
	var sides := [Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT] if not tight else [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	if piece == "hangar" and not tight:
		sides = [Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT]
	out.append([piece, centre, yaw, half, sides, tight])


func _faces_aabb(piece: String) -> AABB:
	var f := KitCollision.shape(piece).get_faces()
	var a := AABB(f[0], Vector3.ZERO)
	for v in f:
		a = a.expand(v)
	return a


func _clear(at: Vector3, r: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = r
	q.shape = s
	q.collision_mask = Sim.LAYER_WORLD
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, r + 0.4, 0))
	for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var shape := PhysicsServer3D.body_get_shape(hit.rid, int(hit.shape))
		if PhysicsServer3D.shape_get_type(shape) != PhysicsServer3D.SHAPE_HEIGHTMAP:
			return false
	return true


func _step(moves: Dictionary, press: Dictionary = {}) -> void:
	var cmds := {}
	for id: int in moves:
		input.yaw = moves[id][1]
		cmds[id] = input.cmd(world.tick, moves[id][0], 0, press.get(id, []))
	SecuredGate.step_all(world)
	world.step(cmds)


func _park(p: SimPlayer, at: Vector3) -> void:
	var s := p.state.copy()
	s.vehicle = -1
	s.vehicle_speed = 0.0
	s.alive = true
	s.health = 100.0
	p.restore(s)
	SimHarness.place(p, at, 0.0)


## Walks (or drives model `model`, -1: walks) from `start` along `dir` for
## `ticks`; the furthest point reached along `dir` past the start (the
## nose's, for a vehicle).
func _run(start: Vector3, dir: Vector3, model: int, ticks: int) -> float:
	var yaw := atan2(-dir.x, -dir.z)
	world.vehicles.clear()
	var p := walker if model < 0 else driver
	_park(walker, WorldTerrain.at(0, 0) + Vector3(0, 0.1, 0) if model >= 0 else start)
	_park(driver, WorldTerrain.at(10, 0) + Vector3(0, 0.1, 0) if model < 0 else start)
	var nose := 0.0
	if model >= 0:
		var v := world.add_vehicle(start, yaw)
		v.model = model
		_step({DRIVER: [Vector2.ZERO, yaw]}, {DRIVER: [PlayerCommand.Action.INTERACT]})
		assert_eq(p.state.vehicle, 0, "boarded")
		nose = float(VehicleSim.MODELS[model].half.y)
	var best := -INF
	for i in ticks:
		_step({p.net_id: [Vector2(0, 1), yaw]})
		best = maxf(best, (p.state.position - start).dot(dir) + nose)
	return best


func test_buildings_stop_people_and_vehicles() -> void:
	var leaks := []
	var tested := 0
	for t: Array in _targets():
		var b := Basis(Vector3.UP, deg_to_rad(float(t[2])))
		var half: Vector2 = t[3]
		for side: Vector3 in t[4]:
			var out_dir := b * side  # from the centre out through this side
			var extent := absf(side.x) * half.x + absf(side.z) * half.y
			var start := WorldTerrain.at((t[1] as Vector3).x + out_dir.x * (extent + 5.5),
					(t[1] as Vector3).z + out_dir.z * (extent + 5.5))
			if t[1].y > start.y + 1.0:
				start.y = t[1].y  # the city's plateau, the floor the building stands on
			start += Vector3(0, 0.1, 0)
			if not _clear(start, 3.6):
				continue
			tested += 1
			# How far in the wall (or what's drawn of it) is from here.
			var wall := 5.5
			var slack := 0.6 if t[5] else extent * 0.7  # a walk-in: what is drawn overhangs its walls (decks, eaves)
			if t[0] == "life/mining_rig":
				slack = extent - 0.5  # an open frame: kept out of its middle (the drill)
			for model in [-1, 0, 2]:
				if model < 0 and t[0] == "life/mining_rig":
					continue  # an open frame: you walk in to its controls
				var reach := _run(start, -out_dir, model, 200 if model < 0 else 150)
				if reach > wall + slack:
					leaks.append("%s at %s from %s: %s got %.1f m in" % [t[0], t[1], side,
							"a person" if model < 0 else VehicleSim.MODELS[model].name, reach - wall])
			_park(driver, WorldTerrain.at(10, 0) + Vector3(0, 0.1, 0))
	gut.p("walked and drove into %d building sides" % tested)
	for l: String in leaks:
		print("LEAK ", l)
	assert_gt(tested, 60, "most buildings were reachable to test")
	assert_eq(leaks, [], "nothing passes through a building")


func _city(x: float, z: float) -> Vector3:
	return CityLayout.ORIGIN + Vector3(x, 0.1, z)


## The city wall: walking (or driving) at it anywhere but the gatehouse
## keeps you out; jetting over it hits the security curtain.
func test_city_wall_is_closed() -> void:
	SecuredGate.refused = {WALKER: true, DRIVER: true}
	var leaks := []
	for k in 21:
		var a := -46.0 + k * 4.6
		for side: Array in [[_city(a, -58), Vector3(0, 0, 1)], [_city(a, 48), Vector3(0, 0, -1)],
				[_city(-58, a), Vector3(1, 0, 0)], [_city(58, a), Vector3(-1, 0, 0)]]:
			var start: Vector3 = side[0]
			start = WorldTerrain.at(start.x, start.z) + Vector3(0, 0.1, 0)
			if not _clear(start, 1.0):
				continue
			for model in [-1, 0]:
				var r := _run(start, side[1], model, 200)
				if r > 9.0:
					leaks.append("%s from %s: %.1f to %s" % ["walked in" if model < 0 else "drove in", start, r,
							(walker if model < 0 else driver).state.position])
	SecuredGate.refused = {}
	assert_eq(leaks, [], "the wall (and the gate, shut on the wanted) keeps them out")


func test_jetpack_cannot_clear_the_wall() -> void:
	var start := _city(0, -40)
	_park(walker, start)
	var s := walker.state.copy()
	s.jetpack = true
	s.jet_fuel = 100.0
	walker.restore(s)
	var top := 0.0
	for i in 900:
		input.yaw = 0.0  # north, at the wall
		world.step({WALKER: input.cmd(world.tick, Vector2(0, 1), PlayerCommand.Held.JUMP, [])})
		top = maxf(top, walker.state.position.y - CityLayout.ORIGIN.y)
	assert_gt(walker.state.position.z, CityLayout.ORIGIN.z - CityLayout.HALF, "still inside the north wall (rose %.1f m)" % top)


## The gatehouse: its doors open for whoever is let through, on foot or
## driving, and stay shut on the wanted.
func test_gate_lets_people_and_vehicles_through_and_refuses_the_wanted() -> void:
	var north := Vector3(0, 0, -1)
	for model in [-1, 0]:
		# People walk the middle; vehicles keep right of the scanner arch.
		var outside := _city(0.0 if model < 0 else 2.0, CityLayout.GATE_Z + 14)
		SecuredGate.refused = {}
		var reach := _run(outside, north, model, 360)
		assert_gt(reach, 22.0, "%s went through the gate" % ("a person" if model < 0 else "a rover"))
		SecuredGate.refused = {WALKER: true, DRIVER: true}
		reach = _run(outside, north, model, 360)
		assert_lt(reach, 10.0, "the wanted %s is turned away at the outer door" % ("person" if model < 0 else "rover"))
	SecuredGate.refused = {}


## Wanted while inside the gatehouse's hall: the way out still opens.
func test_the_wanted_are_never_shut_in_the_gatehouse() -> void:
	SecuredGate.refused = {WALKER: true}
	var hall := _city(0, CityLayout.GATE_Z)
	var reach := _run(hall, Vector3(0, 0, 1), -1, 300)
	assert_gt(reach, 9.0, "walked out of the hall through the outer door")
	# And from the city out through both doors.
	reach = _run(_city(0, CityLayout.GATE_Z - 12), Vector3(0, 0, 1), -1, 400)
	assert_gt(reach, 20.0, "walked out of the city through the gatehouse")
	SecuredGate.refused = {}


## Each building's doors (TitanSettlement.DOORS): a person walks in
## through the porch and the inner door; a shut door (on the wanted) holds.
func test_building_doors_open_and_hold() -> void:
	for name: String in ["titan/hab_r14", "titan/market_hub", "titan/plant_ex03"]:
		var p := TitanSettlement.piece(name)
		var doors: Array = TitanSettlement.DOORS[name]
		var inner := TitanSettlement.to_world(p, doors[0][0], doors[0][1])
		var outer := TitanSettlement.to_world(p, doors[1][0], doors[1][1])
		var inward := (inner - outer).normalized()
		var start := outer - inward * 4.0 + Vector3(0, 0.1, 0)
		var past_inner := (inner - start).dot(inward) + 1.0
		SecuredGate.refused = {}
		assert_gt(_run(start, inward, -1, 300), past_inner, "%s: walked in through both doors" % name)
		SecuredGate.refused = {WALKER: true}
		assert_lt(_run(start, inward, -1, 300), 4.0, "%s: the shut porch door holds" % name)
	SecuredGate.refused = {}
