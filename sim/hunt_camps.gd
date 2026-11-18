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
}
const IDS := ["walls", "turret", "med_bay", "barracks", "comms", "refinery"]
## What a side's bots build, in order.
const BOT_ORDER := ["turret", "walls", "refinery", "med_bay", "turret", "comms", "barracks"]
const BOT_EVERY := 900
const SOCKETS := 6
const SOCKET_RADIUS := 8.0
const WALL_RADIUS := 15.0
const WALL_SEGMENTS := 6  ## one left open: the gate
const WALL_SIZE := Vector3(13.0, 4.2, 1.17)
const CORE_SIZE := Vector3(6.0, 2.8, 5.2)

## A camp's built parts: socket index -> module id; walls; who built what.
class Built:
	var modules: Dictionary = {}  ## socket -> module id
	var builders: Dictionary = {}  ## socket -> builder net id
	var walls: bool = false
	var gate_angle: float = 0.0  ## where the gate is (towards the middle)


var built: Array[Built] = []  ## parallel to HuntWar.camps
var _bodies: Array[Node] = []
var _respawns: Array = []  ## [tick, leader, role]


func reset() -> void:
	for b in _bodies:
		if is_instance_valid(b):
			b.queue_free()
	_bodies.clear()
	built.clear()
	_respawns.clear()


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
	var cost := int(MODULES[module].cost)
	if module == "walls":
		if b.walls or not hunt.economy.spend(builder, cost):
			return false
		b.walls = true
		for seg: Array in wall_segments(c.at, b.gate_angle):
			_solid(world, (seg[0] as Vector3) + Vector3(0, WALL_SIZE.y * 0.5, 0), WALL_SIZE, seg[1])
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
		var size: Vector3 = MODULES[module].size
		_solid(world, socket_at(c.at, free) + Vector3(0, size.y * 0.5, 0), size, 0.0)
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
			var info: Dictionary = MODULES[m]
			var at := socket_at(c.at, socket)
			match m:
				"turret":
					if tick % int(info.every) == 0:
						_turret(world, hunt, c, at, int(b.builders[socket]), info)
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
						hunt.economy.earn(world, int(b.builders[socket]), int(info.credits), "refinery")
	# Barracks: a fallen teammate comes back to its leader after a while.
	for r: Array in _respawns.duplicate():
		if tick >= int(r[0]):
			_respawns.erase(r)
			hunt.squad.rejoin(world, int(r[1]), str(r[2]))
	if tick % BOT_EVERY == 0:
		_bots_build(world, hunt, ids)


## A squad teammate fell: if its leader's camp has barracks, it comes back.
func on_teammate_down(world: SimWorld, hunt: HuntRules, leader: int, role: String) -> void:
	if has(_camp_of(hunt, leader), "barracks"):
		_respawns.append([world.tick + int(MODULES.barracks.respawn), leader, role])


func _turret(world: SimWorld, hunt: HuntRules, c: HuntWar.Camp, at: Vector3, builder: int, info: Dictionary) -> void:
	var head := at + Vector3(0, 3.0, 0)
	var best: SimPlayer = null
	var best_d := float(info.range)
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
	if best == null:
		return
	var shooter := builder if world.players.has(builder) else 0
	world._damage(best, shooter, float(info.damage), false, Weapons.by_id(&"pulse_rifle"), world.tick)
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


func _solid(world: SimWorld, centre: Vector3, size: Vector3, yaw_deg: float) -> void:
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
