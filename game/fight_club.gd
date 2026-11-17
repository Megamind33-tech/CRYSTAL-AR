class_name FightClub
extends RefCounted
## The Pit: the underground fight club. A fight card of AI brawlers with
## ratings; bet your cash on a corner (odds from the ratings, with the house
## cut), or step into the ring yourself: one on one, unarmed, three rounds,
## a referee. Pure logic (no nodes): the city calls `card_for`, `place_bet`,
## `settle`, and drives a `Bout` each tick.

const HOUSE_EDGE := 0.08          ## the book pays 92% of fair odds
const MIN_BET := 10
const MAX_BET := 5000
const ROUNDS := 3
const ROUND_TICKS := 60 * Sim.TICK_RATE
const BREAK_TICKS := 5 * Sim.TICK_RATE
const TKO_KNOCKDOWNS := 3
const WALK_SPEED := 2.5 / Sim.TICK_RATE   ## metres per tick
const RING_HALF := 3.0
const PURSE_WIN := 400                    ## your purse for a win in the ring
const PURSE_SHOW := 50                    ## for showing up and losing
const KNOCKDOWN_POINTS := 10.0

const NAMES := ["Rust Kowalski", "Iron Maeve", "Dusty Okafor", "Red Sato", "Big Lenny",
		"Vex", "Crater Jones", "Mama Ruiz", "Hollow Pete", "Ion Ivanova", "Sledge", "Quiet Kim"]


## Probability that a fighter rated `ra` beats one rated `rb` (Elo).
static func win_chance(ra: float, rb: float) -> float:
	return 1.0 / (1.0 + pow(10.0, (rb - ra) / 400.0))


## Decimal odds the book offers on a fighter with win chance `p`
## (stake included in the return). Never below 1.05.
static func odds(p: float) -> float:
	return maxf(1.05, snappedf((1.0 - HOUSE_EDGE) / clampf(p, 0.01, 0.99), 0.01))


## What a winning bet returns (stake included).
static func payout(stake: int, decimal_odds: float) -> int:
	return floori(stake * decimal_odds)


## Skill for a FightBrain from a rating (800 -> 0.1, 1600 -> 0.9).
static func skill_of(rating: int) -> float:
	return clampf(0.1 + (rating - 800) / 1000.0, 0.05, 0.95)


## Tonight's card: `count` fights, deterministic from `seed_value` (e.g. the
## day). Each fight: {"red": {name, rating}, "blue": {...}, "odds": [r, b]}.
static func card_for(seed_value: int, count: int = 4) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array = NAMES.duplicate()
	var card: Array = []
	for i in count:
		var pair: Array = []
		for c in 2:
			var name: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			pair.append({"name": name, "rating": rng.randi_range(850, 1550)})
		var p := win_chance(pair[0].rating, pair[1].rating)
		card.append({"red": pair[0], "blue": pair[1], "odds": [odds(p), odds(1.0 - p)], "seed": rng.randi()})
	return card


var card: Array = []
var bets: Array = []  ## {"fight", "corner" (0 red/1 blue), "stake", "odds"}
var results := {}     ## fight index -> winning corner


func _init(seed_value: int = 0) -> void:
	card = card_for(seed_value)


## Takes `stake` from the career's wallet (Career.pay) and records the bet.
func place_bet(career: Object, fight: int, corner: int, stake: int) -> bool:
	if fight < 0 or fight >= card.size() or results.has(fight) or corner not in [0, 1]:
		return false
	if stake < MIN_BET or stake > MAX_BET or not career.pay(stake):
		return false
	bets.append({"fight": fight, "corner": corner, "stake": stake, "odds": card[fight].odds[corner]})
	return true


## Runs fight `fight` (AI vs AI) to the end and returns the Bout.
func run_fight(fight: int) -> Bout:
	var f: Dictionary = card[fight]
	var bout := Bout.new()
	var red := FightBrain.new(skill_of(f.red.rating), f.seed)
	var blue := FightBrain.new(skill_of(f.blue.rating), f.seed + 1)
	while not bout.over:
		var a := red.decide(bout.red, bout.blue)
		var b := blue.decide(bout.blue, bout.red)
		bout.tick(a[0], a[1], b[0], b[1])
	results[fight] = bout.winner
	return bout


## Pays out every bet on `fight` (needs a result). Returns the total paid in.
func settle(career: Object, fight: int) -> int:
	if not results.has(fight):
		return 0
	var paid := 0
	for bet: Dictionary in bets.duplicate():
		if bet.fight != fight:
			continue
		bets.erase(bet)
		if bet.corner == results[fight]:
			paid += payout(bet.stake, bet.odds)
	career.d.wallet += paid
	if "earned" in career.d:
		career.d.earned += maxi(0, paid)
	return paid


## Your purse after your own bout.
static func purse(won: bool) -> int:
	return PURSE_WIN if won else PURSE_SHOW


## One bout: red (0) vs blue (1), rounds, a referee. Call `tick` once per sim
## tick with each corner's [move, walk]. Ends on KO (hp 0), TKO (three
## knockdowns in a round) or the judges' decision after the last round
## (damage dealt + 10 per knockdown; red wins a dead draw only on hp left,
## then blue).
class Bout:
	extends RefCounted
	var red := MeleeMoves.Fighter.new()
	var blue := MeleeMoves.Fighter.new()
	var round_no: int = 1
	var clock: int = 0          ## ticks into the round
	var breaking: int = 0       ## ticks left in the break between rounds
	var over: bool = false
	var winner: int = -1
	var how: String = ""        ## "ko", "tko", "decision"
	var points := [0.0, 0.0]    ## judges' cards, summed over finished rounds
	var events: Array = []      ## this tick's [corner, event] (for the HUD / sound)

	func _init() -> void:
		_corners()

	func _corners() -> void:
		red.pos = -1.5
		blue.pos = 1.5

	func tick(red_move: int, red_walk: int, blue_move: int, blue_walk: int) -> void:
		events.clear()
		if over:
			return
		if breaking > 0:
			breaking -= 1
			return
		MeleeMoves.press(red, red_move)
		MeleeMoves.press(blue, blue_move)
		_walk(red, blue, red_walk)
		_walk(blue, red, blue_walk)
		MeleeMoves.step(red)
		MeleeMoves.step(blue)
		var e1 := MeleeMoves.resolve(red, blue)
		var e2 := MeleeMoves.resolve(blue, red)
		if not e1.is_empty():
			events.append([0, e1])
		if not e2.is_empty():
			events.append([1, e2])
		if red.out() or blue.out():
			_end(1 if red.out() else 0, "ko")
			return
		if red.knockdowns >= FightClub.TKO_KNOCKDOWNS or blue.knockdowns >= FightClub.TKO_KNOCKDOWNS:
			_end(1 if red.knockdowns >= FightClub.TKO_KNOCKDOWNS else 0, "tko")
			return
		clock += 1
		if clock >= FightClub.ROUND_TICKS:
			_score_round()
			if round_no >= FightClub.ROUNDS:
				_decision()
			else:
				round_no += 1
				clock = 0
				breaking = FightClub.BREAK_TICKS
				red.reset_round()
				blue.reset_round()
				_corners()

	func _walk(f: MeleeMoves.Fighter, other: MeleeMoves.Fighter, dir: int) -> void:
		if dir == 0 or not (f.phase in [MeleeMoves.Phase.IDLE, MeleeMoves.Phase.BLOCKING]):
			return
		var toward := signf(other.pos - f.pos)
		var np := f.pos + toward * dir * FightClub.WALK_SPEED
		np = clampf(np, -FightClub.RING_HALF, FightClub.RING_HALF)
		if absf(np - other.pos) < 0.6:
			return
		f.pos = np

	func _score_round() -> void:
		points[0] += red.damage_dealt + FightClub.KNOCKDOWN_POINTS * red.knockdowns_scored
		points[1] += blue.damage_dealt + FightClub.KNOCKDOWN_POINTS * blue.knockdowns_scored

	func _decision() -> void:
		if points[0] != points[1]:
			_end(0 if points[0] > points[1] else 1, "decision")
		else:
			_end(0 if red.hp >= blue.hp else 1, "decision")

	func _end(w: int, p_how: String) -> void:
		over = true
		winner = w
		how = p_how
