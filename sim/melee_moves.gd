class_name MeleeMoves
extends RefCounted
## Hand-to-hand (fight club, and later free-roam brawls). Pure, tick-based and
## deterministic: no nodes, no randomness. Two `Fighter`s on a line; each tick
## you `press` a move, then `step` both and `resolve` hits.
##
## Rules:
## - LIGHT: 4 windup / 2 active / 6 recover ticks, 8 damage, 10 stamina.
## - HEAVY: 12 / 3 / 14, 20 damage, 25 stamina. A heavy that lands while the
##   target is winding up (a counter) knocks them down.
## - BLOCK (hold): a blocked light does 1 chip; a blocked heavy does 30% and
##   costs the blocker 30 stamina: at 0 stamina the guard breaks (stunned 30).
## - COMBO: light, light, heavy, each started within 14 ticks of the last hit
##   landing. The finisher does x1.5 and always knocks down.
## - KNOCKDOWN: down for 60 ticks, untouchable. Three in a round is a TKO.
## - Hit: target is stunned 10 (light) / 18 (heavy) ticks and can't act.
## - Stamina regenerates 0.5/tick when not attacking; moves need the stamina.
## - Reach: 1.6 m between the two.

enum Move { NONE, LIGHT, HEAVY, BLOCK }
enum Phase { IDLE, WINDUP, ACTIVE, RECOVER, BLOCKING, STUNNED, DOWN }

const REACH := 1.6
const COMBO_WINDOW := 14
const DOWN_TICKS := 60
const GUARD_BREAK_STUN := 30
const STAMINA_MAX := 100.0
const STAMINA_REGEN := 0.5
const BLOCK_CHIP_LIGHT := 1.0
const BLOCK_HEAVY_FACTOR := 0.3
const BLOCK_HEAVY_STAMINA := 30.0
const COMBO_FINISH_MULT := 1.5

const SPEC := {
	Move.LIGHT: {"windup": 4, "active": 2, "recover": 6, "damage": 8.0, "stamina": 10.0, "stun": 10},
	Move.HEAVY: {"windup": 12, "active": 3, "recover": 14, "damage": 20.0, "stamina": 25.0, "stun": 18},
}


class Fighter:
	extends RefCounted
	var hp: float = 100.0
	var stamina: float = MeleeMoves.STAMINA_MAX
	var pos: float = 0.0
	var phase: int = MeleeMoves.Phase.IDLE
	var move: int = MeleeMoves.Move.NONE
	var timer: int = 0
	var hit_done: bool = false
	var combo: int = 0              ## hits landed in the current chain (light, light...)
	var combo_timer: int = 0
	var finisher: bool = false      ## this heavy is a combo finisher
	var knockdowns: int = 0         ## taken this round
	var damage_dealt: float = 0.0   ## this round (for the judges)
	var knockdowns_scored: int = 0  ## this round

	func can_act() -> bool:
		return phase == MeleeMoves.Phase.IDLE or phase == MeleeMoves.Phase.BLOCKING

	func out() -> bool:
		return hp <= 0.0

	func reset_round() -> void:
		stamina = MeleeMoves.STAMINA_MAX
		phase = MeleeMoves.Phase.IDLE
		move = MeleeMoves.Move.NONE
		timer = 0
		combo = 0
		combo_timer = 0
		knockdowns = 0
		damage_dealt = 0.0
		knockdowns_scored = 0


## Start a move (or hold/release block). Returns false if it can't be done now.
static func press(f: Fighter, m: int) -> bool:
	if not f.can_act():
		return false
	if m == Move.NONE:
		if f.phase == Phase.BLOCKING:
			f.phase = Phase.IDLE
		return true
	if m == Move.BLOCK:
		f.phase = Phase.BLOCKING
		return true
	var s: Dictionary = SPEC[m]
	if f.stamina < s.stamina:
		return false
	f.stamina -= s.stamina
	f.finisher = m == Move.HEAVY and f.combo >= 2 and f.combo_timer > 0
	if m == Move.LIGHT and f.combo_timer <= 0:
		f.combo = 0
	f.move = m
	f.phase = Phase.WINDUP
	f.timer = s.windup
	f.hit_done = false
	return true


## Advance one fighter's timers by a tick.
static func step(f: Fighter) -> void:
	if f.combo_timer > 0:
		f.combo_timer -= 1
		if f.combo_timer == 0:
			f.combo = 0
	if f.phase in [Phase.IDLE, Phase.BLOCKING]:
		f.stamina = minf(STAMINA_MAX, f.stamina + STAMINA_REGEN)
		return
	f.timer -= 1
	if f.timer > 0:
		return
	match f.phase:
		Phase.WINDUP:
			f.phase = Phase.ACTIVE
			f.timer = SPEC[f.move].active
		Phase.ACTIVE:
			f.phase = Phase.RECOVER
			f.timer = SPEC[f.move].recover
		_:
			f.phase = Phase.IDLE
			f.move = Move.NONE


## If `a` is in its active frames and in reach, land on `b`. Returns an event
## dictionary ({} when nothing happened): {"kind": hit|blocked|guard_break,
## "damage", "knockdown", "combo", "counter"}.
static func resolve(a: Fighter, b: Fighter) -> Dictionary:
	if a.phase != Phase.ACTIVE or a.hit_done or absf(a.pos - b.pos) > REACH:
		return {}
	if b.phase == Phase.DOWN:
		return {}
	a.hit_done = true
	var s: Dictionary = SPEC[a.move]
	var heavy := a.move == Move.HEAVY
	if b.phase == Phase.BLOCKING:
		if not heavy:
			return _deal(a, b, BLOCK_CHIP_LIGHT, {"kind": "blocked"})
		b.stamina -= BLOCK_HEAVY_STAMINA
		if b.stamina <= 0.0:
			b.stamina = 0.0
			var ev := _deal(a, b, s.damage, {"kind": "guard_break"})
			_stun(b, GUARD_BREAK_STUN)
			return ev
		return _deal(a, b, s.damage * BLOCK_HEAVY_FACTOR, {"kind": "blocked"})
	var counter: bool = b.phase == Phase.WINDUP
	var dmg: float = s.damage
	var knock := false
	if heavy and a.finisher:
		dmg *= COMBO_FINISH_MULT
		knock = true
	if heavy and counter:
		knock = true
	var ev := _deal(a, b, dmg, {"kind": "hit", "counter": counter, "combo": a.combo + 1})
	if heavy:
		a.combo = 0
		a.combo_timer = 0
	else:
		a.combo += 1
		a.combo_timer = COMBO_WINDOW
	if knock and not b.out():
		b.phase = Phase.DOWN
		b.timer = DOWN_TICKS
		b.move = Move.NONE
		b.knockdowns += 1
		a.knockdowns_scored += 1
	elif not b.out():
		_stun(b, s.stun)
	ev["knockdown"] = knock
	return ev


static func _deal(a: Fighter, b: Fighter, dmg: float, ev: Dictionary) -> Dictionary:
	dmg = minf(dmg, b.hp)
	b.hp -= dmg
	a.damage_dealt += dmg
	ev["damage"] = dmg
	ev["knockdown"] = false
	return ev


static func _stun(f: Fighter, ticks: int) -> void:
	f.phase = Phase.STUNNED
	f.timer = ticks
	f.move = Move.NONE
	f.combo = 0
	f.combo_timer = 0
