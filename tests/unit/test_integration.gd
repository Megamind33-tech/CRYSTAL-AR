extends GutTest
## Wiring checks: the venues have places, plots sit apart on the ground,
## rubies buy plots, the arrival steps come in order.


func test_venues_have_distinct_places() -> void:
	var a := CityVenues.land_desk()
	var b := CityVenues.pit_stairs()
	var c := CityVenues.cutter_bench()
	assert_gt(a.distance_to(b), 3.0)
	assert_gt(a.distance_to(c), 3.0)
	assert_lt(b.distance_to(WorldLayout.shops()[5][1]), 4.0, "the Pit is at the Red Lantern")


func test_plots_do_not_overlap() -> void:
	var ids := LandOffice.PLOTS.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var p: Dictionary = LandOffice.PLOTS[ids[i]]
			var q: Dictionary = LandOffice.PLOTS[ids[j]]
			var gap := Vector2(p.pos.x, p.pos.z).distance_to(Vector2(q.pos.x, q.pos.z))
			assert_gt(gap, (float(p.size) + float(q.size)) * 0.5, "%s / %s" % [ids[i], ids[j]])


func test_plot_for_rubies() -> void:
	var s := LandOffice.new_state()
	var h := {"wallet": 0, "rubies": 12}
	var cost := int(Career.RUBY_PRICES["land:plot"])
	assert_true(LandOffice.buy_rubies(s, h, "r1", 100, cost))
	assert_eq(int(h.rubies), 12 - cost)
	assert_true(LandOffice.owned(s, "r1"))
	assert_false(LandOffice.buy_rubies(s, h, "r2", 100, cost), "not enough rubies left")


func test_arrival_order() -> void:
	var c := Career.new()
	assert_eq(Arrival.next_step(c), "register")
	c.register("Ana", 0)
	assert_eq(Arrival.next_step(c), "nation")
	c.choose_nation(1)
	assert_eq(Arrival.next_step(c), "path")
	c.choose_path("freelance")
	assert_eq(Arrival.next_step(c), "")
	c.d.arrived = true
	assert_eq(Arrival.pending_spawn(c), Vector3.INF, "an arrived career lands nowhere new")


func test_talk_memory_lives_in_the_career() -> void:
	var conv := TalkPanel.conversation()
	conv.remember("foreman", "favour", "test", 1000)
	assert_true(Profile.career().d.memory.has("foreman"), "Career.d.memory holds the talk")
	Profile.career().d.memory.erase("foreman")


func test_free_roam_ally_follows_and_guards() -> void:
	var w := SimWorld.new()
	var b := MercBrain.ally(w, null, 1001, 7, 5)
	assert_not_null(b.own_contract)
	assert_eq(b.own_contract.employer, 5)
	b.on_event({"type": "hit", "target": 5, "attacker": 9})
	assert_true(b._threats.has(9), "whoever shoots the friend is a threat")
	b.on_event({"type": "hit", "target": 5, "attacker": 5})
	assert_false(b._threats.has(5))


func test_rubies_buy_what_they_say() -> void:
	var c := Career.new()
	c.add_rubies(40)
	assert_true(c.buy_with_rubies("licence:pilot", 1000))
	assert_true(c.has_visa("flight", 1000))
	assert_true(c.buy_with_rubies("licence:trader", 1000))
	assert_true(c.has_visa("work", 1000))
	var lock := int(c.d.home.lock)
	assert_true(c.buy_with_rubies("upgrade:lock", 1000))
	assert_eq(int(c.d.home.lock), lock + 1)
	assert_true(c.buy_with_rubies("upgrade:plating", 1000))
	assert_eq(int(c.d.gear.plating), 1)
	assert_eq(c.rubies(), 40 - 8 - 5 - 4 - 6)
	assert_false(c.buy_with_rubies("land:plot", 1000), "plots go through the Land Office")


func test_dig_settle_rolls_once_per_run() -> void:
	var found := 0
	for i in 200:
		var c := Career.new()
		var r := c.settle("run-%d" % i, [{"item": "cargo_case", "value": 1}])
		if r.get("ruby_found", false):
			found += 1
			assert_eq(c.rubies(), 1)
	assert_between(found, 1, 30, "about 4% of runs turn up a ruby")
