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
## Air units have health ("hp"): air defence (HuntCamps' flak, Meridian's
## aegis battery, Halden's bastion) shoots them down. Nations change these
## by their doctrine (NationArsenal).
const UNITS := {
	"scout_drone": {"ticks": 1800, "radius": 60.0, "height": 22.0, "hp": 40.0},
	"attack_drone": {"ticks": 1500, "radius": 30.0, "every": 20, "damage": 7.0, "height": 16.0, "hp": 60.0},
	"swarm": {"ticks": 1500, "radius": 30.0, "every": 20, "damage": 5.0, "height": 15.0, "hp": 40.0, "count": 3},
	"gunship": {"ticks": 2400, "radius": 42.0, "every": 18, "damage": 12.0, "height": 26.0, "hp": 160.0},
	"strike_jet": {"delay": 180, "length": 90.0, "width": 7.0, "damage": 75.0, "height": 40.0, "hp": 120.0},
	"raptor": {"delay": 150, "length": 90.0, "width": 7.0, "damage": 60.0, "height": 36.0, "hp": 110.0, "passes": 2,
			"between": 150},
	"tank": {"radius": 34.0, "every": 24, "damage": 11.0},
	"bastion": {"radius": 36.0, "every": 22, "damage": 13.0, "air_range": 55.0, "air_damage": 14.0},
}
const AIR := ["scout_drone", "attack_drone", "swarm", "gunship", "strike_jet", "raptor"]
const JETS := ["strike_jet", "raptor"]
const LEVEL_BONUS := 0.15
## Rival AI hunters in a war bring a small army (an attack drone and their
## nation's own unit, or a strike jet) and call a unit in on the nearest
## enemy now and then.
const BOT_EVERY := 1800
const MACHINE_RADIUS := 14.0
## Extraction progress per tick beside a machine: hauler, crawler, tank,
## each level adding MACHINE_LEVEL_BONUS.
const MACHINE_SPEED := {"hauler": 1, "crawler": 2, "tank": 1, "bastion": 1}
const MACHINE_LEVEL_BONUS := 1


class Call:
	var unit: String = ""
	var hp: float = 0.0
	var nation: String = ""
	var passes: int = 1
	var offset := 0.0  ## a swarm drone's place in the circle
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
	u[unit] = int(u.get(unit, 0)) + (1 if unit in AIR else 0)
	used[id] = u
	if not NationArsenal.allowed(NationArsenal.of(hunt, id), unit):
		return false  # another nation's
	if unit == "crawler" or unit == "tank" or unit == "bastion":
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
		c.nation = NationArsenal.of(hunt, id)
		c.hp = float(UNITS[unit].get("hp", 1.0)) * NationArsenal.mod(c.nation, unit, "hp")
		c.passes = int(UNITS[unit].get("passes", 1))
		calls.append(c)
		for k in range(1, int(UNITS[unit].get("count", 1))):  # a swarm: more of them
			var more := Call.new()
			more.unit = unit
			more.owner = id
			more.level = lv
			more.at = target
			more.from = c.from
			more.start_tick = c.start_tick
			more.end_tick = c.end_tick
			more.nation = c.nation
			more.hp = c.hp
			more.offset = TAU * k / float(UNITS[unit].count)
			calls.append(more)
	world._emit("ha:%d:%s:%d" % [id, unit, world.tick], "hunt", {"action": "unit_called", "player": id,
			"position": target, "treasure": 0, "kind": -1, "unit": unit})
	return true


func step(world: SimWorld, hunt: HuntRules) -> void:
	var tick := world.tick
	if hunt.war.enabled and tick % BOT_EVERY == BOT_EVERY / 2:
		_bots_call(world, hunt)
	for c in calls.duplicate():
		if tick < c.start_tick:
			continue
		var info: Dictionary = UNITS[c.unit]
		var boost: float = (1.0 + LEVEL_BONUS * c.level) * NationArsenal.mod(c.nation, c.unit, "damage")
		match c.unit:
			"scout_drone":
				if (tick - c.start_tick) % 60 == 0:
					for id: int in world.players:
						var o: SimPlayer = world.players[id]
						if o.state.alive and _enemy(hunt, c.owner, id) and o.state.position.distance_to(c.at) <= float(info.radius):
							hunt.revealed_until[id] = maxi(int(hunt.revealed_until.get(id, 0)), tick + 120)
			"attack_drone", "gunship", "swarm":
				if (tick - c.start_tick) % int(info.every) == 0:
					_fire(world, hunt, c.owner, position_of(c, tick), float(info.radius) + float(info.height),
							float(info.damage) * boost)
			"strike_jet", "raptor":
				_strafe(world, hunt, c, info, boost)
				c.passes -= 1
				if c.passes <= 0:
					calls.erase(c)
				else:
					c.start_tick = tick + int(info.between)  # round again for another pass
				continue
		if tick >= c.end_tick:
			calls.erase(c)
	# The tanks' guns (Halden's bastion fires on aircraft as well).
	for vi: int in machines:
		var mm: Array = machines[vi]
		if not (mm[1] in ["tank", "bastion"]) or vi >= world.vehicles.size():
			continue
		var info: Dictionary = UNITS[mm[1]]
		var nation := NationArsenal.of(hunt, int(mm[0]))
		var dmg := float(info.damage) * (1.0 + LEVEL_BONUS * int(mm[2])) * NationArsenal.mod(nation, "tank", "damage")
		var v: SimVehicle = world.vehicles[vi]
		if tick % int(info.every) == 0:
			_fire(world, hunt, int(mm[0]), v.position + Vector3(0, 2.4, 0), float(info.radius), dmg)
		if mm[1] == "bastion" and tick % int(info.every) == int(info.every) / 2:
			shoot_air(world, hunt, int(mm[0]), v.position + Vector3(0, 2.8, 0), float(info.air_range), float(info.air_damage))


## Where a unit in the air is now: a jet flying in along its run (till it
## strafes), a drone or gunship circling over its target.
func position_of(c: Call, tick: int) -> Vector3:
	var info: Dictionary = UNITS[c.unit]
	if c.unit in JETS:
		var dir := c.at - c.from
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
		var u := clampf(1.0 - float(c.start_tick - tick) / float(info.delay), 0.0, 1.0)
		return (c.at - dir * 260.0).lerp(c.at, u) + Vector3(0, float(info.height), 0)
	var t := float(tick) / 60.0 + c.offset
	var r := 12.0 if c.unit == "gunship" else 6.0
	return c.at + Vector3(cos(t * 0.6) * r, float(info.height), sin(t * 0.6) * r)


## Air defence at `from`: the nearest enemy aircraft within `reach` takes
## `damage`; one brought down is gone (emits "unit_downed").
func shoot_air(world: SimWorld, hunt: HuntRules, owner: int, from: Vector3, reach: float, damage: float) -> bool:
	var best: Call = null
	var best_d := reach
	var tick := world.tick
	for c in calls:
		if not (c.unit in AIR) or not _enemy(hunt, owner, c.owner) or tick < c.start_tick - int(UNITS[c.unit].get("delay", 0)):
			continue
		var d := position_of(c, tick).distance_to(from)
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		return false
	best.hp -= damage
	if best.hp <= 0.0:
		calls.erase(best)
		world._emit("hd:%d:%s:%d" % [best.owner, best.unit, tick], "hunt", {"action": "unit_downed", "player": owner,
				"position": position_of(best, tick), "treasure": 0, "kind": -1, "unit": best.unit, "owner": best.owner})
	return true


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
			var nation := NationArsenal.of(hunt, lead)
			best = maxi(best, int(MACHINE_SPEED[mm[1]]) + MACHINE_LEVEL_BONUS * int(mm[2])
					+ int(NationArsenal.mod(nation, mm[1], "extract")) - 1)
	return best


func _bots_call(world: SimWorld, hunt: HuntRules) -> void:
	for id: int in world.players:
		var p: SimPlayer = world.players[id]
		if not p.is_bot or hunt._aux(id) or not p.state.alive:
			continue
		if not rosters.has(id):
			var n := NationArsenal.of(hunt, id)
			var own: String = NationArsenal.ARSENALS.get(n, {}).get("unique", "")
			var air := own if own in AIR else "strike_jet"
			rosters[id] = {"attack_drone": [1, 0], air: [1, 0]}
		var foe: SimPlayer = null
		var best := 120.0
		for oid: int in world.players:
			var o: SimPlayer = world.players[oid]
			if o.state.alive and not hunt._aux(oid) and _enemy(hunt, id, oid) and o.state.position.distance_to(p.state.position) < best:
				best = o.state.position.distance_to(p.state.position)
				foe = o
		if foe == null:
			continue
		for u: String in rosters[id]:
			if left(id, u) > 0:
				call_unit(world, hunt, id, u, foe.state.position)
				break
