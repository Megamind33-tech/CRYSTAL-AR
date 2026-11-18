class_name SecuredGate
extends StaticBody3D
## A secured door (simulation; deterministic): a solid leaf on the world
## layer that opens for a person or a vehicle it lets through and shuts
## behind them. The checkpoint's rule: anyone `refused` names (a wanted
## player, set by the free-roam game) can't open it from outside (the
## door's local +Z, the side a building's front faces); it stays shut in
## their face. From inside it opens for them too: no one is shut in. A door never closes on someone standing in its frame.
## Presentation (TitanSettlement) slides its leaves from `open`.

const THICK := 0.5
const PERSON_REACH := 3.0    ## metres in front of or behind the door
const VEHICLE_REACH := 9.0   ## a vehicle is seen earlier (it's bigger and faster)
const HEIGHT_REACH := 6.0

var centre := Vector3.ZERO
var yaw_deg: float = 0.0
var width: float = 1.6
var height: float = 2.4
var open: bool = false


func setup(at: Vector3, yaw: float, w: float, h: float) -> void:
	centre = at
	yaw_deg = yaw
	width = w
	height = h
	collision_layer = Sim.LAYER_WORLD
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, THICK)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, h * 0.5, 0)
	add_child(cs)
	transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at)
	add_to_group("secured_gates")


## `at` in the door's frame: x along the leaves, z through the doorway.
func local(at: Vector3) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg)).inverse() * (at - centre)


## One tick: open while someone allowed is near (or anyone stands in the
## frame), shut otherwise.
func step(players: Dictionary, refused: Dictionary) -> void:
	var want := false
	for id: int in players:
		var s: PlayerSimState = (players[id] as SimPlayer).state
		if not s.alive:
			continue
		var l := local(s.position)
		if absf(l.y) > HEIGHT_REACH:
			continue
		if open and absf(l.x) < width * 0.5 + 0.6 and absf(l.z) < THICK + (3.6 if s.vehicle >= 0 else 0.9):
			want = true  # in the open frame: never shut on anyone
			break
		if refused.get(id, false) and l.z > 0.0:
			continue  # the refused can't come in from outside (but can always leave)
		var reach := VEHICLE_REACH if s.vehicle >= 0 else PERSON_REACH
		if absf(l.x) < width * 0.5 + reach * 0.5 and absf(l.z) < reach:
			want = true
			break
	if want != open:
		open = want
		collision_layer = 0 if open else Sim.LAYER_WORLD


## Who the checkpoints refuse: net id -> true (a wanted player; the
## free-roam game sets it). One simulation per process.
static var refused: Dictionary = {}


## A secured door in `world` at `at` (its foot, centre), turned `yaw_deg`.
static func add(world: SimWorld, at: Vector3, yaw_deg: float, w: float, h: float) -> SecuredGate:
	var g := SecuredGate.new()
	g.name = "SecuredGate%d" % all(world).size()
	world.add_child(g)
	g.setup(at, yaw_deg, w, h)
	return g


static func all(world: SimWorld) -> Array:
	var out := []
	for c in world.get_children():
		if c is SecuredGate:
			out.append(c)
	return out


## One tick of every door in `world` (call before the players move).
static func step_all(world: SimWorld) -> void:
	for g: SecuredGate in all(world):
		g.step(world.players, refused)
