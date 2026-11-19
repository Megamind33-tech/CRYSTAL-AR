extends GutTest
## Squads (HuntSquad): a hunter's AI teammates take orders, rules and plans;
## they never hurt their leader or each other; they carry the leader's cargo
## out and the points bank to the leader; the medic heals, the engineer
## speeds the leader's work, the scout marks rivals.

const SPOTS := [Vector3(-12, 0, 0), Vector3(12, 0, 0), Vector3(-8, 0, -15), Vector3(8, 0, -15)]
const ZONE := Vector3(0, 0, 16)
const VAULT := Vector3(-8, 0, 16)
const LEADER := 1
const RIVAL := 2
const MATE_A := 2001
const MATE_B := 2002

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
	h.configure({"treasure_spots": SPOTS, "extraction_zones": [ZONE], "vault": VAULT}, world.match_seed)
	inputs = {}
	for id in [LEADER, RIVAL]:
		var p := world.add_player(id, SimHarness.loadout(), "h%d" % id, id != LEADER)
		SimHarness.place(p, Vector3(-4 + id * 4, 0.05, 5), 0.0)
		p.state.spawn_protection_ticks = 0
		inputs[id] = SimHarness.CommandScript.new()
	assert_true(h.squad.form(world, LEADER, ["medic", "engineer"]))
	# The server's part: a body for each teammate.
	var ids := [MATE_A, MATE_B]
	for i in h.squad.pending.size():
		h.squad.bind(h.squad.pending[i], ids[i])
		var p := world.add_player(ids[i], SimHarness.loadout(), "mate%d" % i, true)
		SimHarness.place(p, Vector3(-6 + i * 2, 0.05, 7), 0.0)
		inputs[ids[i]] = SimHarness.CommandScript.new()
	h.squad.pending.clear()
	world.drain_events()


func _step(ticks: int = 1) -> void:
	for i in ticks:
		var cmds := {}
		for id: int in inputs:
			cmds[id] = inputs[id].cmd(world.tick, Vector2.ZERO, 0, [])
		world.step(cmds)


func test_teammates_are_on_the_leaders_side_only() -> void:
	assert_true(h.protects(LEADER, MATE_A), "leader and teammate")
	assert_true(h.protects(MATE_A, MATE_B), "teammates")
	assert_false(h.protects(RIVAL, MATE_A), "a rival is fair game")
	assert_true(h.friendly(MATE_B, LEADER))
	assert_true(h.assignments_of(MATE_A).is_empty(), "teammates are no hunters: no assignments")
	assert_false(h.economy.credits.has(MATE_A), "and no credits")


func test_orders_rules_and_plans() -> void:
	var sq := h.squad.squad_of(LEADER)
	assert_true(h.request(world, LEADER, "squad_order", {"order": "hold", "role": "medic"}))
	var medic: HuntSquad.Member = h.squad.by_id[MATE_A]
	var eng: HuntSquad.Member = h.squad.by_id[MATE_B]
	assert_eq(medic.order, HuntSquad.Order.HOLD, "the medic holds")
	assert_eq(medic.hold_at, world.players[MATE_A].state.position, "where it stands")
	assert_eq(eng.order, HuntSquad.Order.FOLLOW, "the engineer wasn't told")
	assert_true(h.request(world, LEADER, "squad_rule", {"rule": "weapons_free"}))
	assert_eq(sq.rule, HuntSquad.Rule.WEAPONS_FREE)
	assert_true(h.request(world, LEADER, "squad_strategy", {"strategy": "turtle"}))
	assert_eq(sq.rule, HuntSquad.Rule.RETURN_FIRE, "a plan sets the rule")
	assert_eq(eng.order, HuntSquad.Order.GUARD_PAD, "and each role's order")
	assert_eq(medic.order, HuntSquad.Order.ESCORT)
	assert_false(h.request(world, RIVAL, "squad_order", {"order": "follow"}), "no squad, no orders")
	assert_false(h.request(world, LEADER, "squad_order", {"order": "dance"}), "orders are checked")


func test_a_teammate_carries_the_leaders_cargo_out_for_them() -> void:
	var cargo: HuntRules.Treasure = h.assignments_of(LEADER)[0]
	var mate: SimPlayer = world.players[MATE_B]
	world.teleport(mate, cargo.position + Vector3(0, 0.05, 0))
	_step(2)
	assert_eq(cargo.carrier, MATE_B, "picked up the leader's cargo")
	var rivals_cargo: HuntRules.Treasure = h.assignments_of(RIVAL)[0]
	world.teleport(world.players[MATE_A], rivals_cargo.position + Vector3(0, 0.05, 0))
	_step(2)
	assert_ne(rivals_cargo.carrier, MATE_A, "not a rival's: teammates don't steal")
	var before: int = world.scores.get(LEADER, 0)
	world.teleport(mate, ZONE + Vector3(0, 0.05, 0))
	_step(HuntRules.EXTRACT_TICKS + 5)
	assert_true(cargo.banked, "extracted")
	assert_eq(world.scores.get(LEADER, 0) - before, HuntRules.OWN_POINTS, "the points are the leader's")
	assert_eq(world.scores.get(MATE_B, 0), 0, "not the teammate's")
	assert_false((h.haul.get(LEADER, []) as Array).is_empty(), "the haul is the leader's")


func test_the_medic_heals_and_the_engineer_helps() -> void:
	var lead: SimPlayer = world.players[LEADER]
	world.teleport(world.players[MATE_A], lead.state.position + Vector3(1.5, 0, 0))
	world.teleport(world.players[MATE_B], lead.state.position + Vector3(-1.5, 0, 0))
	lead.state.health = 40.0
	_step(int(HuntSquad.ROLES.medic.heal_every) + 1)
	assert_gt(lead.state.health, 40.0, "patched up")
	assert_eq(h.squad.work_bonus(world, LEADER), 1, "an engineer beside the leader")
	world.teleport(world.players[MATE_B], lead.state.position + Vector3(20, 0, 0))
	assert_eq(h.squad.work_bonus(world, LEADER), 0, "not from across the yard")


func test_a_fallen_teammate_leaves_the_squad() -> void:
	h.squad.on_death(world, MATE_A)
	assert_false(h.squad.is_member(MATE_A))
	assert_true(MATE_A in h.squad.pending_dismissals, "its body goes")
	assert_eq(h.squad.squad_of(LEADER).members.size(), 1)


func test_the_career_keeps_and_pays_for_the_squad() -> void:
	var c := Career.new()
	assert_true(c.squad_add("gunner"))
	assert_true(c.squad_add("scout"))
	assert_true(c.squad_add("medic"))
	assert_false(c.squad_add("engineer"), "three at most")
	assert_false(c.squad_add("dancer"), "only real roles")
	c.d.wallet = Career.SQUAD_COST * 2
	assert_eq(c.squad_deploy(), ["gunner", "scout"], "as many as the wallet pays for")
	assert_eq(int(c.d.wallet), 0)


func test_marks_moves_plans_and_abilities() -> void:
	var medic: HuntSquad.Member = h.squad.by_id[MATE_A]
	assert_true(h.request(world, LEADER, "squad_order", {"order": "attack", "target": RIVAL}))
	assert_eq(medic.target, RIVAL, "after the mark")
	var spot := Vector3(10, 0, -10)
	assert_false(h.request(world, LEADER, "squad_order", {"order": "move"}), "a move needs somewhere")
	assert_true(h.request(world, LEADER, "squad_order", {"order": "move", "point": spot}))
	assert_eq(medic.hold_at, spot, "to where you aimed")
	assert_true(h.request(world, LEADER, "squad_strategy", {"strategy": "gather"}))
	assert_eq(h.squad.squad_of(LEADER).rule, HuntSquad.Rule.HOLD_FIRE)
	# Abilities: a drop to where you aim, a supply crate, a scan; then cooldowns.
	assert_true(h.request(world, LEADER, "squad_ability", {"ability": "drop", "point": spot}))
	assert_lt(world.players[MATE_A].state.position.distance_to(spot), 4.0, "dropped there")
	assert_false(h.request(world, LEADER, "squad_ability", {"ability": "drop", "point": spot}), "cooling down")
	var lead: SimPlayer = world.players[LEADER]
	lead.state.health = 30.0
	assert_true(h.request(world, LEADER, "squad_ability", {"ability": "supply"}))
	assert_gt(lead.state.health, 30.0, "patched up by the crate")
	world.teleport(world.players[RIVAL], lead.state.position + Vector3(20, 0.05, 0))
	assert_true(h.request(world, LEADER, "squad_ability", {"ability": "scan"}))
	assert_true(h.is_revealed(RIVAL, world.tick), "the scan shows the rival")


func test_people_make_a_squad() -> void:
	var w := world
	var p := w.add_player(7, SimHarness.loadout(), "p7", false)
	SimHarness.place(p, Vector3(8, 0.05, 5), 0.0)
	assert_true(h.request(w, LEADER, "squad_invite", {"target": 7}))
	assert_false(h.friendly(LEADER, 7), "not before they accept")
	assert_true(h.request(w, 7, "squad_answer", {"accept": true}))
	assert_eq(h.squad.human_leader(7), LEADER)
	assert_true(h.friendly(LEADER, 7), "squad mates never hurt each other")
	assert_false(h.friendly(7, RIVAL))
	assert_true(h.request(w, LEADER, "squad_order", {"order": "hold", "point": Vector3(1, 0, 1)}), "a leader of people orders")
	assert_eq(h.squad.calls[LEADER].order, "hold")
	assert_eq(h.private_state(w, 7).get("leader"), LEADER, "the member's phone knows its leader")
	assert_false(h.request(w, 7, "squad_answer", {"accept": true}), "no invitation left")
	assert_true(h.request(w, 7, "squad_leave"))
	assert_false(h.friendly(LEADER, 7))
