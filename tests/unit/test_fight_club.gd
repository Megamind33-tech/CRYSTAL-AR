extends GutTest
## Hand-to-hand moves (MeleeMoves) and the fight club (odds, bets, rounds).


class FakeCareer:
	extends RefCounted
	var d := {"wallet": 1000, "earned": 0}

	func pay(amount: int) -> bool:
		if amount < 0 or d.wallet < amount:
			return false
		d.wallet -= amount
		return true


func _pair() -> Array:
	var a := MeleeMoves.Fighter.new()
	var b := MeleeMoves.Fighter.new()
	a.pos = 0.0
	b.pos = 1.0
	return [a, b]


## Steps both and resolves until `a`'s move ends; returns the events of a.
func _run(a: MeleeMoves.Fighter, b: MeleeMoves.Fighter, ticks: int) -> Array:
	var evs: Array = []
	for i in ticks:
		MeleeMoves.step(a)
		MeleeMoves.step(b)
		var e := MeleeMoves.resolve(a, b)
		if not e.is_empty():
			evs.append(e)
	return evs


func test_light_hits_for_8_and_stuns() -> void:
	var p := _pair()
	assert_true(MeleeMoves.press(p[0], MeleeMoves.Move.LIGHT))
	var evs := _run(p[0], p[1], 5)
	assert_eq(evs.size(), 1)
	assert_eq(p[1].hp, 92.0)
	assert_eq(p[1].phase, MeleeMoves.Phase.STUNNED)
	assert_eq(p[0].stamina, 90.0)


func test_out_of_reach_misses() -> void:
	var p := _pair()
	p[1].pos = 3.0
	MeleeMoves.press(p[0], MeleeMoves.Move.HEAVY)
	assert_eq(_run(p[0], p[1], 40).size(), 0)
	assert_eq(p[1].hp, 100.0)


func test_block_light_chips_heavy_reduced() -> void:
	var p := _pair()
	MeleeMoves.press(p[1], MeleeMoves.Move.BLOCK)
	MeleeMoves.press(p[0], MeleeMoves.Move.LIGHT)
	_run(p[0], p[1], 20)
	assert_eq(p[1].hp, 99.0)
	MeleeMoves.press(p[0], MeleeMoves.Move.HEAVY)
	_run(p[0], p[1], 40)
	assert_eq(p[1].hp, 93.0)


func test_guard_break_when_out_of_stamina() -> void:
	var p := _pair()
	p[1].stamina = 20.0
	MeleeMoves.press(p[1], MeleeMoves.Move.BLOCK)
	MeleeMoves.press(p[0], MeleeMoves.Move.HEAVY)
	var evs := _run(p[0], p[1], 13)
	assert_eq(evs[0].kind, "guard_break")
	assert_eq(p[1].phase, MeleeMoves.Phase.STUNNED)


func test_combo_light_light_heavy_knocks_down() -> void:
	var p := _pair()
	MeleeMoves.press(p[0], MeleeMoves.Move.LIGHT)
	_run(p[0], p[1], 12)
	MeleeMoves.press(p[0], MeleeMoves.Move.LIGHT)
	_run(p[0], p[1], 12)
	assert_eq(p[0].combo, 2)
	MeleeMoves.press(p[0], MeleeMoves.Move.HEAVY)
	assert_true(p[0].finisher)
	var evs := _run(p[0], p[1], 13)
	assert_true(evs[0].knockdown)
	assert_eq(evs[0].damage, 30.0)
	assert_eq(p[1].phase, MeleeMoves.Phase.DOWN)
	assert_eq(p[1].knockdowns, 1)


func test_heavy_counter_knocks_down() -> void:
	var p := _pair()
	MeleeMoves.press(p[0], MeleeMoves.Move.HEAVY)
	_run(p[0], p[1], 10)
	MeleeMoves.press(p[1], MeleeMoves.Move.HEAVY)  # b winds up as a's heavy lands
	var evs := _run(p[0], p[1], 3)
	assert_true(evs[0].counter)
	assert_true(evs[0].knockdown)


func test_down_is_untouchable() -> void:
	var p := _pair()
	p[1].phase = MeleeMoves.Phase.DOWN
	p[1].timer = 60
	MeleeMoves.press(p[0], MeleeMoves.Move.LIGHT)
	assert_eq(_run(p[0], p[1], 6).size(), 0)


func test_no_stamina_no_move() -> void:
	var p := _pair()
	p[0].stamina = 5.0
	assert_false(MeleeMoves.press(p[0], MeleeMoves.Move.LIGHT))


func test_odds_from_ratings() -> void:
	assert_almost_eq(FightClub.win_chance(1200, 1200), 0.5, 0.0001)
	assert_almost_eq(FightClub.win_chance(1600, 1200), 0.909, 0.001)
	assert_eq(FightClub.odds(0.5), 1.84)
	assert_eq(FightClub.odds(0.99), 1.05)
	assert_gt(FightClub.odds(0.2), FightClub.odds(0.8))


func test_payout() -> void:
	assert_eq(FightClub.payout(100, 1.84), 184)
	assert_eq(FightClub.payout(33, 2.5), 82)


func test_card_is_deterministic() -> void:
	var a := FightClub.card_for(7)
	var b := FightClub.card_for(7)
	assert_eq(a.size(), 4)
	assert_eq(str(a), str(b))
	assert_ne(a[0].red.name, a[0].blue.name)


func test_bets_and_settle() -> void:
	var c := FakeCareer.new()
	var club := FightClub.new(3)
	assert_false(club.place_bet(c, 0, 0, 5), "under the minimum")
	assert_false(club.place_bet(c, 0, 0, 2000), "can't afford it")
	assert_true(club.place_bet(c, 0, 0, 100))
	assert_true(club.place_bet(c, 0, 1, 100))
	assert_eq(c.d.wallet, 800)
	var bout := club.run_fight(0)
	assert_true(bout.over)
	assert_false(club.place_bet(c, 0, 0, 100), "fight's done")
	var paid := club.settle(c, 0)
	assert_eq(paid, FightClub.payout(100, club.card[0].odds[bout.winner]))
	assert_eq(c.d.wallet, 800 + paid)
	assert_eq(club.settle(c, 0), 0, "paid once")


func test_ko_ends_bout() -> void:
	var bout := FightClub.Bout.new()
	bout.blue.hp = 5.0
	bout.red.pos = 0.0
	bout.blue.pos = 1.0
	for i in 6:
		bout.tick(MeleeMoves.Move.LIGHT if i == 0 else MeleeMoves.Move.NONE, 0, MeleeMoves.Move.NONE, 0)
	assert_true(bout.over)
	assert_eq(bout.winner, 0)
	assert_eq(bout.how, "ko")


func test_rounds_then_decision() -> void:
	var bout := FightClub.Bout.new()
	bout.red.damage_dealt = 12.0
	var ticks := 0
	while not bout.over and ticks < 100000:
		bout.tick(MeleeMoves.Move.NONE, 0, MeleeMoves.Move.NONE, 0)
		ticks += 1
	assert_eq(bout.how, "decision")
	assert_eq(bout.winner, 0)
	assert_eq(bout.round_no, FightClub.ROUNDS)
	assert_eq(ticks, FightClub.ROUNDS * FightClub.ROUND_TICKS + (FightClub.ROUNDS - 1) * FightClub.BREAK_TICKS)


func test_tko_on_three_knockdowns() -> void:
	var bout := FightClub.Bout.new()
	bout.blue.knockdowns = 3
	bout.tick(MeleeMoves.Move.NONE, 0, MeleeMoves.Move.NONE, 0)
	assert_eq(bout.how, "tko")
	assert_eq(bout.winner, 0)


func test_better_fighter_wins_more() -> void:
	var wins := 0
	for s in 20:
		var club := FightClub.new(0)
		club.card[0] = {"red": {"name": "A", "rating": 1550}, "blue": {"name": "B", "rating": 850}, "odds": [1.0, 1.0], "seed": s * 31}
		if club.run_fight(0).winner == 0:
			wins += 1
	assert_gt(wins, 12)
