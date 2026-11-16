extends GutTest
## THE HUNT (HuntRules): assignments, the grand treasure, pickup by touch,
## carrying, dropping (death and interact), stealing by melee, extraction
## and its points, limited ammunition, the alarm trap, and the rule that a
## bot and a human are treated exactly alike. Plus the mode's wiring and
## the Rustwood Yard map data.

const Action := PlayerCommand.Action

## Test arena coordinates (TestArenaLayout): open floor away from cover.
const SPOTS := [Vector3(-12, 0, 0), Vector3(12, 0, 0), Vector3(-8, 0, -15), Vector3(8, 0, -15)]
const ZONE := Vector3(0, 0, 16)
const VAULT := Vector3(-8, 0, 16)
const TRAP := Vector3(8, 0, 16)
const AWAY_A := Vector3(-4, 0.05, 5)
const AWAY_B := Vector3(4, 0.05, 5)

var world: SimWorld
var input_a: SimHarness.CommandScript
var input_b: SimHarness.CommandScript


func before_each() -> void:
	add_child_autofree(SimHarness.make_arena())
	world = SimHarness.make_world()
	add_child_autofree(world)
	await wait_physics_frames(2)
	world.hunt = HuntRules.new()
	world.hunt.configure({"treasure_spots": SPOTS, "extraction_zones": [ZONE], "vault": VAULT, "trap": TRAP},
			world.match_seed)
	input_a = SimHarness.CommandScript.new()
	input_b = SimHarness.CommandScript.new()


func after_each() -> void:
	WeaponSim.limited_ammo = false
	HuntCombat.apply(false)
	Survival.enabled = false


## Hunter 1 (human unless `a_bot`) and hunter 2, both away from everything.
func _hunters(a_bot: bool = false, b_bot: bool = true) -> Array:
	var a := world.add_player(1, SimHarness.loadout(), "a", a_bot)
	var b := world.add_player(2, SimHarness.loadout(), "b", b_bot)
	SimHarness.place(a, AWAY_A, 0.0)
	SimHarness.place(b, AWAY_B, 0.0)
	world.drain_events()
	return [a, b]


func _step(ticks: int = 1, press_a: Array = [], press_b: Array = []) -> void:
	for i in ticks:
		world.step({1: input_a.cmd(world.tick, Vector2.ZERO, 0, press_a if i == 0 else []),
				2: input_b.cmd(world.tick, Vector2.ZERO, 0, press_b if i == 0 else [])})


func _hunt_events(action: String = "") -> Array:
	return world.drain_events().filter(func(e: Dictionary) -> bool:
		return e.type == "hunt" and (action.is_empty() or e.action == action))


func _own(id: int) -> HuntRules.Treasure:
	return world.hunt.assignments_of(id)[0]


func test_assignments_and_grand_treasure() -> void:
	_hunters()
	var h := world.hunt
	assert_not_null(h.grand(), "one shared grand treasure")
	assert_eq(h.grand().position, VAULT)
	for id in [1, 2]:
		var mine := h.assignments_of(id)
		assert_eq(mine.size(), HuntRules.ASSIGNMENTS_PER_HUNTER, "two personal assignments each")
		assert_ne(mine[0].home, mine[1].home, "at different spots")
		for t in mine:
			assert_true(SPOTS.has(t.home), "placed on a treasure spot")
	assert_eq(h.treasures.size(), 1 + 2 * HuntRules.ASSIGNMENTS_PER_HUNTER)
	# A new match rolls everything again.
	world.reset_match(99)
	assert_eq(h.treasures.size(), 1 + 2 * HuntRules.ASSIGNMENTS_PER_HUNTER)
	assert_true(h.grand().on_ground())


func test_take_carry_and_extract_own_treasure() -> void:
	var a: SimPlayer = _hunters()[0]
	var t := _own(1)
	SimHarness.place(a, t.home + Vector3(0, 0.05, 0), 0.0)
	_step()
	assert_eq(t.carrier, 1, "touching a treasure takes it")
	assert_eq(_hunt_events("take").size(), 1)
	SimHarness.place(a, Vector3(4, 0.05, 10), 0.0)
	_step()
	assert_almost_eq(t.position.x, 4.0, 0.01, "a carried treasure rides with its carrier")
	SimHarness.place(a, ZONE + Vector3(0, 0.05, 0), 0.0)
	_step(HuntRules.EXTRACT_TICKS - 1)
	assert_false(t.banked, "not yet: extraction takes time")
	_step()
	assert_true(t.banked)
	assert_eq(t.carrier, 0)
	assert_eq(world.scores[1], HuntRules.OWN_POINTS)
	var ex := _hunt_events("extract")
	assert_eq(ex.size(), 1)
	assert_eq(ex[0].points, HuntRules.OWN_POINTS)


func test_leaving_the_zone_resets_extraction() -> void:
	var a: SimPlayer = _hunters()[0]
	var t := _own(1)
	SimHarness.place(a, t.home + Vector3(0, 0.05, 0), 0.0)
	_step()
	SimHarness.place(a, ZONE + Vector3(0, 0.05, 0), 0.0)
	_step(HuntRules.EXTRACT_TICKS - 10)
	SimHarness.place(a, AWAY_A, 0.0)
	_step()
	assert_false(world.hunt.extract_progress.has(1), "progress lost on leaving")
	SimHarness.place(a, ZONE + Vector3(0, 0.05, 0), 0.0)
	_step(20)
	assert_false(t.banked, "the clock started again")


func test_rival_and_grand_treasures_are_worth_their_points() -> void:
	var a: SimPlayer = _hunters()[0]
	var rival := _own(2)
	SimHarness.place(a, rival.home + Vector3(0, 0.05, 0), 0.0)
	_step()
	assert_eq(rival.carrier, 1, "anyone can take anyone's treasure")
	SimHarness.place(a, ZONE + Vector3(0, 0.05, 0), 0.0)
	_step(HuntRules.EXTRACT_TICKS)
	assert_eq(world.scores[1], HuntRules.STOLEN_POINTS)
	var g := world.hunt.grand()
	SimHarness.place(a, VAULT + Vector3(0, 0.05, 0), 0.0)
	_step()
	assert_eq(g.carrier, 0, "the grand treasure starts locked (Vault Standoff)")
	_step(1, [Action.INTERACT])
	_step(HuntRules.VAULT_UNLOCK_TICKS + 1)
	assert_eq(g.carrier, 1, "unlocked, then taken")
	SimHarness.place(a, ZONE + Vector3(0, 0.05, 0), 0.0)
	_step(HuntRules.EXTRACT_TICKS)
	assert_eq(world.scores[1], HuntRules.STOLEN_POINTS + HuntRules.GRAND_POINTS)
	assert_false(world.hunt.grand_available(world.tick), "the vault is empty for a while")
	world.tick = g.available_tick
	_step()
	assert_true(world.hunt.grand_available(world.tick), "then the grand treasure is back")
	assert_eq(g.position, VAULT)


func test_death_drops_the_treasure_and_kills_score() -> void:
	var pl := _hunters()
	var a: SimPlayer = pl[0]
	var b: SimPlayer = pl[1]
	var t := _own(1)
	SimHarness.place(a, t.home + Vector3(0, 0.05, 0), 0.0)
	_step()
	SimHarness.place(a, Vector3(2, 0.05, 15), 0.0)
	_step()
	world._kill(a, 2, Weapons.at(Weapons.PULSE), false)
	assert_eq(t.carrier, 0, "dropped on death")
	assert_almost_eq(t.position.y, 0.0, 0.1, "on the floor where the carrier fell")
	assert_eq(world.scores[2], HuntRules.KILL_POINTS, "a kill is worth KILL_POINTS")
	SimHarness.place(b, t.position + Vector3(0, 0.05, 0), 0.0)
	_step()
	assert_eq(t.carrier, 2, "the killer picks it up")


func test_interact_drops_and_blocks_an_instant_repick() -> void:
	var a: SimPlayer = _hunters()[0]
	var t := _own(1)
	SimHarness.place(a, t.home + Vector3(0, 0.05, 0), 0.0)
	_step()
	world.drain_events()
	_step(1, [Action.INTERACT])
	assert_eq(t.carrier, 0, "interact drops the treasure")
	assert_eq(_hunt_events("drop").size(), 1)
	_step(10)
	assert_eq(t.carrier, 0, "not taken straight back")
	_step(HuntRules.REPICK_TICKS)
	assert_eq(t.carrier, 1, "but it can be picked up again later")


func test_melee_on_a_carrier_steals() -> void:
	var pl := _hunters()
	var a: SimPlayer = pl[0]
	var b: SimPlayer = pl[1]
	var t := _own(2)
	SimHarness.place(b, t.home + Vector3(0, 0.05, 0), 0.0)
	_step()
	assert_eq(t.carrier, 2)
	# a stands just east of b and swings west at it.
	input_a.yaw = PI * 0.5
	input_b.yaw = -PI * 0.5
	SimHarness.place(b, Vector3(2.8, 0.05, 17), -PI * 0.5)
	SimHarness.place(a, Vector3(4, 0.05, 17), PI * 0.5)
	_step(5)
	a.state.spawn_protection_ticks = 0
	b.state.spawn_protection_ticks = 0
	var aim := b.state.position + Vector3(0, 1.1, 0) - a.eye_position()
	input_a.pitch = atan2(aim.y, Vector2(aim.x, aim.z).length())
	world.drain_events()
	_step(1, [Action.MELEE])
	assert_eq(t.carrier, 1, "the melee hit takes the treasure")
	var st := _hunt_events("steal")
	assert_eq(st.size(), 1)
	assert_eq(st[0].victim, 2)


func test_limited_ammunition() -> void:
	WeaponSim.limited_ammo = true
	var a: SimPlayer = _hunters()[0]
	world.respawn(a)
	var s := a.state
	for i in s.weapons.size():
		var w := Weapons.at(s.weapons[i])
		assert_lte(s.reserve[i], w.mag_size * HuntRules.SPARE_MAGS, "one spare magazine at most")
	# Empty the reserve: the weapon can't reload any more.
	s.reserve[0] = 0
	s.mag[0] = 0
	assert_false(s.has_reserve(0), "no endless reserve in the hunt")
	WeaponSim.limited_ammo = false
	assert_true(s.has_reserve(0), "other modes keep the endless reserve")


func test_alarm_trap_reveals_and_rearms() -> void:
	var a: SimPlayer = _hunters()[0]
	SimHarness.place(a, TRAP + Vector3(1, 0.05, 0), 0.0)
	_step()
	var alarm := _hunt_events("alarm")
	assert_eq(alarm.size(), 1, "stepping near the trap sets it off")
	assert_eq(alarm[0].player, 1)
	assert_true(world.hunt.is_revealed(1, world.tick), "the intruder is revealed")
	_step(5)
	assert_eq(_hunt_events("alarm").size(), 0, "once, then it re-arms")
	world.tick = world.hunt.trap_rearm_tick
	_step()
	assert_eq(_hunt_events("alarm").size(), 1, "armed again")
	assert_false(world.hunt.is_revealed(2, world.tick))


## The same moves give the same result whether hunter 1 is a human or a bot.
func test_human_and_bot_follow_the_same_rules() -> void:
	var results := []
	for bot in [false, true]:
		var a: SimPlayer = _hunters(bot, not bot)[0]
		var t := _own(1)
		var rival := _own(2)
		SimHarness.place(a, t.home + Vector3(0, 0.05, 0), 0.0)
		_step()
		SimHarness.place(a, ZONE + Vector3(0, 0.05, 0), 0.0)
		_step(HuntRules.EXTRACT_TICKS)
		SimHarness.place(a, rival.home + Vector3(0, 0.05, 0), 0.0)
		_step()
		world._kill(a, 2, Weapons.at(Weapons.PULSE), false)
		results.append([world.scores[1], world.scores[2], t.banked, rival.carrier, a.is_bot])
		world.remove_player(1)
		world.remove_player(2)
		world.hunt.reset(world)
		world.drain_events()
	assert_ne(results[0][4], results[1][4], "one run as a human, one as a bot")
	assert_eq(results[0].slice(0, 4), results[1].slice(0, 4), "identical rules for humans and bots")


func test_mode_wiring() -> void:
	assert_eq(GameMode.IDS[GameMode.HUNT], "hunt")
	assert_false(GameMode.is_team_mode(GameMode.HUNT), "every hunter for themselves")
	assert_false(GameMode.networkable(GameMode.HUNT), "single player in this milestone")
	assert_gt(GameMode.score_limit(GameMode.HUNT), 100000, "only the clock ends a hunt")
	assert_eq(GameMode.HUNT_BOTS, 5)
	assert_eq(GameMode.HUNT_MINUTES, 12)
	var server := ServerSession.new()
	server.game_mode = GameMode.HUNT
	add_child_autofree(server)
	assert_eq(server.start(-1, SimHarness.MOVEMENT, SimHarness.loadout(), TestArenaLayout.spawn_points(), [], null, [],
			{"treasure_spots": SPOTS, "extraction_zones": [ZONE], "vault": VAULT, "trap": TRAP}), OK)
	assert_not_null(server.world.hunt, "the server runs the hunt rules")
	assert_true(WeaponSim.limited_ammo, "with limited ammunition")


func test_rustwood_yard_layout() -> void:
	assert_true(Maps.has("hunt"))
	var data := HuntLayout.hunt_data()
	assert_gte(data.treasure_spots.size(), 2 * (GameMode.HUNT_BOTS + 1), "enough spots for six hunters' assignments")
	assert_eq(data.extraction_zones.size(), 3)
	var floor_box: Array = HuntLayout.boxes()[0]
	assert_gte(floor_box[2].x, 150.0, "a 150 m yard")
	for p: Vector3 in data.treasure_spots + data.extraction_zones:
		assert_lt(maxf(absf(p.x), absf(p.z)), HuntLayout.HALF, "inside the fence")
	assert_eq(HuntLayout.spawn_points().size(), 12)


## The real match scene runs a hunt offline: Rustwood Yard, five AI rivals,
## a 12-minute clock, the treasure markers and the objective line.
func test_match_scene_runs_the_hunt() -> void:
	var saved: Variant = Settings.get_value("profile", "mode")
	Settings.set_value("profile", "mode", "hunt")
	var config := MatchConfig.make(MatchConfig.Mode.OFFLINE, "Hunter")
	Settings.set_value("profile", "mode", saved)
	assert_eq(config.game_mode, GameMode.HUNT)
	assert_eq(config.map, GameMode.HUNT_MAP, "the hunt has its own map")
	assert_eq(config.bots, GameMode.HUNT_BOTS, "five AI rivals")
	assert_eq(config.minutes, GameMode.HUNT_MINUTES)
	assert_eq(config.max_combatants(), GameMode.HUNT_BOTS + 1, "room for all six hunters, phones included")
	MatchConfig.pending = config
	var m: Node = (load("res://game/match.tscn") as PackedScene).instantiate()
	add_child_autofree(m)
	await wait_seconds(1.5)
	assert_not_null(m.server)
	assert_not_null(m.server.world.hunt, "the hunt rules run")
	assert_eq(m.server.world.players.size(), GameMode.HUNT_BOTS + 1, "you and five rivals")
	assert_eq(m.server.time_limit_ticks, GameMode.HUNT_MINUTES * 60 * Sim.TICK_RATE)
	assert_true(WeaponSim.limited_ammo)
	assert_eq(m.hunt_visuals._cases.size(), 1 + 2 * (GameMode.HUNT_BOTS + 1), "a case per treasure")
	m._update_objective()
	assert_string_contains(m.hud._objective, tr("HUNT_OBJ_FIND") % 2, "the objective line counts our treasures")
	# The contracts menu: its rows call HuntRules.request(), like the bots.
	assert_not_null(m.hunt_menu, "the contracts menu is there")
	assert_gte(m.hunt_menu._rows.size(), 7, "hire, four orders, dismiss, bounty")
	m.hunt_menu.toggle()
	assert_true(m.hunt_menu.is_open())
	(m.hunt_menu._rows[0][0] as Button).pressed.emit()  # "Hire a mercenary"
	assert_true(m.server.world.hunt.economy.contracts.has(m.local_id()), "hired from the menu")
	await wait_physics_frames(3)
	assert_eq(m.server.hunt_mercs.size(), 1, "and the mercenary arrived")
	m.hunt_menu.toggle()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_hunt_combat_profile_applies_and_restores() -> void:
	var rifle := Weapons.by_id(&"pulse_rifle")
	var base_damage := rifle.damage
	var base_shield := Balance.PLAYER.max_shield
	HuntCombat.apply(true)
	assert_almost_eq(rifle.damage, base_damage * HuntCombat.GUN_SCALE.damage, 0.001, "guns hit harder")
	assert_eq(Balance.PLAYER.max_shield, HuntCombat.PLAYER_VALUES.max_shield, "smaller armour")
	assert_eq(Balance.PLAYER.shield_regen_per_second, 0.0, "armour doesn't recharge")
	assert_eq(Weapons.by_id(&"melee").damage, Weapons.by_id(&"melee").damage, "melee untouched")
	# Health still recovers (armour is never full again).
	var st := PlayerSimState.new()
	st.alive = true
	st.shield = 10.0
	st.health = 50.0
	Health.tick_regen(st)
	assert_gt(st.health, 50.0, "health recovers without armour")
	HuntCombat.apply(false)
	assert_almost_eq(rifle.damage, base_damage, 0.001, "restored")
	assert_eq(Balance.PLAYER.max_shield, base_shield, "restored")
	assert_eq(WeaponSim.move_spread, 0.0, "no movement spread elsewhere")


## Career gear bought in the city goes on at spawn: armour plating adds to
## the starting armour, webbing adds spare magazines (server-side).
func test_career_gear_applies_at_spawn() -> void:
	var server := ServerSession.new()
	server.game_mode = GameMode.HUNT
	add_child_autofree(server)
	assert_eq(server.start(-1, SimHarness.MOVEMENT, SimHarness.loadout(), TestArenaLayout.spawn_points(), [], null, [],
			{"treasure_spots": SPOTS, "extraction_zones": [ZONE], "vault": VAULT, "trap": TRAP}), OK)
	server.world.hunt.gear[ServerSession.LOCAL_PLAYER_ID] = {"shield_bonus": 30.0, "spare_mags": 1}
	var me := server.add_local_player("You")
	var w := me.current_weapon()
	assert_almost_eq(me.state.shield, Balance.PLAYER.max_shield + 30.0, 0.01, "plating adds armour")
	assert_eq(me.state.reserve[me.state.weapon_slot], w.mag_size * (HuntRules.SPARE_MAGS + 1), "one more spare magazine")
