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


func test_red_dust_trade_chain_orders_and_dealers() -> void:
	var c := _rich()
	assert_true(c.chain_advance(NOW), "Sable fronts the work")
	assert_eq(int(c.d.stash.get("red_dust", 0)), Career.CHAIN_SELL)
	assert_eq((c.trade().clients as Dictionary).size(), 3, "and three names")
	assert_false(c.chain_advance(NOW), "sell them first")
	var o := c.next_order(NOW, 0.1)
	assert_false(o.is_empty(), "a client texts an order")
	assert_true(c.next_order(NOW + 5, 0.5).is_empty(), "not straight after")
	var wallet: int = c.d.wallet
	var pay := c.deliver(0, NOW + 30)
	assert_gt(pay, 0, "hand it over, get paid")
	assert_eq(int(c.d.wallet), wallet + pay)
	c.receive("red_dust", 10)
	c.trade().sold = Career.CHAIN_SELL
	assert_true(c.chain_advance(NOW))
	assert_eq(c.mix("dust_frost", 3), 0, "the cuts aren't known yet")
	c.receive("water_ice", 5)
	assert_true(c.chain_advance(NOW), "the ice buys the cuts")
	assert_eq(c.mix("dust_frost", 3), 3)
	assert_gt(c.dust_price("dust_frost", "lena"), c.dust_price("red_dust", "lena"), "a cut is worth more, most to who likes it")
	# Missed orders go cold.
	c.trade().orders = [{"client": "mags", "variant": "red_dust", "count": 1, "due": NOW}]
	var before: int = c.trade().clients.mags.loyalty
	assert_eq(c.expire_orders(NOW + 1), 1)
	assert_lt(int(c.trade().clients.mags.loyalty), before)
	# The turf, then dealers from the crew.
	c.won_turf()
	assert_eq(c.chain_step(), 4)
	assert_eq((c.trade().clients as Dictionary).size(), Career.CLIENTS.size(), "everyone knows you now")
	c.form_gang("Phobos Cartel")
	var who := c.recruit()
	assert_true(c.set_dealer("galleria", who, NOW))
	assert_gt(c.supply_dealer("galleria", "red_dust", 20), 0)
	wallet = c.d.wallet
	var got := c.settle_dealers(NOW + DAY + 1, [0.9])
	assert_gt(int(got.cash), 0, "a sol's sales, less the dealer's cut")
	assert_eq(int(c.d.wallet), wallet + int(got.cash))
	got = c.settle_dealers(NOW + DAY * 2 + 1, [0.01])
	assert_true("galleria" in got.robbed, "and sometimes they're robbed")
	# A search takes it all.
	c.receive("dust_bloom", 2)
	assert_gt(c.confiscate(), 0)
	assert_false(c.carrying_dust())


func test_heist_in_stages() -> void:
	var c := _rich()
	assert_true(c.plan_heist("ring", NOW))
	assert_false(c.heist_ready())
	assert_false(c.choose_approach("loud", NOW, false), "preps first")
	for p: String in ["codes", "intel", "ride"]:
		assert_true(c.heist_prep(p))
	assert_false(c.heist_prep("codes"), "done once")
	assert_true(c.heist_ready())
	assert_eq(c.approach_blocker("loud", NOW, false), "item", "loud needs armour")
	assert_eq(c.approach_blocker("con", NOW, false), "visa", "a con needs Helios papers")
	c.receive("mask", 1)
	assert_eq(c.approach_blocker("quiet", NOW, false), "night", "quiet waits for dark")
	assert_true(c.choose_approach("quiet", NOW, true))
	assert_eq(c.heist_payout(NOW), 0, "no bonds, no pay")
	c.form_gang("Valles Vipers")
	c.recruit()
	c.recruit()
	c.receive("ring_bonds", 1)
	var wallet: int = c.d.wallet
	var pay := c.heist_payout(NOW)
	var take := roundi(Career.HEISTS.ring.take * Career.HEIST_APPROACHES.quiet.mult)
	assert_eq(pay, roundi(take * (1.0 - 2 * Career.CREW_CUT)), "the crew take their shares")
	assert_eq(int(c.d.wallet), wallet + pay)
	assert_false(c.plan_heist("ring", NOW + 10), "the Ring is on alert after")


func test_marsnet_fame_and_partner() -> void:
	var c := _rich()
	assert_eq(c.fame_tier(), 0)
	for i in 50:
		c.post("x", "y", 1, NOW + i, 1)
	assert_eq((c.d.feed as Array).size(), Career.FEED_MAX, "the feed keeps the latest")
	assert_eq(c.fame_tier(), 1, "fame climbs the tiers")
	assert_false(c.partner_met())
	c.meet_partner(NOW)
	assert_true(c.next_invite(NOW, 0.1).is_empty(), "she doesn't text straight away")
	var inv := c.next_invite(NOW + 200, 0.6)
	assert_false(inv.is_empty())
	var b := c.bond()
	c.hung_out(NOW + 210)
	assert_gt(c.bond(), b, "turning up grows the bond")
	c.next_invite(NOW + 210 + Career.INVITE_EVERY + 1, 0.2)
	b = c.bond()
	assert_true(c.invite_lapsed(NOW + 210 + Career.INVITE_EVERY + Career.INVITE_TIME + 5))
	assert_lt(c.bond(), b, "standing her up costs")


func test_cosmetics_and_season() -> void:
	var c := _rich()
	assert_true(c.owns_cosmetic("emote_dance"), "a couple of emotes to start")
	assert_false(c.equip_cosmetic("suit_gold"), "you can't wear what you don't own")
	assert_false(c.buy_cosmetic("suit_gold"), "season looks aren't for sale")
	var wallet: int = c.d.wallet
	assert_true(c.buy_cosmetic("suit_crimson"))
	assert_eq(int(c.d.wallet), wallet - int(Career.COSMETICS.suit_crimson.price))
	assert_true(c.equip_cosmetic("suit_crimson"))
	assert_eq(c.equipped("suit"), "suit_crimson")
	assert_true(c.equip_cosmetic("suit_crimson"))
	assert_eq(c.equipped("suit"), "", "again takes it off")
	assert_eq(c.season_tier(), 0)
	assert_true(c.claim_season(1).is_empty(), "not reached")
	c.add_xp(Career.XP_PER_TIER * 5)
	assert_eq(c.season_tier(), 5)
	var r := c.claim_season(5)
	assert_eq(r.get("cosmetic", ""), "suit_onyx", "tier 5 is the Onyx suit")
	assert_true(c.owns_cosmetic("suit_onyx"))
	assert_true(c.claim_season(5).is_empty(), "once")
	wallet = c.d.wallet
	assert_true(c.claim_season(1).has("cash"))
	assert_gt(int(c.d.wallet), wallet)
	# Nothing cosmetic gives an edge: every cosmetic is a look.
	for id: String in Career.COSMETICS:
		assert_true(Career.COSMETICS[id].kind in ["suit", "flame", "paint", "title", "emote"])


## The jet is retired: a save that owned one gets the rotorcraft and the
## difference in price back; the rotorcraft is the only aircraft for sale.
func test_retired_jet_becomes_the_rotorcraft() -> void:
	var fliers := range(VehicleSim.MODELS.size()).filter(func(i: int) -> bool: return VehicleSim.flies(i))
	assert_eq(fliers.size(), 1, "one aircraft: the rotorcraft")
	var c := Career.new()
	var d: Dictionary = c.d.duplicate(true)
	d["aircraft"] = VehicleSim.MODELS.size()  # the jet's old slot
	d["wallet"] = 100
	var old := Career.new(d)
	assert_eq(int(old.d.aircraft), fliers[0])
	assert_eq(int(old.d.wallet), 100 + VehicleSim.RETIRED_JET_PRICE - int(VehicleSim.MODELS[fliers[0]].price))
