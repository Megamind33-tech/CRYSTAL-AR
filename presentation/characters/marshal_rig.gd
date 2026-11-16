@tool
class_name MarshalRig
extends MercenaryRig
## The Kasei Marshals, Mars' police: a navy suit with white trim and a
## cyan stripe, a white helmet with a cyan visor and a red-blue light bar,
## a navy vest with a gold badge (Blender-built). A uniform, not a team colour.

const MARSHAL_SUIT := Color(0.1, 0.14, 0.3)
const MARSHAL_WHITE := Color(0.92, 0.93, 0.96)
const MARSHAL_CYAN := Color(0.25, 0.85, 1.0)


func _suit(mat: ShaderMaterial, _color: Color) -> void:
	mat.set_shader_parameter("suit", MARSHAL_SUIT)
	mat.set_shader_parameter("trim", MARSHAL_WHITE)
	mat.set_shader_parameter("stripe", MARSHAL_CYAN)
	mat.set_shader_parameter("boots", Color(0.05, 0.05, 0.07))


func _gear() -> Array:
	return [["world/marshal_helmet", "Head"], ["world/marshal_vest", "spine_03"]]
