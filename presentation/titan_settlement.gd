class_name TitanSettlement
extends Node3D
## Life in Titan's settlement block (tools/blender/build_titan.py): who lives
## and works in each building and what they do there, and the doors that
## slide open for whoever comes up to them.
##
## Routines are stops in the building's own Blender coordinates (x, y; front
## -y): walk to a stop, stay `dwell` seconds facing `face` (degrees, Blender:
## 0 = +y, 90 = +x) doing what's there, walk on. Paths go through the
## doorways. Posts are people who stay put at their place of work (and turn
## to you when you come close, like the city's vendors).

## [piece, style ("civilian", "worker", "marshal"), colour index, stops:
## [[x, y, dwell, face], ...] (dwell 0: just passing through)]
const ROUTINES := [
	# R-14: one cooks and eats and sits, checks the air plant; the other
	# works at the desk in the east bedroom.
	["titan/hab_r14", "civilian", 2, [[2.3, -0.6, 9.0, 90.0], [-0.6, -1.5, 7.0, 0.0], [-1.0, 0.8, 10.0, 0.0],
			[1.7, 1.4, 0.0, 0.0], [1.7, 2.7, 0.0, 0.0], [1.3, 3.6, 5.0, 0.0], [1.7, 2.7, 0.0, 0.0], [1.7, 1.4, 0.0, 0.0]]],
	["titan/hab_r14", "civilian", 6, [[0.5, -1.0, 0.0, 0.0], [4.4, -1.0, 0.0, 0.0], [6.1, 0.2, 12.0, 0.0],
			[4.4, -1.0, 0.0, 0.0], [0.6, 0.6, 8.0, 180.0], [-2.0, -2.8, 6.0, 180.0]]],
	# The market hub: a customer browses the aisle and pays at the counter.
	["titan/market_hub", "civilian", 4, [[-2.7, -3.4, 4.0, -90.0], [-2.7, -1.2, 5.0, 90.0], [-2.7, 0.8, 3.0, -90.0],
			[1.8, 0.4, 6.0, 0.0], [2.6, -2.0, 4.0, 180.0]]],
	# EX-03: a technician does the rounds of the machines and the bench.
	["titan/plant_ex03", "worker", 0, [[1.0, 2.0, 6.0, 0.0], [4.0, 2.0, 5.0, 0.0], [6.0, -1.3, 6.0, 0.0],
			[1.5, -3.7, 5.0, 0.0], [5.6, -3.8, 8.0, 180.0]]],
	# The gatehouse: a SALTS officer walks the hall past the scanner.
	["titan/gatehouse", "marshal", 5, [[-0.6, -3.5, 6.0, 180.0], [-0.6, 3.5, 6.0, 0.0]]],
]

## [piece, style, colour index, x, y, face]: people at their posts.
const POSTS := [
	["titan/plant_ex03", "worker", 1, -5.0, -2.4, 0.0],     # the operator at the control console
	["titan/gatehouse", "marshal", 5, -7.0, -1.0, 180.0],   # the SALTS desk officer
]

## Doors: [piece, x, y, width, height]. Each building's inner door and the
## airlock porch's outer door; the gatehouse's great doors at both ends.
const DOORS := {
	"titan/hab_r14": [[0.0, -5.0, 1.6, 2.4], [0.0, -7.4, 1.6, 2.4]],
	"titan/market_hub": [[0.0, -5.0, 1.6, 2.4], [0.0, -7.4, 1.6, 2.4]],
	"titan/plant_ex03": [[0.0, -6.0, 1.6, 2.4], [0.0, -8.4, 1.6, 2.4]],
	"titan/gatehouse": [[0.0, -5.0, 8.0, 5.4], [0.0, 5.0, 8.0, 5.4]],
}
const OPEN_REACH := 3.0       ## metres in front of or behind a person door
const OPEN_REACH_GATE := 9.0  ## the great doors open early for a vehicle
const SLIDE_SPEED := 2.5      ## of the opening, per second


## EX-03's filling station, between the electrolysers in the machine hall.
static func air_station() -> Vector3:
	var p := piece("titan/plant_ex03")
	return to_world(p, 2.5, 2.2) if not p.is_empty() else Vector3.INF


## A point in building `piece`'s Blender coordinates, in the world.
static func to_world(piece: Array, x: float, y: float) -> Vector3:
	var b := Basis(Vector3.UP, deg_to_rad(float(piece[2])))
	return (piece[1] as Vector3) + b * Vector3(x, 0.0, -y)


## A facing in the building's coordinates (degrees, 0 = +y) as a yaw.
static func to_yaw(piece: Array, face_deg: float) -> float:
	var a := deg_to_rad(face_deg)
	var dir := Basis(Vector3.UP, deg_to_rad(float(piece[2]))) * Vector3(sin(a), 0.0, -cos(a))
	return atan2(-dir.x, -dir.z)


## The placed building `name` (CityLayout.pieces row), or [] if absent.
static func piece(name: String) -> Array:
	for p: Array in CityLayout.pieces():
		if p[0] == name:
			return p
	return []


# --- Doors -------------------------------------------------------------------

var _doors: Array = []
var _t: float = 0.0


## Every leaf of a size is one instance of a MultiMesh (two draws: the cel
## pass and its outline) instead of two draws per leaf: the settlement's
## sixteen leaves were thirty-odd draws on a phone.
var _groups: Array = []  ## [MultiMeshInstance3D, centre Vector3] per leaf size


func _ready() -> void:
	var mat := Comic.kit_material(0.01)
	var by_size := {}  ## Vector2(w, h) -> [[door, leaf side]...]
	for name: String in DOORS:
		var p := piece(name)
		if p.is_empty():
			continue
		for d: Array in DOORS[name]:
			var w: float = d[2]
			var h: float = d[3]
			var centre := to_world(p, d[0], d[1])
			var b := Basis(Vector3.UP, deg_to_rad(float(p[2])))
			var key := Vector2(w, h)
			if not by_size.has(key):
				by_size[key] = []
			# [centre, basis, width, reach, opening, height, wanted, group, first instance]
			var door := [centre, b, w, OPEN_REACH_GATE if w > 4.0 else OPEN_REACH, 0.0, h, 0.0, -1, 0]
			by_size[key].append(door)
			_doors.append(door)
	for key: Vector2 in by_size:
		var doors: Array = by_size[key]
		var mid := Vector3.ZERO
		for d: Array in doors:
			mid += d[0] as Vector3
		mid /= float(doors.size())
		var box := BoxMesh.new()
		box.size = Vector3(key.x * 0.5, key.y, 0.1)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = CityMode._tinted(box, Color(0.58, 0.62, 0.68))
		mm.instance_count = doors.size() * 2
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Doors_%d" % _groups.size()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.position = mid
		mmi.visibility_range_end = 150.0
		mmi.custom_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, key.y + 4.0, 120))
		add_child(mmi)
		var gi := _groups.size()
		_groups.append([mmi, mid])
		for i in doors.size():
			(doors[i] as Array)[7] = gi
			(doors[i] as Array)[8] = i * 2
			_place(doors[i], 0.0)


## Puts a door's two leaves, `opening` (0..1) open.
func _place(d: Array, opening: float) -> void:
	var g: Array = _groups[d[7]]
	var mm: MultiMesh = (g[0] as MultiMeshInstance3D).multimesh
	var centre: Vector3 = d[0]
	var b: Basis = d[1]
	var w: float = d[2]
	var h: float = d[5]
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var at := centre + Vector3(0, h * 0.5, 0) + b * Vector3(side * (w * 0.25 + opening * w * 0.48), 0, 0)
		mm.set_instance_transform(int(d[8]) + k, Transform3D(b, at - (g[1] as Vector3)))


## Doors slide open when anyone (you, the people about, a driver) is near
## the doorway, and close behind them. Every body is a PlayerVisual in the
## "movers" group; checked every CHECK seconds, the slide every frame.
const CHECK := 0.15


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = CHECK
		var people: Array = []
		for v: Node in get_tree().get_nodes_in_group("movers"):
			if (v as Node3D).is_visible_in_tree():
				people.append((v as Node3D).global_position)
		var secured: Array = get_tree().get_nodes_in_group("secured_gates")
		for d: Array in _doors:
			var centre: Vector3 = d[0]
			d[6] = 0.0
			# A secured door (the gatehouse's): the simulation decides
			# (SecuredGate: it stays shut on the wanted).
			var gate: SecuredGate = null
			for g: SecuredGate in secured:
				if Vector2(g.centre.x - centre.x, g.centre.z - centre.z).length() < 1.0:
					gate = g
			if gate != null:
				d[6] = 1.0 if gate.open else 0.0
				continue
			for at: Vector3 in people:
				if Vector2(at.x - centre.x, at.z - centre.z).length() < float(d[3]) and absf(at.y - centre.y) < 6.0:
					d[6] = 1.0
					break
	for d: Array in _doors:
		var opening: float = move_toward(float(d[4]), float(d[6]), delta * SLIDE_SPEED)
		if opening == float(d[4]):
			continue
		d[4] = opening
		_place(d, opening)
