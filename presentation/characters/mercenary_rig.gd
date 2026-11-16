@tool
class_name MercenaryRig
extends CivilianRig
## THE HUNT's mercenaries (the player, rival hunters, hired guns): the base
## human in a charcoal combat undersuit with accents in their colour, and
## the Kasei contractor's kit modelled in Blender (tools/blender/
## build_world.py): a pressure helmet with an amber visor on the Head bone,
## a chest rig and a life-support pack with twin O2 bottles on spine_03.
## No bulky armour: a contractor, not a trooper.

const SUIT := Color(0.13, 0.12, 0.14)
## [kit piece, bone].
const GEAR := [["world/merc_helmet", "Head"], ["world/merc_rig", "spine_03"]]


func _suit(mat: ShaderMaterial, color: Color) -> void:
	var accent := Color.from_hsv(color.h, maxf(color.s, 0.55), maxf(color.v, 0.75))
	mat.set_shader_parameter("suit", SUIT)
	mat.set_shader_parameter("trim", accent)
	mat.set_shader_parameter("stripe", accent)
	mat.set_shader_parameter("boots", Color(0.07, 0.06, 0.07))


## Where the kit's bones sit on the man's body at rest (model space), and
## how a woman's body is scaled around them.
const MALE_BONES := {"Head": Vector3(0.0, 1.5998, -0.0174), "spine_03": Vector3(0.0, 1.3109, 0.0069)}
const FEMALE_FIT := {"Head": Vector3(0.93, 0.95, 0.93), "spine_03": Vector3(0.82, 0.97, 0.94)}


## The kit this body wears: [kit piece, bone] pairs.
func _gear() -> Array:
	return GEAR


func _dress() -> void:
	for g: Array in _gear():
		var bone := _skeleton.find_bone(g[1])
		if bone < 0:
			continue
		var attach := BoneAttachment3D.new()
		attach.bone_name = g[1]
		_skeleton.add_child(attach)
		var mi := MeshInstance3D.new()
		mi.mesh = Comic.kit_mesh_lod(g[0])
		mi.material_override = Comic.kit_material(0.006)
		# The kit is modelled where it sits on the man's body at rest: map it
		# onto this body around the bone (a woman's head and chest are a
		# little smaller and narrower), then undo the bone's rest so it rides
		# the bone from there.
		var rest := _skeleton.get_bone_global_rest(bone)
		var fit := Transform3D.IDENTITY
		if female:
			var male_at: Vector3 = MALE_BONES.get(g[1], rest.origin)
			var s: Vector3 = FEMALE_FIT.get(g[1], Vector3(0.95, 0.97, 0.95))
			fit = Transform3D(Basis.from_scale(s), rest.origin) * Transform3D(Basis.IDENTITY, -male_at)
		mi.transform = rest.affine_inverse() * fit
		attach.add_child(mi)
