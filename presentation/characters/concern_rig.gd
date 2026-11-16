@tool
class_name ConcernRig
extends MercenaryRig
## The Tharsis Mining Concern's security troopers (raiders on Dust Hollow):
## a slate undersuit with the Concern's yellow, a full-face helmet with a
## red slit visor and crest, a chest plate with the yellow chevron and
## pauldrons (Blender-built). The same everywhere: a uniform, not a team colour.

const CONCERN_SUIT := Color(0.22, 0.24, 0.27)
const CONCERN_YELLOW := Color(0.98, 0.78, 0.16)


func _suit(mat: ShaderMaterial, _color: Color) -> void:
	mat.set_shader_parameter("suit", CONCERN_SUIT)
	mat.set_shader_parameter("trim", CONCERN_YELLOW)
	mat.set_shader_parameter("stripe", CONCERN_YELLOW)
	mat.set_shader_parameter("boots", Color(0.06, 0.06, 0.07))


func _gear() -> Array:
	return [["world/concern_helmet", "Head"], ["world/concern_armor", "spine_03"]]
