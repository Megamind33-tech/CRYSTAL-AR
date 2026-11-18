class_name StaticBatches
extends Node3D
## The world's static kit pieces merged by cell (phone budget: 86 draws,
## 100k triangles). One kit piece is two draws (the cel pass and its ink
## outline), so a valley of separate pieces costs hundreds. Here every
## static piece in a CELL-metre square with the same view distance becomes
## one mesh with its own detail levels, placed at the cell's centre (so
## view distances and mesh LOD measure from there), and only cells near the
## camera keep the outline pass: past OUTLINE_RANGE the shell is a hairline
## on a phone screen anyway.
##
## Pieces that move, get hidden or are looked up by name (trees, interiors,
## the farm, the train, vehicles) stay separate nodes.

const CELL := 128.0
## Cells nearer than this (camera to the cell's box) are drawn with outlines.
const OUTLINE_RANGE := 50.0
const CHECK_EVERY := 0.25
## View distances are rounded up to these (0, always drawn, stays): a cell
## with a dozen distinct distances was a dozen draws. Small props (160-260 m)
## show to 260, everything else to 450 or 500.
const REACH_TIERS := [260.0, 450.0, 500.0]

## [cell, reach, outline] -> [PackedVector3Array verts, normals, PackedColorArray colors]
var _parts: Dictionary = {}
## [MeshInstance3D, world AABB, outline]
var _batches: Array = []
var _t: float = 0.0


## A kit piece as Comic.kit_instance places it. `reach` is its view
## distance (0: always drawn).
func add_piece(piece: String, at: Vector3, yaw_deg: float, scale: float, reach: float, outline: bool = true) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * scale), at)
	add_arrays(Comic.kit_arrays(piece), xf, reach, outline)


## Any vertex-coloured mesh drawn with the kit material, at `xf` (in this
## node's space), in the cell of `at` (default: xf's origin). Without an
## outline (roads) it's drawn as is, with no detail levels.
func add_mesh(mesh: Mesh, xf: Transform3D, reach: float, outline: bool = true, at: Vector3 = Vector3.INF) -> void:
	for s in mesh.get_surface_count():
		add_arrays(mesh.surface_get_arrays(s), xf, reach, outline, at)


## Surface arrays (as Mesh.surface_get_arrays) placed like add_mesh.
func add_arrays(arrays: Array, xf: Transform3D, reach: float, outline: bool = true, at: Vector3 = Vector3.INF) -> void:
	var where := xf.origin if at == Vector3.INF else at
	if outline:
		reach = _tier(reach)
	var cell := Vector2i(floori(where.x / CELL), floori(where.z / CELL))
	var key := [cell, reach, outline]
	if not _parts.has(key):
		_parts[key] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
	var part: Array = _parts[key]
	var rot := Transform3D(xf.basis.orthonormalized(), Vector3.ZERO)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if colors.is_empty():
		colors.resize(verts.size())
		colors.fill(Color.WHITE)
	if not idx.is_empty():  # small primitives (footings): unindex them
		var v2 := PackedVector3Array()
		var n2 := PackedVector3Array()
		var c2 := PackedColorArray()
		v2.resize(idx.size())
		n2.resize(idx.size())
		c2.resize(idx.size())
		for k in idx.size():
			v2[k] = verts[idx[k]]
			n2[k] = normals[idx[k]]
			c2[k] = colors[idx[k]]
		verts = v2
		normals = n2
		colors = c2
	# Packed arrays are values: take each out, grow it, put it back.
	var pv: PackedVector3Array = part[0]
	var pn: PackedVector3Array = part[1]
	var pc: PackedColorArray = part[2]
	part[0] = PackedVector3Array()  # drop the dictionary's reference so append doesn't copy
	part[1] = PackedVector3Array()
	part[2] = PackedColorArray()
	pv.append_array(xf * verts)
	pn.append_array(rot * normals)
	pc.append_array(colors)
	part[0] = pv
	part[1] = pn
	part[2] = pc


static func _tier(reach: float) -> float:
	if reach <= 0.0:
		return reach
	for t: float in REACH_TIERS:
		if reach <= t:
			return t
	return reach


## Builds the merged meshes (once, after every piece is added).
func build() -> void:
	for key: Array in _parts:
		var part: Array = _parts[key]
		var verts: PackedVector3Array = part[0]
		if verts.is_empty():
			continue
		var cell: Vector2i = key[0]
		var reach: float = key[1]
		var outline: bool = key[2]
		var centre := Vector3((cell.x + 0.5) * CELL, 0.0, (cell.y + 0.5) * CELL)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = Transform3D(Basis(), -centre) * verts
		arrays[Mesh.ARRAY_NORMAL] = part[1]
		arrays[Mesh.ARRAY_COLOR] = part[2]
		var mi := MeshInstance3D.new()
		mi.name = "Batch_%d_%d_%d%s" % [cell.x, cell.y, int(reach), "" if outline else "_flat"]
		mi.mesh = Comic.compact_mesh(arrays, outline)
		mi.position = centre
		mi.material_override = Comic.kit_material() if outline else Comic.kit_material_plain()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if reach > 0.0:
			mi.visibility_range_end = reach
			mi.visibility_range_end_margin = 10.0
		add_child(mi)
		_batches.append([mi, AABB(mi.get_aabb().position + centre, mi.get_aabb().size), outline])  # in this node's space
	_parts.clear()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = CHECK_EVERY
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := to_local(cam.global_position)
	for b: Array in _batches:
		if not b[2]:
			continue
		var box: AABB = b[1]
		var near := _distance(box, eye) < OUTLINE_RANGE
		var mi: MeshInstance3D = b[0]
		var want: Material = Comic.kit_material() if near else Comic.kit_material_plain()
		if mi.material_override != want:
			mi.material_override = want


static func _distance(box: AABB, p: Vector3) -> float:
	var q := p.clamp(box.position, box.end)
	return q.distance_to(p)
