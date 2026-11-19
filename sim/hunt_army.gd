class_name HuntArmy
extends RefCounted
## THE HUNT's armies (part of HuntRules, server-authoritative): each hunter
## deploys the units of their roster (Career.UNITS, counted and upgraded)
## and calls them in through the run (HuntRules.request "call_unit"):
##   scout_drone: reveals enemies round the target for a while
##   attack_drone, gunship: hover over the target, shoot enemies they can see
##   strike_jet: a strafing run along the line from the caller to the target
##   bomber: a heavy run, a wide carpet of bombs (wrecks camps)
##   mortar: a salvo of shells on the target after a short flight
##   emp_drone: hovers over the target; enemy turrets, flak and tank guns
##     under it go quiet
##   medevac: a rotorcraft over the target heals its side below
##   recon_sat: every enemy on the field shown for a while (not shootable)
##   nations' own: hive (a big swarm, Aurora), aegis_drone (shields its
##     side below, Meridian), nightwing (a jet flak can't see, Vesper),
##     howitzer (heavy shells, Halden), besides swarm, raptor, bastion
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
	"bomber": {"delay": 240, "length": 70.0, "width": 14.0, "damage": 110.0, "height": 48.0, "hp": 220.0},
	"nightwing": {"delay": 120, "length": 80.0, "width": 8.0, "damage": 70.0, "height": 34.0, "hp": 90.0, "stealth": true},
	"mortar": {"delay": 150, "shells": 6, "every": 20, "spread": 9.0, "blast": 5.0, "damage": 38.0},
	"howitzer": {"delay": 210, "shells": 8, "every": 18, "spread": 11.0, "blast": 7.0, "damage": 55.0},
	"emp_drone": {"ticks": 1200, "radius": 35.0, "height": 20.0, "hp": 55.0},
	"medevac": {"ticks": 1200, "radius": 12.0, "every": 60, "heal": 10.0, "height": 14.0, "hp": 110.0},
	"aegis_drone": {"ticks": 1500, "radius": 16.0, "every": 60, "shield": 14.0, "height": 15.0, "hp": 140.0},
	"hive": {"ticks": 1500, "radius": 30.0, "every": 20, "damage": 3.5, "height": 14.0, "hp": 30.0, "count": 6},
	"recon_sat": {"ticks": 900},
	"tank": {"radius": 34.0, "every": 24, "damage": 11.0},
	"bastion": {"radius": 36.0, "every": 22, "damage": 13.0, "air_range": 55.0, "air_damage": 14.0},
}
const AIR := ["scout_drone", "attack_drone", "swarm", "gunship", "strike_jet", "raptor", "bomber", "nightwing", "emp_drone",
		"medevac", "aegis_drone", "hive"]
const JETS := ["strike_jet", "raptor", "bomber", "nightwing"]
## Shells: units that fire from far off (nothing to shoot down).
const ARTILLERY := ["mortar", "howitzer"]
const LEVEL_BONUS := 0.15
## War machines' health (the hauler is your rover: it can't be destroyed);
## a nation's doctrine scales it (NationArsenal "hp").
const MACHINE_HP := {"crawler": 600.0, "tank": 900.0, "bastion": 1300.0}
## How big a target each is for a shot (a sphere's radius, metres).
const HIT_RADIUS := {"scout_drone": 1.0, "attack_drone": 1.3, "swarm": 1.1, "gunship": 3.5, "strike_jet": 4.0,
		"raptor": 4.0, "machine": 2.6, "bomber": 5.5, "nightwing": 3.5, "emp_drone": 1.2, "medevac": 3.0, "aegis_drone": 1.6,
		"hive": 0.9}
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
## vehicle index -> health left (war machines)
var machine_hp: Dictionary = {}


func reset() -> void:
	rosters.clear()
	used.clear()
	calls.clear()
	machines.clear()
	machine_hp.clear()


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
	u[unit] = int(u.get(unit, 0)) + (1 if Career.UNITS.get(unit, {}).get("spent", false) else 0)
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
		machine_hp[world.vehicles.size() - 1] = float(MACHINE_HP[unit]) * NationArsenal.mod(NationArsenal.of(hunt, id),
				"tank" if unit == "bastion" else unit, "hp") * (1.0 + LEVEL_BONUS * lv)
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
			"emp_drone":
				pass  # its work is jammed(): the defences under it ask
			"medevac", "aegis_drone":
				if (tick - c.start_tick) % int(info.every) == 0:
					for id: int in world.players:
						var o: SimPlayer = world.players[id]
						if o.state.alive and not _enemy(hunt, c.owner, id) and o.state.position.distance_to(c.at) <= float(info.radius):
							if info.has("heal"):
								o.state.health = minf(o.state.health + float(info.heal) * boost, Balance.PLAYER.max_health)
							if info.has("shield"):
								o.state.shield = minf(o.state.shield + float(info.shield) * boost, Balance.PLAYER.max_shield)
			"recon_sat":
				if (tick - c.start_tick) % 60 == 0:
					for id: int in world.players:
						if world.players[id].state.alive and _enemy(hunt, c.owner, id) and not hunt._aux(id):
							hunt.revealed_until[id] = maxi(int(hunt.revealed_until.get(id, 0)), tick + 120)
			"mortar", "howitzer":
				var k: int = tick - c.start_tick
				if k % int(info.every) == 0 and k / int(info.every) < int(info.shells):
					var r := RandomNumberGenerator.new()
					r.seed = hash([c.owner, c.start_tick, k])
					var a := r.randf() * TAU
					var at: Vector3 = c.at + Vector3(cos(a), 0.0, sin(a)) * r.randf() * float(info.spread)
					blast(world, hunt, c.owner, at, float(info.blast), float(info.damage) * boost, c.unit)
				if k >= int(info.every) * int(info.shells):
					calls.erase(c)
				continue
			"hive":
				if (tick - c.start_tick) % int(info.every) == 0:
					_fire(world, hunt, c.owner, position_of(c, tick), float(info.radius) + float(info.height),
							float(info.damage) * boost)
			"strike_jet", "raptor", "bomber", "nightwing":
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
		if jammed(world, hunt, int(mm[0]), v.position):
			continue
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
	var r := 12.0 if c.unit == "gunship" else (3.0 if c.unit in ["medevac", "aegis_drone"] else 6.0)
	return c.at + Vector3(cos(t * 0.6) * r, float(info.height), sin(t * 0.6) * r)


## Air defence at `from`: the nearest enemy aircraft within `reach` takes
## `damage`; one brought down is gone (emits "unit_downed").
func shoot_air(world: SimWorld, hunt: HuntRules, owner: int, from: Vector3, reach: float, damage: float) -> bool:
	var best: Call = null
	var best_d := reach
	var tick := world.tick
	for c in calls:
		if not (c.unit in AIR) or not _enemy(hunt, owner, c.owner) or tick < c.start_tick - int(UNITS[c.unit].get("delay", 0)) \
				or UNITS[c.unit].get("stealth", false):
			continue
		var d := position_of(c, tick).distance_to(from)
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		return false
	world._emit("hf:%d:%d:%d" % [owner, int(from.x), tick], "hunt", {"action": "flak_fire", "player": owner,
			"position": from, "treasure": 0, "kind": -1, "to": position_of(best, tick)})
	damage_air(world, owner, best, damage)
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
	for vi: int in machine_hp.keys():  # the strafe hits machines on the line too
		if vi >= world.vehicles.size() or not _enemy(hunt, c.owner, int(machines[vi][0])):
			continue
		var vp: Vector3 = world.vehicles[vi].position
		var q := Geometry3D.get_closest_point_to_segment(vp, a, b)
		if Vector2(q.x - vp.x, q.z - vp.z).length() <= float(info.width):
			damage_machine(world, hunt, c.owner, vi, float(info.damage) * boost)
	if hunt.war.enabled:  # buildings along the run take it too
		for k in 5:
			hunt.war.builds.on_blast(world, hunt, c.owner, a.lerp(b, k / 4.0), float(info.width), float(info.damage) * boost * 0.5)
	world._emit("hj:%d:%d" % [c.owner, world.tick], "hunt", {"action": "jet_strike", "player": c.owner,
			"position": c.at, "treasure": 0, "kind": -1, "from": a, "to": b})


## A shell (or bomb) lands at `at`: enemies within `radius` take `damage`
## (less further out), and their aircraft, machines and buildings too.
func blast(world: SimWorld, hunt: HuntRules, owner: int, at: Vector3, radius: float, damage: float, what: String) -> void:
	for id: int in world.players:
		var o: SimPlayer = world.players[id]
		if not o.state.alive or not _enemy(hunt, owner, id):
			continue
		var d := o.state.position.distance_to(at)
		if d < radius:
			world._damage(o, owner if world.players.has(owner) else 0, damage * (1.0 - 0.5 * d / radius), false,
					Weapons.by_id(&"pulse_rifle"), world.tick)
	on_blast(world, hunt, owner, at, radius, damage)
	world._emit("hsh:%d:%d:%d" % [owner, int(at.x * 10.0), world.tick], "hunt", {"action": "shell_hit", "player": owner,
			"position": at, "treasure": 0, "kind": -1, "unit": what})


## Whether an enemy EMP drone of `owner`'s foes hovers over `at` (their
## turrets, flak and tank guns there stay quiet).
func jammed(world: SimWorld, hunt: HuntRules, owner: int, at: Vector3) -> bool:
	for c in calls:
		if c.unit == "emp_drone" and world.tick >= c.start_tick and _enemy(hunt, c.owner, owner) \
				and Vector2(at.x - c.at.x, at.z - c.at.z).length() <= float(UNITS.emp_drone.radius) * NationArsenal.mod(c.nation, "emp_drone", "range"):
			return true
	return false


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
	# An enemy war machine nearer than any person: the gun takes that.
	var best_v := -1
	for vi: int in machine_hp:
		if vi >= world.vehicles.size() or not _enemy(hunt, owner, int(machines[vi][0])):
			continue
		var d := from.distance_to(world.vehicles[vi].position)
		if d < best_d:
			best_d = d
			best_v = vi
	if best_v >= 0:
		damage_machine(world, hunt, owner, best_v, damage)
		return
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
			var extra: String = ["mortar", "emp_drone", "medevac", "bomber"][id % 4]  # rivals differ
			rosters[id] = {"attack_drone": [1, 0], air: [1, 0], extra: [1, 0]}
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


# --- Damage to the army: shots, guns and strikes hit aircraft and machines ---

## A hitscan shot from `from` to `to` (where it ended): the first enemy
## aircraft or war machine on the line takes `damage`.
func on_shot(world: SimWorld, hunt: HuntRules, shooter: int, from: Vector3, to: Vector3, damage: float) -> void:
	if hunt.war.enabled:
		hunt.war.builds.on_shot(world, hunt, shooter, to, damage)
	var best_d := from.distance_to(to)
	var hit_call: Call = null
	var hit_machine := -1
	var tick := world.tick
	for c in calls:
		if not (c.unit in AIR) or not _enemy(hunt, shooter, c.owner) or tick < c.start_tick - int(UNITS[c.unit].get("delay", 0)):
			continue
		var d := _ray_sphere(from, to, position_of(c, tick), float(HIT_RADIUS[c.unit]))
		if d >= 0.0 and d < best_d:
			best_d = d
			hit_call = c
	for vi: int in machine_hp:
		if vi >= world.vehicles.size() or not _enemy(hunt, shooter, int(machines[vi][0])):
			continue
		var d := _ray_sphere(from, to, world.vehicles[vi].position + Vector3(0, 1.2, 0), float(HIT_RADIUS.machine))
		if d >= 0.0 and d < best_d:
			best_d = d
			hit_machine = vi
			hit_call = null
	if hit_machine >= 0:
		damage_machine(world, hunt, shooter, hit_machine, damage)
	elif hit_call != null:
		damage_air(world, shooter, hit_call, damage)


## Where the segment a-b first enters the sphere (distance from a), or -1.
static func _ray_sphere(a: Vector3, b: Vector3, centre: Vector3, r: float) -> float:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return -1.0
	d /= len
	var m := a - centre
	var bq := m.dot(d)
	var cq := m.dot(m) - r * r
	if cq > 0.0 and bq > 0.0:
		return -1.0
	var disc := bq * bq - cq
	if disc < 0.0:
		return -1.0
	var t := maxf(-bq - sqrt(disc), 0.0)
	return t if t <= len else -1.0


func damage_air(world: SimWorld, by: int, c: Call, damage: float) -> void:
	c.hp -= damage
	if c.hp <= 0.0 and c in calls:
		calls.erase(c)
		world._emit("hd:%d:%s:%d" % [c.owner, c.unit, world.tick], "hunt", {"action": "unit_downed", "player": by,
				"position": position_of(c, world.tick), "treasure": 0, "kind": -1, "unit": c.unit, "owner": c.owner})


## A war machine hit: destroyed at no health left (its driver thrown out,
## the vehicle gone from the field, lost from its owner's roster).
func damage_machine(world: SimWorld, hunt: HuntRules, by: int, vi: int, damage: float) -> void:
	if not machine_hp.has(vi):
		return
	machine_hp[vi] = float(machine_hp[vi]) - damage
	world.vehicles[vi].condition = clampf(100.0 * float(machine_hp[vi]) / float(MACHINE_HP[machines[vi][1]]), 0.0, 100.0)
	if float(machine_hp[vi]) > 0.0:
		return
	var mm: Array = machines[vi]
	machine_hp.erase(vi)
	machines.erase(vi)
	var v: SimVehicle = world.vehicles[vi]
	if v.driver != 0 and world.players.has(v.driver):
		var d: SimPlayer = world.players[v.driver]
		d.state.vehicle = -1
		world.teleport(d, v.position + Vector3(2.5, 0.5, 0))
		v.driver = 0
	v.position += Vector3(0, -400.0, 0)  # gone from the field (wreck shown by the effect)
	var u: Dictionary = used.get(int(mm[0]), {})
	u[mm[1]] = int(u.get(mm[1], 0)) + 1  # lost: off the roster after the run
	used[int(mm[0])] = u
	world._emit("hk2:%d:%d" % [vi, world.tick], "hunt", {"action": "machine_destroyed", "player": by,
			"position": v.position + Vector3(0, 400.0, 0), "treasure": 0, "kind": -1, "unit": mm[1], "owner": mm[0]})


## An explosion at `at`: enemy aircraft and war machines within `radius`
## take `damage`, less with distance.
func on_blast(world: SimWorld, hunt: HuntRules, owner: int, at: Vector3, radius: float, damage: float) -> void:
	if radius <= 0.0:
		return
	if hunt.war.enabled:
		hunt.war.builds.on_blast(world, hunt, owner, at, radius, damage)
	for c in calls.duplicate():
		if c.unit in AIR and _enemy(hunt, owner, c.owner):
			var d := position_of(c, world.tick).distance_to(at)
			if d < radius + float(HIT_RADIUS[c.unit]):
				damage_air(world, owner, c, damage * clampf(1.0 - d / (radius + 1.0), 0.3, 1.0))
	for vi: int in machine_hp.keys():
		if vi < world.vehicles.size() and _enemy(hunt, owner, int(machines[vi][0])):
			var d := world.vehicles[vi].position.distance_to(at)
			if d < radius + float(HIT_RADIUS.machine):
				damage_machine(world, hunt, owner, vi, damage * clampf(1.0 - d / (radius + 1.0), 0.3, 1.0))


## The nearest enemy war machine to `from` within `reach` (vehicle index, -1).
func nearest_enemy_machine(world: SimWorld, hunt: HuntRules, owner: int, from: Vector3, reach: float) -> int:
	var best := -1
	var best_d := reach
	for vi: int in machine_hp:
		if vi >= world.vehicles.size() or not _enemy(hunt, owner, int(machines[vi][0])):
			continue
		var d := from.distance_to(world.vehicles[vi].position)
		if d < best_d:
			best_d = d
			best = vi
	return best
