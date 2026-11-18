class_name SquadBrain
extends MercBrain
## A squad teammate (HuntSquad): a bot body with BotBrain's perception, aim,
## movement and stuck recovery (through MercBrain: threats are whoever hurt
## its leader or itself), doing what its leader says.
##
## Orders: FOLLOW (behind the leader, wider when the squad spreads out),
## HOLD (where it was told), GUARD_PAD (round the extraction pad nearest the
## leader), ESCORT (close round the leader), FETCH (to the leader's nearest
## cargo: it picks it up and extracts it for them), ATTACK (the leader's
## mark, else the rival nearest the leader), FALL_BACK (on the leader, no
## fighting). Rules of engagement: HOLD_FIRE (never shoots), RETURN_FIRE
## (threats only), WEAPONS_FREE (any rival in its role's range).
## Carrying cargo it makes for a pad whatever the order.

const SqOrder := HuntSquad.Order
const SqRule := HuntSquad.Rule
const RING := 3.5         ## metres round the leader (ESCORT: closer)
const SPREAD_RING := 9.0  ## spread out
const PAD_RING := 6.0     ## round a pad it guards
const ATTACK_RANGE := 60.0


func _init(world: SimWorld, nav: BotNavigation, id: int, seed_value: int, p_leader: int) -> void:
	super(world, nav, id, seed_value, p_leader)


func _member() -> HuntSquad.Member:
	return _world.hunt.squad.by_id.get(_id) if _world.hunt != null else null


func _choose_goal(tick: int, p: SimPlayer) -> void:
	var h := _world.hunt
	var m := _member()
	var boss: SimPlayer = _world.players.get(employer)
	var sq: HuntSquad.Squad = h.squad.squad_of(employer) if h != null else null
	if m == null or sq == null or boss == null:
		goal = Goal.ROAM  # the server removes us shortly
		return
	# Carrying the leader's cargo: to a pad, whatever else is going on.
	if h.carried_by(_id) != null:
		target_id = 0
		_set_objective(h.nearest_zone(p.state.position, tick))
		return
	var target: SimPlayer = _world.players.get(target_id)
	if target != null and (h.friendly(_id, target_id) or target_id == employer):
		target_id = 0
		target = null
	var peaceful := sq.rule == SqRule.HOLD_FIRE or m.order == SqOrder.FALL_BACK
	if not peaceful and _visible and target != null and _engages(tick, m, sq, boss, p, target):
		var losing := p.state.shield <= 0.0 and p.state.health < CONFIG.retreat_health
		if not losing:
			goal = Goal.ATTACK
			return
	if peaceful:
		target_id = 0
	_set_objective(_squad_station(tick, p, m, sq, boss))


## Whether to fight `target`, by the squad's rule and this teammate's order.
func _engages(tick: int, m: HuntSquad.Member, sq: HuntSquad.Squad, boss: SimPlayer, p: SimPlayer,
		target: SimPlayer) -> bool:
	if tick - int(_threats.get(target.net_id, -100000)) < THREAT_TICKS:
		return true  # it hurt us or the leader: always answered (bar HOLD_FIRE)
	if _world.hunt.in_truce(tick):
		return false
	if m.order == SqOrder.ATTACK and target.net_id == _attack_target(m, boss):
		return true
	if sq.rule == SqRule.WEAPONS_FREE:
		var reach: float = HuntSquad.ROLES[m.role].engage
		return target.state.position.distance_to(p.state.position) <= reach
	return false


## Who an ATTACK order is after: the leader's mark, else the rival nearest
## the leader (within ATTACK_RANGE).
func _attack_target(m: HuntSquad.Member, boss: SimPlayer) -> int:
	if m.target != 0 and _world.players.has(m.target) and _world.players[m.target].state.alive:
		return m.target
	var best := 0
	var best_d := ATTACK_RANGE
	for id: int in _world.players:
		var o: SimPlayer = _world.players[id]
		if id == employer or id == _id or not o.state.alive or _world.hunt.friendly(employer, id) \
				or _world.hunt.squad.is_member(id):
			continue
		var d := o.state.position.distance_to(boss.state.position)
		if d < best_d:
			best_d = d
			best = id
	return best


## Where to be for the order.
func _squad_station(tick: int, p: SimPlayer, m: HuntSquad.Member, sq: HuntSquad.Squad, boss: SimPlayer) -> Vector3:
	var h := _world.hunt
	var lead := boss.state.position
	var spot := lead
	match m.order:
		SqOrder.HOLD:
			spot = m.hold_at
		SqOrder.GUARD_PAD:
			spot = _ring(h.nearest_zone(lead, tick), PAD_RING, m.slot, sq.members.size(), 0.0)
		SqOrder.ESCORT:
			spot = _ring(lead, 2.2, m.slot, sq.members.size(), boss.state.yaw)
		SqOrder.FETCH:
			spot = _ring(lead, RING, m.slot, sq.members.size(), boss.state.yaw)
			var best := INF
			for t in h.assignments_of(employer):
				if t.on_ground():
					var d := t.position.distance_to(p.state.position)
					if d < best:
						best = d
						spot = t.position  # walk onto it: the pickup is automatic
		SqOrder.ATTACK:
			var who := _attack_target(m, boss)
			spot = _world.players[who].state.position if who != 0 else _ring(lead, RING, m.slot, sq.members.size(), boss.state.yaw)
			target_id = who if who != 0 else target_id
		SqOrder.FALL_BACK:
			spot = _ring(lead, 1.8, m.slot, sq.members.size(), boss.state.yaw)
		_:  # FOLLOW: behind the leader, out of their line of fire
			var r := SPREAD_RING if sq.spread == 1 else RING
			spot = _ring(lead, r, m.slot, sq.members.size(), boss.state.yaw, true)
	if p.state.position.distance_to(spot) < FOLLOW_NEAR * 0.6:
		return p.state.position
	return spot


## A place on a ring of radius `r` round `c` for the `slot`-th of `n`:
## behind (`behind`: in the half circle at the leader's back) or all round.
static func _ring(c: Vector3, r: float, slot: int, n: int, yaw: float, behind: bool = false) -> Vector3:
	var span := PI if behind else TAU
	var a := yaw + (span * (float(slot) + 0.5) / float(maxi(n, 1))) - (span * 0.5 if behind else 0.0)
	return c + Vector3(sin(a), 0.0, cos(a)) * r
