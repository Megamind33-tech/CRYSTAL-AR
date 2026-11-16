@tool
class_name CivilianRig
extends ArmoredRig
## Mars colonists (THE HUNT's city and settlement people): ArmoredRig's
## body and animation tree without the armour, in a work jumpsuit
## (civilian.gdshader) of a given colour, with the base character's skin,
## eyes and hair. Unarmed by default.

const CIVILIAN_SHADER := preload("res://presentation/characters/civilian.gdshader")
const HEIGHT := 1.81
## Women and men: the same skeleton (Quaternius' base characters), so the
## same animations and kit fit both.
const SCENE_FEMALE := "res://art/characters/ubc/Superhero_Female_FullBody.gltf"
const HEIGHT_FEMALE := 1.767
const SKIN := {false: "res://art/characters/ubc/T_Superhero_Male_Dark.png",
		true: "res://art/characters/ubc/T_Superhero_Female_Dark_BaseColor.png"}
var female: bool = false
static var _rest_meshes: Dictionary = {}  ## source mesh -> mesh with rest heights in COLOR


func setup(color: Color) -> void:
	_color = color
	_model = (load(SCENE_FEMALE if female else SCENE) as PackedScene).instantiate()
	_model.rotation.y = PI
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	var mat := ShaderMaterial.new()
	mat.shader = CIVILIAN_SHADER
	_suit(mat, color)
	mat.set_shader_parameter("skin_tex", load(SKIN[female]))
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mi.name not in ["Eyes", "Eyebrows"]:  # the body (node "SuperHero_Male")
			mi.mesh = _with_rest_heights(mi.mesh, str(mi.name), HEIGHT_FEMALE if female else HEIGHT)
			mi.material_override = mat
	_build_tree(_retargeted(_skeleton), UPPER_BONES)
	_dress()


## The work suit in `color` (MercenaryRig: a combat suit with accents).
func _suit(mat: ShaderMaterial, color: Color) -> void:
	mat.set_shader_parameter("suit", color)
	mat.set_shader_parameter("stripe", color.lerp(Color.WHITE, 0.6))


## Gear on the body after the tree is built (none for colonists).
func _dress() -> void:
	pass


## The body's detail levels (tools/bake_npc_bodies.gd): a rebuilt mesh
## gets them back, so far characters draw lighter versions.
const LODS := "res://art/characters/ubc/body_lods.res"
static var _lods: Resource


## The body mesh with each vertex's rest height (0..1) in COLOR.r, with the
## model's own detail levels kept.
static func _with_rest_heights(src: Mesh, part: String = "", height: float = HEIGHT) -> Mesh:
	if _rest_meshes.has(src):
		return _rest_meshes[src]
	var out := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for k in verts.size():
			# r: rest height, g: distance out along the arms, b: front/back
			# (all as fractions of the height), so the suit's details stay put.
			colors[k] = Color(clampf(verts[k].y / height, 0.0, 1.0), clampf(absf(verts[k].x) / height, 0.0, 1.0),
					clampf(0.5 + verts[k].z / height, 0.0, 1.0))
		arrays[Mesh.ARRAY_COLOR] = colors
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[c] = null  # the woman's model carries spare channels the suit shader doesn't use
		if _lods == null and ResourceLoader.exists(LODS):
			_lods = load(LODS)
		var lods := {}
		if _lods != null and _lods.has_meta(part):
			var surfaces: Array = _lods.get_meta(part)
			if i < surfaces.size():
				for level: Array in surfaces[i]:
					lods[float(level[0])] = level[1]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods, src.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_name(i, src.surface_get_name(i))
	_rest_meshes[src] = out
	return out
