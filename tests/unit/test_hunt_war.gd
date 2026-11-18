extends GutTest
## Wars and battlegrounds: the runs are fought at six sites round the valley,
## each laid out on level, lawless ground; each run rolls what wins it (hold
## the point, supply drops, camps, or extraction), and a side can win it.

const SPOTS := [Vector3(-12, 0, 0), Vector3(12, 0, 0), Vector3(-8, 0, -15), Vector3(8, 0, -15)]
const ZONE := Vector3(0, 0, 16)
const VAULT := Vector3(-8, 0, 16)
const POINT := Vector3(0, 0, -6)
const CAMPS := [Vector3(-14, 0, 10), Vector3(14, 0, 10)]

var world: SimWorld
var h: HuntRules
var inputs := {}


func before_each() -> void:
	add_child_autofree(SimHarness.make_arena())
	world = SimHarness.make_world()
	add_child_autofree(world)
	await wait_physics_frames(2)
	world.hunt = HuntRules.new()
	h = world.hunt
	h.configure({"treasure_spots": SPOTS, "extraction_zones": [ZONE], "vault": VAULT, "war": true,
			"war_point": POINT, "war_camps": CAMPS}, world.match_seed)
	inputs = {}
	for id in [1, 2]:
		var p := world.add_player(id, SimHarness.loadout(), "h%d" % id, id != 1)
		SimHarness.place(p, Vector3(-20 + id * 10, 0.05, 20), 0.0)
		p.state.spawn_protection_ticks = 0
		inputs[id] = SimHarness.CommandScript.new()
	world.drain_events()


func _step(ticks: int = 1, held: Dictionary = {}) -> void:
	for i in ticks:
		var cmds := {}
		for id: int in inputs:
			cmds[id] = inputs[id].cmd(world.tick, Vector2.ZERO, 0, [])
		h.step(world, inputs.keys(), held)
		world.tick += 1


func _start(objective: int) -> void:
	h.war.objective = objective
	h.war.camps.clear()
	if objective == HuntWar.Objective.CAMPS:
		for i in 2:
			var c := HuntWar.Camp.new()
			c.side = h.war.side_of(h, i + 1)
			c.at = CAMPS[i]
			h.war.camps.append(c)


func test_holding_the_point_alone_wins() -> void:
	_start(HuntWar.Objective.HOLD)
	world.teleport(world.players[1], POINT + Vector3(0, 0.05, 0))
	_step(60)
	assert_eq(h.war.holder, h.war.side_of(h, 1), "alone on the point: holding it")
	world.teleport(world.players[2], POINT + Vector3(2, 0.05, 0))
	var held: int = h.war.hold[h.war.side_of(h, 1)]
	_step(60)
	assert_eq(h.war.holder, -1, "contested: nobody holds it")
	assert_eq(h.war.hold[h.war.side_of(h, 1)], held, "and the time stands still")
	world.teleport(world.players[2], Vector3(30, 0.05, 30))
	h.war.hold[h.war.side_of(h, 1)] = HuntWar.HOLD_SECONDS * Sim.TICK_RATE - 5
	_step(10)
	assert_eq(h.war.winner_side, h.war.side_of(h, 1), "five minutes held: the war is won")
	assert_eq(h.war.winner_id(world, h), 1)


func test_supply_drops_land_and_count_for_a_side() -> void:
	_start(HuntWar.Objective.DROPS)
	var before := h.caches.size()
	h.war.next_drop_tick = world.tick
	_step(1)
	assert_eq(h.caches.size(), before + 1, "a drop landed")
	var t := HuntRules.Treasure.new()
	t.kind = HuntRules.Kind.RESOURCE
	for i in HuntWar.DROP_TARGET:
		h.war.on_banked(world, h, 2, t)
	assert_eq(h.war.winner_side, h.war.side_of(h, 2), "enough drops out: won")


func test_camps_fall_to_sabotage_unless_guarded() -> void:
	_start(HuntWar.Objective.CAMPS)
	var target: HuntWar.Camp = h.war.camps[1]  # hunter 2's camp
	world.teleport(world.players[1], target.at + Vector3(0, 0.05, 0))
	world.teleport(world.players[2], target.at + Vector3(4, 0.05, 0))
	_step(HuntWar.SABOTAGE_TICKS + 5, {1: true})
	assert_eq(target.charges, HuntWar.CAMP_CHARGES, "a defender beside it: no sabotage")
	world.teleport(world.players[2], Vector3(40, 0.05, 40))
	for k in HuntWar.CAMP_CHARGES:
		_step(HuntWar.SABOTAGE_TICKS + 1, {1: true})
	assert_eq(target.charges, 0, "unguarded: blown")
	assert_eq(h.war.winner_side, h.war.side_of(h, 1), "the last camp standing wins")


func test_squad_teammates_fight_for_their_leaders_side() -> void:
	assert_true(h.squad.form(world, 1, ["gunner"]))
	h.squad.bind(h.squad.pending[0], 2001)
	assert_eq(h.war.side_of(h, 2001), h.war.side_of(h, 1))


func test_battlegrounds_are_many_and_sound() -> void:
	assert_gte(Battlegrounds.IDS.size(), 6, "six sites")
	var seen := {}
	for run in Battlegrounds.IDS.size():
		seen[Battlegrounds.for_run(run)] = true
	assert_eq(seen.size(), Battlegrounds.IDS.size(), "the runs come round every site")
	for id: String in Battlegrounds.IDS:
		var d := Battlegrounds.hunt_data(id)
		assert_gte((d.treasure_spots as Array).size(), 7, "%s: cargo spots" % id)
		assert_eq((d.extraction_zones as Array).size(), 3, "%s: three pads" % id)
		assert_eq((d.war_camps as Array).size(), 4, "%s: four camps" % id)
		assert_true(d.get("war", false))
		var area := Battlegrounds.nav_area(id)
		for p: Vector3 in (d.treasure_spots as Array) + (d.extraction_zones as Array) + (d.war_camps as Array):
			assert_false(WorldLayout.region_at(p.x, p.z) in WorldLayout.LAWFUL, "%s: lawless at %s" % [id, p])
			assert_true(area.has_point(p), "%s: inside the bots' navigation at %s" % [id, p])
		assert_gte(Battlegrounds.spawns(id).size(), 6, "%s: spawns" % id)
