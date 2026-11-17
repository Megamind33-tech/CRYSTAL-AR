extends GutTest
## THE HUNT's persistent career: contract board, settlement from the
## server's haul, market prices, gear, and the anti-exploit rules.


func test_fresh_career_and_board() -> void:
	var c := Career.new()
	assert_eq(c.d.wallet, Career.START_WALLET)
	assert_eq(c.offers().size(), Career.BOARD_SIZE, "three offers")
	var first: Dictionary = c.offers()[0]
	assert_true(c.accept(first.id), "accept an offer")
	assert_false(c.accept(c.offers()[1].id), "one contract at a time")
	assert_false(Career.new().accept("not_on_the_board"), "only offers on the board")


func test_settle_pays_contract_and_stashes_loot_once() -> void:
	var c := Career.new()
	c.d.contract = Career.CONTRACTS[0].duplicate()  # recover 1 cargo case, tharsis
	var haul := [{"item": "cargo_case", "value": 100}, {"item": "vault_relic", "value": 300}]
	var r := c.settle("run-1", haul)
	assert_eq(r.contract, "done")
	assert_eq(c.d.wallet, Career.START_WALLET + Career.CONTRACTS[0].pay, "contract paid")
	assert_false(c.d.stash.has("cargo_case"), "the client took the contracted case")
	assert_eq(c.d.stash.vault_relic, 1, "other loot kept")
	assert_eq(c.standing("tharsis"), Career.DONE_STANDING)
	var again := c.settle("run-1", haul)
	assert_false(again.applied, "a run settles once (no duplication)")
	assert_eq(c.d.stash.vault_relic, 1)


func test_failed_contract_costs_standing() -> void:
	var c := Career.new()
	c.d.contract = Career.CONTRACTS[2].duplicate()  # vault relic, kasei
	var r := c.settle("run-2", [{"item": "cargo_case", "value": 100}])
	assert_eq(r.contract, "failed")
	assert_eq(c.standing("kasei"), Career.FAIL_STANDING)
	assert_true(c.d.contract.is_empty())
	assert_eq(c.d.stash.cargo_case, 1, "loot is still yours")


func test_market_prices_fall_on_sale_and_recover() -> void:
	var c := Career.new()
	c.d.stash = {"helium3": 3}
	var p0 := c.price("helium3")
	var got := c.sell("helium3", 2)
	assert_eq(got, p0 + roundi(Career.ITEMS.helium3.base * (1.0 - Career.SELL_IMPACT)), "second sells lower")
	assert_lt(c.price("helium3"), p0, "price fell")
	assert_eq(c.sell("helium3", 5), 0, "can't sell more than you have")
	assert_eq(c.sell("vault_relic", 1), 0, "can't sell what isn't stashed")
	var low := c.price("helium3")
	c.settle("run-3", [])
	assert_gt(c.price("helium3"), low, "NPC trade recovers the price between runs")


func test_gear_costs_and_loadout() -> void:
	var c := Career.new()
	c.d.wallet = 100
	assert_false(c.buy_gear("plating"), "can't afford")
	c.d.wallet = 2000
	assert_true(c.buy_gear("plating"))
	assert_true(c.buy_gear("ammo"))
	assert_eq(c.loadout(), {"shield_bonus": 15.0, "spare_mags": 1})
	for i in 5:
		c.buy_gear("plating")
	assert_eq(c.d.gear.plating, Career.GEAR.plating.levels.size(), "capped at the last level")
	assert_eq(c.gear_cost("plating"), -1)


func test_normalize_survives_json_round_trip() -> void:
	var c := Career.new()
	c.d.stash = {"rare_ore": 2}
	var back: Variant = JSON.parse_string(JSON.stringify(c.d))
	var c2 := Career.new(back)
	assert_eq(typeof(c2.d.wallet), TYPE_INT)
	assert_eq(c2.d.stash.rare_ore, 2)


func test_hunt_rules_record_haul_and_apply_gear() -> void:
	var h := HuntRules.new()
	var t := HuntRules.Treasure.new()
	t.kind = HuntRules.Kind.PERSONAL
	t.owner = 7
	assert_eq(h.loot_item(t, 7), "cargo_case")
	assert_eq(h.loot_item(t, 9), "stolen_cargo")
	t.kind = HuntRules.Kind.GRAND
	assert_eq(h.loot_item(t, 9), "vault_relic")
	t.kind = HuntRules.Kind.RESOURCE
	t.resource = "helium3"
	assert_eq(h.loot_item(t, 9), "helium3")
	for item in ["cargo_case", "stolen_cargo", "vault_relic", "bounty_proof", "helium3", "rare_ore", "water_ice"]:
		assert_true(Career.ITEMS.has(item), "%s sells at the market" % item)


func test_trust_from_talking_once_per_deployment() -> void:
	var c := Career.new()
	assert_true(c.talk("trader"))
	assert_false(c.talk("trader"), "once per deployment")
	assert_eq(c.trust("trader"), Career.TALK_TRUST)
	c.settle("r1", [])
	assert_true(c.talk("trader"), "again after a deployment")
	assert_false(c.talk("nobody"))


func test_friends_help() -> void:
	var c := Career.new()
	c.d.stash = {"helium3": 1}
	var p0 := c.price("helium3")
	var g0 := c.gear_cost("plating")
	c.d.trust = {"trader": Career.FRIEND, "armourer": Career.FRIEND}
	assert_gt(c.price("helium3"), p0, "the trader pays a friend more")
	assert_lt(c.gear_cost("plating"), g0, "the armourer charges a friend less")
	c.d.contract = Career.CONTRACTS[2].duplicate()  # kasei: the broker's faction
	c.d.trust["broker"] = Career.FRIEND
	var r := c.settle("r1", [{"item": "vault_relic"}])
	assert_eq(r.pay, roundi(Career.CONTRACTS[2].pay * (1.0 + Career.FRIEND_PAY_BONUS)))
	assert_gt(c.trust("trader"), Career.FRIEND, "the faction's people trust you more")


func test_claim_and_run_dust_hollow() -> void:
	var c := Career.new()
	c.d.wallet = 2000
	assert_eq(c.claim_blocker(), "trust", "the foreman must back you")
	assert_false(c.claim_hollow())
	assert_true(c.buy_supplies(5))
	assert_eq(c.deliver_supplies(), 5)
	assert_eq(c.d.stash.get("supply_crate", 0), 0)
	c.d.trust["foreman"] = Career.CLAIM_TRUST
	assert_true(c.claim_hollow())
	assert_true(c.owns_hollow())
	assert_eq(c.standing("tharsis"), -Career.CLAIM_STANDING_LOSS, "the Concern lost it")
	c.settle("r1", [])
	assert_eq(c.d.hollow.ingots, Career.REFINERY_PER_RUN, "the refinery runs on supplies")
	assert_eq(c.d.hollow.supplies, 5 - Career.REFINERY_PER_RUN)
	assert_eq(c.collect_ingots(), Career.REFINERY_PER_RUN)
	assert_eq(c.d.stash.refined_ingot, Career.REFINERY_PER_RUN)


func test_hollow_lost_without_supplies() -> void:
	var c := Career.new()
	c.d.hollow.owner = "player"
	for i in Career.UNREST_LIMIT:
		c.settle("r%d" % i, [])
	assert_false(c.owns_hollow(), "left without supplies, the Concern takes it back")
	assert_eq(c.d.hollow.ingots, 0)


func test_raids_come_and_must_be_answered() -> void:
	var c := Career.new()
	c.d.hollow.owner = "player"
	c.d.hollow.supplies = 20
	for i in Career.RAID_EVERY:
		c.settle("r%d" % i, [])
	assert_true(c.d.hollow.raid_due, "a raid is coming")
	c.raid_won()
	assert_false(c.d.hollow.raid_due)
	assert_true(c.owns_hollow())
	assert_eq(c.trust("foreman"), Career.RAID_TRUST, "the Hollow remembers who defended it")
	# Ignored with a weak militia: lost.
	for i in Career.RAID_EVERY + 1:
		c.settle("s%d" % i, [])
	assert_false(c.owns_hollow(), "an undefended raid with one militiaman loses the Hollow")


func test_strong_militia_holds_an_undefended_raid() -> void:
	var c := Career.new()
	c.d.hollow.owner = "player"
	c.d.hollow.supplies = 20
	c.d.trust = {"foreman": Career.FRIEND}
	assert_eq(c.militia(), Career.MILITIA_HOLDS)
	for i in Career.RAID_EVERY + 1:
		c.settle("r%d" % i, [])
	assert_true(c.owns_hollow(), "friends held it")
	assert_lt(c.d.hollow.supplies, 20, "but it cost supplies")


func test_lab_brews_oxygen_from_ice() -> void:
	var c := Career.new()
	assert_eq(c.lab_blocker("oxygen"), "inputs")
	c.d.stash = {"water_ice": 1}
	assert_true(c.lab_start("oxygen", 1000))
	assert_eq(c.lab_blocker("oxygen"), "busy", "one batch at a time")
	assert_eq(c.lab_collect(1010), 0, "not ready yet")
	assert_eq(c.lab_left(1010), Career.RECIPES.oxygen.seconds - 10)
	assert_eq(c.lab_collect(1000 + Career.RECIPES.oxygen.seconds), 3)
	assert_eq(c.d.stash.oxygen_canister, 3)


func test_contraband_dealer_and_checkpoint() -> void:
	var c := Career.new()
	c.d.stash = {"red_dust": 2}
	assert_eq(c.sell("red_dust"), 0, "not at the exchange")
	assert_eq(c.checkpoint(0.9), 0, "not searched")
	assert_eq(c.checkpoint(0.1), 2, "searched: confiscated")
	assert_eq(c.d.wallet, Career.START_WALLET - Career.SEARCH_FINE)
	c.d.stash = {"red_dust": 2}
	assert_eq(c.sell_contraband(), 2 * Career.DEALER_PRICE)


func test_jobs_come_round_again() -> void:
	var c := Career.new()
	assert_true(c.take_job("courier"))
	assert_false(c.take_job("ice"), "one job at a time")
	assert_eq(c.d.stash.parcel, 1)
	assert_eq(c.finish_job().pay, Career.JOBS.courier.pay)
	var now := int(Time.get_unix_time_from_system())
	assert_false(c.job_available("courier", now), "just done")
	assert_true(c.take_job("ice"))
	c.finish_job()
	assert_eq(c.d.stash.water_ice, 2)
	assert_true(c.job_available("courier", now + Career.JOB_COOLDOWN), "comes round again")
	for j: String in Career.JOBS:
		assert_true(Career.new().job_available(j), "%s on offer from the start" % j)


func test_kit_and_companion() -> void:
	var c := Career.new()
	assert_true(c.buy("oxygen_canister", 2))
	assert_eq(c.kit(), [100.0, 2, 0.0, 100.0, 0, 0, 100.0, false])
	c.store_kit(40.0, 1, 75.0, 30.0, 2)
	assert_eq(c.kit(), [40.0, 1, 75.0, 30.0, 2, 0, 100.0, false])
	c.rest()
	assert_eq(c.d.fatigue, 0.0)
	assert_false(c.set_companion("foreman"), "only friends come along")
	c.d.trust = {"foreman": Career.FRIEND}
	assert_true(c.set_companion("foreman"))


func test_scavenge_and_theft() -> void:
	var c := Career.new()
	var table := [["water_ration", 2, 3.0], ["oxygen_canister", 1, 1.0]]
	assert_eq(c.scavenge("crate1", table, 0.1, 100, 300), {"water_ration": 2})
	assert_eq(c.scavenge("crate1", table, 0.1, 200, 300), {}, "empty until it refills")
	assert_eq(c.scavenge("crate1", table, 0.95, 401, 300), {"oxygen_canister": 1})
	c.steal_algae(2)
	c.caught_stealing()
	assert_false(c.d.stash.has("algae_culture"), "the guards took it back")


# --- Nation, squad and robbery (docs/game-plan.md) ---

func test_choosing_a_nation() -> void:
	var c := Career.new()
	assert_eq(c.nation(), Nations.NONE, "nobody's until you choose")
	assert_true(c.choose_nation(2))
	assert_eq(c.nation(), 2)
	assert_false(c.choose_nation(9), "only the four")
	assert_eq(Career.new(c.d).nation(), 2, "it's saved")


func test_robbed_down_to_clothes_and_helmet() -> void:
	var c := Career.new()
	c.d.runs = 3
	c.d.stash = {"rail_sniper": 1, "medkit": 2, "rare_ore": 4}
	c.d.armed = "rail_sniper"
	c.d.gear = {"plating": 2, "ammo": 1}
	c.d.cosmetics.append("helmet_visor")
	c.d.home.locker = {"refined_ingot": 3}
	var wallet: int = c.d.wallet
	var lost := c.robbed()
	assert_eq(lost.items, {"rail_sniper": 1, "medkit": 2, "rare_ore": 4}, "the whole pack")
	assert_eq(lost.gear, {"plating": 2, "ammo": 1}, "and the upgrades")
	assert_true(c.d.stash.is_empty())
	assert_eq(c.d.armed, "", "back to the issued Pulse")
	assert_eq(c.primary_index(), 0)
	assert_true("helmet_visor" in c.d.cosmetics, "clothes and helmet stay")
	assert_eq(c.d.home.locker, {"refined_ingot": 3}, "the locker at home is safe")
	assert_eq(c.d.wallet, wallet, "and the money")


func test_the_guided_run_is_insured() -> void:
	var c := Career.new()
	c.d.stash = {"medkit": 1}
	assert_true(c.guided_run())
	assert_true(c.robbed().items.is_empty(), "nothing is taken on your first run")
	assert_eq(c.d.stash, {"medkit": 1})
	c.choose_nation(0)
	assert_false(c.squadmate_may_turn(c.pick_squadmate(5)), "and nobody turns on you")


func test_turns_on_you_are_paced_and_never_by_the_same_person() -> void:
	var c := Career.new()
	c.choose_nation(1)
	c.d.runs = 5
	var mate := c.pick_squadmate(11)
	assert_true(mate in Nations.names(1))
	assert_true(c.squadmate_may_turn(mate))
	c.record_squad_run(mate, "turned_on_me")
	for s in 40:
		assert_ne(c.pick_squadmate(s), mate, "who turned on you is never your squadmate again")
	var next := c.pick_squadmate(12)
	assert_false(c.squadmate_may_turn(next), "not again right away")
	c.d.runs = 5 + Career.TURN_GAP_RUNS
	assert_true(c.squadmate_may_turn(next), "only after a while")


func test_turning_on_your_squad_costs_and_is_remembered() -> void:
	var c := Career.new()
	c.choose_nation(0)
	c.d.runs = 4
	var mate := c.pick_squadmate(3)
	var standing: int = c.d.nation_standing
	c.record_squad_run(mate, "i_turned")
	assert_eq(c.d.nation_standing, standing + Career.TURN_STANDING, "your nation notices")
	assert_true(c.grudge(mate), "and so do they")
	c.d.last_turned_run = c.d.runs  # even right after a turn
	assert_true(c.squadmate_may_turn(mate), "a grudge may be settled any time")
	c.record_squad_run(mate, "turned_on_me")
	assert_false(c.grudge(mate), "settled")
	c.record_squad_run(c.pick_squadmate(4), "")
	assert_eq(c.d.nation_standing, standing + Career.TURN_STANDING + Career.RUN_STANDING, "a run together pays")


func test_a_new_squadmate_each_run() -> void:
	var c := Career.new()
	c.choose_nation(3)
	var last := ""
	for run in 12:
		var mate := c.pick_squadmate(run * 31)
		assert_ne(mate, last, "never the same face twice in a row")
		c.record_squad_run(mate, "")
		last = mate


func test_the_hold_is_searched_apart_from_the_pack() -> void:
	var c := Career.new()
	c.d.stash = {"red_dust": 2}
	c.d.rover_cargo = {"red_dust": 3, "rare_ore": 1}
	assert_true(c.hold_has_dust())
	assert_eq(c.confiscate_hold(), 3, "the hold's dust is found")
	assert_eq(c.d.rover_cargo, {"rare_ore": 1}, "the rest of the hold stays")
	assert_eq(c.d.stash, {"red_dust": 2}, "the pack wasn't searched")


func test_hidden_stashes_survive_a_robbery() -> void:
	var c := Career.new()
	c.d.runs = 2
	c.d.stash = {"rare_ore": 4, "red_dust": 2}
	var i := c.make_cache(Vector3(100, 0, 50))
	assert_eq(c.make_cache(Vector3(101, 0, 50)), i, "the same spot is the same stash")
	assert_eq(c.hide_in(i, "rare_ore"), 4)
	assert_eq(c.cache_at(Vector3(100.5, 0, 50)), i, "found again when you come back")
	assert_eq(c.cache_at(Vector3(120, 0, 50)), -1)
	c.robbed()
	assert_eq(c.d.caches[i].items, {"rare_ore": 4}, "robbers take your pack, not your stash")
	for k in Career.MAX_CACHES:
		c.make_cache(Vector3(k * 20.0, 0, 0))
	assert_eq(c.make_cache(Vector3(999, 0, 0)), -1, "only so many stashes")
	c.tidy_caches()
	assert_eq(c.d.caches.size(), 1, "empty ones are forgotten")
