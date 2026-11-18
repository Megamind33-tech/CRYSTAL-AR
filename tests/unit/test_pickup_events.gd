extends GutTest
## Every pickup event says what the career pack gets: kind, item, count.

const Action := PlayerCommand.Action
const ARC_SPOT := Vector3(4, 0, 17)
const GRENADE_SPOT := Vector3(-4, 0, 17)
const BOX_SPOT := Vector3(0, 0, 20)

var world: SimWorld
var a: SimPlayer
var input_a: SimHarness.CommandScript


func before_each() -> void:
	add_child_autofree(SimHarness.make_arena())
	world = SimHarness.make_world()
	world.pickups_enabled = true
	world.configure(7, SimHarness.MOVEMENT, TestArenaLayout.spawn_points(), [
		{"weapon": &"arc_launcher", "position": ARC_SPOT, "respawn_ticks": 600},
		{"weapon": &"grenade", "position": GRENADE_SPOT, "respawn_ticks": 300},
		{"weapon": &"ammo_box", "position": BOX_SPOT, "respawn_ticks": 300},
	])
	add_child_autofree(world)
	await wait_physics_frames(2)
	a = world.add_player(1, Loadouts.make(0), "A", false)
	input_a = SimHarness.CommandScript.new()
	SimHarness.place(a, Vector3(10, 0.05, 10), 0.0)
	_run(5)


func _run(ticks: int, press: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in ticks:
		world.step({1: input_a.cmd(world.tick, Vector2.ZERO, 0, press if i == 0 else [])})
		out.append_array(world.drain_events().filter(func(e: Dictionary) -> bool: return e.type == "pickup"))
	return out


func test_weapon_event_is_the_launcher() -> void:
	SimHarness.place(a, ARC_SPOT + Vector3(0, 0.05, 0), 0.0)
	var ev := _run(2, [Action.INTERACT])
	assert_eq(ev.size(), 1)
	assert_eq(ev[0].kind, &"weapon")
	assert_eq(ev[0].item, &"arc_launcher")
	assert_eq(ev[0].count, 1)
	assert_eq(PickupItems.career_item(ev[0]), {"item": "rocket_launcher", "count": 1})


func test_grenade_event() -> void:
	a.state.grenades = 0
	SimHarness.place(a, GRENADE_SPOT + Vector3(0, 0.05, 0), 0.0)
	var ev := _run(2)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0].kind, &"grenade")
	assert_eq(PickupItems.career_item(ev[0]), {"item": "frag_grenade", "count": 1})


func test_ammo_event_counts_rounds_added() -> void:
	SimHarness.place(a, ARC_SPOT + Vector3(0, 0.05, 0), 0.0)
	_run(2, [Action.INTERACT])
	a.state.reserve[0] = 0
	world._add_item(-1, Weapons.ARC, a.state.position, 1, 2, 0)
	var ev := _run(2)
	assert_eq(ev.size(), 1, "taken automatically as ammo")
	assert_eq(ev[0].kind, &"ammo")
	assert_eq(ev[0].item, &"arc_launcher")
	assert_eq(ev[0].count, mini(3, Weapons.at(Weapons.ARC).reserve))
	assert_eq(PickupItems.career_item(ev[0]).item, "bullets")


func test_ammo_box_tops_up_and_reports() -> void:
	SimHarness.place(a, ARC_SPOT + Vector3(0, 0.05, 0), 0.0)
	_run(2, [Action.INTERACT])
	var w := Weapons.at(a.state.weapons[0])
	assert_eq(a.state.weapons[0], Weapons.ARC)
	a.state.reserve[0] = 0
	SimHarness.place(a, BOX_SPOT + Vector3(0, 0.05, 0), 0.0)
	var ev := _run(2)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0].kind, &"ammo_box")
	assert_gt(ev[0].count, 0)
	assert_eq(a.state.reserve[0], mini(w.mag_size, w.reserve))
	assert_eq(PickupItems.career_item(ev[0]), {"item": "ammo_case", "count": 1})


func test_ammo_box_left_when_nothing_needs_ammo() -> void:
	for i in a.state.weapons.size():
		var w := Weapons.at(a.state.weapons[i])
		if w != null:
			a.state.reserve[i] = w.reserve
	SimHarness.place(a, BOX_SPOT + Vector3(0, 0.05, 0), 0.0)
	assert_eq(_run(2).size(), 0)

