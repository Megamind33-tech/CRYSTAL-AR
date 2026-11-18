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

enum Objective { EXTRACT, HOLD, DROPS, CAMPS, KING, CONVOY, TERRITORY, LAST_STANDING, RACE }
const IDS := ["extract", "hold", "drops", "camps", "king", "convoy", "territory", "last_standing", "race"]
## Out of 10 runs: how often each comes up.
const WEIGHTS := [3, 1, 1, 1, 1, 1, 1, 1, 1]
##   KING: unlock the vault and hold its relic; a side scores while one of
##     its people carries it; KING_SECONDS held wins (the relic can't be
##     extracted in this war).
##   CONVOY: a supply crawler in the middle; a side alone beside it pushes
##     it towards the nearest enemy camp; reaching it wins.
##   TERRITORY: three flags; a side alone on one for CAPTURE_SECONDS takes
##     it; each flag held scores a point a second; TERRITORY_TARGET wins.
##   LAST_STANDING: each side has SIDE_LIVES; out of lives and nobody left
##     alive, it's out; the last side in wins.
##   RACE: RACE_SECONDS of resource drops (one every RACE_DROP_EVERY);
##     the side with most extracted when time is up wins.
const KING_SECONDS := 180
const CONVOY_SPEED := 2.5  ## m/s
const CONVOY_RADIUS := 8.0
const CONVOY_GOAL := 12.0
const CAPTURE_SECONDS := 10
const TERRITORY_TARGET := 400
const SIDE_LIVES := 12
const RACE_SECONDS := 360
const RACE_DROP_EVERY := 30 * 60

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
var king: Dictionary = {}  ## side -> ticks it held the relic
var convoy := Vector3.ZERO
var convoy_pusher: int = -1
var flags: Array = []  ## [position, owner side (-1), capturing side, progress ticks]
var territory: Dictionary = {}  ## side -> points
var lives: Dictionary = {}  ## side -> lives left
var out_sides: Array = []
var race_end_tick: int = 0
var builds := HuntCamps.new()  ## what the sides build at their camps
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
	king.clear()
	flags.clear()
	territory.clear()
	lives.clear()
	out_sides.clear()
	convoy_pusher = -1
	builds.reset()
	holder = -1
	winner_side = -1
	objective = Objective.EXTRACT
	if not enabled:
		return
	_rng.seed = hash(["war", world.match_seed])
	var total := 0
	for w in WEIGHTS:
		total += int(w)
	var roll := _rng.randi_range(0, total - 1)
	for i in WEIGHTS.size():
		roll -= int(WEIGHTS[i])
		if roll < 0:
			objective = i
			break
	if force_objective >= 0:
		objective = force_objective
	# Every side has a camp in a war, whatever wins it (HuntCamps: they build).
	var sides := sides_in(world, hunt)
	for i in mini(sides.size(), camp_spots.size()):
		var c := Camp.new()
		c.side = sides[i]
		c.at = camp_spots[i]
		camps.append(c)
	if objective == Objective.CAMPS and camps.size() < 2:
		objective = Objective.EXTRACT  # one side: no war of camps
	if (objective == Objective.CONVOY or objective == Objective.LAST_STANDING) and sides.size() < 2:
		objective = Objective.EXTRACT
	builds.start(world, self)
	next_drop_tick = world.tick + DROP_EVERY / 3
	match objective:
		Objective.CONVOY:
			convoy = point
		Objective.TERRITORY:
			flags.append([point, -1, -1, 0])
			for k in [0, hunt.spots.size() / 2]:
				if k < hunt.spots.size():
					flags.append([hunt.spots[k], -1, -1, 0])
		Objective.LAST_STANDING:
			for sd in sides:
				lives[sd] = SIDE_LIVES
		Objective.RACE:
			race_end_tick = world.tick + RACE_SECONDS * Sim.TICK_RATE
			next_drop_tick = world.tick + 60
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
	builds.step(world, hunt, ids)
	match objective:
		Objective.HOLD:
			_step_hold(world, hunt, ids)
		Objective.DROPS:
			if world.tick >= next_drop_tick:
				next_drop_tick = world.tick + DROP_EVERY
				_drop(world, hunt)
		Objective.CAMPS:
			_step_camps(world, hunt, ids, interacting)
		Objective.KING:
			var g := hunt.grand()
			if g != null and g.carrier != 0 and world.players.has(g.carrier):
				var sd := side_of(hunt, g.carrier)
				king[sd] = int(king.get(sd, 0)) + 1
				if int(king[sd]) >= KING_SECONDS * Sim.TICK_RATE:
					_win(world, hunt, sd)
		Objective.CONVOY:
			_step_convoy(world, hunt, ids)
		Objective.TERRITORY:
			_step_territory(world, hunt, ids)
		Objective.LAST_STANDING:
			var alive_in := []
			for sd: int in lives:
				if sd in out_sides:
					continue
				var anyone := false
				for id: int in ids:
					if world.players[id].state.alive and side_of(hunt, id) == sd:
						anyone = true
				if int(lives[sd]) <= 0 and not anyone:
					out_sides.append(sd)
					world._emit("hw7:%d:%d" % [sd, world.tick], "hunt", {"action": "war_side_out", "player": 0,
							"position": point, "treasure": 0, "kind": -1, "side": sd})
				else:
					alive_in.append(sd)
			if alive_in.size() == 1:
				_win(world, hunt, alive_in[0])
		Objective.RACE:
			if world.tick >= next_drop_tick:
				next_drop_tick = world.tick + RACE_DROP_EVERY
				_drop(world, hunt)
			if world.tick >= race_end_tick:
				var lead := leader_side()
				if lead >= 0:
					_win(world, hunt, lead)
				else:
					race_end_tick = world.tick + 60 * Sim.TICK_RATE  # nobody's got any: a minute more


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
	if not enabled or (objective != Objective.DROPS and objective != Objective.RACE) or t.kind != HuntRules.Kind.RESOURCE or winner_side >= 0:
		return
	var s := side_of(hunt, banker)
	drops[s] = int(drops.get(s, 0)) + 1
	if objective == Objective.DROPS and int(drops[s]) >= DROP_TARGET:
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
		Objective.KING:
			table = king
		Objective.TERRITORY:
			table = territory
		Objective.LAST_STANDING:
			table = lives
		Objective.RACE:
			table = drops
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


## In a King war the relic stays in play: it can't be extracted.
func blocks_extract(t: HuntRules.Treasure) -> bool:
	return enabled and objective == Objective.KING and t.kind == HuntRules.Kind.GRAND


## A death: in Last Standing it costs the side a life.
func on_death(hunt: HuntRules, victim: int) -> void:
	if not enabled or objective != Objective.LAST_STANDING or hunt._aux(victim):
		return
	var sd := side_of(hunt, victim)
	if lives.has(sd):
		lives[sd] = maxi(int(lives[sd]) - 1, 0)


## The convoy: pushed by a side alone beside it, towards that side's
## nearest enemy camp; arriving there wins.
func _step_convoy(world: SimWorld, hunt: HuntRules, ids: Array) -> void:
	var present := []
	for id: int in ids:
		var p: SimPlayer = world.players[id]
		if p.state.alive and HuntRules._flat(p.state.position, convoy) <= CONVOY_RADIUS:
			var sd := side_of(hunt, id)
			if not sd in present:
				present.append(sd)
	convoy_pusher = int(present[0]) if present.size() == 1 else -1
	if convoy_pusher < 0:
		return
	var goal := Vector3.INF
	for c in camps:
		if c.side != convoy_pusher and (goal == Vector3.INF or c.at.distance_to(convoy) < goal.distance_to(convoy)):
			goal = c.at
	if goal == Vector3.INF:
		return
	var to := goal - convoy
	to.y = 0.0
	if to.length() <= CONVOY_GOAL:
		_win(world, hunt, convoy_pusher)
		return
	var next := convoy + to.normalized() * CONVOY_SPEED / Sim.TICK_RATE
	var floor := hunt._floor_at(world, next + Vector3.UP * 3.0)
	convoy = Vector3(next.x, floor.y, next.z)


## Territory: flags taken by a side alone on them; each held flag scores.
func _step_territory(world: SimWorld, hunt: HuntRules, ids: Array) -> void:
	for f: Array in flags:
		var present := []
		for id: int in ids:
			var p: SimPlayer = world.players[id]
			if p.state.alive and HuntRules._flat(p.state.position, f[0]) <= HOLD_RADIUS:
				var sd := side_of(hunt, id)
				if not sd in present:
					present.append(sd)
		var alone := int(present[0]) if present.size() == 1 else -1
		if alone >= 0 and alone != int(f[1]):
			if alone != int(f[2]):
				f[2] = alone
				f[3] = 0
			f[3] = int(f[3]) + 1
			if int(f[3]) >= CAPTURE_SECONDS * Sim.TICK_RATE:
				f[1] = alone
				f[3] = 0
				world._emit("hw8:%d:%d" % [alone, world.tick], "hunt", {"action": "war_flag", "player": 0,
						"position": f[0], "treasure": 0, "kind": -1, "side": alone})
		elif alone < 0:
			f[3] = maxi(int(f[3]) - 1, 0)
	if world.tick % Sim.TICK_RATE == 0:
		for f: Array in flags:
			if int(f[1]) >= 0:
				territory[f[1]] = int(territory.get(f[1], 0)) + 1
				if int(territory[f[1]]) >= TERRITORY_TARGET:
					_win(world, hunt, int(f[1]))
					return
