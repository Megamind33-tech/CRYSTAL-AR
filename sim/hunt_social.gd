class_name HuntSocial
extends RefCounted
## THE HUNT's social rules, part of HuntRules (server-authoritative, the same
## for humans and bots; nothing here reads is_bot).
##
## Most Wanted: a theft or an unprovoked kill puts a bounty on the
## culprit. At WANTED_BOUNTY the hunter is Wanted: every PING_TICKS the
## others learn an APPROXIMATE last-known position (fuzzed, never live
## tracking). Killing a Wanted hunter drops a bounty proof (a HuntRules
## treasure worth the bounty) and clears the bounty, so a target can't be
## farmed; the proof counts only once extracted. Carrying treasure never
## makes anyone a criminal on its own.
##
## Alliances (Vault Standoff, Double-Cross): one hunter proposes, the other
## accepts or rejects within PROPOSAL_TICKS. Allies can't hurt each other
## and share information. Either may leave peacefully (protection holds for
## DISSOLVE_GRACE_TICKS, no penalty) or betray (protection ends at once; the
## betrayer loses reputation and gets a bounty; the betrayed is alerted).
## One alliance per hunter.

const WANTED_BOUNTY := 50
const MAX_BOUNTY := 400
## Theft: a base plus a share of what was taken.
const STEAL_BOUNTY_BASE := 50  ## any theft makes the thief Wanted
const STEAL_BOUNTY_SHARE := 0.25
## Killing a hunter who carried nothing, wasn't Wanted and hadn't hurt the
## killer in the last PROVOCATION_TICKS.
const UNPROVOKED_KILL_BOUNTY := 30
const PROVOCATION_TICKS := 600
## Last-known positions: public every 20 s, every 8 s for hunters who
## accepted the contract, fuzzed by up to PING_FUZZ metres.
const PING_TICKS := 1200
const CONTRACT_PING_TICKS := 480
const PING_FUZZ := 8.0
## A last-known position older than this is no use to anyone.
const LAST_KNOWN_TTL := 1800
const PROPOSAL_TICKS := 600
const DISSOLVE_GRACE_TICKS := 300
const START_REPUTATION := 100
const BETRAYAL_REPUTATION := 40
const BETRAYAL_BOUNTY := 100
## A modest bonus for an ally when its partner banks the grand treasure
## during an alliance at least this old (once per alliance).
const COOPERATION_BONUS := 40
const COOPERATION_MIN_TICKS := 1800

var bounty: Dictionary = {}  ## net id -> posted bounty
var last_known: Dictionary = {}  ## target id -> {"position": Vector3, "tick": int}
var contracts: Dictionary = {}  ## hunter id -> target id (accepted bounty contracts)
var claimed: Dictionary = {}  ## net id -> bounty points claimed (stats)
var allies: Dictionary = {}  ## net id -> partner id (both directions)
var alliance_since: Dictionary = {}  ## net id -> tick the alliance formed
var dissolving: Dictionary = {}  ## net id -> tick its peaceful exit completes
var proposals: Dictionary = {}  ## recipient id -> {"from": id, "expires": tick}
var reputation: Dictionary = {}  ## net id -> 0..100 (missing: START_REPUTATION)
var _bonus_paid: Dictionary = {}  ## alliance key -> true
var _next_public_ping: Dictionary = {}  ## target -> tick
var _next_contract_ping: Dictionary = {}  ## target -> tick
var _rng := RandomNumberGenerator.new()


func reset(seed_value: int) -> void:
	_rng.seed = seed_value ^ 0x5eed
	bounty.clear()
	last_known.clear()
	contracts.clear()
	claimed.clear()
	allies.clear()
	alliance_since.clear()
	dissolving.clear()
	proposals.clear()
	reputation.clear()
	_bonus_paid.clear()
	_next_public_ping.clear()
	_next_contract_ping.clear()


func is_wanted(id: int) -> bool:
	return bounty.get(id, 0) >= WANTED_BOUNTY


func add_bounty(world: SimWorld, id: int, amount: int, reason: String) -> void:
	if amount <= 0 or not world.players.has(id):
		return
	var was_wanted := is_wanted(id)
	bounty[id] = mini(bounty.get(id, 0) + amount, MAX_BOUNTY)
	world._emit("hb:%d:%d:%s" % [id, world.tick, reason], "hunt", {"action": "bounty", "player": id,
			"amount": amount, "bounty": bounty[id], "reason": reason, "wanted": is_wanted(id),
			"position": Vector3.ZERO, "treasure": 0, "kind": -1})
	if is_wanted(id) and not was_wanted:
		_ping(world, id)


## Accepting a Wanted hunter's contract: more frequent last-known positions.
func accept_contract(world: SimWorld, hunter: int, target: int) -> bool:
	if hunter == target or not is_wanted(target) or not world.players.has(hunter):
		return false
	contracts[hunter] = target
	world._emit("hc:%d:%d:%d" % [hunter, target, world.tick], "hunt", {"action": "contract", "player": hunter,
			"target": target, "position": Vector3.ZERO, "treasure": 0, "kind": -1})
	return true


## Every tick: alliance timers and last-known positions for the Wanted.
func step(world: SimWorld, ids: Array) -> void:
	_step_alliances(world)
	for id in ids:
		if not is_wanted(id) or not world.players[id].state.alive:
			continue
		var has_contract := contracts.values().has(id)
		if world.tick >= _next_public_ping.get(id, 0) \
				or (has_contract and world.tick >= _next_contract_ping.get(id, 0)):
			_ping(world, id)
	for id: int in last_known.keys():
		if world.tick - int(last_known[id].tick) > LAST_KNOWN_TTL:
			last_known.erase(id)


## A death: returns the bounty the killer claims (0 if none) and posts a
## bounty for an unprovoked kill. `victim_carried`: the victim held a
## treasure when it died.
func on_kill(world: SimWorld, victim: SimPlayer, killer: int, suicide: bool, victim_carried: bool) -> int:
	var claim := 0
	if is_wanted(victim.net_id) and not suicide and killer != 0 and world.players.has(killer):
		claim = bounty[victim.net_id]
		claimed[killer] = claimed.get(killer, 0) + claim
		_clear(victim.net_id)
	elif not suicide and killer != 0 and world.players.has(killer) and not victim_carried \
			and not is_wanted(victim.net_id) and not _provoked(world, killer, victim.net_id) \
			and contracts.get(killer, 0) != victim.net_id:
		add_bounty(world, killer, UNPROVOKED_KILL_BOUNTY, "unprovoked_kill")
	return claim


func remove_player(id: int) -> void:
	_clear(id)
	contracts.erase(id)
	if allies.has(id):
		_end_alliance(id)
	proposals.erase(id)


# --- Alliances ---

func allied(a: int, b: int) -> bool:
	return a != b and allies.get(a, 0) == b


func rep_of(id: int) -> int:
	return reputation.get(id, START_REPUTATION)


func propose(world: SimWorld, from: int, to: int) -> bool:
	if from == to or allies.has(from) or allies.has(to) or not world.players.has(to) or proposals.has(to):
		return false
	proposals[to] = {"from": from, "expires": world.tick + PROPOSAL_TICKS}
	_emit(world, "alliance_proposed", from, {"target": to, "reputation": rep_of(from)})
	return true


func respond(world: SimWorld, to: int, accept: bool) -> bool:
	var p: Dictionary = proposals.get(to, {})
	if p.is_empty() or world.tick > int(p.expires):
		proposals.erase(to)
		return false
	proposals.erase(to)
	var from: int = p.from
	if not accept or allies.has(from) or allies.has(to) or not world.players.has(from):
		_emit(world, "alliance_rejected", to, {"target": from})
		return true
	allies[from] = to
	allies[to] = from
	alliance_since[from] = world.tick
	alliance_since[to] = world.tick
	_emit(world, "alliance_formed", from, {"target": to})
	return true


## Leaving peacefully: protection holds a few seconds, no penalty.
func leave(world: SimWorld, id: int) -> bool:
	if not allies.has(id) or dissolving.has(id):
		return false
	var partner: int = allies[id]
	dissolving[id] = world.tick + DISSOLVE_GRACE_TICKS
	dissolving[partner] = dissolving[id]
	_emit(world, "alliance_leaving", id, {"target": partner})
	return true


## Betrayal: protection ends now; reputation and a bounty for the betrayer;
## the betrayed is alerted (the event names the betrayer).
func betray(world: SimWorld, id: int) -> bool:
	if not allies.has(id):
		return false
	var partner: int = allies[id]
	_end_alliance(id)
	reputation[id] = maxi(rep_of(id) - BETRAYAL_REPUTATION, 0)
	_emit(world, "alliance_betrayed", id, {"target": partner, "reputation": reputation[id]})
	add_bounty(world, id, BETRAYAL_BOUNTY, "betrayal")
	return true


## The grand treasure banked by `id`: its ally of long enough earns a
## modest cooperation bonus, once per alliance.
func on_grand_banked(world: SimWorld, id: int) -> void:
	if not allies.has(id) or dissolving.has(id):
		return
	var partner: int = allies[id]
	var key := "%d:%d" % [mini(id, partner), maxi(id, partner)]
	if _bonus_paid.has(key) or world.tick - int(alliance_since.get(id, world.tick)) < COOPERATION_MIN_TICKS:
		return
	_bonus_paid[key] = true
	world.scores[partner] = world.scores.get(partner, 0) + COOPERATION_BONUS
	_emit(world, "cooperation_bonus", partner, {"target": id, "points": COOPERATION_BONUS})


func _step_alliances(world: SimWorld) -> void:
	for to: int in proposals.keys():
		if world.tick > int(proposals[to].expires):
			var from: int = proposals[to].from
			proposals.erase(to)
			_emit(world, "alliance_rejected", to, {"target": from, "expired": true})
	for id: int in dissolving.keys():
		if dissolving.has(id) and world.tick >= int(dissolving[id]) and allies.has(id):
			var partner: int = allies[id]
			_end_alliance(id)
			_emit(world, "alliance_ended", id, {"target": partner})


func _end_alliance(id: int) -> void:
	var partner: int = allies.get(id, 0)
	allies.erase(id)
	allies.erase(partner)
	alliance_since.erase(id)
	alliance_since.erase(partner)
	dissolving.erase(id)
	dissolving.erase(partner)


func _emit(world: SimWorld, action: String, player: int, extra: Dictionary) -> void:
	var data := {"action": action, "player": player, "position": Vector3.ZERO, "treasure": 0, "kind": -1}
	data.merge(extra)
	world._emit("ha%s:%d:%d" % [action.right(4), player, world.tick], "hunt", data)


## Whether `victim` damaged `killer` recently (self-defence is no crime).
func _provoked(world: SimWorld, killer: int, victim: int) -> bool:
	for e: Array in world._damage_log.get(killer, []):
		if e[0] == victim and world.tick - int(e[2]) <= PROVOCATION_TICKS:
			return true
	return false


func _clear(id: int) -> void:
	bounty.erase(id)
	last_known.erase(id)
	_next_public_ping.erase(id)
	_next_contract_ping.erase(id)
	for hunter: int in contracts.keys():
		if contracts[hunter] == id:
			contracts.erase(hunter)


func _ping(world: SimWorld, id: int) -> void:
	var p: SimPlayer = world.players[id]
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(PING_FUZZ * 0.4, PING_FUZZ)
	var approx := p.state.position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	last_known[id] = {"position": approx, "tick": world.tick}
	_next_public_ping[id] = world.tick + PING_TICKS
	_next_contract_ping[id] = world.tick + CONTRACT_PING_TICKS
	world._emit("hp:%d:%d" % [id, world.tick], "hunt", {"action": "wanted_ping", "player": id, "position": approx,
			"bounty": bounty.get(id, 0), "treasure": 0, "kind": -1})
