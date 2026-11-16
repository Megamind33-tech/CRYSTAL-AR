class_name MercBrain
extends BotBrain
## A hired mercenary (THE HUNT, Mercenary Contract): an ordinary bot body
## with BotBrain's perception, aim, movement, traversal and stuck recovery,
## but its own goals. It never hunts treasure (HuntRules won't let it carry
## any) and never picks fights: it engages only threats, meaning a hunter
## who recently hurt its employer or itself, or, under DEFEND, any hunter
## close to the employer. Orders come from the contract (HuntEconomy):
## FOLLOW keeps a few metres behind the employer, off its line; HOLD stays
## where the order was given; DEFEND follows closer and engages anyone near;
## RETREAT regroups on the employer and doesn't engage.

const Order := HuntEconomy.Order
const FOLLOW_NEAR := 3.0  ## closer than this to the spot: stand
const FOLLOW_BEHIND := 4.0
const FOLLOW_SIDE := 2.0
const DEFEND_RADIUS := 12.0
const THREAT_TICKS := 300  ## a hunter stays a threat this long after hurting us

var employer: int = 0
var _threats: Dictionary = {}  ## hunter id -> tick it last hurt the employer or us


func _init(world: SimWorld, nav: BotNavigation, id: int, seed_value: int, p_employer: int) -> void:
	super(world, nav, id, seed_value, Difficulty.NORMAL)
	employer = p_employer


## Damage to the employer or to us marks the attacker as a threat (the
## server forwards the employer's hits too).
func on_event(e: Dictionary) -> void:
	if e.type == "hit" and (e.target == employer or e.target == _id) and e.attacker != employer \
			and e.attacker != _id and e.attacker != 0:
		_threats[e.attacker] = _world.tick
	super(e)


func _choose_goal(tick: int, p: SimPlayer) -> void:
	var c: HuntEconomy.Contract = _world.hunt.economy.contracts.get(employer) if _world.hunt != null else null
	var boss: SimPlayer = _world.players.get(employer)
	if c == null or boss == null:
		goal = Goal.ROAM  # the server removes us shortly
		return
	var target: SimPlayer = _world.players.get(target_id)
	if c.order != Order.RETREAT and _visible and target != null and _is_threat(tick, c, boss, target):
		var s := p.state
		var losing := s.shield <= 0.0 and s.health < CONFIG.retreat_health
		if not losing:
			goal = Goal.ATTACK
			return
	target_id = 0 if c.order == Order.RETREAT else target_id
	_set_objective(_station(p, c, boss))


func _is_threat(tick: int, c: HuntEconomy.Contract, boss: SimPlayer, target: SimPlayer) -> bool:
	if tick - int(_threats.get(target.net_id, -100000)) < THREAT_TICKS:
		return true
	if _world.hunt != null and _world.hunt.in_truce(tick):
		return false  # the opening truce: only someone who hurt us is a threat
	return c.order == Order.DEFEND and target.state.position.distance_to(boss.state.position) < DEFEND_RADIUS


## Where to stand: behind and to the side of the employer (out of its line
## of fire and path), the hold point, or right here when close enough.
func _station(p: SimPlayer, c: HuntEconomy.Contract, boss: SimPlayer) -> Vector3:
	var spot := c.hold_at
	if c.order != Order.HOLD:
		var yaw := boss.state.yaw
		var back := Vector3(sin(yaw), 0.0, cos(yaw))
		var side := Vector3(cos(yaw), 0.0, -sin(yaw)) * (FOLLOW_SIDE if _id % 2 == 0 else -FOLLOW_SIDE)
		var behind := FOLLOW_BEHIND * (0.6 if c.order == Order.DEFEND else 1.0)
		spot = boss.state.position + back * behind + side
	if p.state.position.distance_to(spot) < FOLLOW_NEAR:
		return p.state.position
	return spot
