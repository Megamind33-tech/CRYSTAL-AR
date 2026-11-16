extends GutTest
## THE HUNT's packs and robbery: hold-ups need the edge, goods move between
## packs, the dead drop theirs, a rover's hold is reached from behind (no
## boarding there), and the shops and guns in the career.


func _state(at: Vector3, yaw: float, health: float = 100.0, shield: float = 0.0) -> PlayerSimState:
	var s := PlayerSimState.new()
	s.alive = true
	s.position = at
	s.yaw = yaw
	s.health = health
	s.shield = shield
	return s


func test_hold_up_needs_the_edge() -> void:
	# yaw 0 faces -Z. The robber at the origin aims down -Z at the victim 3 m off.
	var robber := _state(Vector3.ZERO, 0.0, 100.0, 50.0)
	var hurt := _state(Vector3(0, 0, -3), PI, 30.0)  # facing the robber, badly hurt
	assert_true(Robbery.can_hold_up(robber, hurt), "badly hurt: they give up")
	var healthy := _state(Vector3(0, 0, -3), PI, 100.0)
	assert_false(Robbery.can_hold_up(robber, healthy), "healthy and facing you: no")
	var turned := _state(Vector3(0, 0, -3), 0.0, 60.0)  # facing away
	assert_true(Robbery.can_hold_up(robber, turned), "caught from behind, you much stronger")
	var strong_turned := _state(Vector3(0, 0, -3), 0.0, 100.0, 50.0)
	assert_false(Robbery.can_hold_up(robber, strong_turned), "behind, but as strong as you")
	assert_false(Robbery.can_hold_up(_state(Vector3.ZERO, PI * 0.5), hurt), "not aiming at them")
	assert_false(Robbery.can_hold_up(robber, _state(Vector3(0, 0, -8), PI, 20.0)), "too far")
	var down := _state(Vector3(0, 0, -3), PI, 20.0)
	down.alive = false
	assert_false(Robbery.can_hold_up(robber, down), "the dead are searched, not held up")


func test_goods_move_between_packs() -> void:
	var a := {"scrap": 3, "helium3": 1}
	var b := {"scrap": 1}
	assert_eq(Robbery.take(a, b, "scrap", 2), 2)
	assert_eq(a, {"scrap": 1, "helium3": 1})
	assert_eq(b, {"scrap": 3})
	assert_eq(Robbery.take(a, b, "scrap", 5), 1, "only what's there")
	assert_false(a.has("scrap"), "an empty stack is gone")
	var moved := Robbery.take_all(a, b)
	assert_eq(moved, {"helium3": 1})
	assert_true(a.is_empty())
	assert_eq(b, {"scrap": 4, "helium3": 1})


func test_fighters_carry_packs_deterministically() -> void:
	for role in ["concern", "guard", "raider"]:
		var p := Robbery.pack_for(role, 12345)
		assert_eq(p, Robbery.pack_for(role, 12345), "same roll, same pack")
		assert_true(p.has("cred_chip"), "everyone carries some chips")
		for item: String in p:
			assert_true(Career.ITEMS.has(item), item)
			assert_gt(int(p[item]), 0)


func test_the_dead_drop_their_pack_and_it_lies_there() -> void:
	var world := SimHarness.make_world()
	add_child_autofree(world)
	var p := world.add_player(7, SimHarness.loadout(), "Concern·Halden", false)
	p.state.position = Vector3(4, 0, 4)
	world.packs[7] = {"refined_ingot": 2}
	world.drop_pack(p, "")
	assert_false(world.packs.has(7), "the pack left them")
	assert_eq(world.drops.size(), 1)
	var dr := world.drop_near(Vector3(5, 0, 4))
	assert_eq(dr.name, "Concern·Halden")
	assert_eq(dr.items, {"refined_ingot": 2})
	assert_true(world.drop_near(Vector3(20, 0, 4)).is_empty(), "out of reach")
	(dr.items as Dictionary).clear()
	world.step({})
	assert_true(world.drops.is_empty(), "an emptied pack is gone")


func test_rover_hold_is_behind_and_not_a_door() -> void:
	var v := SimVehicle.new()
	v.position = Vector3.ZERO
	v.yaw = 0.0  # faces -Z: the hatch is at +Z
	assert_true(VehicleSim.at_hold(v, Vector3(0, 0, VehicleSim.HOLD_BACK)), "at the hatch")
	assert_false(VehicleSim.at_hold(v, Vector3(0, 0, -VehicleSim.HOLD_BACK)), "the front isn't the hold")
	assert_false(VehicleSim.at_hold(v, Vector3(2.5, 0, 0)), "the door side isn't the hold")


func test_shops_guns_and_the_rover_hold() -> void:
	var c := Career.new()
	c.d.wallet = 1000
	assert_eq(c.primary_index(), 0, "the issue Pulse rifle")
	assert_eq(c.shop_price("store", "burst_rifle"), -1, "the store sells no guns")
	assert_true(c.buy_at("arms", "burst_rifle"))
	assert_eq(c.d.wallet, 1000 - 520)
	assert_eq(int(c.d.stash.burst_rifle), 1)
	assert_true(c.equip("burst_rifle"))
	assert_eq(c.primary_index(), 1, "the Burst rifle in hand")
	assert_eq(c.shop_offer("store", "burst_rifle"), 0, "the store won't buy guns")
	assert_eq(c.shop_offer("guns", "burst_rifle"), 190, "a used gun: half its value")
	assert_eq(c.sell_at("guns", "burst_rifle"), 190)
	assert_eq(c.primary_index(), 0, "sold it: back to the Pulse")
	assert_eq(c.d.armed, "")
	c.receive("scrap", 3)
	assert_eq(c.shop_offer("arms", "scrap"), 0, "the arms dealer buys guns only")
	assert_gt(c.shop_offer("salvage", "scrap"), 0)
	assert_eq(c.shop_offer("salvage", "red_dust"), 0, "no contraband over the counter")
	assert_true(c.load_rover("scrap", 3))
	assert_false(c.d.stash.has("scrap"))
	assert_eq(c.d.rover_cargo, {"scrap": 3})
	assert_true(c.unload_rover("scrap", 1))
	assert_eq(int(c.d.stash.scrap), 1)
	var again := Career.new(JSON.parse_string(JSON.stringify(c.d)))
	assert_eq(int(again.d.rover_cargo.scrap), 2, "the hold survives a save")
	c.d.armed = "flux_smg"
	assert_eq(c.primary_index(), 0, "a gun you don't have isn't in your hands")


func test_wanted_level_rises_and_they_lose_you() -> void:
	var w := Wanted.new()
	assert_eq(w.officers(), 0)
	w.commit("holdup")
	assert_eq(w.stars, 1)
	w.commit("convoy")
	assert_eq(w.stars, 3, "the convoy is two stars")
	assert_eq(w.officers(), Wanted.OFFICERS[3])
	for i in 10:
		w.commit("officer_down")
	assert_eq(w.stars, Wanted.MAX, "five stars at most")
	assert_false(w.step(w.escape_time() - 1.0, false), "not yet")
	assert_false(w.step(5.0, true), "seen again: the clock resets")
	assert_eq(w.unseen, 0.0)
	assert_true(w.step(w.escape_time() + 0.1, false), "out of sight long enough: lost them")
	assert_eq(w.stars, 0)


func test_grenades_ride_in_the_pack_and_the_marshals_fine_you() -> void:
	var c := Career.new()
	c.d.wallet = 2000
	assert_true(c.buy_at("arms", "frag_grenade"))
	assert_true(c.buy_at("guns", "frag_grenade"))
	assert_eq(int(c.kit()[5]), 2, "two grenades to throw")
	c.store_kit(100.0, 0, 0.0, 100.0, 0, 1)
	assert_eq(int(c.d.stash.frag_grenade), 1, "one thrown")
	c.receive("red_dust", 2)
	c.receive("scrap", 1)
	var fine := c.busted()
	assert_gt(fine, 0)
	assert_false(c.d.stash.has("red_dust"), "contraband seized")
	assert_true(c.d.stash.has("scrap"), "honest goods kept")


func test_your_locker_its_lock_and_thieves() -> void:
	var c := Career.new()
	c.d.wallet = 1000
	c.receive("refined_ingot", 4)
	c.receive("scrap", 2)
	c.receive("water_ration", 1)
	assert_true(c.store_home("refined_ingot"))
	assert_true(c.store_home("scrap"))
	assert_true(c.store_home("water_ration"))
	assert_false(c.d.stash.has("refined_ingot"), "out of the pack, into the locker")
	assert_eq(int(c.d.home.locker.refined_ingot), 4)
	assert_true(c.burglary(10000, [1.0]).is_empty(), "the first visit only starts the clock")
	assert_true(c.burglary(10000 + 100, [1.0]).is_empty(), "too soon for another try")
	var held := c.burglary(10000 + Career.BURGLARY_EVERY, [0.1])
	assert_true(held.is_empty(), "the latch held that time")
	var taken := c.burglary(10000 + Career.BURGLARY_EVERY * 2, [0.99])
	assert_eq(taken.get("refined_ingot", 0), 2, "half the most valuable stack")
	assert_eq(taken.size(), 2, "two stacks at most")
	assert_eq(int(c.d.home.locker.refined_ingot), 2)
	assert_eq(c.lock_cost(), 250)
	assert_true(c.upgrade_lock())
	assert_eq(int(c.d.home.lock), 1)
	assert_true(c.burglary(10000 + Career.BURGLARY_EVERY * 3, [0.84]).is_empty(), "the reinforced lock holds 0.84")
	var again := Career.new(JSON.parse_string(JSON.stringify(c.d)))
	assert_eq(int(again.d.home.locker.refined_ingot), 2, "the locker survives a save")


func test_breaking_into_someone_elses_hab() -> void:
	var c := Career.new()
	var got := c.break_in("home_1", [0.0, 0.99], 5000)
	assert_false(got.is_empty())
	for item: String in got:
		assert_true(Career.ITEMS.has(item), item)
	assert_true(c.break_in("home_1", [0.5, 0.5], 5100).is_empty(), "cleaned out until it restocks")
	assert_false(c.break_in("home_1", [0.5, 0.5], 5000 + Career.BREAKIN_COOLDOWN).is_empty())
	assert_eq(Wanted.CRIMES.burglary, 2)


func test_rival_hunters_hold_fire_at_the_start() -> void:
	var h := HuntRules.new()
	assert_false(h.in_truce(0), "no clock, no truce")
	h.opened_tick = 100
	assert_true(h.in_truce(100 + 60))
	assert_false(h.in_truce(100 + HuntRules.OPENING_TRUCE_TICKS), "a minute in, it's on")


func test_tools_and_kit() -> void:
	var c := Career.new()
	c.d.wallet = 2000
	assert_eq(c.break_tool(), "", "bare hands won't open a lock")
	assert_true(c.buy_at("store", "crowbar"))
	assert_eq(c.break_tool(), "crowbar")
	assert_true(c.buy_at("guns", "lockpick"))
	assert_eq(c.break_tool(), "lockpick", "picks first: quick and quiet")
	assert_true(c.use_up("lockpick"))
	assert_eq(c.break_tool(), "crowbar", "the pick snapped; the crowbar lasts")
	assert_lt(float(Career.BREAK_TOOLS.lockpick[0]), float(Career.BREAK_TOOLS.crowbar[0]))
	assert_true(c.buy_at("store", "medkit"))
	assert_true(c.use_up("medkit"))
	assert_false(c.use_up("medkit"), "used up")
	assert_false(c.set_masked(true), "no mask to wear")
	assert_true(c.buy_at("guns", "mask"))
	assert_true(c.set_masked(true))
	assert_true(c.masked())
	var w := Wanted.new()
	w.commit("burglary", true)
	assert_eq(w.stars, 1, "masked: one star less")
	w.commit("burglary_quiet", true)
	assert_eq(w.stars, 2, "never less than one a crime")
	var plain := c.mine("hollow_rig", {"rare_ore": 1}, 1000, 60)
	assert_eq(plain.rare_ore, 1)
	assert_true(c.buy_at("salvage", "hand_drill"))
	var drilled := c.mine("hollow_rig", {"rare_ore": 1}, 2000, 60)
	assert_eq(drilled.rare_ore, 2, "the hand drill bites deeper")
	for shop: String in Career.SHOPS:
		for item: String in Career.SHOPS[shop].sells:
			assert_true(Career.ITEMS.has(item), "%s sells a real item: %s" % [shop, item])


func test_rovers_burn_fuel_and_take_knocks() -> void:
	var v := SimVehicle.new()
	var s := PlayerSimState.new()
	s.vehicle_speed = 15.0
	VehicleSim.wear_and_tear(v, s)
	for i in 60 * 60:  # a minute at 15 m/s: 900 m
		VehicleSim.wear_and_tear(v, s)
	assert_almost_eq(v.fuel, 100.0 - 0.915 * VehicleSim.FUEL_PER_KM, 0.3, "about 9% a kilometre")
	assert_eq(v.condition, 100.0, "no knocks on a clear road")
	s.vehicle_speed = 2.0  # a wall at 15 m/s
	VehicleSim.wear_and_tear(v, s)
	assert_lt(v.condition, 80.0, "a crash costs condition")
	v.fuel = 0.0
	s.vehicle_speed = 12.0
	VehicleSim.wear_and_tear(v, s)
	assert_eq(s.vehicle_speed, VehicleSim.CRAWL_SPEED, "an empty tank only crawls")


func test_the_garage() -> void:
	var c := Career.new()
	c.d.wallet = 1000
	assert_eq(c.respray_cost(2), 300)
	assert_true(c.pay(300))
	assert_eq(c.d.wallet, 700)
	assert_false(c.pay(5000))
	assert_eq(c.chop("rover_3", "concern", 100), Career.CHOP_PRICE.concern)
	assert_eq(c.chop("rover_3", "concern", 200), 0, "too hot to chop again so soon")
	assert_eq(c.chop("rover_1", "public", 200), Career.CHOP_PRICE.public, "another rover's fine")
	assert_eq(c.chop("rover_3", "concern", 100 + Career.CHOP_COOLDOWN), Career.CHOP_PRICE.concern)
