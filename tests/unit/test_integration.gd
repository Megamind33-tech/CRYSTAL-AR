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
