class_name HuntCamps
extends RefCounted
## The sides' camps in a war (HuntWar): a camp core every side starts with,
## and what they build round it with their run credits (HuntEconomy), on
## SOCKETS sockets round the core, and a ring of walls with a gate facing
## the site's middle. Every building is solid (a static body on the world
## layer: it stops people, shots and turret sight), and does something:
##   turret: shoots enemies in range it can see (credited to its builder)
##   med_bay: heals the side's people near it
##   barracks: brings fallen squad teammates back (HuntSquad)
##   comms: reveals enemies near the camp on everyone's map of the side
##   refinery: pays its builder credits over time
##   walls: the ring (one purchase)
## Bots (AI hunters) build for their side as their credits allow.

const MODULES := {
	"walls": {"cost": 100},
	"turret": {"cost": 120, "range": 28.0, "every": 30, "damage": 9.0, "size": Vector3(2.2, 3.2, 2.2)},
	"med_bay": {"cost": 90, "every": 120, "heal": 10.0, "radius": 14.0, "size": Vector3(6.2, 2.4, 3.6)},
	"barracks": {"cost": 110, "respawn": 1800, "size": Vector3(8.0, 6.7, 6.7)},
	"comms": {"cost": 70, "every": 600, "reveal": 420, "radius": 70.0, "size": Vector3(2.8, 16.5, 3.3)},
	"refinery": {"cost": 80, "every": 1800, "credits": 15, "size": Vector3(8.0, 6.5, 4.5)},
	# Air defence: shoots down enemy drones, gunships and jets (HuntArmy).
	"air_defense": {"cost": 110, "range": 48.0, "every": 15, "damage": 16.0, "size": Vector3(2.6, 3.0, 2.6)},
	"aegis_battery": {"cost": 220, "range": 72.0, "every": 10, "damage": 24.0, "size": Vector3(3.4, 4.0, 3.4)},
	# The rotorcraft pad: flies you and your squad back to camp (request "fly_to_camp").
	"helipad": {"cost": 140, "size": Vector3(9.0, 0.4, 9.0)},
}
const IDS := ["walls", "turret", "air_defense", "aegis_battery", "med_bay", "barracks", "comms", "refinery", "helipad"]
## What a side's bots build, in order.
const BOT_ORDER := ["turret", "walls", "air_defense", "refinery", "med_bay", "turret", "comms", "barracks"]
const BOT_EVERY := 900
const SOCKETS := 6
const SOCKET_RADIUS := 8.0
const WALL_RADIUS := 15.0
const WALL_SEGMENTS := 6  ## one left open: the gate
const WALL_SIZE := Vector3(13.0, 4.2, 1.17)
const CORE_SIZE := Vector3(6.0, 2.8, 5.2)
## Buildings' health (the ring of walls is one); each upgrade level adds
## LEVEL_HP to it and LEVEL_POWER to what the building does.
const MODULE_HP := {"walls": 1600.0, "turret": 500.0, "air_defense": 450.0, "aegis_battery": 700.0, "med_bay": 400.0,
		"barracks": 600.0, "comms": 350.0, "refinery": 500.0, "helipad": 450.0}
const MAX_LEVEL := 2
const LEVEL_HP := 0.3
const LEVEL_POWER := 0.25
## Repairing: credits per point of health; an engineer teammate mends what's
## near them for free, REPAIR_RATE a second.
const REPAIR_COST := 0.25
const REPAIR_RATE := 8.0
const REPAIR_RADIUS := 12.0
## The rotorcraft pad: fly back to camp (you and your squad), this often.
const FLY_COOLDOWN := 60 * 60

## A camp's built parts: socket index -> module id; walls; who built what.
class Built:
	var modules: Dictionary = {}  ## socket -> module id
	var builders: Dictionary = {}  ## socket -> builder net id
	var hp: Dictionary = {}  ## socket -> health left ("walls" for the ring)
	var levels: Dictionary = {}  ## socket -> upgrade level ("walls" too)
	var bodies: Dictionary = {}  ## socket -> its solid body ("walls": an Array)
	var walls: bool = false
	var gate_angle: float = 0.0  ## where the gate is (towards the middle)


var built: Array[Built] = []  ## parallel to HuntWar.camps
var _bodies: Array[Node] = []
var _respawns: Array = []  ## [tick, leader, role]
var _flown: Dictionary = {}  ## hunter -> tick they last flew back


func reset() -> void:
	for b in _bodies:
		if is_instance_valid(b):
			b.queue_free()
	_bodies.clear()
	built.clear()
	_respawns.clear()
	_flown.clear()


## The war's camps are set: each gets its core (solid) and an empty plot.
func start(world: SimWorld, war: HuntWar) -> void:
	reset()
	for c in war.camps:
		var b := Built.new()
		var to_middle := war.point - c.at
		b.gate_angle = atan2(to_middle.z, to_middle.x)
		built.append(b)
		_solid(world, c.at + Vector3(0, CORE_SIZE.y * 0.5, 0), CORE_SIZE, 0.0)


static func socket_at(camp_at: Vector3, i: int) -> Vector3:
	var a := TAU * (float(i) + 0.5) / SOCKETS
	return camp_at + Vector3(cos(a), 0.0, sin(a)) * SOCKET_RADIUS


## The wall ring's segments: [centre, yaw (deg)] (the gate's left open).
static func wall_segments(camp_at: Vector3, gate_angle: float) -> Array:
	var out := []
	for k in WALL_SEGMENTS:
		var a := gate_angle + TAU * float(k) / WALL_SEGMENTS
		if k == 0:
			continue  # the gate, facing the middle
		var at := camp_at + Vector3(cos(a), 0.0, sin(a)) * WALL_RADIUS
		out.append([at, rad_to_deg(-a) + 90.0])
	return out


## `builder` builds `module` at its side's camp (first free socket).
func build(world: SimWorld, hunt: HuntRules, builder: int, module: String) -> bool:
	if not MODULES.has(module) or hunt._aux(builder) or not world.players.has(builder):
		return false
	_plots(hunt.war)
	var ci := _camp_of(hunt, builder)
	if ci < 0:
		return false
	var c: HuntWar.Camp = hunt.war.camps[ci]
	var b := built[ci]
	if c.charges <= 0:
		return false  # a fallen camp builds nothing
	var nation := NationArsenal.of(hunt, builder)
	if not NationArsenal.allowed(nation, module):
		return false  # another nation's
	var cost := roundi(float(MODULES[module].cost) * NationArsenal.mod(nation, module, "cost"))
	if module == "walls":
		if b.walls or not hunt.economy.spend(builder, cost):
			return false
		b.walls = true
		b.hp["walls"] = float(MODULE_HP.walls)
		b.levels["walls"] = 0
		var ring := []
		for seg: Array in wall_segments(c.at, b.gate_angle):
			ring.append(_solid(world, (seg[0] as Vector3) + Vector3(0, WALL_SIZE.y * 0.5, 0), WALL_SIZE, seg[1]))
		b.bodies["walls"] = ring
	else:
		var free := -1
		for i in SOCKETS:
			if not b.modules.has(i):
				free = i
				break
		if free < 0 or not hunt.economy.spend(builder, cost):
			return false
		b.modules[free] = module
		b.builders[free] = builder
		b.hp[free] = float(MODULE_HP[module])
		b.levels[free] = 0
		var size: Vector3 = MODULES[module].size
		b.bodies[free] = _solid(world, socket_at(c.at, free) + Vector3(0, size.y * 0.5, 0), size, 0.0)
	world._emit("hb:%d:%s:%d" % [builder, module, world.tick], "hunt", {"action": "camp_built", "player": builder,
			"position": c.at, "treasure": 0, "kind": -1, "module": module, "side": c.side})
	return true


## A plot for every camp (camps set up without start(): tools, tests).
func _plots(war: HuntWar) -> void:
	while built.size() < war.camps.size():
		var b := Built.new()
		var c: HuntWar.Camp = war.camps[built.size()]
		var to_middle := war.point - c.at
		b.gate_angle = atan2(to_middle.z, to_middle.x)
		built.append(b)


func _camp_of(hunt: HuntRules, id: int) -> int:
	var side := hunt.war.side_of(hunt, id)
	for i in hunt.war.camps.size():
		if hunt.war.camps[i].side == side:
			return i
	return -1


func has(ci: int, module: String) -> bool:
	return ci >= 0 and ci < built.size() and (module in built[ci].modules.values() or (module == "walls" and built[ci].walls))


func step(world: SimWorld, hunt: HuntRules, ids: Array) -> void:
	var tick := world.tick
	_plots(hunt.war)
	for ci in built.size():
		var c: HuntWar.Camp = hunt.war.camps[ci]
		if c.charges <= 0:
			continue
		var b := built[ci]
		for socket: int in b.modules:
			var m: String = b.modules[socket]
			var info: Dictionary = MODULES[m].duplicate()
			var k := power(ci, socket)  # upgrades: stronger, further, more
			for stat in ["damage", "range", "heal", "credits", "radius"]:
				if info.has(stat):
					info[stat] = float(info[stat]) * k
			var at := socket_at(c.at, socket)
			match m:
				"turret":
					if tick % int(info.every) == 0 and not hunt.army.jammed(world, hunt, int(b.builders[socket]), at):
						_turret(world, hunt, c, at, int(b.builders[socket]), info)
				"air_defense", "aegis_battery":
					if tick % int(info.every) == 0 and not hunt.army.jammed(world, hunt, int(b.builders[socket]), at):
						var who := int(b.builders[socket])
						var n := NationArsenal.of(hunt, who)
						hunt.army.shoot_air(world, hunt, who, at + Vector3(0, 3.0, 0),
								float(info.range) * NationArsenal.mod(n, "air_defense", "range"),
								float(info.damage) * NationArsenal.mod(n, "air_defense", "damage"))
				"med_bay":
					if tick % int(info.every) == 0:
						for id: int in ids:
							var p: SimPlayer = world.players[id]
							if p.state.alive and hunt.war.side_of(hunt, id) == c.side and p.state.position.distance_to(at) <= float(info.radius):
								p.state.health = minf(p.state.health + float(info.heal), Balance.PLAYER.max_health)
				"comms":
					if tick % int(info.every) == 0:
						for id: int in ids:
							var p: SimPlayer = world.players[id]
							if p.state.alive and not hunt._aux(id) and hunt.war.side_of(hunt, id) != c.side \
									and p.state.position.distance_to(c.at) <= float(info.radius):
								hunt.revealed_until[id] = maxi(int(hunt.revealed_until.get(id, 0)), tick + int(info.reveal))
				"refinery":
					if tick % int(info.every) == 0:
						hunt.economy.earn(world, int(b.builders[socket]), roundi(float(info.credits)), "refinery")
	# Barracks: a fallen teammate comes back to its leader after a while.
	for r: Array in _respawns.duplicate():
		if tick >= int(r[0]):
			_respawns.erase(r)
			hunt.squad.rejoin(world, int(r[1]), str(r[2]))
	if tick % 60 == 0:
		_engineers_repair(world, hunt)
	if tick % BOT_EVERY == 0:
		_bots_build(world, hunt, ids)


## A squad teammate fell: if its leader's camp has barracks, it comes back.
func on_teammate_down(world: SimWorld, hunt: HuntRules, leader: int, role: String) -> void:
	if has(_camp_of(hunt, leader), "barracks"):
		_respawns.append([world.tick + int(MODULES.barracks.respawn), leader, role])


func _turret(world: SimWorld, hunt: HuntRules, c: HuntWar.Camp, at: Vector3, builder: int, info: Dictionary) -> void:
	var head := at + Vector3(0, 3.0, 0)
	var best: SimPlayer = null
	var nation := NationArsenal.of(hunt, builder)
	var best_d := float(info.range) * NationArsenal.mod(nation, "turret", "range")
	for id: int in world.players:
		var p: SimPlayer = world.players[id]
		if not p.state.alive or hunt.war.side_of(hunt, id) == c.side:
			continue
		var chest := p.state.position + Vector3(0, 1.2, 0)
		var d := head.distance_to(chest)
		if d >= best_d:
			continue
		var hit := world._ray(head, chest)
		if not hit.is_empty() and head.distance_to(hit.position) < d - 0.6:
			continue  # a wall in the way
		best = p
		best_d = d
	var shooter := builder if world.players.has(builder) else 0
	var vi := hunt.army.nearest_enemy_machine(world, hunt, builder, head, best_d)
	if vi >= 0:  # an enemy tank or crawler nearer than anyone: the turret takes it on
		hunt.army.damage_machine(world, hunt, shooter, vi,
				float(info.damage) * NationArsenal.mod(nation, "turret", "damage"))
		return
	if best == null:
		return
	world._damage(best, shooter, float(info.damage) * NationArsenal.mod(nation, "turret", "damage"), false,
			Weapons.by_id(&"pulse_rifle"), world.tick)
	world._emit("ht:%d:%d" % [best.net_id, world.tick], "hunt", {"action": "turret_fire", "player": shooter,
			"position": head, "treasure": 0, "kind": -1, "target": best.net_id})


func _bots_build(world: SimWorld, hunt: HuntRules, ids: Array) -> void:
	for id: int in ids:
		var p: SimPlayer = world.players[id]
		if not p.is_bot or hunt._aux(id):
			continue
		var ci := _camp_of(hunt, id)
		if ci < 0:
			continue
		for m: String in BOT_ORDER:
			var have := 0
			for v in built[ci].modules.values():
				have += 1 if v == m else 0
			var want := BOT_ORDER.count(m)
			if (m == "walls" and built[ci].walls) or (m != "walls" and have >= want):
				continue
			build(world, hunt, id, m)
			break


func _solid(world: SimWorld, centre: Vector3, size: Vector3, yaw_deg: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Sim.LAYER_WORLD
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), centre)
	world.add_child(body)
	_bodies.append(body)
	return body


# --- Combat and upkeep: damage, destruction, repair, upgrades, the pad ---

## A building's power at its level (damage, range, healing).
func power(ci: int, socket: Variant) -> float:
	return 1.0 + LEVEL_POWER * int(built[ci].levels.get(socket, 0))


func max_hp(ci: int, socket: Variant) -> float:
	var m: String = "walls" if socket is String else built[ci].modules[socket]
	return float(MODULE_HP[m]) * (1.0 + LEVEL_HP * int(built[ci].levels.get(socket, 0)))


## A shot that ended at `to` (on something solid): if that's an enemy
## building (a module's box, a wall of the ring), it takes `damage`.
func on_shot(world: SimWorld, hunt: HuntRules, shooter: int, to: Vector3, damage: float) -> void:
	var hit := _building_at(hunt, shooter, to, 0.4)
	if not hit.is_empty():
		damage_building(world, hunt, shooter, int(hit[0]), hit[1], damage)


## A blast at `at`: enemy buildings within `radius` take damage.
func on_blast(world: SimWorld, hunt: HuntRules, owner: int, at: Vector3, radius: float, damage: float) -> void:
	for ci in built.size():
		var c: HuntWar.Camp = hunt.war.camps[ci]
		if not _enemy_camp(hunt, owner, c):
			continue
		for socket: int in built[ci].modules.keys():
			var d := socket_at(c.at, socket).distance_to(at)
			if d < radius + 2.0:
				damage_building(world, hunt, owner, ci, socket, damage * clampf(1.0 - d / (radius + 2.0), 0.3, 1.0))
		if built[ci].walls:
			var d := absf(Vector2(at.x - c.at.x, at.z - c.at.z).length() - WALL_RADIUS)
			if d < radius:
				damage_building(world, hunt, owner, ci, "walls", damage * clampf(1.0 - d / radius, 0.3, 1.0))


## [camp index, socket or "walls"] of an enemy building at `p`, or [].
func _building_at(hunt: HuntRules, shooter: int, p: Vector3, margin: float) -> Array:
	for ci in built.size():
		var c: HuntWar.Camp = hunt.war.camps[ci]
		if not _enemy_camp(hunt, shooter, c):
			continue
		if Vector2(p.x - c.at.x, p.z - c.at.z).length() > WALL_RADIUS + 3.0:
			continue
		for socket: int in built[ci].modules:
			var size: Vector3 = MODULES[built[ci].modules[socket]].size
			var at := socket_at(c.at, socket)
			var lo := at - Vector3(size.x * 0.5, 0, size.z * 0.5) - Vector3.ONE * margin
			var hi := at + Vector3(size.x * 0.5, size.y, size.z * 0.5) + Vector3.ONE * margin
			if p.x >= lo.x and p.x <= hi.x and p.y >= lo.y - 1.0 and p.y <= hi.y and p.z >= lo.z and p.z <= hi.z:
				return [ci, socket]
		if built[ci].walls and absf(Vector2(p.x - c.at.x, p.z - c.at.z).length() - WALL_RADIUS) < WALL_SIZE.z + margin:
			return [ci, "walls"]
	return []


func _enemy_camp(hunt: HuntRules, who: int, c: HuntWar.Camp) -> bool:
	return hunt.war.side_of(hunt, who) != c.side


func damage_building(world: SimWorld, hunt: HuntRules, by: int, ci: int, socket: Variant, damage: float) -> void:
	var b := built[ci]
	if not b.hp.has(socket):
		return
	b.hp[socket] = float(b.hp[socket]) - damage
	if float(b.hp[socket]) > 0.0:
		return
	var what: String = "walls" if socket is String else b.modules[socket]
	var body: Variant = b.bodies.get(socket)
	if body is Array:
		for n: Node in body:
			if is_instance_valid(n):
				n.queue_free()
	elif body != null and is_instance_valid(body):
		(body as Node).queue_free()
	b.bodies.erase(socket)
	b.hp.erase(socket)
	b.levels.erase(socket)
	if socket is String:
		b.walls = false
	else:
		b.modules.erase(socket)
		b.builders.erase(socket)
	var c: HuntWar.Camp = hunt.war.camps[ci]
	world._emit("hm2:%d:%s:%d" % [ci, str(socket), world.tick], "hunt", {"action": "module_destroyed", "player": by,
			"position": c.at, "treasure": 0, "kind": -1, "module": what, "side": c.side, "socket": socket})


## Repair your camp's damaged buildings (credits, REPAIR_COST a point).
func repair(world: SimWorld, hunt: HuntRules, who: int) -> bool:
	var ci := _camp_of(hunt, who)
	if ci < 0 or hunt._aux(who):
		return false
	var need := 0.0
	for socket: Variant in built[ci].hp:
		need += max_hp(ci, socket) - float(built[ci].hp[socket])
	var cost := ceili(need * REPAIR_COST)
	if need <= 0.0 or not hunt.economy.spend(who, cost):
		return false
	for socket: Variant in built[ci].hp.keys():
		built[ci].hp[socket] = max_hp(ci, socket)
	world._emit("hr2:%d:%d" % [who, world.tick], "hunt", {"action": "camp_repaired", "player": who,
			"position": hunt.war.camps[ci].at, "treasure": 0, "kind": -1, "side": hunt.war.camps[ci].side})
	return true


## Upgrade the lowest-level building of `module` at your camp a level.
func upgrade(world: SimWorld, hunt: HuntRules, who: int, module: String) -> bool:
	var ci := _camp_of(hunt, who)
	if ci < 0 or hunt._aux(who) or not MODULES.has(module):
		return false
	var b := built[ci]
	var pick: Variant = null
	if module == "walls":
		pick = "walls" if b.walls else null
	else:
		for socket: int in b.modules:
			if b.modules[socket] == module and (pick == null or int(b.levels[socket]) < int(b.levels[pick])):
				pick = socket
	if pick == null or int(b.levels.get(pick, 0)) >= MAX_LEVEL:
		return false
	var nation := NationArsenal.of(hunt, who)
	var cost := roundi(float(MODULES[module].cost) * 0.8 * (int(b.levels[pick]) + 1) * NationArsenal.mod(nation, module, "cost"))
	if not hunt.economy.spend(who, cost):
		return false
	var frac := float(b.hp[pick]) / max_hp(ci, pick)
	b.levels[pick] = int(b.levels[pick]) + 1
	b.hp[pick] = max_hp(ci, pick) * frac
	world._emit("hu2:%d:%s:%d" % [who, module, world.tick], "hunt", {"action": "camp_upgraded", "player": who,
			"position": hunt.war.camps[ci].at, "treasure": 0, "kind": -1, "module": module, "level": b.levels[pick],
			"side": hunt.war.camps[ci].side})
	return true


## The rotorcraft pad: you (and your squad) fly back to your camp.
func fly_to_camp(world: SimWorld, hunt: HuntRules, who: int) -> bool:
	var ci := _camp_of(hunt, who)
	var p: SimPlayer = world.players.get(who)
	if ci < 0 or p == null or not p.state.alive or p.state.vehicle >= 0 or not has(ci, "helipad") \
			or world.tick - int(_flown.get(who, -FLY_COOLDOWN)) < FLY_COOLDOWN or hunt.carried_by(who) != null:
		return false
	_flown[who] = world.tick
	var pad := Vector3.ZERO
	for socket: int in built[ci].modules:
		if built[ci].modules[socket] == "helipad":
			pad = socket_at(hunt.war.camps[ci].at, socket)
	world.teleport(p, pad + Vector3(0, 0.6, 0))
	var sq := hunt.squad.squad_of(who)
	if sq != null:
		for m in sq.members:
			if world.players.has(m.id):
				world.teleport(world.players[m.id], pad + Vector3(2.0 + m.slot, 0.6, 2.0))
	world._emit("hp2:%d:%d" % [who, world.tick], "hunt", {"action": "flew_to_camp", "player": who,
			"position": pad, "treasure": 0, "kind": -1})
	return true


## Engineers on a squad mend their side's buildings near them, for free.
func _engineers_repair(world: SimWorld, hunt: HuntRules) -> void:
	for id: int in hunt.squad.by_id:
		var m: HuntSquad.Member = hunt.squad.by_id[id]
		var body: SimPlayer = world.players.get(id)
		if m.role != "engineer" or body == null or not body.state.alive:
			continue
		var ci := _camp_of(hunt, m.leader)
		if ci < 0:
			continue
		var c: HuntWar.Camp = hunt.war.camps[ci]
		for socket: Variant in built[ci].hp.keys():
			var at := c.at if socket is String else socket_at(c.at, socket)
			if body.state.position.distance_to(at) <= REPAIR_RADIUS + (WALL_RADIUS if socket is String else 0.0):
				built[ci].hp[socket] = minf(float(built[ci].hp[socket]) + REPAIR_RATE, max_hp(ci, socket))
