class_name HuntArmy
extends RefCounted
## THE HUNT's armies (part of HuntRules, server-authoritative): each hunter
## deploys the units of their roster (Career.UNITS, counted and upgraded)
## and calls them in through the run (HuntRules.request "call_unit"):
##   scout_drone: reveals enemies round the target for a while
##   attack_drone, gunship: hover over the target, shoot enemies they can see
##   strike_jet: a strafing run along the line from the caller to the target
##   crawler, tank: a machine arrives by the caller (a vehicle you can drive);
##     the tank's gun fires on enemies in range, driven or not
## Extraction machines (your rover: the hauler, a crawler, a tank) matter at
## the pads: heavy loads (the vault's relic, resources) only go out with one
## of yours parked at the pad, and any load goes out faster beside one
## (more with each upgrade).
## Units called in are spent; machines come home unless destroyed.

## Effects per unit: duration (ticks), reach (m), how often it fires,
## damage; each upgrade level adds LEVEL_BONUS.
const UNITS := {
	"scout_drone": {"ticks": 1800, "radius": 60.0, "height": 22.0},
	"attack_drone": {"ticks": 1500, "radius": 30.0, "every": 20, "damage": 7.0, "height": 16.0},
	"gunship": {"ticks": 2400, "radius": 42.0, "every": 18, "damage": 12.0, "height": 26.0},
	"strike_jet": {"delay": 180, "length": 90.0, "width": 7.0, "damage": 75.0, "height": 40.0},
	"tank": {"radius": 34.0, "every": 24, "damage": 11.0},
}
const LEVEL_BONUS := 0.15
const MACHINE_RADIUS := 14.0
## Extraction progress per tick beside a machine: hauler, crawler, tank,
## each level adding MACHINE_LEVEL_BONUS.
const MACHINE_SPEED := {"hauler": 1, "crawler": 2, "tank": 1}
const MACHINE_LEVEL_BONUS := 1


class Call:
	var unit: String = ""
	var owner: int = 0
	var level: int = 0
	var at := Vector3.ZERO  ## target (on the ground)
	var from := Vector3.ZERO  ## a jet's run starts here
	var start_tick: int = 0
	var end_tick: int = 0


## hunter id -> {unit: [count left, level]}
var rosters: Dictionary = {}
## hunter id -> {unit: used} (for the career afterwards)
var used: Dictionary = {}
var calls: Array[Call] = []
## vehicle index -> [owner, unit, level]: the army's machines in the world
var machines: Dictionary = {}


func reset() -> void:
	rosters.clear()
	used.clear()
	calls.clear()
	machines.clear()


## A hunter's army for this run (the match passes Career.army_deploy).
func deploy(id: int, roster: Dictionary) -> void:
	var r := {}
	for u: String in roster:
		r[u] = [int(roster[u][0]), int(roster[u][1])]
	rosters[id] = r


## Your own rover is your hauler (machines: its vehicle index).
func set_hauler(id: int, vehicle_index: int) -> void:
	var lv := int(rosters.get(id, {}).get("hauler", [1, 0])[1])
	machines[vehicle_index] = [id, "hauler", lv]


func left(id: int, unit: String) -> int:
	return int(rosters.get(id, {}).get(unit, [0, 0])[0])


## `id` calls `unit` in at `target` (where they aim).
func call_unit(world: SimWorld, hunt: HuntRules, id: int, unit: String, target: Vector3) -> bool:
	var p: SimPlayer = world.players.get(id)
	if p == null or not p.state.alive or left(id, unit) <= 0 or unit == "hauler":
		return false
	var lv := int(rosters[id][unit][1])
	rosters[id][unit][0] = left(id, unit) - 1
	var u: Dictionary = used.get(id, {})
	u[unit] = int(u.get(unit, 0)) + (1 if unit in ["scout_drone", "attack_drone", "gunship", "strike_jet"] else 0)
	used[id] = u
	if unit == "crawler" or unit == "tank":
		var yaw := p.state.yaw
		var at := p.state.position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 6.0 + Vector3(0, 0.4, 0)
		var v := world.add_vehicle(at, yaw)
		v.model = VehicleSim.CRAWLER if unit == "crawler" else VehicleSim.TANK
		v.owner = id
		machines[world.vehicles.size() - 1] = [id, unit, lv]
	else:
		var c := Call.new()
		c.unit = unit
		c.owner = id
		c.level = lv
		c.at = target
		c.from = p.state.position
		c.start_tick = world.tick + int(UNITS[unit].get("delay", 0))
		c.end_tick = c.start_tick + int(UNITS[unit].get("ticks", 1))
		calls.append(c)
	world._emit("ha:%d:%s:%d" % [id, unit, world.tick], "hunt", {"action": "unit_called", "player": id,
			"position": target, "treasure": 0, "kind": -1, "unit": unit})
	return true


func step(world: SimWorld, hunt: HuntRules) -> void:
	var tick := world.tick
	for c in calls.duplicate():
		if tick < c.start_tick:
			continue
		var info: Dictionary = UNITS[c.unit]
		var boost: float = 1.0 + LEVEL_BONUS * c.level
		match c.unit:
			"scout_drone":
				if (tick - c.start_tick) % 60 == 0:
					for id: int in world.players:
						var o: SimPlayer = world.players[id]
						if o.state.alive and _enemy(hunt, c.owner, id) and o.state.position.distance_to(c.at) <= float(info.radius):
							hunt.revealed_until[id] = maxi(int(hunt.revealed_until.get(id, 0)), tick + 120)
			"attack_drone", "gunship":
				if (tick - c.start_tick) % int(info.every) == 0:
					_fire(world, hunt, c.owner, c.at + Vector3(0, float(info.height), 0), float(info.radius) + float(info.height),
							float(info.damage) * boost)
			"strike_jet":
				_strafe(world, hunt, c, info, boost)
				calls.erase(c)
				continue
		if tick >= c.end_tick:
			calls.erase(c)
	# The tanks' guns.
	for vi: int in machines:
		var mm: Array = machines[vi]
		if mm[1] != "tank" or vi >= world.vehicles.size():
			continue
		var info: Dictionary = UNITS.tank
		if tick % int(info.every) == 0:
			var v: SimVehicle = world.vehicles[vi]
			_fire(world, hunt, int(mm[0]), v.position + Vector3(0, 2.4, 0), float(info.radius),
					float(info.damage) * (1.0 + LEVEL_BONUS * int(mm[2])))


## A strike jet's run: everyone of the enemy along the line from where it
## was called to the target and on, within its width, is hit hard.
func _strafe(world: SimWorld, hunt: HuntRules, c: Call, info: Dictionary, boost: float) -> void:
	var dir := c.at - c.from
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var a := c.at - dir * float(info.length) * 0.5
	var b := c.at + dir * float(info.length) * 0.5
	for id: int in world.players:
		var o: SimPlayer = world.players[id]
		if not o.state.alive or not _enemy(hunt, c.owner, id):
			continue
		var q := Geometry3D.get_closest_point_to_segment(o.state.position, a, b)
		if Vector2(q.x - o.state.position.x, q.z - o.state.position.z).length() <= float(info.width):
			world._damage(o, c.owner if world.players.has(c.owner) else 0, float(info.damage) * boost, false,
					Weapons.by_id(&"pulse_rifle"), world.tick)
	world._emit("hj:%d:%d" % [c.owner, world.tick], "hunt", {"action": "jet_strike", "player": c.owner,
			"position": c.at, "treasure": 0, "kind": -1, "from": a, "to": b})


## A gun at `from`: the nearest enemy it can see within `reach`.
func _fire(world: SimWorld, hunt: HuntRules, owner: int, from: Vector3, reach: float, damage: float) -> void:
	var best: SimPlayer = null
	var best_d := reach
	for id: int in world.players:
		var o: SimPlayer = world.players[id]
		if not o.state.alive or not _enemy(hunt, owner, id):
			continue
		var chest := o.state.position + Vector3(0, 1.2, 0)
		var d := from.distance_to(chest)
		if d >= best_d:
			continue
		var hit := world._ray(from, chest)
		if not hit.is_empty() and from.distance_to(hit.position) < d - 0.6:
			continue
		best = o
		best_d = d
	if best != null:
		world._damage(best, owner if world.players.has(owner) else 0, damage, false, Weapons.by_id(&"pulse_rifle"), world.tick)


func _enemy(hunt: HuntRules, owner: int, id: int) -> bool:
	if id == owner or hunt.friendly(owner, id):
		return false
	if hunt.war.enabled:
		return hunt.war.side_of(hunt, id) != hunt.war.side_of(hunt, owner)
	return true


## Extraction beside a machine: how much faster `carrier`'s load goes out
## at `zone` (0: no machine of theirs there), from their side's machines.
func extraction_boost(world: SimWorld, hunt: HuntRules, carrier: int, zone: Vector3) -> int:
	var best := 0
	var lead := hunt.squad.leader_of(carrier) if hunt.squad.is_member(carrier) else carrier
	for vi: int in machines:
		var mm: Array = machines[vi]
		if int(mm[0]) != lead or vi >= world.vehicles.size():
			continue
		var v: SimVehicle = world.vehicles[vi]
		if HuntRules._flat(v.position, zone) <= MACHINE_RADIUS:
			best = maxi(best, int(MACHINE_SPEED[mm[1]]) + MACHINE_LEVEL_BONUS * int(mm[2]))
	return best
