class_name KitCollision
extends RefCounted
## Walk-in buildings: collision from the Blender piece's own triangles
## (ConcavePolygonShape3D, both sides), so doorways are open and walls are
## where they're drawn. Cached per piece. Used by Kasei Valley's gameplay.

static var _shapes: Dictionary = {}


static func shape(piece: String) -> ConcavePolygonShape3D:
	if _shapes.has(piece):
		return _shapes[piece]
	var path := ("res://art/environment/%s.glb" % piece) if piece.contains("/") else "res://art/environment/kit/%s.glb" % piece
	# A walk-in piece with fine detail ships its walls and floors alone.
	var col := path.get_basename() + "_col.glb"
	if ResourceLoader.exists(col):
		path = col
	var scene: Node = (load(path) as PackedScene).instantiate()
	var faces := PackedVector3Array()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != scene:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for f in mi.mesh.get_faces():
			faces.append(xf * f)
	scene.free()
	var s := ConcavePolygonShape3D.new()
	s.set_faces(faces)
	s.backface_collision = true
	_shapes[piece] = s
	return s


## A body part for `piece` placed at `at`, turned `yaw_deg`, scaled `scale`.
static func add(body: StaticBody3D, piece: String, at: Vector3, yaw_deg: float, scale: float = 1.0) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape(piece)
	cs.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * scale), at)
	body.add_child(cs)
