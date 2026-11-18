extends GutTest
## The objective tracker and the guided first run (Guide, docs/game-plan.md §7).


func test_the_first_run_one_step_at_a_time() -> void:
	var c := Career.new()
	assert_eq(Guide.step(c), Guide.Step.NATION, "first: choose a nation")
	assert_eq(Guide.city_objective(c).target, Vector3.INF, "chosen on the screen, not somewhere")
	c.choose_nation(1)
	assert_eq(Guide.step(c), Guide.Step.BOARD, "then a contract")
	var board: Vector3 = Guide.city_objective(c).target
	assert_eq(board, CityLayout.terminals()[Guide.BOARD][1], "at the Broker's board")
	c.accept(c.offers()[0].id)
	assert_eq(Guide.step(c), Guide.Step.DEPLOY, "then deploy")
	c.settle("first", [{"item": "cargo_case", "value": 100}])
	assert_eq(Guide.step(c), Guide.Step.SELL, "back with goods: sell them")
	assert_eq(Guide.city_objective(c).target, CityLayout.terminals()[Guide.MARKET][1], "at the Trader")
	c.sell("cargo_case", int(c.d.stash.get("cargo_case", 0)))
	assert_eq(Guide.step(c), Guide.Step.DONE, "taught")
	assert_false(Guide.teaching(c))
	assert_eq(int(Guide.city_objective(c).step), 0, "the tracker carries on without step numbers")
	assert_ne(Guide.city_objective(c).target, Vector3.INF, "always somewhere to go")


func test_an_empty_first_run_skips_selling() -> void:
	var c := Career.new()
	c.choose_nation(0)
	c.settle("empty", [])
	assert_eq(Guide.step(c), Guide.Step.DONE, "nothing to sell: done")


func test_distance_text() -> void:
	assert_eq(Guide.distance_text(Vector3.ZERO, Vector3(30, 5, 40)), "  ·  50 m", "flat distance")
	assert_eq(Guide.distance_text(Vector3.ZERO, Vector3.INF), "", "no target, no distance")


func test_the_recommended_card_is_the_safest_for_a_new_player() -> void:
	var offers := [Career.CONTRACTS[2], Career.CONTRACTS[0], Career.CONTRACTS[3]]  # vault, cargo, rival
	assert_eq(Guide.recommended(offers, 0), "recover_cargo", "first run: low risk, short")
	var ordered := Guide.ordered(offers, 0)
	assert_eq(ordered[0].id, "recover_cargo", "recommended card first")
	assert_eq(ordered.size(), 3, "nothing dropped")
	assert_ne(Guide.recommended(Career.CONTRACTS, 5), "", "always one to recommend")


func test_every_contract_has_a_card_and_a_path() -> void:
	for k: Dictionary in Career.CONTRACTS:
		assert_true(Guide.CARDS.has(k.id), "card facts for %s" % k.id)
		assert_between(int(Guide.card(k).risk), 1, 3, "risk is 1-3")
	assert_eq(Guide.path_of(Career.CONTRACTS[0]), "government", "Kraken jobs are the government path")
	assert_eq(Guide.path_of(Career.CONTRACTS[2]), "freelance", "others are freelance")


func test_intro_and_hints_have_words() -> void:
	for key in Guide.intro_keys():
		assert_ne(TranslationServer.translate(key), key, "%s is translated" % key)
	var c := Career.new()
	c.choose_nation(0)
	assert_eq(Guide.board_hint(c), TranslationServer.translate("GUIDE_HINT_PICK"), "pick the first card")
	c.accept(c.offers()[0].id)
	assert_ne(Guide.board_hint(c), TranslationServer.translate("GUIDE_HINT_PICK"), "then a path hint")
