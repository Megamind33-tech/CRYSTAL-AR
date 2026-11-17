extends GutTest
## Arrival: registration, nation flags, colonies, the government/freelance choice.


func test_register_validates_and_saves() -> void:
	var c := Career.new()
	assert_false(c.registered())
	assert_false(c.register("ab", 0), "too short")
	assert_true(c.register("  Ilsa  ", 99))
	assert_true(c.registered())
	assert_eq(c.d.reg.name, "Ilsa")
	assert_eq(c.d.reg.body, CharacterRig.SELECTABLE.size() - 1, "body clamped")


func test_flags_are_distinct() -> void:
	var seen := {}
	for i in Nations.IDS.size():
		var t := Nations.flag_texture(i, 90)
		assert_eq(t.get_width(), 90)
		var img := t.get_image()
		seen[img.get_data().hex_encode().hash()] = true
		var found := false
		for y in img.get_height():
			for x in img.get_width():
				found = found or absf(img.get_pixel(x, y).r - Nations.flag_design(i)[2].r) < 0.02 and absf(img.get_pixel(x, y).g - Nations.flag_design(i)[2].g) < 0.02 and absf(img.get_pixel(x, y).b - Nations.flag_design(i)[2].b) < 0.02
		assert_true(found, "emblem drawn")
	assert_eq(seen.size(), 4)


func test_each_nation_has_its_own_colony() -> void:
	var seen := {}
	for i in Nations.IDS.size():
		seen[Arrival.colony_centre(i)] = true
		var p := Arrival.spawn(i)
		assert_almost_eq(p.y, WorldTerrain.height(p.x, p.z) + 0.3, 0.001)
	assert_eq(seen.size(), 4)
	assert_eq(Arrival.colony_id(0), "helios")


func test_arrival_flow_and_path() -> void:
	var c := Career.new()
	assert_eq(Arrival.next_step(c), "register")
	c.register("Teo", 1)
	assert_eq(Arrival.next_step(c), "nation")
	assert_eq(Arrival.pending_spawn(c), Vector3.INF, "no nation, no landing")
	c.choose_nation(2)
	assert_eq(Arrival.pending_spawn(c), Arrival.spawn(2))
	assert_eq(Arrival.next_step(c), "path")
	assert_false(c.choose_path("pirate"))
	assert_true(c.choose_path("freelance"))
	assert_eq(Arrival.next_step(c), "")
	c.d.arrived = true
	assert_eq(Arrival.pending_spawn(c), Vector3.INF)
