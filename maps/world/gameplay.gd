extends Node3D
## Gameplay half of Kasei Valley: the ground as a height map (WorldTerrain,
## the same grid the visible terrain is built from: TerrainMesh), the city's
## and the settlements' buildings, the valley's outer bounds, spawn points.


func _ready() -> void:
	var body := StaticBody3D.new()
	body.name = "World"
	body.collision_layer = Sim.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	var n := WorldTerrain.cells() + 1
	var half := WorldTerrain.SIZE * 0.5
	var data := WorldTerrain.grid()
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	hm.map_data = data
	var ground := CollisionShape3D.new()
	ground.shape = hm
	ground.scale = Vector3(WorldTerrain.STEP, 1.0, WorldTerrain.STEP)
	body.add_child(ground)
	for p: Array in CityLayout.pieces():
		var size: Vector3 = p[4]
		if size != Vector3.ZERO:
			_box(body, (p[1] as Vector3) + Vector3(0, size.y * 0.5, 0), size, p[2])
		elif p[0] in CityLayout.WALK_IN:
			KitCollision.add(body, p[0], p[1], p[2], p[3])
		else:
			_solid(body, p[0], p[1], p[2], p[3])
	for c: Array in CityLayout.security_curtain():
		_box(body, c[0], c[1], 0.0)
	for p: Array in CityLayout.plants():
		if p[0] == "life/tree":
			_box(body, (p[1] as Vector3) + Vector3(0, 1.6, 0), Vector3(0.5, 3.2, 0.5), 0.0)
	KitCollision.add(body, "life/farm_hall", WorldLayout.farm_origin(), 0.0)
	for kind: String in WorldLayout.INTERIORS:
		KitCollision.add(body, "districts/" + kind, WorldLayout.INTERIORS[kind], 0.0)
	for t: Array in CityLayout.terminals():
		_box(body, (t[1] as Vector3) + Vector3(0, 1.2, 0), Vector3(1.2, 2.4, 1.2), 0.0)
	for p: Array in WorldLayout.pieces():
		var size: Vector3 = p[5]
		# Set into the ground exactly as drawn (WorldLayout.sink): the walk-in
		# floors were 0.15 m off the drawn ones (the Galleria deck), footed
		# props' tops 0.15 m under theirs (feet sank into them).
		var at := WorldTerrain.at(p[1], p[2]) + Vector3(0, -WorldLayout.sink(p[0]), 0)
		if size != Vector3.ZERO:
			_box(body, at + Vector3(0, size.y * 0.5, 0), size, p[3])
		elif p[0] in CityLayout.WALK_IN:
			KitCollision.add(body, p[0], at, p[3], p[4])
		else:
			_solid(body, p[0], at, p[3], p[4])
	for s in [-1.0, 1.0]:
		_box(body, Vector3(0, 60, (half - 4) * s), Vector3(half * 2, 160, 1), 0.0)
		_box(body, Vector3((half - 4) * s, 60, 0), Vector3(1, 160, half * 2), 0.0)


## Pieces drawn with no collision of their own that you drive or walk
## onto, not into: pads flush with the ground, and the arc towers (their
## towers and bridge have boxes of their own, the arch between is a street).
const OPEN_PIECES := ["districts/landing_pad", "districts/arc_towers"]


## A solid prop with no box in the layout: a box round what's drawn.
func _solid(body: StaticBody3D, piece: String, at: Vector3, yaw_deg: float, scale: float) -> void:
	if piece == "" or piece in OPEN_PIECES:
		return
	var a := KitCollision.bounds(piece)
	if a.size.y < 0.6:
		return  # flat: walked on
	var c := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * (a.get_center() * scale)
	var size := a.size * scale
	if absf(fmod(yaw_deg, 180.0)) > 0.1 and absf(fmod(yaw_deg, 90.0)) <= 0.1:
		size = Vector3(size.z, size.y, size.x)  # a quarter turn: the footprint in the world's axes
	_box(body, at + c, size, yaw_deg)


## A box `size` (in the world's axes for a quarter turn: the layouts give
## their boxes that way; any other turn turns the box) at `at`.
func _box(body: StaticBody3D, at: Vector3, size: Vector3, yaw_deg: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = at
	if absf(fmod(yaw_deg, 90.0)) > 0.1:
		cs.basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	body.add_child(cs)


func spawn_points() -> Array[Transform3D]:
	return CityLayout.spawn_points()


## A run at the dig spawns hunters in the canyon; free roam, in the city.
func spawn_points_for(game_mode: int) -> Array[Transform3D]:
	return Battlegrounds.spawns() if game_mode == GameMode.HUNT else CityLayout.spawn_points()


func pickup_spots() -> Array:
	return Battlegrounds.pickups()


func hunt_data() -> Dictionary:
	return Battlegrounds.hunt_data()  # the run's site (Battlegrounds.current)


## Set by the match before BotNavigation bakes: free roam bakes around Dust
## Hollow (raids), a run around the dig.
var nav_mode: int = GameMode.HUNT


func nav_area() -> AABB:
	if nav_mode == GameMode.CITY:
		# Raids at Dust Hollow only (Deep Furrow bakes on demand: farm_nav_area).
		var h := WorldLayout.HOLLOW
		return AABB(Vector3(h.x - 70, h.y - 20, h.z - 70), Vector3(140, 60, 140))
	return Battlegrounds.nav_area()


func flag_bases() -> Array:
	return []
