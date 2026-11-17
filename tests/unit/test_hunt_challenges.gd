extends GutTest
## THE HUNT dynamic challenges, one section per challenge, on the test
## arena (a small playable fixture). Humans and bots go through the same
## rules and the same HuntRules.request() entry point.

const Action := PlayerCommand.Action

const SPOTS := [Vector3(-12, 0, 0), Vector3(12, 0, 0), Vector3(-8, 0, -15), Vector3(8, 0, -15)]
const ZONE := Vector3(0, 0, 16)
const VAULT := Vector3(-8, 0, 16)
const AWAY_A := Vector3(-4, 0.05, 5)
const AWAY_B := Vector3(4, 0.05, 5)
const AWAY_C := Vector3(-14, 0.05, -8)

var world: SimWorld
var h: HuntRules
var inputs := {}


func after_each() -> void:
	WeaponSim.limited_ammo = false
	HuntCombat.apply(false)
	Survival.enabled = false


func before_each() -> void:
	add_child_autofree(SimHarness.make_arena())
	world = SimHarness.make_world()
	add_child_autofree(world)
	await wait_physics_frames(2)
	world.hunt = HuntRules.new()
	h = world.hunt
	h.configure({"treasure_spots": SPOTS, "extraction_zones": [ZONE], "vault": VAULT}, world.match_seed)
	inputs = {}


## Hunters 1..n (1 human, the rest bots), away from everything.
func _hunters(n: int = 2) -> Array:
	var out := []
	var places := [AWAY_A, AWAY_B, AWAY_C]
	for i in n:
		var id := i + 1
		var p := world.add_player(id, SimHarness.loadout(), "h%d" % id, id != 1)
		SimHarness.place(p, places[i], 0.0)
		p.state.spawn_protection_ticks = 0
		inputs[id] = SimHarness.CommandScript.new()
		out.append(p)
	world.drain_events()
	return out


func _step(ticks: int = 1, presses: Dictionary = {}) -> void:
	for i in ticks:
		var cmds := {}
		for id: int in inputs:
			cmds[id] = inputs[id].cmd(world.tick, Vector2.ZERO, 0, presses.get(id, []) if i == 0 else [])
		world.step(cmds)


func _events(action: String) -> Array:
	return world.drain_events().filter(func(e: Dictionary) -> bool: return e.type == "hunt" and e.action == action)


## `thief` steals the treasure `victim` carries with a melee hit (the real
## melee path: SimWorld._resolve_melee -> HuntRules.on_melee_hit).
func _steal(thief: SimPlayer, victim: SimPlayer) -> void:
	inputs[thief.net_id].yaw = PI * 0.5
	inputs[victim.net_id].yaw = -PI * 0.5
	SimHarness.place(victim, Vector3(2.8, 0.05, 17), -PI * 0.5)
	SimHarness.place(thief, Vector3(4, 0.05, 17), PI * 0.5)
	_step(5)
	thief.state.spawn_protection_ticks = 0
	victim.state.spawn_protection_ticks = 0
	var aim := victim.state.position + Vector3(0, 1.1, 0) - thief.eye_position()
	inputs[thief.net_id].pitch = atan2(aim.y, Vector2(aim.x, aim.z).length())
	_step(1, {thief.net_id: [Action.MELEE]})


func _carry(p: SimPlayer, t: HuntRules.Treasure) -> void:
	SimHarness.place(p, t.position + Vector3(0, 0.05, 0), 0.0)
	_step()


func _extract(p: SimPlayer) -> void:
	SimHarness.place(p, ZONE + Vector3(0, 0.05, 0), 0.0)
	_step(HuntRules.EXTRACT_TICKS)


# --- Challenge 1: Most Wanted ---

func test_carrying_treasure_is_not_a_crime() -> void:
	var a: SimPlayer = _hunters()[0]
	_carry(a, h.assignments_of(2)[0])  # even someone else's, picked up off the ground
	assert_eq(h.carried_by(1) != null, true)
	assert_eq(h.social.bounty.get(1, 0), 0, "no bounty for carrying")
	assert_false(h.social.is_wanted(1))


func test_theft_makes_the_thief_wanted_with_approximate_pings() -> void:
	var pl := _hunters()
	var a: SimPlayer = pl[0]
	var b: SimPlayer = pl[1]
	_carry(b, h.assignments_of(2)[0])
	world.drain_events()
	_steal(a, b)
	assert_eq(h.carried_by(1) != null, true, "stolen")
	var expected := HuntSocial.STEAL_BOUNTY_BASE + int(HuntRules.STOLEN_POINTS * HuntSocial.STEAL_BOUNTY_SHARE)
	assert_eq(h.social.bounty[1], expected, "theft posts a bounty")
	assert_true(h.social.is_wanted(1), "and makes the thief Wanted")
	assert_true(h.social.last_known.has(1), "rivals get a last-known position")
	var lk: Vector3 = h.social.last_known[1].position
	var off := Vector2(lk.x - a.state.position.x, lk.z - a.state.position.z).length()
	assert_between(off, HuntSocial.PING_FUZZ * 0.4 - 0.01, HuntSocial.PING_FUZZ + 0.01, "approximate, never exact")
	# The next public ping comes PING_TICKS later, not every tick.
	var first_tick: int = h.social.last_known[1].tick
	_step(60)
	assert_eq(h.social.last_known[1].tick, first_tick, "no live tracking")
	world.tick = first_tick + HuntSocial.PING_TICKS
	_step()
	assert_gt(h.social.last_known[1].tick, first_tick, "a fresh ping on schedule")


func test_contract_and_bounty_proof_pay_once() -> void:
	var pl := _hunters(3)
	var a: SimPlayer = pl[0]
	var b: SimPlayer = pl[1]
	h.social.add_bounty(world, 2, 80, "test")
	assert_false(h.request(world, 1, "accept_bounty", {"target": 3}), "no contract on someone not Wanted")
	assert_true(h.request(world, 1, "accept_bounty", {"target": 2}), "a contract on a Wanted hunter")
	world._kill(b, 1, Weapons.at(Weapons.PULSE), false)
	assert_false(h.social.is_wanted(2), "the bounty is cleared by the kill")
	assert_false(h.social.contracts.has(1), "and so is the contract")
	var proofs := h.treasures.filter(func(t: HuntRules.Treasure) -> bool: return t.kind == HuntRules.Kind.PROOF)
	assert_eq(proofs.size(), 1, "a bounty proof drops")
	var proof: HuntRules.Treasure = proofs[0]
	assert_eq(proof.value, 80)
	var before: int = world.scores[1]
	_carry(a, proof)
	_extract(a)
	assert_eq(world.scores[1], before + 80, "the proof pays the bounty once extracted")
	# Farming: killing the same hunter again pays nothing more.
	world.respawn(b)
	world._kill(b, 1, Weapons.at(Weapons.PULSE), false)
	assert_eq(h.treasures.filter(func(t: HuntRules.Treasure) -> bool: return t.kind == HuntRules.Kind.PROOF and not t.banked).size(), 0,
			"no second proof without a new bounty")


func test_a_target_cannot_cash_its_own_proof_and_proofs_expire() -> void:
	var pl := _hunters(3)
	var b: SimPlayer = pl[1]
	h.social.add_bounty(world, 2, 60, "test")
	world._kill(b, 1, Weapons.at(Weapons.PULSE), false)
	var proof: HuntRules.Treasure = h.treasures.filter(func(t: HuntRules.Treasure) -> bool: return t.kind == HuntRules.Kind.PROOF)[0]
	world.respawn(b)
	_carry(b, proof)
	assert_true(proof.banked, "the target touching its own proof destroys it")
	assert_eq(h.carried_by(2), null)
	h.social.add_bounty(world, 3, 60, "test")
	world._kill(pl[2], 1, Weapons.at(Weapons.PULSE), false)
	var second: HuntRules.Treasure = h.treasures.back()
	world.tick = second.return_tick
	_step()
	assert_true(second.banked and second.carrier == 0, "an unclaimed proof expires")


func test_unprovoked_kills_post_bounties_self_defence_does_not() -> void:
	var pl := _hunters(3)
	var b: SimPlayer = pl[1]
	var c: SimPlayer = pl[2]
	world._kill(b, 1, Weapons.at(Weapons.PULSE), false)
	assert_eq(h.social.bounty.get(1, 0), HuntSocial.UNPROVOKED_KILL_BOUNTY, "killing an unarmed-of-treasure, peaceful hunter")
	# 3 hurt 2 first, so 2 killing 3 is self-defence.
	world.respawn(b)
	world._damage_log[2] = [[3, 20.0, world.tick]]
	world._kill(c, 2, Weapons.at(Weapons.PULSE), false)
	assert_eq(h.social.bounty.get(2, 0), 0, "self-defence is no crime")
	# Killing a treasure carrier is competition, not a crime.
	world.respawn(c)
	c.state.spawn_protection_ticks = 0
	_carry(c, h.assignments_of(3)[0])
	world._kill(c, 2, Weapons.at(Weapons.PULSE), false)
	assert_eq(h.social.bounty.get(2, 0), 0, "taking down a carrier is fair game")


func test_bots_chase_last_known_positions_only_when_fit() -> void:
	var pl := _hunters(2)
	var bot := BotBrain.new(world, null, 2, 1)
	h.social.add_bounty(world, 1, 90, "test")
	var lk: Vector3 = h.social.last_known[1].position
	assert_eq(bot._bounty_target(pl[1]), lk, "heads for the published last-known position, not the live one")
	assert_eq(h.social.contracts.get(2, 0), 1, "and accepts the contract through the shared request")
	pl[1].state.health = 30.0
	pl[1].state.shield = 0.0
	assert_eq(bot._bounty_target(pl[1]), Vector3.INF, "an injured bot doesn't chase bounties")


# --- Challenge 2: Recovery Contract ---

func _stolen_from_b(a: SimPlayer, b: SimPlayer) -> HuntRules.Treasure:
	var t := h.assignments_of(2)[0]
	_carry(b, t)
	world.drain_events()
	_steal(a, b)
	return t


func test_theft_opens_a_recovery_contract_with_limited_clues() -> void:
	var pl := _hunters()
	var t := _stolen_from_b(pl[0], pl[1])
	assert_eq(t.carrier, 1)
	assert_eq(t.stolen_from, 2, "the item remembers who it was taken from")
	assert_eq(h.stolen_from_hunter(2), t)
	assert_false(h.recovery_clues.has(2), "no instant tracking")
	world.tick = t.next_clue_tick
	_step()
	assert_true(h.recovery_clues.has(2), "a clue on schedule")
	var clue: Dictionary = h.recovery_clues[2]
	assert_eq(clue.treasure, t.id, "about this very item")
	var off := Vector2(clue.position.x - t.position.x, clue.position.z - t.position.z).length()
	assert_between(off, HuntRules.RECOVERY_CLUE_FUZZ * 0.4 - 0.01, HuntRules.RECOVERY_CLUE_FUZZ + 0.01, "fuzzed")


func test_recovering_by_pickup_pays_once_and_is_no_crime() -> void:
	var pl := _hunters()
	var a: SimPlayer = pl[0]
	var b: SimPlayer = pl[1]
	var t := _stolen_from_b(a, b)
	var bounty_before: int = h.social.bounty.get(2, 0)
	world._kill(a, 2, Weapons.at(Weapons.PULSE), false)  # b takes down the thief...
	b.state.spawn_protection_ticks = 0
	world.drain_events()
	_carry(b, t)  # ...and picks its treasure back up
	assert_eq(t.carrier, 2)
	assert_eq(t.stolen_from, 0, "the contract closes")
	assert_eq(_events("recovered").size(), 1)
	var score_after: int = world.scores[2]
	assert_eq(h.social.bounty.get(2, 0), bounty_before, "recovering is no crime")
	# Steal and recover again: no second bonus for the same item.
	world.respawn(a)
	_steal(a, b)
	_steal(b, a)
	assert_eq(t.carrier, 2, "taken back by melee")
	assert_eq(world.scores[2], score_after, "the recovery bonus is paid once per item")
	assert_eq(h.social.bounty.get(2, 0), bounty_before, "melee recovery is no theft")
	# And it still extracts once, for its normal value.
	_extract(b)
	assert_eq(world.scores[2], score_after + HuntRules.OWN_POINTS)
	assert_true(t.banked)


func test_thief_extracting_ends_the_contract() -> void:
	var pl := _hunters()
	var a: SimPlayer = pl[0]
	var t := _stolen_from_b(a, pl[1])
	world.drain_events()
	_extract(a)
	assert_true(t.banked, "the thief banked it")
	assert_eq(_events("recovery_failed").size(), 1, "the victim is told")
	assert_null(h.stolen_from_hunter(2), "nothing left to recover")
	assert_false(h.recovery_clues.has(2))


func test_bot_follows_recovery_clues_only_while_useful() -> void:
	var pl := _hunters()
	var t := _stolen_from_b(pl[0], pl[1])
	var bot := BotBrain.new(world, null, 2, 1)
	world.tick = t.next_clue_tick
	_step()
	var clue: Dictionary = h.recovery_clues[2]
	assert_eq(bot._hunt_objective(pl[1]), clue.position, "the victim bot heads for the clue")
	world.tick += BotBrain.HUNT_CLUE_TTL + 1
	assert_ne(bot._hunt_objective(pl[1]), clue.position, "a stale clue is abandoned")


# --- Challenge 3: Last Extraction ---

const ZONE_B := Vector3(-16, 0, -17)


func _two_zone_clock(end_in: int) -> void:
	h.configure({"treasure_spots": SPOTS, "extraction_zones": [ZONE, ZONE_B], "vault": VAULT}, world.match_seed)
	h.reset(world)
	h.set_clock(world, world.tick + end_in)


func test_pads_close_to_one_on_the_clock() -> void:
	_hunters()
	assert_true(h.zone_open(0, world.tick) and h.zone_open(0, world.tick + 1000000), "no clock: always open")
	_two_zone_clock(HuntRules.LAST_EXTRACTION_TICKS + 600)
	var last := h.final_zone
	assert_between(last, 0, 1)
	assert_true(h.zone_open(0, world.tick) and h.zone_open(1, world.tick), "both open before the last window")
	var closing := h.end_tick - HuntRules.LAST_EXTRACTION_TICKS
	assert_true(h.zone_open(last, closing), "the last pad stays open")
	assert_false(h.zone_open(1 - last, closing), "the other closes")
	assert_eq(h.nearest_zone(h.zones[1 - last], closing), h.zones[last], "carriers are sent to the open pad")


func test_announcements_and_closed_pad_extraction() -> void:
	var a: SimPlayer = _hunters()[0]
	_two_zone_clock(HuntRules.FINAL_WARNING_TICKS + 120)
	var closed: Vector3 = h.zones[1 - h.final_zone]
	var open: Vector3 = h.zones[h.final_zone]
	world.drain_events()
	_step(121)
	assert_eq(_events("final_warning").size(), 1, "one final warning")
	_carry(a, h.assignments_of(1)[0])
	SimHarness.place(a, closed + Vector3(0, 0.05, 0), 0.0)
	world.tick = h.end_tick - HuntRules.LAST_EXTRACTION_TICKS - 30
	_step(20)
	assert_gt(h.extract_progress.get(1, 0), 0, "extracting while the pad is still open")
	world.drain_events()
	_step(20)
	assert_eq(_events("last_extraction").size(), 1, "the pads close once")
	_step(HuntRules.EXTRACT_TICKS)
	assert_false(h.carried_by(1) == null, "no extraction on a closed pad")
	assert_false(h.extract_progress.has(1), "its progress was reset")
	SimHarness.place(a, open + Vector3(0, 0.05, 0), 0.0)
	_step(HuntRules.EXTRACT_TICKS)
	assert_null(h.carried_by(1), "the last pad still extracts")


func test_cargo_still_carried_at_the_bell_is_lost() -> void:
	var a: SimPlayer = _hunters()[0]
	_two_zone_clock(300)
	_carry(a, h.assignments_of(1)[0])
	var score: int = world.scores[1]
	world.drain_events()
	world.tick = h.end_tick
	_step()
	assert_eq(_events("cargo_lost").size(), 1, "the carrier is told")
	assert_eq(world.scores[1], score, "unextracted cargo never scores")


func test_bots_play_the_final_phase_sensibly() -> void:
	var pl := _hunters()
	var bot := BotBrain.new(world, null, 2, 1)
	_two_zone_clock(HuntRules.LAST_EXTRACTION_TICKS - 600)  # already in the last window
	var open: Vector3 = h.zones[h.final_zone]
	_carry(pl[1], h.assignments_of(2)[0])
	assert_eq(bot._hunt_objective(pl[1]), open, "a carrier heads for the one open pad")
	h._drop(world, pl[1])
	world.tick = h.end_tick - 15 * Sim.TICK_RATE
	SimHarness.place(pl[1], Vector3(-18, 0.05, 18), 0.0)
	var goal := bot._hunt_objective(pl[1])
	assert_true(goal == Vector3.INF or goal.distance_to(pl[1].state.position) < 1.0,
			"15 s before the end: no hopeless runs, no camping the pad")


# --- Challenge 4: Mercenary Contract ---

## A real server (it spawns mercenary bodies) with navigation on the arena.
func _merc_server() -> ServerSession:
	var server := ServerSession.new()
	server.game_mode = GameMode.HUNT
	add_child_autofree(server)
	server.start(-1, SimHarness.MOVEMENT, SimHarness.loadout(), TestArenaLayout.spawn_points(), [], null, [],
			{"treasure_spots": SPOTS, "extraction_zones": [ZONE], "vault": VAULT})
	var nav := BotNavigation.new()
	add_child_autofree(nav)
	nav.build(get_tree().root.find_children("*", "StaticBody3D", true, false)[0].get_parent())
	await wait_until(func() -> bool: return nav.ready_for_queries, 10.0)
	server.bot_nav = nav
	return server


func test_credits_and_hiring_rules() -> void:
	_hunters()
	var e := h.economy
	assert_eq(e.credits[1], HuntEconomy.START_CREDITS)
	assert_true(h.request(world, 1, "hire_mercenary"))
	assert_eq(e.credits[1], HuntEconomy.START_CREDITS - HuntEconomy.MERC_COST, "the contract is paid for")
	assert_false(h.request(world, 1, "hire_mercenary"), "one mercenary per hunter")
	e.credits[2] = HuntEconomy.MERC_COST - 1
	assert_false(h.request(world, 2, "hire_mercenary"), "not without the credits")
	e.earn(world, 2, 100000, "test")
	assert_eq(e.credits[2], HuntEconomy.MAX_CREDITS, "credits are capped")
	assert_true(h.request(world, 2, "hire_mercenary"))
	e.credits[3] = 1000
	assert_false(e.hire(world, 3), "and capped per match (phones)")


func test_mercenary_spawns_protects_and_obeys() -> void:
	var server: ServerSession = await _merc_server()
	var w := server.world
	var me := w.add_player(1, SimHarness.loadout(), "boss", false)
	var rival := w.add_player(3, SimHarness.loadout(), "rival", true)
	SimHarness.place(me, Vector3(-4, 0.05, 5), 0.0)
	SimHarness.place(rival, Vector3(10, 0.05, -10), 0.0)
	assert_true(w.hunt.request(w, 1, "hire_mercenary"))
	await wait_physics_frames(3)
	assert_eq(server.hunt_mercs.size(), 1, "the server spawned the mercenary")
	var merc_id: int = server.hunt_mercs.keys()[0]
	var merc := w.get_player(merc_id)
	assert_lt(merc.state.position.distance_to(me.state.position), 4.0, "next to its employer")
	assert_true(w.hunt.economy.is_merc(merc_id))
	assert_eq(w.hunt.assignments_of(merc_id).size(), 0, "a mercenary is no hunter")
	assert_false(w._can_hurt(1, merc) or w._can_hurt(merc_id, me), "employer and mercenary can't hurt each other")
	assert_true(w._can_hurt(merc_id, rival), "but it can fight others")
	# Orders.
	var brain: MercBrain = server.hunt_mercs[merc_id]
	var c: HuntEconomy.Contract = w.hunt.economy.contracts[1]
	assert_true(w.hunt.request(w, 1, "merc_order", {"order": "hold"}))
	assert_eq(c.hold_at, merc.state.position, "hold where it stands")
	assert_false(w.hunt.request(w, 1, "merc_order", {"order": "dance"}), "unknown orders are refused")
	w.hunt.request(w, 1, "merc_order", {"order": "follow"})
	SimHarness.place(merc, Vector3(12, 0.05, -12), 0.0)  # far away: it must come back
	var spot := brain._station(merc, c, me)
	assert_between(spot.distance_to(me.state.position), 3.0, 6.0, "follows a few metres off")
	# Threats: only hunters who hurt the employer (or anyone near, under DEFEND).
	assert_false(brain._is_threat(w.tick, c, me, rival), "a hunter minding its own business is no threat")
	brain.on_event({"type": "hit", "target": 1, "attacker": 3, "amount": 10.0})
	assert_true(brain._is_threat(w.tick, c, me, rival), "attacking the employer makes a threat")
	# Hired guns don't score.
	var before: int = w.scores.get(merc_id, 0)
	w._kill(rival, merc_id, Weapons.at(Weapons.PULSE), false)
	assert_eq(w.scores.get(merc_id, 0), before, "no points for a mercenary's kill")
	assert_eq(w.hunt.social.bounty.get(merc_id, 0), 0, "and no bounty")
	# Dismissal removes the body.
	assert_true(w.hunt.request(w, 1, "dismiss_merc"))
	await wait_physics_frames(2)
	assert_eq(server.hunt_mercs.size(), 0, "dismissed")
	assert_false(w.players.has(merc_id))


func test_contract_ends_on_employer_death_expiry_and_extraction() -> void:
	var server: ServerSession = await _merc_server()
	var w := server.world
	var me := w.add_player(1, SimHarness.loadout(), "boss", false)
	SimHarness.place(me, Vector3(-4, 0.05, 5), 0.0)
	var e := w.hunt.economy
	e.credits[1] = 1000
	w.hunt.request(w, 1, "hire_mercenary")
	await wait_physics_frames(2)
	w._kill(me, 0, null, false)
	await wait_physics_frames(2)
	assert_false(e.contracts.has(1), "the employer's death ends the contract")
	assert_eq(server.hunt_mercs.size(), 0)
	w.respawn(me)
	w.hunt.request(w, 1, "hire_mercenary")
	await wait_physics_frames(2)
	w.tick = e.contracts[1].expires_tick
	await wait_physics_frames(2)
	assert_false(e.contracts.has(1), "contracts expire")
	w.hunt.request(w, 1, "hire_mercenary")
	await wait_physics_frames(2)
	var t := w.hunt.assignments_of(1)[0]
	SimHarness.place(me, t.position + Vector3(0, 0.05, 0), 0.0)
	await wait_physics_frames(2)
	SimHarness.place(me, ZONE + Vector3(0, 0.05, 0), 0.0)
	await wait_until(func() -> bool: return t.banked, 6.0)
	await wait_physics_frames(2)
	assert_false(e.contracts.has(1), "extracting ends the contract")
	assert_gt(e.credits[1], 0, "and extraction pays credits")


func test_bots_hire_when_it_is_worth_it() -> void:
	var pl := _hunters(2)
	var bot := BotBrain.new(world, null, 2, 1)
	h.grand().available_tick = world.tick + 100000  # the vault is empty for now
	bot._hunt_contracts(pl[1])
	assert_false(h.economy.contracts.has(2), "nothing worth protecting: no contract")
	h.social.add_bounty(world, 2, 60, "test")
	bot._hunt_contracts(pl[1])
	assert_true(h.economy.contracts.has(2), "Wanted: hires protection")
	_carry(pl[1], h.assignments_of(2)[0])
	bot._hunt_contracts(pl[1])
	assert_eq(h.economy.contracts[2].order, HuntEconomy.Order.DEFEND, "defend while carrying")


func test_a_match_reset_dismisses_mercenaries_without_making_them_hunters() -> void:
	var server: ServerSession = await _merc_server()
	var w := server.world
	var me := w.add_player(1, SimHarness.loadout(), "boss", false)
	SimHarness.place(me, Vector3(-4, 0.05, 5), 0.0)
	w.hunt.request(w, 1, "hire_mercenary")
	await wait_physics_frames(2)
	var merc_id: int = server.hunt_mercs.keys()[0]
	w.reset_match(5)
	assert_eq(w.hunt.assignments_of(merc_id).size(), 0, "no assignments for a mercenary body")
	assert_false(w.hunt.economy.credits.has(merc_id), "no credits either")
	await wait_physics_frames(2)
	assert_eq(server.hunt_mercs.size(), 0, "and it is gone after the reset")


# --- Challenge 5: Resource Dispute ---

const CACHE_AT := Vector3(13, 0, 12)  ## open floor, away from the treasure spots


func test_resource_types_are_data() -> void:
	for id: String in HuntResources.IDS:
		assert_true(HuntResources.has(id))
		assert_gt(HuntResources.points(id), 0)
		assert_gt(HuntResources.collect_ticks(id), 60, "collection takes several seconds")
	assert_null(h.spawn_cache(world, "unobtainium", CACHE_AT), "unknown types are refused")


func test_collecting_a_cache_makes_unsecured_cargo() -> void:
	var a: SimPlayer = _hunters()[0]
	var c := h.spawn_cache(world, "helium3", CACHE_AT)
	SimHarness.place(a, CACHE_AT + Vector3(0.5, 0.05, 0), 0.0)
	_step(30)
	assert_eq(c.collector, 0, "standing there isn't collecting: interact starts it")
	_step(1, {1: [Action.INTERACT]})
	assert_eq(c.collector, 1)
	_step(HuntResources.collect_ticks("helium3") - 5)
	assert_null(h.carried_by(1), "still collecting")
	world.drain_events()
	_step(10)
	var t := h.carried_by(1)
	assert_not_null(t, "the load is now carried cargo")
	assert_eq(t.kind, HuntRules.Kind.RESOURCE)
	assert_true(c.empty, "the cache is spent")
	var score: int = world.scores[1]
	assert_eq(score, 0, "nothing counts before extraction")
	var credits: int = h.economy.credits[1]
	_extract(a)
	assert_eq(world.scores[1], HuntResources.points("helium3"), "it counts once extracted")
	assert_eq(h.economy.credits[1], credits + HuntResources.credits("helium3"), "and pays the expedition")
	_extract(a)
	assert_eq(world.scores[1], HuntResources.points("helium3"), "once")


func test_collection_is_interrupted_by_damage_or_leaving() -> void:
	var pl := _hunters()
	var a: SimPlayer = pl[0]
	var c := h.spawn_cache(world, "water_ice", CACHE_AT)
	SimHarness.place(a, CACHE_AT + Vector3(0.5, 0.05, 0), 0.0)
	_step(1, {1: [Action.INTERACT]})
	_step(30)
	world._damage(a, 2, 15.0, false, Weapons.at(Weapons.PULSE), 1)
	world.drain_events()
	_step()
	assert_eq(c.collector, 0, "damage interrupts")
	assert_eq(_events("cache_interrupted").size(), 1, "the collector is told")
	_step(1, {1: [Action.INTERACT]})
	assert_eq(c.collector, 1, "it can be restarted")
	SimHarness.place(a, CACHE_AT + Vector3(6, 0.05, 0), 0.0)
	_step()
	assert_eq(c.collector, 0, "walking away interrupts")
	assert_eq(c.progress, 0, "and progress is lost")


func test_resources_can_be_stolen_like_any_treasure() -> void:
	var pl := _hunters()
	var b: SimPlayer = pl[1]
	var c := h.spawn_cache(world, "rare_ore", CACHE_AT)
	SimHarness.place(b, CACHE_AT + Vector3(0.5, 0.05, 0), 0.0)
	_step(1, {2: [Action.INTERACT]})
	_step(HuntResources.collect_ticks("rare_ore") + 1)
	var t := h.carried_by(2)
	assert_not_null(t)
	_steal(pl[0], b)
	assert_eq(t.carrier, 1, "unsecured cargo can be taken")
	assert_eq(t.stolen_from, 2, "and recovered later")


func test_bots_weigh_caches_against_their_objectives() -> void:
	var pl := _hunters()
	var bot := BotBrain.new(world, null, 2, 1)
	h.grand().available_tick = world.tick + 100000
	for t in h.assignments_of(2):
		t.banked = true  # nothing else to do
	var c := h.spawn_cache(world, "helium3", CACHE_AT)
	assert_eq(bot._hunt_objective(pl[1]), c.position, "an idle bot goes for the cache")
	SimHarness.place(pl[1], CACHE_AT + Vector3(0.5, 0.05, 0), 0.0)
	var presses_before: int = bot._presses[Action.INTERACT]
	bot._hunt_objective(pl[1])
	assert_eq(bot._presses[Action.INTERACT], presses_before + 1, "and presses interact there")
	c.collector = 1  # a healthy rival is collecting it
	SimHarness.place(pl[1], AWAY_B, 0.0)
	assert_ne(bot._hunt_objective(pl[1]), c.position, "no fight over a cache held by a healthy rival")


# --- Challenge 6: Grand Vault Standoff ---

func _unlock_start(p: SimPlayer) -> void:
	SimHarness.place(p, VAULT + Vector3(0.5, 0.05, 0), 0.0)
	_step(1, {p.net_id: [Action.INTERACT]})


func test_vault_announced_locked_and_unlocked_by_interaction() -> void:
	world.drain_events()
	var a: SimPlayer = _hunters()[0]
	h.reset(world)
	assert_eq(_events("vault_open").size(), 1, "every hunter learns the vault is open (and where)")
	var g := h.grand()
	assert_true(g.locked)
	SimHarness.place(a, VAULT + Vector3(0.3, 0.05, 0), 0.0)
	_step(5)
	assert_eq(g.carrier, 0, "touching a locked grand treasure doesn't take it")
	_step(1, {1: [Action.INTERACT]})
	assert_eq(h.vault_unlocker, 1, "interact starts unlocking")
	_step(HuntRules.VAULT_UNLOCK_TICKS)
	assert_false(g.locked, "unlocked")
	_step()
	assert_eq(g.carrier, 1, "then it can be taken: still one contested item")


func test_rivals_can_interrupt_the_unlock() -> void:
	var pl := _hunters()
	_unlock_start(pl[0])
	_step(60)
	world._damage(pl[0], 2, 20.0, false, Weapons.at(Weapons.PULSE), 1)
	world.drain_events()
	_step()
	assert_eq(h.vault_unlocker, 0, "a rival's shot interrupts")
	assert_eq(h.vault_progress, 0)
	assert_eq(_events("vault_interrupted").size(), 1)
	assert_true(h.grand().locked)


func test_allies_share_the_vault_and_cooperation_pays_modestly() -> void:
	var pl := _hunters(3)
	assert_true(h.request(world, 1, "propose_alliance", {"target": 2}))
	assert_true(h.request(world, 2, "respond_alliance", {"accept": true}))
	assert_true(h.social.allied(1, 2))
	assert_true(h.friendly(1, 2) and h.friendly(2, 1), "allies don't target each other")
	assert_false(h.friendly(1, 3), "others are fair game")
	assert_true(world._can_hurt(1, pl[1]), "but anyone can turn on anyone (friendly fire is on)")
	SimHarness.place(pl[1], VAULT + Vector3(3, 0.05, 0), 0.0)  # the ally is inside the vault
	var c1: int = h.economy.credits[1]
	var c2: int = h.economy.credits[2]
	var c3: int = h.economy.credits[3]
	_unlock_start(pl[0])
	_step(HuntRules.VAULT_UNLOCK_TICKS + 1)
	assert_eq(h.economy.credits[1], c1 + HuntRules.VAULT_SHARE_CREDITS / 2, "the unlocker's share")
	assert_eq(h.economy.credits[2], c2 + HuntRules.VAULT_SHARE_CREDITS / 2, "the ally's share")
	assert_eq(h.economy.credits[3], c3, "nothing for outsiders")
	var score2: int = world.scores[2]
	world.tick += HuntSocial.COOPERATION_MIN_TICKS
	_step()
	assert_eq(h.carried_by(1), h.grand(), "the unlocker took the grand treasure")
	_extract(pl[0])
	assert_eq(world.scores[2], score2 + HuntSocial.COOPERATION_BONUS, "a modest bonus for the loyal ally")
	assert_false(h.request(world, 3, "propose_alliance", {"target": 1}), "one alliance per hunter")


func test_bots_cooperate_or_compete_at_the_vault() -> void:
	var pl := _hunters(2)
	var bot := BotBrain.new(world, null, 2, 1)
	# A proposal from a reliable, stronger hunter while we're at the vault: accept.
	SimHarness.place(pl[1], VAULT + Vector3(2, 0.05, 0), 0.0)
	h.request(world, 1, "propose_alliance", {"target": 2})
	bot._hunt_diplomacy(world.tick, pl[1])
	assert_true(h.social.allied(1, 2), "accepted")
	h.social._end_alliance(1)
	# From a hunter with a ruined reputation: reject.
	h.social.reputation[1] = 10
	h.request(world, 1, "propose_alliance", {"target": 2})
	bot._hunt_diplomacy(world.tick, pl[1])
	assert_false(h.social.allied(1, 2), "no deals with a known betrayer")
	# At the locked grand treasure with nobody unlocking: the bot unlocks.
	SimHarness.place(pl[1], VAULT + Vector3(0.5, 0.05, 0), 0.0)
	var before: int = bot._presses[Action.INTERACT]
	bot._vault_move(pl[1], h.grand())
	assert_eq(bot._presses[Action.INTERACT], before + 1, "interacts to unlock")


# --- Challenge 7: Double-Cross ---

func _ally(a: int, b: int) -> void:
	h.request(world, a, "propose_alliance", {"target": b})
	h.request(world, b, "respond_alliance", {"accept": true})


func test_betrayal_removes_protection_at_once_with_consequences() -> void:
	var pl := _hunters(2)
	_ally(1, 2)
	world.drain_events()
	assert_true(h.request(world, 1, "betray_alliance"))
	assert_false(h.social.allied(1, 2), "protection ends immediately")
	assert_true(world._can_hurt(1, pl[1]), "the betrayer can fire at once")
	assert_eq(h.social.rep_of(1), HuntSocial.START_REPUTATION - HuntSocial.BETRAYAL_REPUTATION, "reputation penalty")
	assert_true(h.social.is_wanted(1), "and a bounty")
	var alert := world.drain_events().filter(func(e: Dictionary) -> bool: return e.type == "hunt" and e.action == "alliance_betrayed")
	assert_eq(alert.size(), 1)
	assert_eq(alert[0].player, 1, "the alert names the betrayer")
	assert_eq(alert[0].target, 2, "to the betrayed")
	assert_eq(h.social.rep_of(2), HuntSocial.START_REPUTATION, "the betrayed loses nothing")


func test_leaving_peacefully_keeps_protection_briefly_and_costs_nothing() -> void:
	var pl := _hunters(2)
	_ally(1, 2)
	assert_true(h.request(world, 1, "leave_alliance"))
	_step(HuntSocial.DISSOLVE_GRACE_TICKS - 10)
	assert_true(h.friendly(1, 2), "still allies during the notice")
	_step(20)
	assert_false(h.social.allied(1, 2), "then it ends")
	assert_eq(h.social.rep_of(1), HuntSocial.START_REPUTATION, "no penalty for leaving honestly")
	assert_false(h.social.is_wanted(1))
	assert_false(h.request(world, 1, "betray_alliance"), "nothing left to betray")


func test_proposals_expire_and_need_an_answer() -> void:
	_hunters(2)
	h.request(world, 1, "propose_alliance", {"target": 2})
	assert_false(h.social.allied(1, 2), "not allied by proposing")
	world.tick += HuntSocial.PROPOSAL_TICKS + 1
	_step()
	assert_false(h.social.proposals.has(2), "expired")
	assert_false(h.request(world, 2, "respond_alliance", {"accept": true}), "too late to accept")


func test_bots_honour_alliances_unless_a_defined_reason_holds() -> void:
	var pl := _hunters(2)
	var bot := BotBrain.new(world, null, 2, 1)
	_ally(1, 2)
	# The ally carries its own treasure, healthy: honour.
	_carry(pl[0], h.assignments_of(1)[0])
	SimHarness.place(pl[1], pl[0].state.position + Vector3(3, 0, 0), 0.0)
	for i in 5:
		bot._keep_or_break(world.tick, pl[1])
	assert_true(h.social.allied(1, 2), "no betrayal without a reason")
	# The ally carries the grand treasure, badly hurt, the bot healthy and behind on points: betray.
	h._drop(world, pl[0])
	var g := h.grand()
	g.locked = false
	g.carrier = 1
	pl[0].state.shield = 0.0
	pl[0].state.health = 40.0
	world.scores[1] = 300
	bot._keep_or_break(world.tick, pl[1])
	assert_false(h.social.allied(1, 2), "a defined, observable reason: betrayal")
	assert_eq(bot.target_id, 1, "and it goes for the cargo")
	# A far-away ally for long enough: leave peacefully, no penalty.
	var bot3 := BotBrain.new(world, null, 3, 1)
	var c := world.add_player(3, SimHarness.loadout(), "h3", true)
	inputs[3] = SimHarness.CommandScript.new()
	_ally(1, 3)
	SimHarness.place(c, Vector3(15, 0.05, -15), 0.0)
	SimHarness.place(pl[0], Vector3(-15, 0.05, 15), 0.0)
	h.social._end_alliance(1)
	h.social.allies[1] = 3
	h.social.allies[3] = 1
	SimHarness.place(c, pl[0].state.position + Vector3(70, 0, 0), 0.0)
	bot3._keep_or_break(world.tick, c)
	world.tick += BotBrain.HUNT_ALLY_FAR_TICKS + 1
	bot3._keep_or_break(world.tick, c)
	assert_true(h.social.dissolving.has(3), "leaves an alliance that no longer helps")
	assert_eq(h.social.rep_of(3), HuntSocial.START_REPUTATION)


# --- Challenge 8: Informant ---

func test_intel_costs_credits_and_carries_time_and_confidence() -> void:
	var pl := _hunters(2)
	var credits: int = h.economy.credits[1]
	assert_false(h.request(world, 1, "buy_intel", {"kind": "cache_clue"}), "no cache: nothing to sell")
	assert_eq(h.economy.credits[1], credits, "and no charge")
	var c := h.spawn_cache(world, "rare_ore", CACHE_AT)
	assert_true(h.request(world, 1, "buy_intel", {"kind": "cache_clue"}))
	assert_eq(h.economy.credits[1], credits - HuntEconomy.INTEL.cache_clue.cost, "paid")
	var r: Dictionary = h.economy.intel_of(1, world.tick)[0]
	assert_eq(r.tick, world.tick, "timestamped")
	assert_almost_eq(float(r.confidence), 0.9, 0.001, "with a confidence")
	assert_lte(Vector2(r.position.x - c.position.x, r.position.z - c.position.z).length(), 3.01, "close, fuzzed")
	c.empty = true
	assert_false(h.intel_useful(r, world.tick), "useless once the cache is gone")
	assert_false(h.request(world, 1, "buy_intel", {"kind": "nonsense"}))


func test_rival_intel_is_fuzzed_prefers_carriers_and_expires() -> void:
	var pl := _hunters(3)
	_carry(pl[2], h.assignments_of(3)[0])
	assert_true(h.request(world, 1, "buy_intel", {"kind": "rival_position"}))
	var r: Dictionary = h.economy.intel_of(1, world.tick)[0]
	assert_eq(r.subject, 3, "the rival carrying cargo, over a closer empty-handed one")
	assert_true(r.carrying)
	var off := Vector2(r.position.x - pl[2].state.position.x, r.position.z - pl[2].state.position.z).length()
	assert_between(off, 12.0 * 0.4 - 0.01, 12.01, "approximate")
	world.tick = int(r.expires)
	assert_eq(h.economy.intel_of(1, world.tick).size(), 0, "expired")


func test_allies_share_intel_and_vault_status_reports_truthfully() -> void:
	_hunters(2)
	_ally(1, 2)
	assert_true(h.request(world, 1, "buy_intel", {"kind": "vault_status"}))
	var mine: Dictionary = h.economy.intel_of(1, world.tick)[0]
	assert_eq(h.economy.intel_of(2, world.tick).size(), 1, "the ally gets a copy")
	assert_true(mine.locked, "the vault is reported locked")
	assert_eq(int(mine.unlocking), 0)


func test_bots_buy_intel_when_idle_and_use_it_not_live_positions() -> void:
	var pl := _hunters(3)
	var bot := BotBrain.new(world, null, 2, 1)
	var credits: int = h.economy.credits[2]
	_carry(pl[2], h.assignments_of(3)[0])
	assert_eq(bot._intel_lead(pl[1]), Vector3.INF, "first it buys (nothing known yet)")
	assert_lt(h.economy.credits[2], credits, "paid for intel")
	var r: Dictionary = h.economy.intel_of(2, world.tick)[0]
	assert_eq(bot._intel_lead(pl[1]), r.position, "then follows the report, not the live position")
	assert_ne(r.position, pl[2].state.position)


# --- Nations, squads and friendly fire (docs/game-plan.md) ---

func test_nations_seat_every_hunter_and_squad_the_human() -> void:
	var seats := Nations.seat([1, 1000, 1001, 1002, 1003, 1004], {1: 2}, 77)
	assert_eq(seats[1], 2, "the human keeps their nation")
	assert_eq(seats[1000], 2, "the first AI is the human's squadmate")
	var counts := {}
	for id: int in seats:
		counts[seats[id]] = int(counts.get(seats[id], 0)) + 1
	assert_eq(counts.size(), 4, "all four nations take part")
	assert_eq(Nations.seat([1, 1000, 1001, 1002, 1003, 1004], {1: 2}, 77), seats, "the same seed seats the same way")
	assert_ne(Nations.seat([1, 1000, 1001, 1002, 1003, 1004], {1: 2}, 78), seats, "another run, other rivals")


func test_a_runs_squads_start_allied() -> void:
	var pl := _hunters(3)
	h.home_nations = {1: 0}
	h.reset(world)
	var mate: int = h.social.allies.get(1, 0)
	assert_ne(mate, 0, "the human starts with a squadmate")
	assert_eq(h.nation_of(mate), 0, "of their own nation")
	assert_true(h.social.is_squad(1))
	assert_true(h.friendly(1, mate))
	assert_eq(pl.size(), 3)


func test_friendly_fire_warns_then_turns() -> void:
	var pl := _hunters(2)
	h.social.form(world, 1, 2)
	world.drain_events()
	world._damage(pl[1], 1, 10.0, false, Weapons.at(Weapons.PULSE), 1)
	assert_true(h.social.allied(1, 2), "a stray hit is only a warning")
	assert_eq(_events("friendly_fire").size(), 1)
	world._damage(pl[1], 1, 40.0, false, Weapons.at(Weapons.PULSE), 2)
	assert_false(h.social.allied(1, 2), "keep shooting and you've turned on them")
	var turned := _events("alliance_betrayed")
	assert_eq(turned.size(), 1)
	assert_eq(turned[0].player, 1, "the shooter is the betrayer")
	assert_eq(turned[0].reason, "fire")
	assert_true(turned[0].squad)
	assert_true(h.social.is_wanted(1), "with a bounty")


func test_a_squadmate_the_run_forbids_never_turns() -> void:
	var pl := _hunters(2)
	h.social.form(world, 1, 2)
	h.personalities[2] = "ambitious"
	h.may_turn[2] = false
	var brain := BotBrain.new(world, null, 2, 1)
	pl[0].state.health = 10.0
	pl[0].state.shield = 0.0
	pl[1].state.health = 100.0
	pl[1].state.shield = 100.0
	SimHarness.place(pl[1], pl[0].state.position + Vector3(3, 0, 0), 0.0)
	h.grand().carrier = 1  # the prize, on a beaten partner, late in the run
	brain._keep_or_break(world.tick, pl[1])
	assert_true(h.social.allied(1, 2), "the career said not this run")
	h.may_turn[2] = true
	h.personalities[2] = "loyal"
	brain._keep_or_break(world.tick, pl[1])
	assert_true(h.social.allied(1, 2), "the loyal never turn first")
	h.grudges[2] = true
	brain._keep_or_break(world.tick, pl[1])
	assert_false(h.social.allied(1, 2), "but a grudge is settled")
