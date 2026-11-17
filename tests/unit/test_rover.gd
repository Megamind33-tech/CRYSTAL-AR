extends GutTest
## THE HUNT's rover (VehicleSim): boarding with interact, throttle and
## steering, weapons down while driving, parking where it's left, and the
## driver stepping out beside it. A clear lane in the test arena (z = -15).

var world: SimWorld
var input: Variant
var p: SimPlayer


func before_each() -> void:
	add_child_autofree(SimHarness.make_arena())
	world = SimHarness.make_world()
	add_child_autofree(world)
	await wait_physics_frames(2)
	p = world.add_player(1, SimHarness.loadout(), "driver", false)
	SimHarness.place(p, Vector3(-12, 0.05, -15), -PI * 0.5)
	p.state.spawn_protection_ticks = 0
	input = SimHarness.CommandScript.new()
	input.yaw = -PI * 0.5
	world.add_vehicle(Vector3(-11, 0.05, -15), -PI * 0.5)  # facing +X, down the lane
	for i in 10:
		_step(Vector2.ZERO)


func _step(move: Vector2, press: Array = []) -> void:
	world.step({1: input.cmd(world.tick, move, 0, press)})


func test_board_drive_steer_and_park() -> void:
	_step(Vector2.ZERO, [PlayerCommand.Action.INTERACT])
	assert_eq(p.state.vehicle, 0, "boarded the rover in reach")
	assert_eq(world.vehicles[0].driver, 1)
	var start := p.state.position
	for i in 72:  # 1.2 s of full throttle
		_step(Vector2(0, 1))
	assert_gt(p.state.vehicle_speed, 6.0, "picked up speed")
	assert_gt(p.state.position.x - start.x, 4.0, "drove forward (+X)")
	assert_almost_eq(p.state.position.z, start.z, 0.3, "straight without steering")
	assert_almost_eq(world.vehicles[0].position.x, p.state.position.x, 0.01, "the rover moves with its driver")
	var yaw0 := p.state.vehicle_yaw
	for i in 20:
		_step(Vector2(1, 0.4))  # steer right
	assert_lt(p.state.vehicle_yaw, yaw0, "steering right turns it clockwise")
	for i in 90:
		_step(Vector2(0, -1))  # brake
	assert_lt(p.state.vehicle_speed, 0.5, "braked")
	var parked := p.state.position
	_step(Vector2.ZERO, [PlayerCommand.Action.INTERACT])
	assert_eq(p.state.vehicle, -1, "got out")
	assert_eq(world.vehicles[0].driver, 0)
	assert_almost_eq(world.vehicles[0].position.x, parked.x, 0.2, "parked where it was left")
	assert_gt(p.state.position.distance_to(world.vehicles[0].position), 1.5, "stepped out beside it")


func test_no_firing_while_driving() -> void:
	_step(Vector2.ZERO, [PlayerCommand.Action.INTERACT])
	var mag: int = p.state.mag[p.state.weapon_slot]
	for i in 30:
		world.step({1: input.cmd(world.tick, Vector2.ZERO, PlayerCommand.Held.FIRE)})
	assert_eq(p.state.mag[p.state.weapon_slot], mag, "weapons are down in the rover")


func test_out_of_reach_does_not_board() -> void:
	SimHarness.place(p, Vector3(8, 0.05, -15), 0.0)
	_step(Vector2.ZERO, [PlayerCommand.Action.INTERACT])
	assert_eq(p.state.vehicle, -1)


## Running people down: a rover at speed hits the one in its path (hurt,
## thrown), not the one off to the side.
func test_a_rover_at_speed_hits_who_is_in_front() -> void:
	var ahead := world.add_player(2, SimHarness.loadout(), "ahead", true)
	var aside := world.add_player(3, SimHarness.loadout(), "aside", true)
	SimHarness.place(ahead, Vector3(2, 0.05, -15), 0.0)
	SimHarness.place(aside, Vector3(2, 0.05, -10), 0.0)
	for q in [ahead, aside]:
		q.state.spawn_protection_ticks = 0
	_step(Vector2.ZERO, [PlayerCommand.Action.INTERACT])
	var hp: float = ahead.state.health + ahead.state.shield
	world.drain_events()
	for i in 150:
		world.step({1: input.cmd(world.tick, Vector2(0, 1), 0, []), 2: SimHarness.CommandScript.new().cmd(world.tick, Vector2.ZERO, 0, []),
				3: SimHarness.CommandScript.new().cmd(world.tick, Vector2.ZERO, 0, [])})
	assert_lt(ahead.state.health + ahead.state.shield, hp, "the one in front is hurt")
	assert_eq(aside.state.health + aside.state.shield, hp, "the one aside isn't")
	var hits := world.drain_events().filter(func(e: Dictionary) -> bool: return e.type == "hit" and e.target == 2)
	assert_eq(hits.size(), 1, "one hit, not one per tick")
	assert_eq(hits[0].attacker, 1, "by the driver")
