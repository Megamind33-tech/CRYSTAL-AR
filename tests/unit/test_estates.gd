extends GutTest
## Free roam's holdings and papers (Career): visas, property to rent or
## own (rent each sol, businesses' takings), aircraft (a licence first),
## the gang (form, recruit, respect, ranks). And an aircraft flies.

const DAY := int(GameClock.DAY_SECONDS)
const NOW := 1_000_000


func _rich() -> Career:
	var c := Career.new()
	c.d.wallet = 200000
	return c


func test_visas_are_bought_and_run_out() -> void:
	var c := _rich()
	assert_false(c.has_visa("flight", NOW))
	assert_true(c.buy_visa("flight", NOW))
	assert_true(c.has_visa("flight", NOW + DAY))
	assert_false(c.has_visa("flight", NOW + DAY * 11), "ten sols, then it's gone")
	assert_true(c.buy_visa("flight", NOW + DAY), "extending adds to what's left")
	assert_true(c.has_visa("flight", NOW + DAY * 15))
	var poor := Career.new()
	poor.d.wallet = 10
	assert_false(poor.buy_visa("helios", NOW), "papers cost money")


func test_property_rent_and_buy() -> void:
	var c := _rich()
	assert_false(c.rent_property("helios_spire", NOW), "Helios needs a residency visa")
	assert_eq(c.property_blocker("helios_spire", NOW), "helios")
	assert_true(c.rent_property("terrace_tower", NOW), "the Terrace doesn't")
	assert_true(c.has_property("terrace_tower", NOW + 10))
	var before: int = c.d.wallet
	c.settle_property(NOW + DAY * 3 + 5)
	assert_eq(before - int(c.d.wallet), 3 * int(Career.PROPERTIES.terrace_tower.rent), "rent comes out each sol")
	assert_true(c.has_property("terrace_tower", NOW + DAY * 3 + 5))
	c.d.wallet = 0
	var out := c.settle_property(NOW + DAY * 6)
	assert_true("terrace_tower" in out.evicted, "no rent: you're out")
	assert_false(c.has_property("terrace_tower", NOW + DAY * 6))
	c.d.wallet = 200000
	c.buy_visa("helios", NOW)
	assert_true(c.buy_property("helios_spire", NOW))
	assert_true(c.property_owned("helios_spire"))
	before = c.d.wallet
	c.settle_property(NOW + DAY * 30)
	assert_eq(int(c.d.wallet), before, "owned homes cost nothing after")


func test_businesses_pay_every_sol() -> void:
	var c := _rich()
	assert_false(c.buy_property("galleria_unit_a", NOW), "a business needs a work visa")
	c.buy_visa("work", NOW)
	assert_true(c.buy_property("galleria_unit_a", NOW))
	var before: int = c.d.wallet
	var out := c.settle_property(NOW + DAY * 2 + 1)
	assert_eq(int(out.income), 2 * int(Career.PROPERTIES.galleria_unit_a.income))
	assert_eq(int(c.d.wallet) - before, int(out.income))
	assert_eq(int(c.settle_property(NOW + DAY * 2 + 30).income), 0, "paid once a sol")


func test_aircraft_need_a_licence() -> void:
	var c := _rich()
	var vtol := -1
	for i in VehicleSim.MODELS.size():
		if VehicleSim.MODELS[i].get("fly", "") == "vtol":
			vtol = i
	assert_gt(vtol, 0)
	assert_false(c.buy_ride(vtol), "Kasei Motors doesn't sell aircraft")
	assert_false(c.buy_aircraft(vtol, NOW), "no licence, no aircraft")
	c.buy_visa("flight", NOW)
	assert_true(c.buy_aircraft(vtol, NOW))
	assert_eq(int(c.d.aircraft), vtol)


func test_gang_ranks_and_crew() -> void:
	var c := _rich()
	assert_false(c.in_gang())
	assert_eq(c.recruit(), "", "no gang, no crew")
	assert_true(c.form_gang("Phobos Cartel"))
	assert_eq(c.gang_slots(), 2)
	assert_ne(c.recruit(), "")
	assert_ne(c.recruit(), "")
	assert_eq(c.recruit(), "", "a street crew holds two")
	assert_true(c.gang_respect(120), "respect lifts the rank")
	assert_eq(Career.GANG_RANKS[c.gang_rank()][0], "Runners")
	assert_ne(c.recruit(), "", "and a bigger crew")
	var job_respect: int = c.d.gang.respect
	c.d.job = {"id": "salvage"}
	c.finish_job()
	assert_gt(int(c.d.gang.respect), job_respect, "a job done earns respect")


func test_a_vtol_climbs_and_hovers() -> void:
	add_child_autofree(SimHarness.make_arena())
	var world := SimHarness.make_world()
	add_child_autofree(world)
	await wait_physics_frames(2)
	var p := world.add_player(1, SimHarness.loadout(), "pilot", false)
	var input := SimHarness.CommandScript.new()
	SimHarness.place(p, Vector3(0, 0.05, 16.5), 0.0)
	for i in 10:
		world.step({1: input.cmd(world.tick, Vector2.ZERO, 0, [])})
	var v := world.add_vehicle(p.state.position, 0.0)
	var vtol := 0
	for i in VehicleSim.MODELS.size():
		if VehicleSim.MODELS[i].get("fly", "") == "vtol":
			vtol = i
	v.model = vtol
	v.driver = 1
	p.state.vehicle = world.vehicles.size() - 1
	p.state.vehicle_model = vtol
	var ground := p.state.position.y
	for i in 120:  # two seconds of climb
		world.step({1: input.cmd(world.tick, Vector2.ZERO, PlayerCommand.Held.JUMP, [])})
	var up := p.state.position.y
	assert_gt(up - ground, 10.0, "it lifts straight up")
	for i in 120:  # let go: it hovers
		world.step({1: input.cmd(world.tick, Vector2.ZERO, 0, [])})
	assert_almost_eq(p.state.velocity.y, 0.0, 0.5, "and holds its height")
	assert_gt(p.state.position.y, up - 3.0)


func test_bounty_board_alive_or_dead() -> void:
	var c := _rich()
	var wallet: int = c.d.wallet
	assert_true(c.take_bounty("kroll", NOW))
	assert_false(c.take_bounty("orlov", NOW), "one bounty at a time")
	assert_eq(c.claim_bounty(false, NOW), 0, "dead needs the proof")
	c.receive("bounty_proof", 1)
	var pay := c.claim_bounty(false, NOW)
	assert_eq(pay, int(Career.BOUNTIES.kroll.reward))
	assert_eq(int(c.d.wallet), wallet + pay)
	assert_false(c.take_bounty("kroll", NOW + 10), "back on the board later")
	assert_true(c.take_bounty("kroll", NOW + Career.BOUNTY_COOLDOWN + 1))
	assert_eq(c.claim_bounty(true, NOW + Career.BOUNTY_COOLDOWN + 5), roundi(Career.BOUNTIES.kroll.reward * Career.BOUNTY_ALIVE),
			"alive pays more")
	for id: String in Career.BOUNTIES:
		assert_true(WorldLayout.BOUNTY_HIDEOUTS.has(id), "%s has a hideout" % id)
