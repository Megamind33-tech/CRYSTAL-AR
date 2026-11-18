extends GutTest
## Land, building and renting: plot prices, ownership, building time and
## zoning, upkeep, bot tenants and their rent, player listings.

const DAY := LandOffice.DAY
const NOW := 1_000_000


func _setup(wallet: int = 500000) -> Array:
	return [LandOffice.new_state(), {"wallet": wallet}]


func test_prices_and_ownership() -> void:
	var a := _setup(20000)
	var s: Dictionary = a[0]
	var h: Dictionary = a[1]
	assert_eq(LandOffice.price(s, "r1"), 18000)
	assert_false(LandOffice.buy(s, h, "c1", NOW), "can't afford")
	assert_true(LandOffice.buy(s, h, "r1", NOW))
	assert_eq(int(h.wallet), 2000)
	assert_true(LandOffice.owned(s, "r1"))
	assert_eq(LandOffice.price(s, "r1"), 0)
	h.wallet = 100000
	assert_false(LandOffice.buy(s, h, "r1", NOW), "already yours")
	assert_false(LandOffice.buy(s, h, "nowhere", NOW))
	assert_eq(LandOffice.sell(s, h, "r1", NOW), int(18000 * LandOffice.SELL_BACK))
	assert_false(LandOffice.owned(s, "r1"))


func test_building_zoning_and_time() -> void:
	var a := _setup()
	var s: Dictionary = a[0]
	var h: Dictionary = a[1]
	assert_eq(LandOffice.can_build(s, h, "r1", "hab_r14"), "not your plot")
	LandOffice.buy(s, h, "r1", NOW)
	assert_eq(LandOffice.can_build(s, h, "r1", "market_hub"), "zoned residential")
	var before: int = h.wallet
	assert_true(LandOffice.build(s, h, "r1", "hab_r14", NOW))
	assert_eq(before - int(h.wallet), 30000)
	assert_false(LandOffice.build(s, h, "r1", "hab_r14", NOW), "already built")
	assert_false(LandOffice.built(s, "r1", NOW + DAY))
	assert_eq(LandOffice.build_left(s, "r1", NOW + DAY), DAY)
	assert_true(LandOffice.built(s, "r1", NOW + 2 * DAY))
	assert_eq(LandOffice.sale_value(s, "r1", NOW + 2 * DAY), int(18000 * 0.8) + 15000)


func test_upkeep_bot_tenant_and_rent() -> void:
	var a := _setup()
	var s: Dictionary = a[0]
	var h: Dictionary = a[1]
	LandOffice.buy(s, h, "r1", NOW)
	LandOffice.build(s, h, "r1", "hab_r14", NOW)
	var start: int = h.wallet
	var out := LandOffice.settle(s, h, NOW + 2 * DAY)
	assert_eq(int(out.upkeep), 0, "nothing while it's going up")
	# Done at +2; vacant 2 days (upkeep only), tenant from day 3 on.
	out = LandOffice.settle(s, h, NOW + 7 * DAY + 10)
	assert_eq((out.moved_in as Array).size(), 1)
	assert_ne(LandOffice.plot(s, "r1").tenant, "")
	assert_eq(int(out.upkeep), 5 * 120)
	assert_eq(int(out.income), 3 * 600)
	assert_eq(int(h.wallet) - start, 3 * 600 - 5 * 120)
	assert_eq(int(LandOffice.settle(s, h, NOW + 7 * DAY + 20).income), 0, "no double pay")
	LandOffice.evict(s, "r1", NOW + 7 * DAY)
	assert_true(LandOffice.vacant(s, "r1", NOW + 7 * DAY))


func test_player_listing() -> void:
	var a := _setup()
	var s: Dictionary = a[0]
	var h: Dictionary = a[1]
	LandOffice.buy(s, h, "c1", NOW)
	LandOffice.build(s, h, "c1", "market_hub", NOW)
	assert_false(LandOffice.list_for_players(s, "c1", 1000, NOW), "not finished")
	var t := NOW + 3 * DAY
	assert_true(LandOffice.list_for_players(s, "c1", 1000, t))
	assert_eq(LandOffice.listings(s).size(), 1)
	LandOffice.settle(s, h, t + 5 * DAY)
	assert_eq(LandOffice.plot(s, "c1").tenant, "", "listed: bots don't move in")
	assert_true(LandOffice.player_rents(s, "c1", "Rival", t + 5 * DAY))
	assert_eq(LandOffice.listings(s).size(), 0)
	var out := LandOffice.settle(s, h, t + 6 * DAY)
	assert_eq(int(out.income), 1000)
