class_name FightBrain
extends RefCounted
## Drives one AI fighter in the ring (fight club). Skill 0..1 (from the
## rating) sets how often it reacts well: blocks a heavy it sees coming,
## punishes a whiff, goes for the light-light-heavy combo. Seeded RNG, so a
## bout between two brains is a deterministic replay.

var skill: float = 0.5
var rng := RandomNumberGenerator.new()
var _think: int = 0


func _init(p_skill: float, seed_value: int) -> void:
	skill = clampf(p_skill, 0.0, 1.0)
	rng.seed = seed_value


## Returns [move, walk] for this tick: move is a MeleeMoves.Move, walk is
## -1/0/+1 toward (+) or away from (-) the opponent.
func decide(me: MeleeMoves.Fighter, them: MeleeMoves.Fighter) -> Array:
	var dist := absf(me.pos - them.pos)
	if not me.can_act():
		return [MeleeMoves.Move.NONE, 0]
	_think -= 1
	# They're winding up a heavy close by: block it (better fighters see it more).
	if them.phase == MeleeMoves.Phase.WINDUP and them.move == MeleeMoves.Move.HEAVY and dist <= MeleeMoves.REACH + 0.3:
		if rng.randf() < 0.3 + 0.6 * skill:
			return [MeleeMoves.Move.BLOCK, 0]
	if me.phase == MeleeMoves.Phase.BLOCKING and them.phase != MeleeMoves.Phase.WINDUP:
		return [MeleeMoves.Move.NONE, 0]
	if dist > MeleeMoves.REACH * 0.9:
		return [MeleeMoves.Move.NONE, 1]
	if _think > 0:
		return [MeleeMoves.Move.NONE, 0]
	_think = int(lerpf(14.0, 3.0, skill)) + rng.randi_range(0, 4)
	# Mid-combo: finish it.
	if me.combo >= 2 and me.combo_timer > 0 and me.stamina >= 25.0:
		return [MeleeMoves.Move.HEAVY, 0]
	# They're open (recovering or stunned): punish.
	if them.phase in [MeleeMoves.Phase.RECOVER, MeleeMoves.Phase.STUNNED]:
		return [MeleeMoves.Move.LIGHT if rng.randf() < 0.6 else MeleeMoves.Move.HEAVY, 0]
	if me.stamina < 30.0:
		return [MeleeMoves.Move.BLOCK, -1]
	var r := rng.randf()
	if r < 0.55:
		return [MeleeMoves.Move.LIGHT, 0]
	if r < 0.8:
		return [MeleeMoves.Move.HEAVY, 0]
	return [MeleeMoves.Move.BLOCK, 0]
