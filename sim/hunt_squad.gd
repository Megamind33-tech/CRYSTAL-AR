class_name HuntSquad
extends RefCounted
## THE HUNT's squads (part of HuntRules, server-authoritative): a hunter
## deploys with up to MAX_SIZE AI teammates, each with a role, and commands
## them through the run: orders (to everyone or one role), rules of
## engagement, keeping together or spreading out, and one-tap strategies
## that set all of it. The server spawns each teammate as an ordinary bot
## body driven by SquadBrain (same models, weapons, navigation, damage).
##
## Teammates are no hunters (no assignments, credits or bounties) but they
## may carry their leader's own cargo and extract it: the points, credits and
## haul go to the leader. Leader and teammates never hurt each other.

enum Order { FOLLOW, HOLD, GUARD_PAD, ESCORT, FETCH, ATTACK, FALL_BACK }
const ORDER_IDS := ["follow", "hold", "guard_pad", "escort", "fetch", "attack", "fall_back"]
enum Rule { HOLD_FIRE, RETURN_FIRE, WEAPONS_FREE }
const RULE_IDS := ["hold_fire", "return_fire", "weapons_free"]
const SPREAD_IDS := ["together", "spread"]
const MAX_SIZE := 3

## Roles: what each brings. `engage` is how far (m) it opens fire on its
## own under WEAPONS_FREE; the rest are effects HuntSquad.step applies.
const ROLES := {
	"gunner": {"engage": 45.0},
	"scout": {"engage": 25.0, "reveal_every": 900, "reveal_ticks": 420},
	"medic": {"engage": 20.0, "heal_every": 120, "heal": 8.0, "heal_radius": 7.0},
	"engineer": {"engage": 25.0, "work_radius": 4.0},
}
const ROLE_IDS := ["gunner", "scout", "medic", "engineer"]

## One-tap plans: the rule, the spread, and each role's order.
const STRATEGIES := {
	"stealth": {"rule": Rule.HOLD_FIRE, "spread": 1,
			"orders": {"gunner": Order.FOLLOW, "scout": Order.FETCH, "medic": Order.FOLLOW, "engineer": Order.FETCH}},
	"assault": {"rule": Rule.WEAPONS_FREE, "spread": 0,
			"orders": {"gunner": Order.ATTACK, "scout": Order.ATTACK, "medic": Order.FOLLOW, "engineer": Order.FOLLOW}},
	"turtle": {"rule": Rule.RETURN_FIRE, "spread": 1,
			"orders": {"gunner": Order.GUARD_PAD, "scout": Order.GUARD_PAD, "medic": Order.ESCORT, "engineer": Order.GUARD_PAD}},
	"bodyguard": {"rule": Rule.RETURN_FIRE, "spread": 0,
			"orders": {"gunner": Order.ESCORT, "scout": Order.ESCORT, "medic": Order.ESCORT, "engineer": Order.ESCORT}},
}
const STRATEGY_IDS := ["stealth", "assault", "turtle", "bodyguard"]


class Member:
	var id: int = 0  ## net id once spawned (0 while pending)
	var leader: int = 0
	var role: String = "gunner"
	var order: int = Order.FOLLOW
	var hold_at := Vector3.ZERO
	var target: int = 0  ## ATTACK: who
	var slot: int = 0  ## place in the squad (spacing round the leader)


class Squad:
	var leader: int = 0
	var members: Array[Member] = []
	var rule: int = Rule.RETURN_FIRE
	var spread: int = 0  ## 0 together, 1 spread out
	var strategy: String = ""


var squads: Dictionary = {}  ## leader id -> Squad
var by_id: Dictionary = {}  ## teammate net id -> Member
## Server work queues (the simulation can't create bodies itself).
var pending: Array[Member] = []  ## teammates waiting for a body
var pending_dismissals: Array[int] = []  ## teammate ids to remove


func reset() -> void:
	for id: int in by_id:
		pending_dismissals.append(id)
	squads.clear()
	by_id.clear()
	pending.clear()


func is_member(id: int) -> bool:
	return by_id.has(id)


func leader_of(id: int) -> int:
	var m: Member = by_id.get(id)
	return m.leader if m != null else 0


func squad_of(leader: int) -> Squad:
	return squads.get(leader)


## Leader and teammates, and teammates of one squad, never hurt each other.
func same_side(a: int, b: int) -> bool:
	var la := leader_of(a) if is_member(a) else a
	var lb := leader_of(b) if is_member(b) else b
	return la != 0 and la == lb and (is_member(a) or is_member(b))


## A squad of `roles` (up to MAX_SIZE) deploys with `leader`: their bodies
## come from the server next tick.
func form(world: SimWorld, leader: int, roles: Array) -> bool:
	if not world.players.has(leader) or squads.has(leader) or roles.is_empty():
		return false
	var sq := Squad.new()
	sq.leader = leader
	for r: String in roles.slice(0, MAX_SIZE):
		if not ROLES.has(r):
			continue
		var m := Member.new()
		m.leader = leader
		m.role = r
		m.slot = sq.members.size()
		sq.members.append(m)
		pending.append(m)
	if sq.members.is_empty():
		return false
	squads[leader] = sq
	_emit(world, leader, "squad_formed", {"size": sq.members.size()})
	return true


## The server spawned `member`'s body as `id`.
func bind(member: Member, id: int) -> void:
	member.id = id
	by_id[id] = member


## An order to the whole squad (`role` "") or to the teammates of one role.
func order(world: SimWorld, leader: int, order_id: String, role: String = "", target: int = 0) -> bool:
	var sq: Squad = squads.get(leader)
	var o := ORDER_IDS.find(order_id)
	if sq == null or o < 0:
		return false
	var any := false
	for m in sq.members:
		if not role.is_empty() and m.role != role:
			continue
		_set_order(world, m, o, target)
		any = true
	if any:
		sq.strategy = ""  # a hand-given order: no plan any more
		_emit(world, leader, "squad_order", {"order": order_id, "role": role})
	return any


func _set_order(world: SimWorld, m: Member, o: int, target: int) -> void:
	m.order = o
	m.target = target if o == Order.ATTACK else 0
	if o == Order.HOLD:
		var body: SimPlayer = world.players.get(m.id)
		var lead: SimPlayer = world.players.get(m.leader)
		m.hold_at = body.state.position if body != null else (lead.state.position if lead != null else Vector3.ZERO)


func set_rule(world: SimWorld, leader: int, rule_id: String) -> bool:
	var sq: Squad = squads.get(leader)
	var r := RULE_IDS.find(rule_id)
	if sq == null or r < 0:
		return false
	sq.rule = r
	_emit(world, leader, "squad_rule", {"rule": rule_id})
	return true


func set_spread(world: SimWorld, leader: int, spread_id: String) -> bool:
	var sq: Squad = squads.get(leader)
	var s := SPREAD_IDS.find(spread_id)
	if sq == null or s < 0:
		return false
	sq.spread = s
	_emit(world, leader, "squad_spread", {"spread": spread_id})
	return true


func set_strategy(world: SimWorld, leader: int, strategy_id: String) -> bool:
	var sq: Squad = squads.get(leader)
	if sq == null or not STRATEGIES.has(strategy_id):
		return false
	var plan: Dictionary = STRATEGIES[strategy_id]
	sq.rule = int(plan.rule)
	sq.spread = int(plan.spread)
	for m in sq.members:
		_set_order(world, m, int(plan.orders.get(m.role, Order.FOLLOW)), 0)
	sq.strategy = strategy_id
	_emit(world, leader, "squad_strategy", {"strategy": strategy_id})
	return true


## Roles at work: the medic patches up the squad and its leader, the scout
## marks the nearest rival now and then. (The engineer's help with the vault
## and caches: work_bonus.)
func step(world: SimWorld, hunt: HuntRules) -> void:
	var tick := world.tick
	for leader: int in squads:
		var sq: Squad = squads[leader]
		var lead: SimPlayer = world.players.get(leader)
		for m in sq.members:
			var body: SimPlayer = world.players.get(m.id)
			if body == null or not body.state.alive:
				continue
			var info: Dictionary = ROLES[m.role]
			if m.role == "medic" and tick % int(info.heal_every) == 0:
				var patients: Array[SimPlayer] = []
				if lead != null:
					patients.append(lead)
				for other in sq.members:
					if world.players.has(other.id):
						patients.append(world.players[other.id])
				for pt in patients:
					if pt.state.alive and pt.state.position.distance_to(body.state.position) <= float(info.heal_radius):
						pt.state.health = minf(pt.state.health + float(info.heal), Balance.PLAYER.max_health)
			if m.role == "scout" and tick % int(info.reveal_every) == 0 and lead != null:
				var rival := _nearest_rival(world, hunt, leader, body.state.position)
				if rival != 0:
					hunt.revealed_until[rival] = maxi(int(hunt.revealed_until.get(rival, 0)), tick + int(info.reveal_ticks))
					_emit(world, leader, "squad_spotted", {"target": rival})


## Extra progress a leader's work (the vault's lock, a cache) gets this
## tick from an engineer working beside them.
func work_bonus(world: SimWorld, leader: int) -> int:
	var sq: Squad = squads.get(leader)
	var lead: SimPlayer = world.players.get(leader)
	if sq == null or lead == null:
		return 0
	for m in sq.members:
		var body: SimPlayer = world.players.get(m.id)
		if m.role == "engineer" and body != null and body.state.alive \
				and body.state.position.distance_to(lead.state.position) <= float(ROLES.engineer.work_radius):
			return 1
	return 0


## A death: a fallen teammate leaves the squad (its body is removed).
func on_death(world: SimWorld, victim: int) -> void:
	var m: Member = by_id.get(victim)
	if m == null:
		return
	var sq: Squad = squads.get(m.leader)
	if sq != null:
		sq.members.erase(m)
		if sq.members.is_empty():
			squads.erase(m.leader)
	by_id.erase(victim)
	pending_dismissals.append(victim)
	_emit(world, m.leader, "squad_down", {"role": m.role})


## The leader is gone (left the match): the squad goes with them.
func disband(world: SimWorld, leader: int) -> void:
	var sq: Squad = squads.get(leader)
	if sq == null:
		return
	for m in sq.members:
		if m.id != 0:
			by_id.erase(m.id)
			pending_dismissals.append(m.id)
		pending.erase(m)
	squads.erase(leader)


func _nearest_rival(world: SimWorld, hunt: HuntRules, leader: int, from: Vector3) -> int:
	var best := 0
	var best_d := INF
	for id: int in world.players:
		var p: SimPlayer = world.players[id]
		if id == leader or not p.state.alive or is_member(id) or hunt.economy.is_merc(id) or hunt.friendly(leader, id):
			continue
		var d := p.state.position.distance_to(from)
		if d < best_d:
			best_d = d
			best = id
	return best


func _emit(world: SimWorld, leader: int, action: String, extra: Dictionary) -> void:
	var e := {"action": action, "player": leader, "position": Vector3.ZERO, "treasure": 0, "kind": -1}
	e.merge(extra)
	world._emit("hq:%s:%d:%d" % [action, leader, world.tick], "hunt", e)
