class_name HuntWar
extends RefCounted
## THE HUNT as a war between sides (part of HuntRules, server-authoritative):
## on a map that opts in ("war": every battleground), each run rolls what
## wins it. A side is a nation (HuntRules.nations: you and your countrymen)
## or, without nations, each hunter alone; squad teammates fight for their
## leader's side.
##   EXTRACT: as ever: cargo out, points; the clock decides.
##   HOLD: a control point in the middle. A side alone on it builds its time;
##     HOLD_SECONDS held in all wins.
##   DROPS: supply drops of minerals land round the site every DROP_EVERY;
##     DROP_TARGET of them extracted by a side wins.
##   CAMPS: every side has a camp; an enemy standing at its core with
##     interact held for SABOTAGE_TICKS (no defender near) blows one of its
##     CAMP_CHARGES. The last side with a camp standing wins.
## A win is final: the server ends the match; the winners score WIN_POINTS.

enum Objective { EXTRACT, HOLD, DROPS, CAMPS }
const IDS := ["extract", "hold", "drops", "camps"]
## Out of 10 runs: how often each comes up.
const WEIGHTS := [4, 2, 2, 2]

const HOLD_SECONDS := 300
const HOLD_RADIUS := 7.0
const DROP_EVERY := 90 * 60
const DROP_TARGET := 6
const CAMP_CHARGES := 3
const SABOTAGE_TICKS := 300
const CAMP_RADIUS := 3.0
const GUARD_RADIUS := 9.0
const WIN_POINTS := 300


class Camp:
	var side: int = 0
	var at := Vector3.ZERO
	var charges: int = CAMP_CHARGES
	var saboteur: int = 0
	var progress: int = 0


var enabled: bool = false
var objective: int = Objective.EXTRACT
var point := Vector3.ZERO
var camp_spots: Array[Vector3] = []
var camps: Array[Camp] = []
var hold: Dictionary = {}  ## side -> ticks held
var holder: int = -1  ## the side alone on the point now (-1: nobody, or contested)
var drops: Dictionary = {}  ## side -> drops extracted
var next_drop_tick: int = 0
var winner_side: int = -1
var _rng := RandomNumberGenerator.new()
## Tools and screenshots: every run gets this objective (-1: rolled).
static var force_objective: int = -1


func configure(map: Dictionary) -> void:
	enabled = bool(map.get("war", false))
	point = map.get("war_point", Vector3.ZERO)
	camp_spots.assign(map.get("war_camps", []))


## A new run: roll the objective (from the match seed, on its own stream)
## and set up the sides' camps.
func start(world: SimWorld, hunt: HuntRules) -> void:
	hold.clear()
	drops.clear()
	camps.clear()
	holder = -1
	winner_side = -1
	objective = Objective.EXTRACT
	if not enabled:
		return
	_rng.seed = hash(["war", world.match_seed])
	var roll := _rng.randi_range(0, 9)
	for i in WEIGHTS.size():
		roll -= int(WEIGHTS[i])
		if roll < 0:
			objective = i
			break
	if force_objective >= 0:
		objective = force_objective
	if objective == Objective.CAMPS:
		var sides := sides_in(world, hunt)
		for i in mini(sides.size(), camp_spots.size()):
			var c := Camp.new()
			c.side = sides[i]
			c.at = camp_spots[i]
			camps.append(c)
		if camps.size() < 2:
			objective = Objective.EXTRACT  # one side: no war of camps
			camps.clear()
	next_drop_tick = world.tick + DROP_EVERY / 3
	world._emit("hw2:%d" % world.tick, "hunt", {"action": "war_objective", "player": 0, "position": point,
			"treasure": 0, "kind": -1, "objective": IDS[objective]})


## Whose side `id` fights for.
func side_of(hunt: HuntRules, id: int) -> int:
	var who := hunt.squad.leader_of(id) if hunt.squad.is_member(id) else id
	if hunt.nations.has(who):
		return 100 + int(hunt.nations[who])  # a nation (apart from hunter ids)
	return who


## The sides of the hunters in the run, in a stable order.
func sides_in(world: SimWorld, hunt: HuntRules) -> Array:
	var out := []
	var ids := world.players.keys()
	ids.sort()
	for id: int in ids:
		if hunt._aux(id):
			continue
		var s := side_of(hunt, id)
		if not s in out:
			out.append(s)
	return out


func step(world: SimWorld, hunt: HuntRules, ids: Array, interacting: Dictionary) -> void:
	if not enabled or winner_side >= 0:
		return
	match objective:
		Objective.HOLD:
			_step_hold(world, hunt, ids)
		Objective.DROPS:
			if world.tick >= next_drop_tick:
				next_drop_tick = world.tick + DROP_EVERY
				_drop(world, hunt)
		Objective.CAMPS:
			_step_camps(world, hunt, ids, interacting)


func _step_hold(world: SimWorld, hunt: HuntRules, ids: Array) -> void:
	var present := []
	for id: int in ids:
		var p: SimPlayer = world.players[id]
		if p.state.alive and HuntRules._flat(p.state.position, point) <= HOLD_RADIUS:
			var s := side_of(hunt, id)
			if not s in present:
				present.append(s)
	var now := int(present[0]) if present.size() == 1 else -1
	if now != holder:
		holder = now
		world._emit("hw3:%d" % world.tick, "hunt", {"action": "war_hold", "player": 0, "position": point,
				"treasure": 0, "kind": -1, "side": holder})
	if holder < 0:
		return
	hold[holder] = int(hold.get(holder, 0)) + 1
	if int(hold[holder]) >= HOLD_SECONDS * Sim.TICK_RATE:
		_win(world, hunt, holder)


## A supply drop: a mineral cache somewhere on the site (a cargo spot no
## one's assignment lies on), announced where it lands.
func _drop(world: SimWorld, hunt: HuntRules) -> void:
	if hunt.spots.is_empty():
		return
	var at: Vector3 = hunt.spots[_rng.randi_range(0, hunt.spots.size() - 1)]
	var res: String = HuntResources.IDS[_rng.randi_range(0, HuntResources.IDS.size() - 1)]
	var c := hunt.spawn_cache(world, res, hunt._floor_at(world, at + Vector3.UP * 1.5))
	if c != null:
		world._emit("hw4:%d" % world.tick, "hunt", {"action": "war_drop", "player": 0, "position": c.position,
				"treasure": c.id, "kind": -1, "resource": res})


## A resource banked: in DROPS, a point for the banker's side.
func on_banked(world: SimWorld, hunt: HuntRules, banker: int, t: HuntRules.Treasure) -> void:
	if not enabled or objective != Objective.DROPS or t.kind != HuntRules.Kind.RESOURCE or winner_side >= 0:
		return
	var s := side_of(hunt, banker)
	drops[s] = int(drops.get(s, 0)) + 1
	if int(drops[s]) >= DROP_TARGET:
		_win(world, hunt, s)


func _step_camps(world: SimWorld, hunt: HuntRules, ids: Array, interacting: Dictionary) -> void:
	for c in camps:
		if c.charges <= 0:
			continue
		var guarded := false
		var at_core := 0
		for id: int in ids:
			var p: SimPlayer = world.players[id]
			if not p.state.alive:
				continue
			var d := HuntRules._flat(p.state.position, c.at)
			var s := side_of(hunt, id)
			if s == c.side and d <= GUARD_RADIUS:
				guarded = true
			elif s != c.side and d <= CAMP_RADIUS and interacting.has(id) and at_core == 0:
				at_core = id
		if guarded or at_core == 0 or (c.saboteur != 0 and c.saboteur != at_core):
			c.saboteur = 0
			c.progress = 0
			if at_core != 0 and not guarded:
				c.saboteur = at_core
			continue
		c.saboteur = at_core
		c.progress += 1
		if c.progress >= SABOTAGE_TICKS:
			c.progress = 0
			c.saboteur = 0
			c.charges -= 1
			world._emit("hw5:%d:%d" % [c.side, world.tick], "hunt", {"action": "war_sabotage", "player": at_core,
					"position": c.at, "treasure": 0, "kind": -1, "side": c.side, "charges": c.charges})
	var standing := camps.filter(func(c: Camp) -> bool: return c.charges > 0)
	if standing.size() == 1:
		_win(world, hunt, (standing[0] as Camp).side)


## Who leads when the clock runs out: most held, most drops, most charges left.
func leader_side() -> int:
	var best := -1
	var best_v := -1
	var table := {}
	match objective:
		Objective.HOLD:
			table = hold
		Objective.DROPS:
			table = drops
		Objective.CAMPS:
			for c in camps:
				table[c.side] = c.charges
	for s: int in table:
		if int(table[s]) > best_v:
			best_v = int(table[s])
			best = s
	return best


func _win(world: SimWorld, hunt: HuntRules, side: int) -> void:
	winner_side = side
	for id: int in world.players:
		if not hunt._aux(id) and side_of(hunt, id) == side:
			world.scores[id] = world.scores.get(id, 0) + WIN_POINTS
	world._emit("hw6:%d" % world.tick, "hunt", {"action": "war_won", "player": 0, "position": point,
			"treasure": 0, "kind": -1, "side": side, "objective": IDS[objective]})


## A hunter of the winning side with the best score (the match's winner).
func winner_id(world: SimWorld, hunt: HuntRules) -> int:
	var best := 0
	var best_s := -INF
	for id: int in world.players:
		if not hunt._aux(id) and side_of(hunt, id) == winner_side and float(world.scores.get(id, 0)) > best_s:
			best_s = float(world.scores.get(id, 0))
			best = id
	return best
