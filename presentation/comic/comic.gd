class_name Comic
extends RefCounted
## THE HUNT's comic materials: the cel environment material and the ink
## outline pass (shared resources, so every user batches together).

const ENV_SHADER := preload("res://presentation/comic/comic_env.gdshader")
const OUTLINE_SHADER := preload("res://presentation/comic/comic_outline.gdshader")
const FLAT_SHADER := preload("res://presentation/comic/comic_flat.gdshader")
## The Blender-built outpost kit (tools/blender/build_outpost_kit.py).
const KIT := "res://art/environment/kit/%s.glb"

static var _kit_meshes: Dictionary = {}  ## piece -> ArrayMesh
static var _kit_mats: Dictionary = {}  ## outline width -> ShaderMaterial

static var _outlines: Dictionary = {}  ## width -> ShaderMaterial


## A cel-shaded triplanar material on `albedo` (Mars PBR diffuse map).
static func env_material(albedo: Texture2D, uv_scale: float, tint: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ENV_SHADER
	m.set_shader_parameter("albedo_tex", albedo)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("tint", tint)
	return m


## The shared ink outline pass of a given width (metres at 1 m).
static func outline(width: float = 0.012) -> ShaderMaterial:
	if not _outlines.has(width):
		var m := ShaderMaterial.new()
		m.shader = OUTLINE_SHADER
		m.set_shader_parameter("width", width)
		m.render_priority = -1
		_outlines[width] = m
	return _outlines[width]


## Puts an ink outline under every mesh below `root` (characters, weapons)
## as a next_pass on the material it already uses (in place: the rigs keep
## driving their own materials, and every weapon of a kind shares one).
static func outline_meshes(root: Node, width: float = 0.012) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override != null:
			if mi.material_override.next_pass == null:
				mi.material_override.next_pass = outline(width)
			continue
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat != null and mat.next_pass == null and not (mat is BaseMaterial3D and \
					(mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
				mat.next_pass = outline(width)


## A kit piece as one mesh: every surface merged, its Blender material's
## colour baked into the vertex colours (one draw, plus one for the outline).
static func kit_mesh(piece: String) -> ArrayMesh:
	if not _kit_meshes.has(piece):
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, kit_arrays(piece))
		_kit_meshes[piece] = mesh
	return _kit_meshes[piece]


static var _kit_arrays: Dictionary = {}  ## piece -> surface arrays (CPU only)


## kit_mesh's vertices (unindexed: position, normal, colour) without
## putting them on the GPU: what StaticBatches merges.
static func kit_arrays(piece: String) -> Array:
	if _kit_arrays.has(piece):
		return _kit_arrays[piece]
	# "world/x" pieces live with the world (art/environment/world).
	var path := ("res://art/environment/%s.glb" % piece) if piece.contains("/") else KIT % piece
	var scene: Node = (load(path) as PackedScene).instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var xf := _transform_to(scene, mi)
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			# Imported albedo colours are sRGB; vertex COLOR is used as linear.
			var col := ((mat as BaseMaterial3D).albedo_color if mat is BaseMaterial3D else Color.WHITE).srgb_to_linear()
			col.a = surface_tag(mat.resource_name if mat != null else "")
			var arrays := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var order: Variant = idx if not idx.is_empty() else range(verts.size())
			for k in order:
				st.set_color(col)
				st.set_normal((xf.basis * normals[k]).normalized())
				st.add_vertex(xf * verts[k])
	scene.free()
	var out := st.commit_to_arrays()
	_kit_arrays[piece] = out
	return out


static var _kit_lods: Dictionary = {}  ## piece -> ArrayMesh with detail levels


## The kit piece indexed, with generated detail levels, compressed: what a
## placed piece draws (on phones a far piece is a few hundred triangles).
static func kit_mesh_lod(piece: String) -> ArrayMesh:
	if not _kit_lods.has(piece):
		_kit_lods[piece] = compact_mesh(kit_arrays(piece), true)
	return _kit_lods[piece]


## A triangle surface indexed (shared vertices merged), with generated
## detail levels if `lods`, its attributes compressed (16-bit positions and
## normals: about half the video memory).
static func compact_mesh(arrays: Array, lods: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.index()
	var indexed := st.commit_to_arrays()
	var levels := {}
	if lods:
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, indexed)
		im.generate_lods(25.0, 60.0, [])
		for l in im.get_surface_lod_count(0):
			levels[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, indexed, [], levels, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	return mesh


## What a Blender material is, for the kit shader (in the vertex alpha):
## glass reflects the sky and lights up at night, lamps ("light_*") and neon glow,
## bare steel shines, the rest is painted and weathered.
const TAG_GLASS := 0.25
const TAG_GLOW := 0.5
const TAG_METAL := 0.75


static func surface_tag(material_name: String) -> float:
	var n := material_name.to_lower()
	if n.begins_with("glass"):
		return TAG_GLASS
	if n.begins_with("light_") or n.begins_with("neon"):  # plain "light" is pale paint
		return TAG_GLOW
	if n.begins_with("steel") or n.begins_with("chrome"):
		return TAG_METAL
	return 1.0


static func _transform_to(root: Node, n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## The shared cel material for kit pieces (vertex colours) with an ink
## outline of `outline_width` (thin for gear on bodies).
static func kit_material(outline_width: float = 0.03) -> ShaderMaterial:
	if not _kit_mats.has(outline_width):
		var m := ShaderMaterial.new()
		m.shader = FLAT_SHADER
		m.set_shader_parameter("grime_tex", load("res://art/environment/mars/concrete_slab_wall_diff_1k.jpg"))
		m.next_pass = outline(outline_width)
		_kit_mats[outline_width] = m
	return _kit_mats[outline_width]


static var _plain: ShaderMaterial


## The kit material without the outline pass (roads, far batches): one draw.
static func kit_material_plain() -> ShaderMaterial:
	if _plain == null:
		_plain = kit_material().duplicate() as ShaderMaterial
		_plain.next_pass = null
	return _plain


static var _paints: Dictionary = {}  ## colour -> ShaderMaterial


## The kit material with a paint job: light body panels in `color`.
static func kit_material_paint(color: Color) -> ShaderMaterial:
	if not _paints.has(color):
		var m := kit_material().duplicate() as ShaderMaterial
		m.set_shader_parameter("paint", Color(color, 1.0))
		_paints[color] = m
	return _paints[color]


## A placed kit piece.
static func kit_instance(piece: String, at: Vector3, yaw_deg: float = 0.0, scale: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Kit_" + piece
	mi.mesh = kit_mesh_lod(piece)
	mi.material_override = kit_material()
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * scale), at)
	return mi
