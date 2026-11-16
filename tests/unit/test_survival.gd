extends GutTest
## THE HUNT's survival (Survival): oxygen outside the dome, spares, the dome
## refilling, suffocation, taking air from a kill, stamina, fatigue.


func before_each() -> void:
	Survival.enabled = true
	Survival.air_zones.clear()
	Survival.air_zones.append(Vector3(0, 0, 50))


func after_each() -> void:
	Survival.enabled = false
	Survival.weather = false
	Survival.air_zones.clear()


func _outdoors() -> PlayerSimState:
	var s := PlayerSimState.new()
	s.alive = true
	s.position = Vector3(500, 0, 0)
	return s


func test_tank_drains_outside_and_spare_swaps_in() -> void:
	var s := _outdoors()
	for i in 60 * 60:  # a minute
		Survival.step(s)
	assert_almost_eq(s.oxygen, 100.0 - 100.0 * 60.0 / Survival.TANK_SECONDS, 0.5, "a minute's air")
	s.oxygen = Survival.SWAP_AT + 0.001
	s.o2_spares = 1
	for i in 10:
		Survival.step(s)
	assert_eq(s.o2_spares, 0, "the spare went in")
	assert_gt(s.oxygen, 99.0)


func test_empty_tank_suffocates_and_the_dome_refills() -> void:
	var s := _outdoors()
	s.oxygen = 0.0
	assert_gt(Survival.step(s), 0.0, "health lost with no air")
	s.position = Vector3(10, 0, 0)  # inside the dome
	for i in 60 * 10:
		Survival.step(s)
	assert_gt(s.oxygen, 30.0, "the dome refills the suit")


func test_kill_takes_their_air() -> void:
	var victim := _outdoors()
	victim.oxygen = 80.0
	victim.o2_spares = 2
	var killer := _outdoors()
	killer.oxygen = 20.0
	var took := Survival.on_kill(victim, killer)
	assert_eq(took.spares, 2)
	assert_eq(killer.o2_spares, 2)
	assert_almost_eq(killer.oxygen, 60.0, 0.01, "half their tank")


func test_stamina_and_fatigue() -> void:
	var s := _outdoors()
	s.sprinting = true
	for i in 60 * 12:
		Survival.step(s)
	assert_true(s.winded, "out of breath after a long sprint")
	assert_false(Survival.can_sprint(s))
	s.sprinting = false
	for i in 60 * 3:
		Survival.step(s)
	assert_true(Survival.can_sprint(s), "breath back")
	s.fatigue = Survival.TIRED
	assert_lt(Survival.pace(s), 1.0, "tired legs")


func test_thirst() -> void:
	var s := _outdoors()
	s.water = Survival.DRINK_AT + 0.001
	s.water_spares = 1
	for i in 10:
		Survival.step(s)
	assert_eq(s.water_spares, 0, "drank a ration")
	s.water = 0.0
	s.oxygen = 100.0
	assert_gt(Survival.step(s), 0.0, "dry: weakening")
	var killer := _outdoors()
	s.water_spares = 2
	assert_eq(Survival.on_kill(s, killer).water, 2, "a kill takes their water")


func test_storms_drain_air_and_water_faster_outside() -> void:
	Survival.weather = true
	var peak := int((Survival.STORM_FIRST + Survival.STORM_LENGTH * 0.5) / Sim.TICK_DT)
	assert_eq(Survival.storm_at(0), 0.0, "clear skies at first")
	assert_almost_eq(Survival.storm_at(peak), 1.0, 0.001, "the storm at its height")
	var calm := _outdoors()
	var storm := _outdoors()
	for i in 600:
		Survival.step(calm, 0)
		Survival.step(storm, peak)
	var calm_air := 100.0 - calm.oxygen
	var storm_air := 100.0 - storm.oxygen
	assert_almost_eq(storm_air / calm_air, Survival.STORM_AIR, 0.01, "filters clog in the storm")
	assert_almost_eq((100.0 - storm.water) / (100.0 - calm.water), Survival.STORM_WATER, 0.01, "and it dries you out")
	var inside := PlayerSimState.new()
	inside.alive = true
	inside.position = Vector3(5, 0, 0)
	inside.oxygen = 50.0
	Survival.step(inside, peak)
	assert_gt(inside.oxygen, 50.0, "the dome still refills during a storm")
	Survival.weather = false
	assert_eq(Survival.storm_at(peak), 0.0, "no storms on maps without weather")


func test_suit_state_survives_the_network_exactly() -> void:
	var s := _outdoors()
	s.oxygen = 37.25
	s.water = 61.5
	s.stamina = 12.125
	s.fatigue = 71.75
	s.o2_spares = 3
	s.water_spares = 2
	s.winded = true
	s.vehicle = 1
	s.vehicle_yaw = 1.25
	s.vehicle_speed = 9.5
	s.jetpack = true
	s.jet_fuel = 63.5
	var w := Wire.Writer.new()
	Snapshot.write_owner(w, s)
	var back := Snapshot.read_owner(Wire.Reader.new(w.data()))
	assert_not_null(back)
	for f in ["oxygen", "water", "stamina", "fatigue", "o2_spares", "water_spares", "winded", "vehicle", "vehicle_yaw", "vehicle_speed", "jetpack", "jet_fuel"]:
		assert_eq(back.get(f), s.get(f), f)


func test_hunger_and_starving() -> void:
	var s := _outdoors()
	s.o2_spares = 9
	s.water_spares = 9
	for i in 60 * 60:  # a minute
		Survival.step(s)
	assert_almost_eq(s.food, 100.0 - 100.0 * 60.0 / Survival.FOOD_SECONDS, 0.2, "a minute's hunger")
	s.food = 0.0
	s.water = 100.0
	s.oxygen = 100.0
	assert_gt(Survival.step(s), 0.0, "starving costs health")
	s.stamina = 50.0
	Survival.step(s)
	assert_almost_eq(s.stamina, 50.0 + Survival.STAMINA_REGEN * 0.5 * Sim.TICK_DT, 0.001, "and slows getting your breath back")
	var w := Wire.Writer.new()
	s.food = 42.5
	Snapshot.write_owner(w, s)
	assert_eq(Snapshot.read_owner(Wire.Reader.new(w.data())).food, 42.5, "hunger crosses the network exactly")


func test_meat_fills_you() -> void:
	var c := Career.new()
	c.d.wallet = 500
	assert_true(c.buy_at("store", "vat_meat"))
	assert_true(c.buy("fresh_meat"))
	assert_gt(float(Career.USE.fresh_meat.food), float(Career.USE.vat_meat.food), "fresh fills more")
	assert_gt(c.price("fresh_meat"), c.price("vat_meat"), "and is worth more: a luxury")
	assert_true(c.sellable("fresh_meat"))
	c.store_kit(100.0, 0, 0.0, 100.0, 0, 0, 37.0)
	assert_eq(float(c.kit()[6]), 37.0, "hunger carries between places")
