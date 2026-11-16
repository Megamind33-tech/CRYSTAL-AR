class_name VehicleSim
extends RefCounted
## THE HUNT's rover (simulation; identical for every player and replayable):
## a world vehicle (SimVehicle) that a player boards with interact. While
## driving, the move stick is throttle (forward/back) and steering (left/
## right); the driver's body moves as the rover along the ground with the
## usual collision; weapons are down. The rover parks where it is left.

const BRAKE := 22.0
const DOWNFORCE := 4.0       ## times gravity on a driven vehicle
const SNAP_DOWN := 1.2       ## metres the ground may drop under the wheels and they follow
const STEEP := 0.8           ## floor normal's up below this (about 37 degrees): too steep to climb
const DRAG := 1.6            ## coasting slow-down, m/s^2
## The models (SimVehicle.model): top speed and reverse (m/s), acceleration
## (m/s^2), turn rate at speed (rad/s), hold stacks, factory price, and the
## half-size of its body on the ground (width, length) for hitting walls.
const MODELS := [
	{"name": "Rover", "max": 26.0, "rev": 7.0, "accel": 10.0, "turn": 1.8, "slots": 12, "price": 1200,
			"half": Vector2(1.1, 2.1), "kit": "world/rover"},
	{"name": "Dune buggy", "max": 34.0, "rev": 9.0, "accel": 15.0, "turn": 2.3, "slots": 4, "price": 1900,
			"half": Vector2(1.0, 1.7), "kit": "world/buggy"},
	{"name": "Hauler", "max": 19.0, "rev": 5.0, "accel": 6.5, "turn": 1.25, "slots": 30, "price": 2600,
			"half": Vector2(1.35, 3.2), "kit": "world/hauler"},
	# Aircraft (Kasei Aero at the Skyport; a flight licence to buy one).
	# "fly": "vtol" hovers and lifts straight up; "jet" needs a run to fly.
	{"name": "Skyhopper VTOL", "max": 48.0, "rev": 6.0, "accel": 11.0, "turn": 1.3, "slots": 6, "price": 9000,
			"half": Vector2(2.6, 3.4), "kit": "world/skyhopper", "fly": "vtol"},
	{"name": "Kestrel jet", "max": 105.0, "rev": 0.0, "accel": 17.0, "turn": 0.95, "slots": 2, "price": 24000,
			"half": Vector2(4.2, 5.6), "kit": "world/kestrel", "fly": "jet"},
]
## Flight (aircraft only): how fast it climbs and sinks, the speed a jet
## lifts off at, how high anything flies above the ground below it.
const CLIMB := 11.0
const JET_CLIMB := 16.0
const LIFT_OFF := 30.0
const TAXI := 9.0
const CEILING := 320.0


static func flies(model: int) -> bool:
	return MODELS[clampi(model, 0, MODELS.size() - 1)].has("fly")
## The Rover's numbers, for anyone who asks the old way.
const MAX_SPEED := 26.0
const ACCEL := 10.0
const TURN := 1.8
const BOARD_RANGE := 3.6
const EXIT_SIDE := 2.4       ## metres to the driver's left on exit
## Something solid where the front (`dir`) of a body `half` (width,
## length) is about to be: a box at bumper height, clear of the ground.
static func _blocked(p: SimPlayer, dir: Vector3, half: Vector2) -> bool:
	if not p.is_inside_tree():
		return false
	var space := p.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(half.x * 2.0, 0.9, 0.8)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = Sim.LAYER_WORLD
	var at := p.global_position + dir * (half.y + 0.5) + Vector3(0, 1.45, 0)
	q.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), at)
	q.exclude = [p.get_rid()]
	return not space.intersect_shape(q, 1).is_empty()


## Free roam (THE HUNT's valley): rovers burn fuel and take knocks. Off in
## runs and in tests that don't ask for it.
static var wear: bool = false
const FUEL_PER_KM := 9.0        ## percent of a tank per kilometre
const CRAWL_SPEED := 2.5        ## an empty tank or a wreck only crawls
const CRASH_SPEED := 6.0        ## a speed loss above this in one tick is a crash
const CRASH_DAMAGE := 2.2       ## condition lost per m/s lost in a crash


## Fuel burned and knocks taken by `v` while `s` drives it, one tick; and
## an empty tank or a wreck only crawls.
static func wear_and_tear(v: SimVehicle, s: PlayerSimState) -> void:
	var speed := absf(s.vehicle_speed)
	v.fuel = maxf(v.fuel - speed * Sim.TICK_DT / 1000.0 * FUEL_PER_KM, 0.0)
	var lost := v.last_speed - speed
	if lost > CRASH_SPEED:
		v.condition = maxf(v.condition - lost * CRASH_DAMAGE, 0.0)
	if v.fuel <= 0.0 or v.condition <= 0.0:
		s.vehicle_speed = clampf(s.vehicle_speed, -CRAWL_SPEED, CRAWL_SPEED)
	v.last_speed = absf(s.vehicle_speed)


const HOLD_BACK := 2.8       ## the hold's hatch, behind the rover's centre
const HOLD_REACH := 1.7


## Whether `pos` stands at `v`'s rear hatch (there you open the hold; you
## don't climb in).
static func at_hold(v: SimVehicle, pos: Vector3) -> bool:
	var hatch := v.position - Vector3(-sin(v.yaw), 0.0, -cos(v.yaw)) * HOLD_BACK
	return Vector2(pos.x - hatch.x, pos.z - hatch.z).length() < HOLD_REACH and absf(pos.y - v.position.y) < 2.5


## One tick of driving for `p` (its state has `vehicle` >= 0).
static func drive(p: SimPlayer, cmd: PlayerCommand) -> void:
	var s := p.state
	var dt := Sim.TICK_DT
	var m: Dictionary = MODELS[clampi(s.vehicle_model, 0, MODELS.size() - 1)]
	var mv := cmd.move_vector()
	var throttle := mv.y
	var steer := mv.x
	if m.has("fly"):
		_fly(p, cmd, m)
		return
	if absf(throttle) > 0.05:
		var pushing_against := signf(throttle) != signf(s.vehicle_speed) and absf(s.vehicle_speed) > 0.3
		var rate: float = BRAKE if pushing_against else float(m.accel)
		s.vehicle_speed += throttle * rate * dt
	else:
		s.vehicle_speed = move_toward(s.vehicle_speed, 0.0, DRAG * dt)
	s.vehicle_speed = clampf(s.vehicle_speed, -float(m.rev), float(m.max))
	# Steering bites with speed; reversing turns the other way, like a car.
	var bite := clampf(absf(s.vehicle_speed) / 4.0, 0.0, 1.0) * signf(s.vehicle_speed)
	s.vehicle_yaw = wrapf(s.vehicle_yaw - steer * float(m.turn) * bite * dt, -PI, PI)
	var fwd := Vector3(-sin(s.vehicle_yaw), 0.0, -cos(s.vehicle_yaw))
	# The body is bigger than the driver: a wall in front (or behind, in
	# reverse) stops it dead instead of letting the nose through.
	if absf(s.vehicle_speed) > 0.05 and _blocked(p, fwd * signf(s.vehicle_speed), m.half):
		s.vehicle_speed = -s.vehicle_speed * 0.15
	# Downforce: a rover is heavy and low; at speed in Mars' gravity it would
	# float off every crest. Steep ground saps its speed (no driving up cliffs).
	var on_floor := s.is_on_floor()
	var vy := s.velocity.y if not on_floor else 0.0
	vy -= p.config.gravity * DOWNFORCE * dt
	if on_floor and s.floor_normal.y < STEEP and fwd.dot(s.floor_normal) * signf(s.vehicle_speed) < 0.0:
		s.vehicle_speed *= 0.94
	s.velocity = fwd * s.vehicle_speed + Vector3(0.0, vy, 0.0)
	var before := s.position
	PlayerMovement._move_and_collide(p)
	s.position = p.global_position
	# Over a crest: keep the wheels on the ground if it's just dropped away.
	if not s.is_on_floor() and s.velocity.y <= 0.0 and p.is_inside_tree():
		var space := p.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(s.position + Vector3(0, 0.3, 0),
				s.position - Vector3(0, SNAP_DOWN, 0), Sim.LAYER_WORLD, [p.get_rid()]))
		if not hit.is_empty():
			s.position = (hit.position as Vector3) + Vector3(0, 0.02, 0)
			p.global_position = s.position
			s.velocity.y = 0.0
	# A wall or a building takes the speed off.
	var moved := Vector2(s.position.x - before.x, s.position.z - before.z).length() / dt
	if moved < absf(s.vehicle_speed) * 0.5 and absf(s.vehicle_speed) > 2.0:
		s.vehicle_speed *= 0.5


## One tick of flying `p`'s aircraft. Gas and brake set the airspeed, the
## steering turns it, climb (jump) and descend (crouch) set the climb rate.
## A VTOL hovers when you let go and lifts at any speed; a jet sinks when
## it's slow and only leaves the ground above LIFT_OFF. On the ground both
## taxi slowly; touching down hard is a crash (wear_and_tear).
static func _fly(p: SimPlayer, cmd: PlayerCommand, m: Dictionary) -> void:
	var s := p.state
	var dt := Sim.TICK_DT
	var mv := cmd.move_vector()
	var on_floor := s.is_on_floor()
	var climb := (1.0 if cmd.is_held(PlayerCommand.Held.JUMP) else 0.0) - (1.0 if cmd.is_held(PlayerCommand.Held.CROUCH) else 0.0)
	var jet: bool = m.fly == "jet"
	var top: float = m.max
	if on_floor and climb <= 0.0 and not (jet and absf(s.vehicle_speed) > LIFT_OFF * 0.8):
		top = TAXI  # taxiing
	if absf(mv.y) > 0.05:
		s.vehicle_speed += mv.y * float(m.accel) * dt
	else:
		s.vehicle_speed = move_toward(s.vehicle_speed, 0.0, (DRAG * 0.4 if not on_floor else DRAG) * dt)
	s.vehicle_speed = clampf(s.vehicle_speed, -float(m.rev), top)
	var grip := 1.0 if not jet else clampf(absf(s.vehicle_speed) / 20.0, 0.25, 1.0)
	s.vehicle_yaw = wrapf(s.vehicle_yaw - mv.x * float(m.turn) * grip * dt, -PI, PI)
	var fwd := Vector3(-sin(s.vehicle_yaw), 0.0, -cos(s.vehicle_yaw))
	var vy := s.velocity.y
	if jet:
		var lift := clampf((absf(s.vehicle_speed) - LIFT_OFF * 0.7) / (LIFT_OFF * 0.6), 0.0, 1.0)
		var target := climb * JET_CLIMB * lift - (1.0 - lift) * 7.0
		if on_floor and lift < 1.0 and climb <= 0.0:
			target = minf(target, 0.0)
		vy = move_toward(vy, target, 14.0 * dt)
	else:
		vy = move_toward(vy, climb * CLIMB, 16.0 * dt)
	# The ceiling: thin air high over the ground below.
	var ground := WorldTerrain.height(s.position.x, s.position.z)
	if s.position.y > ground + CEILING:
		vy = minf(vy, 0.0)
	if on_floor and vy < 0.0:
		vy = 0.0
	s.velocity = fwd * s.vehicle_speed + Vector3(0.0, vy, 0.0)
	var before := s.position
	PlayerMovement._move_and_collide(p)
	s.position = p.global_position
	var moved := Vector2(s.position.x - before.x, s.position.z - before.z).length() / dt
	if moved < absf(s.vehicle_speed) * 0.5 and absf(s.vehicle_speed) > 3.0:
		s.vehicle_speed *= 0.4  # flew into something
