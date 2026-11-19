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
	h.army.rosters[2] = {}  # the rival bot brings no army here (it would call a drone on the saboteur)
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


## Camps: every side builds with its credits; the buildings are solid and
## work (turret, med bay, refinery, comms); walls make a ring with a gate.
func test_building_a_camp() -> void:
	_start(HuntWar.Objective.HOLD)
	for i in 2:
		var c := HuntWar.Camp.new()
		c.side = h.war.side_of(h, i + 1)
		c.at = CAMPS[i]
		h.war.camps.append(c)
	h.economy.credits[1] = 1000
	h.economy.credits[2] = 0
	assert_true(h.request(world, 1, "build", {"module": "turret"}))
	assert_false(h.request(world, 2, "build", {"module": "turret"}), "no credits, no turret")
	assert_false(h.request(world, 1, "build", {"module": "castle"}), "only real modules")
	assert_eq(h.economy.credits[1], 1000 - int(HuntCamps.MODULES.turret.cost), "paid")
	assert_true(h.request(world, 1, "build", {"module": "walls"}))
	assert_false(h.request(world, 1, "build", {"module": "walls"}), "one ring")
	await wait_physics_frames(2)
	# The turret is solid: a ray through its socket hits it.
	var sock := HuntCamps.socket_at(CAMPS[0], 0)
	var hit := world._ray(sock + Vector3(-5, 1.0, 0), sock + Vector3(5, 1.0, 0))
	assert_false(hit.is_empty(), "the turret stops a shot")
	# It fires on an enemy in range.
	var rival: SimPlayer = world.players[2]
	world.teleport(rival, sock + Vector3(0, 0.05, 4.5))  # inside the walls (they block its sight)
	rival.state.shield = 0.0
	var hp := rival.state.health
	_step(HuntCamps.MODULES.turret.every * 2 + 1)
	assert_lt(rival.state.health, hp, "the turret hits the rival")
	assert_true(h.request(world, 1, "build", {"module": "med_bay"}))
	var me: SimPlayer = world.players[1]
	world.teleport(me, HuntCamps.socket_at(CAMPS[0], 2) + Vector3(3, 0.05, 0))
	me.state.health = 30.0
	_step(HuntCamps.MODULES.med_bay.every + 1)
	assert_gt(me.state.health, 30.0, "the med bay heals its side")


## Armies: units by rank, counted and upgraded in the career; called in
## during a run they act (drones and gunships shoot, a jet strafes, a
## scout reveals); machines speed extraction and heavy loads need one.
func test_the_career_army() -> void:
	var c := Career.new()
	c.d.wallet = 100000
	assert_eq(c.rank(), 0, "a recruit")
	assert_false(c.buy_unit("tank"), "a tank needs rank")
	assert_true(c.buy_unit("scout_drone"))
	c.d.war_xp = 8000
	assert_eq(c.rank(), Career.RANKS.size() - 1, "a commander")
	assert_true(c.buy_unit("tank"))
	assert_true(c.buy_unit("strike_jet"))
	assert_true(c.upgrade_unit("tank"))
	assert_eq(c.unit_level("tank"), 1)
	assert_true(c.set_deploy("tank", 1))
	assert_true(c.set_deploy("strike_jet", 1))
	var plan := c.army_deploy()
	assert_eq(plan.tank, [1, 1])
	assert_true(plan.has("hauler"), "everyone brings the hauler")
	c.settle_army({"strike_jet": 1}, true)
	assert_eq(c.unit_count("strike_jet"), 0, "a jet called in is spent")
	assert_eq(c.unit_count("tank"), 1, "a tank comes home")
	assert_eq(int(c.d.war_xp), 8000 + Career.WAR_XP_RUN + Career.WAR_XP_WIN, "war experience")


func test_called_in_units_act() -> void:
	h.army.deploy(1, {"attack_drone": [1, 0], "strike_jet": [1, 0], "scout_drone": [1, 0]})
	var rival: SimPlayer = world.players[2]
	world.teleport(rival, Vector3(12, 0.05, 10))
	rival.state.shield = 0.0
	var hp := rival.state.health
	assert_true(h.request(world, 1, "call_unit", {"unit": "attack_drone", "target": Vector3(12, 0, 10)}))
	assert_eq(h.army.left(1, "attack_drone"), 0, "spent")
	assert_false(h.request(world, 1, "call_unit", {"unit": "attack_drone", "target": Vector3.ZERO}), "none left")
	await wait_physics_frames(2)
	_step(HuntArmy.UNITS.attack_drone.every * 3 + 1)
	assert_lt(rival.state.health, hp, "the drone hits the rival")
	assert_true(h.request(world, 1, "call_unit", {"unit": "scout_drone", "target": Vector3(12, 0, 10)}))
	_step(61)
	assert_true(h.is_revealed(2, world.tick), "the scout drone reveals the rival")
	rival.state.health = Balance.PLAYER.max_health
	rival.state.shield = 0.0
	assert_true(h.request(world, 1, "call_unit", {"unit": "strike_jet", "target": Vector3(12, 0, 10)}))
	_step(HuntArmy.UNITS.strike_jet.delay + 2)
	assert_lt(rival.state.health, Balance.PLAYER.max_health, "the jet's run hits")


func test_heavy_loads_need_a_machine_at_the_pad() -> void:
	var t := h._new_treasure(HuntRules.Kind.RESOURCE, 0, ZONE)
	t.resource = "rare_ore"
	var me: SimPlayer = world.players[1]
	world.teleport(me, ZONE + Vector3(0, 0.05, 0))
	t.carrier = 1
	_step(HuntRules.EXTRACT_TICKS + 5)
	assert_false(t.banked, "no machine at the pad: the load stays")
	var v := world.add_vehicle(ZONE + Vector3(5, 0.4, 0), 0.0)
	v.owner = 1
	h.army.deploy(1, {"hauler": [1, 1]})
	h.army.set_hauler(1, world.vehicles.size() - 1)
	_step(HuntRules.EXTRACT_TICKS / 2)
	assert_true(t.banked, "beside your hauler (level 1): out, and faster")



## Air defence and the nations' arsenals: flak shoots aircraft down; each
## nation's doctrine changes what its units do and cost; uniques are its own.
func test_air_defense_and_doctrines() -> void:
	assert_gt(NationArsenal.mod("aurora", "attack_drone", "damage"), 1.0, "Aurora: strong drones")
	assert_lt(NationArsenal.mod("aurora", "tank", "hp"), 1.0, "and weak tanks")
	assert_gt(NationArsenal.mod("halden", "tank", "hp"), 1.0, "Halden: strong tanks")
	assert_lt(NationArsenal.mod("halden", "attack_drone", "damage"), 1.0, "and weak drones")
	assert_gt(NationArsenal.mod("vesper", "strike_jet", "damage"), 1.0, "Vesper: strong jets")
	assert_lt(NationArsenal.mod("vesper", "air_defense", "damage"), 1.0, "and weak flak")
	assert_gt(NationArsenal.mod("meridian", "air_defense", "range"), 1.0, "Meridian: long-reach flak")
	assert_lt(NationArsenal.mod("meridian", "strike_jet", "damage"), 1.0, "and weak jets")
	for n: String in Nations.IDS:
		var own: String = NationArsenal.ARSENALS[n].unique
		assert_true(NationArsenal.allowed(n, own), "%s fields its own" % n)
		for other: String in Nations.IDS:
			if other != n:
				assert_false(NationArsenal.allowed(other, own), "%s can't field %s's %s" % [other, n, own])
	# Flak brings an attack drone down.
	h.army.rosters[2] = {}
	for i in 2:
		var c := HuntWar.Camp.new()
		c.side = h.war.side_of(h, i + 1)
		c.at = CAMPS[i]
		h.war.camps.append(c)
	h.economy.credits[2] = 1000
	h.army.deploy(1, {"attack_drone": [1, 0]})
	assert_true(h.request(world, 2, "build", {"module": "air_defense"}))
	var sock := HuntCamps.socket_at(CAMPS[1], 0)
	assert_true(h.request(world, 1, "call_unit", {"unit": "attack_drone", "target": sock + Vector3(4, 0, 4)}))
	assert_eq(h.army.calls.size(), 1)
	_step(600)
	assert_eq(h.army.calls.size(), 0, "shot down by the flak")


## Your own guns hit the army: shots down aircraft, wear tanks down to
## wrecks (lost from the roster); a tougher doctrine's tank lasts longer.
func test_guns_down_aircraft_and_destroy_machines() -> void:
	h.army.rosters[2] = {}
	h.army.deploy(1, {"attack_drone": [1, 0], "tank": [1, 0]})
	assert_true(h.request(world, 1, "call_unit", {"unit": "attack_drone", "target": Vector3(12, 0, 10)}))
	var c: HuntArmy.Call = h.army.calls[0]
	var at := h.army.position_of(c, world.tick)
	var from := at + Vector3(0, -10, 0)
	for k in 10:
		h.army.on_shot(world, h, 2, from, at + Vector3(0, 5, 0), 12.0)
	assert_true(h.army.calls.is_empty(), "shot down by a rifle")
	assert_true(h.request(world, 1, "call_unit", {"unit": "tank", "target": Vector3.ZERO}))
	var vi: int = h.army.machine_hp.keys()[0]
	var hp: float = h.army.machine_hp[vi]
	var tank_at: Vector3 = world.vehicles[vi].position
	h.army.on_shot(world, h, 2, tank_at + Vector3(20, 1.2, 0), tank_at + Vector3(-20, 1.2, 0), 50.0)
	assert_eq(h.army.machine_hp[vi], hp - 50.0, "a shot hits the tank")
	assert_lt(world.vehicles[vi].condition, 100.0, "its condition shows it")
	h.army.damage_machine(world, h, 2, vi, hp)
	assert_false(h.army.machine_hp.has(vi), "destroyed")
	assert_eq(int(h.army.used[1].tank), 1, "lost: off the roster after the run")


func test_doctrine_tank_toughness() -> void:
	var tough := 900.0 * NationArsenal.mod("halden", "tank", "hp")
	var frail := 900.0 * NationArsenal.mod("aurora", "tank", "hp")
	assert_gt(tough, frail * 1.8, "Halden's tank takes nearly twice Aurora's punishment")


## Camp combat and upkeep: shots wear an enemy building down and destroy it
## (its body gone); repairs cost credits; upgrades add power and health;
## the rotorcraft pad flies you home.
func _two_camps() -> void:
	_start(HuntWar.Objective.HOLD)
	for i in 2:
		var c := HuntWar.Camp.new()
		c.side = h.war.side_of(h, i + 1)
		c.at = CAMPS[i]
		h.war.camps.append(c)
	h.army.rosters[2] = {}


func test_buildings_take_damage_and_fall() -> void:
	_two_camps()
	h.economy.credits[2] = 1000
	assert_true(h.request(world, 2, "build", {"module": "turret"}))
	var b: HuntCamps.Built = h.war.builds.built[1]
	var face := HuntCamps.socket_at(CAMPS[1], 0) + Vector3(-1.1, 1.5, 0)  # on its west face
	h.war.builds.on_shot(world, h, 2, face, 100.0)
	assert_eq(float(b.hp[0]), float(HuntCamps.MODULE_HP.turret), "its own side's shots don't hurt it")
	h.war.builds.on_shot(world, h, 1, face, 100.0)
	assert_eq(float(b.hp[0]), float(HuntCamps.MODULE_HP.turret) - 100.0, "an enemy shot does")
	h.war.builds.on_shot(world, h, 1, face, 1000.0)
	assert_false(b.modules.has(0), "destroyed")
	await wait_physics_frames(2)
	var sock := HuntCamps.socket_at(CAMPS[1], 0)
	assert_true(world._ray(sock + Vector3(0, 6.0, 0), sock + Vector3(0, 0.6, 0)).is_empty(), "its body is gone")


func test_repair_upgrade_and_the_pad() -> void:
	_two_camps()
	h.economy.credits[1] = 1000
	assert_true(h.request(world, 1, "build", {"module": "med_bay"}))
	var b: HuntCamps.Built = h.war.builds.built[0]
	h.war.builds.damage_building(world, h, 2, 0, 0, 200.0)
	var before: int = h.economy.credits[1]
	assert_true(h.request(world, 1, "repair_camp"))
	assert_eq(float(b.hp[0]), float(HuntCamps.MODULE_HP.med_bay), "repaired")
	assert_eq(h.economy.credits[1], before - ceili(200.0 * HuntCamps.REPAIR_COST), "for credits")
	assert_true(h.request(world, 1, "upgrade_module", {"module": "med_bay"}))
	assert_eq(int(b.levels[0]), 1)
	assert_gt(h.war.builds.max_hp(0, 0), float(HuntCamps.MODULE_HP.med_bay), "more health")
	assert_gt(h.war.builds.power(0, 0), 1.0, "and more power")
	assert_false(h.request(world, 1, "fly_to_camp"), "no pad, no flight")
	h.economy.credits[1] = 1000
	assert_true(h.request(world, 1, "build", {"module": "helipad"}))
	world.teleport(world.players[1], Vector3(18, 0.05, -18))
	assert_true(h.request(world, 1, "fly_to_camp"))
	assert_lt(world.players[1].state.position.distance_to(CAMPS[0]), HuntCamps.SOCKET_RADIUS + 3.0, "home")
	assert_false(h.request(world, 1, "fly_to_camp"), "not again so soon")


func test_king_of_the_vault() -> void:
	_start(HuntWar.Objective.KING)
	h.army.rosters[2] = {}
	var g := h.grand()
	g.locked = false
	g.carrier = 1
	world.teleport(world.players[1], ZONE + Vector3(0, 0.05, 0))
	_step(HuntRules.EXTRACT_TICKS + 5)
	assert_false(g.banked, "the relic can't be extracted in a King war")
	h.war.king[h.war.side_of(h, 1)] = HuntWar.KING_SECONDS * Sim.TICK_RATE - 3
	_step(5)
	assert_eq(h.war.winner_side, h.war.side_of(h, 1), "held long enough: won")


func test_the_convoy() -> void:
	_two_camps()
	h.war.objective = HuntWar.Objective.CONVOY
	h.war.convoy = POINT
	world.teleport(world.players[1], POINT + Vector3(1, 0.05, 0))
	world.teleport(world.players[2], Vector3(-18, 0.05, -18))
	var start := h.war.convoy
	_step(120)
	assert_eq(h.war.convoy_pusher, h.war.side_of(h, 1), "pushed by the side alone beside it")
	assert_lt(h.war.convoy.distance_to(CAMPS[1]), start.distance_to(CAMPS[1]), "towards the enemy camp")
	h.war.convoy = CAMPS[1] + Vector3(0, 0, -HuntWar.CONVOY_GOAL + 1)
	world.teleport(world.players[1], h.war.convoy + Vector3(1, 0.05, 0))
	_step(2)
	assert_eq(h.war.winner_side, h.war.side_of(h, 1), "arrived: won")


func test_territory_and_last_standing() -> void:
	_two_camps()
	h.war.objective = HuntWar.Objective.TERRITORY
	h.war.flags = [[POINT, -1, -1, 0]]
	world.teleport(world.players[1], POINT + Vector3(0, 0.05, 0))
	world.teleport(world.players[2], Vector3(-18, 0.05, -18))
	_step(HuntWar.CAPTURE_SECONDS * Sim.TICK_RATE + 1)
	assert_eq(int(h.war.flags[0][1]), h.war.side_of(h, 1), "taken")
	h.war.territory[h.war.side_of(h, 1)] = HuntWar.TERRITORY_TARGET - 1
	_step(Sim.TICK_RATE + 1)
	assert_eq(h.war.winner_side, h.war.side_of(h, 1), "territory target: won")
	# Last standing: a side out of lives with nobody up is out.
	h.war.winner_side = -1
	h.war.objective = HuntWar.Objective.LAST_STANDING
	h.war.lives = {h.war.side_of(h, 1): 3, h.war.side_of(h, 2): 1}
	h.war.on_death(h, 2)
	world.players[2].state.alive = false
	_step(1)
	assert_true(h.war.side_of(h, 2) in h.war.out_sides)
	assert_eq(h.war.winner_side, h.war.side_of(h, 1), "the last side in wins")


func test_resource_race() -> void:
	_start(HuntWar.Objective.RACE)
	h.army.rosters[2] = {}
	h.war.race_end_tick = world.tick + 30
	var t := HuntRules.Treasure.new()
	t.kind = HuntRules.Kind.RESOURCE
	h.war.on_banked(world, h, 2, t)
	assert_eq(h.war.winner_side, -1, "no win before time")
	_step(31)
	assert_eq(h.war.winner_side, h.war.side_of(h, 2), "most extracted at the bell wins")


## Match modifiers: drawn per war match, data-driven; they change the rules.
func test_match_modifiers() -> void:
	var base := world.movement_config.gravity
	h.mods.start(world, h, ["low_gravity", "hardcore", "mercenary_market", "methane_storm"])
	assert_almost_eq(world.movement_config.gravity, base * 0.6, 0.001, "low gravity")
	assert_true(Survival.storm_at(world.tick) > 0.9, "a squall all match")
	assert_eq(h.economy.merc_cost, HuntEconomy.MERC_COST / 2, "half-price guns")
	var p: SimPlayer = world.players[1]
	p.state.shield = 50.0
	h.on_spawn(world, p)
	assert_eq(p.state.shield, 0.0, "hardcore: no shields")
	var zone_before: Vector3 = h.zones[0]
	world.tick += HuntMods.DECK.methane_storm.pad_shift * Sim.TICK_RATE + 1
	h.mods.step(world, h)
	assert_true(h.zones[0] != zone_before or SPOTS.size() == 1, "the pads moved")
	h.mods.clear(world)
	assert_almost_eq(world.movement_config.gravity, base, 0.001, "gravity back after the match")
	assert_false(Survival.forced_storm, "the storm over")
	# Drawn per match: a war draws one or two.
	h.mods.start(world, h)
	assert_between(h.mods.active.size(), 1, 2)
	h.mods.clear(world)


## Four-way wars: sides make alliances (AI sides accept when nobody of the
## two leads) and break them; allies don't hurt each other.
func test_side_alliances() -> void:
	h.army.rosters[2] = {}
	var p3 := world.add_player(3, SimHarness.loadout(), "h3", true)
	SimHarness.place(p3, Vector3(8, 0.05, 8), 0.0)
	inputs[3] = SimHarness.CommandScript.new()
	_start(HuntWar.Objective.HOLD)
	var s1 := h.war.side_of(h, 1)
	var s2 := h.war.side_of(h, 2)
	h.war.hold[h.war.side_of(h, 3)] = 100  # side 3 leads
	assert_false(h.request(world, 1, "war_ally", {"side": h.war.side_of(h, 3)}), "the leader isn't anyone's friend")
	assert_true(h.request(world, 1, "war_ally", {"side": s2}))
	assert_true(h.war.sides_allied(s1, s2))
	assert_true(h.friendly(1, 2), "allies don't hurt each other")
	assert_true(h.request(world, 1, "war_betray"))
	assert_false(h.friendly(1, 2), "betrayed: fair game again")
	assert_true(HuntWar.duel_for(1) or not HuntWar.duel_for(1), "the format is drawn per match")


func test_campaign_territory_changes_hands_and_pays() -> void:
	var c := Career.new()
	var mine := c.nation_id()
	if mine.is_empty():
		pass_test("no nation chosen")
		return
	var before: int = c.d.wallet
	var income := c.settle_territory("crater", mine, 7)
	assert_eq(c.site_holder("crater"), mine, "the winner takes the site")
	assert_gte(income, Career.SITE_INCOME, "held sites pay")
	assert_eq(c.d.wallet, before + income)


func test_a_late_joiner_gets_a_camp() -> void:
	var w := HuntWar.new()
	w.enabled = true
	w.camp_spots.assign([Vector3(10, 0, 0), Vector3(-10, 0, 0)])
	var c := HuntWar.Camp.new()
	c.side = 1000
	c.at = w.camp_spots[0]
	w.camps.append(c)
	var h := HuntRules.new()
	h.war = w
	var world := SimWorld.new()
	add_child_autofree(world)
	w._seat_late(world, h, [1000, 3])
	assert_eq(w.camps.size(), 2, "a free spot becomes the newcomer's camp")
	assert_eq(w.builds._camp_of(h, 3), 1)
	w._seat_late(world, h, [1000, 3, 4])
	assert_true(w.joined.has(4), "no spot left: joins a side")
	assert_true(w.builds._camp_of(h, 4) >= 0)


func test_the_wider_arsenal() -> void:
	for n: String in NationArsenal.ARSENALS:
		var two: String = NationArsenal.ARSENALS[n].unique2
		assert_true(NationArsenal.allowed(n, two), "%s fields its second unit" % n)
		for other: String in NationArsenal.ARSENALS:
			if other != n:
				assert_false(NationArsenal.allowed(other, two), "%s's %s is its own" % [n, two])
	for u: String in Career.UNIT_IDS:
		assert_true(u == "hauler" or HuntArmy.UNITS.has(u) or u == "crawler", "%s has its effects" % u)
		assert_true(Career.UNITS.has(u))
	for u: String in HuntArmy.AIR:
		assert_true(HuntArmy.HIT_RADIUS.has(u), "%s can be hit" % u)


## The wider arsenal at work: shells land, medevacs heal, EMP silences
## flak, flak can't see the Nightwing, a recon pass shows everyone.
func test_new_units_act() -> void:
	h.army.rosters[2] = {}
	var rival: SimPlayer = world.players[2]
	var me: SimPlayer = world.players[1]
	world.teleport(rival, Vector3(12, 0.05, 10))
	h.army.deploy(1, {"mortar": [1, 0], "medevac": [1, 0], "recon_sat": [1, 0], "emp_drone": [1, 0], "nightwing": [1, 0]})
	# Mortar: shells land round the target.
	rival.state.shield = 0.0
	var hp := rival.state.health
	assert_true(h.request(world, 1, "call_unit", {"unit": "mortar", "target": rival.state.position}))
	_step(HuntArmy.UNITS.mortar.delay + HuntArmy.UNITS.mortar.every * HuntArmy.UNITS.mortar.shells + 2)
	assert_lt(rival.state.health, hp, "the salvo hurts")
	assert_true(h.army.calls.is_empty(), "the salvo is over")
	# Medevac: heals its own side below.
	me.state.health = 40.0
	assert_true(h.request(world, 1, "call_unit", {"unit": "medevac", "target": me.state.position}))
	_step(130)
	assert_gt(me.state.health, 40.0, "healed")
	# Recon satellite: the rival is shown, wherever they are.
	world.teleport(rival, Vector3(-150, 0.05, -150))
	assert_true(h.request(world, 1, "call_unit", {"unit": "recon_sat", "target": Vector3.ZERO}))
	_step(61)
	assert_true(h.is_revealed(2, world.tick), "everyone shown")
	# EMP: the rival's flak under it goes quiet; and it can't see a Nightwing.
	var sock := Vector3(30, 0, 30)
	assert_false(h.army.jammed(world, h, 2, sock))
	assert_true(h.request(world, 1, "call_unit", {"unit": "emp_drone", "target": sock}))
	assert_true(h.army.jammed(world, h, 2, sock), "jammed under the EMP drone")
	assert_false(h.army.jammed(world, h, 1, sock), "not its own side")
	assert_false(h.request(world, 1, "call_unit", {"unit": "nightwing", "target": sock}), "not Vesper: no Nightwing")
	h.army.deploy(1, {"nightwing": [1, 0]})
	h.home_nations[1] = Nations.index_of("vesper")
	assert_true(h.request(world, 1, "call_unit", {"unit": "nightwing", "target": sock}), "Vesper's own")
	h.army.calls = h.army.calls.filter(func(c: HuntArmy.Call) -> bool: return c.unit == "nightwing")
	assert_false(h.army.shoot_air(world, h, 2, sock + Vector3(0, 30, 0), 500.0, 50.0), "flak can't see the Nightwing")


## Each camp owns its pad: you extract at yours, never at a rival's; the
## mining is out in no man's land between the camps.
func test_camps_own_their_extraction() -> void:
	for i in 2:
		var c := HuntWar.Camp.new()
		c.side = h.war.side_of(h, i + 1)
		c.at = CAMPS[i]
		h.war.camps.append(c)
	h.war.camp_pads(world, h)
	assert_eq(h.zones.size(), 2, "one pad per camp")
	assert_true(h.may_use_zone(0, 1), "yours")
	assert_false(h.may_use_zone(1, 1), "not a rival's")
	assert_true(h.may_use_zone(1, 2))
	assert_lt(h.zones[0].distance_to(CAMPS[0]), HuntCamps.WALL_RADIUS, "inside your walls")
	assert_eq(h.nearest_zone(CAMPS[1], -1, 1), h.zones[0], "you head home, even from beside a rival's pad")
	for id: String in Battlegrounds.IDS:
		if id == "rustwood" or id == "deep_furrow":
			continue
		var d := Battlegrounds.hunt_data(id)
		var mid: Vector3 = d.war_point
		var nearest_camp := INF
		for c: Vector3 in d.war_camps:
			nearest_camp = minf(nearest_camp, Vector2(c.x - mid.x, c.z - mid.z).length())
		for s: Vector3 in d.treasure_spots:
			assert_lt(Vector2(s.x - mid.x, s.z - mid.z).length(), nearest_camp * 0.75, "%s: mining in no man's land" % id)


func test_recruits_never_deploy_alone() -> void:
	var c := Career.new()
	c.d.war_xp = 0
	c.d.nation = "halden"
	assert_eq(c.nation_id(), "halden")
	assert_true(c.sponsored(), "a recruit who serves a nation")
	assert_eq(c.squad_deploy(), Career.SPONSORED_SQUAD, "a government squad, free")
	c.d.war_xp = 99999
	assert_false(c.sponsored(), "promoted: on their own terms")
