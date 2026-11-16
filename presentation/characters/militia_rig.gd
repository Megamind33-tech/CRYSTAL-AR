@tool
class_name MilitiaRig
extends MercenaryRig
## Dust Hollow's people under arms (the militia, and friends who come along
## on runs): miners' orange work suits, a hard hat with a lamp and a
## hi-vis harness (Blender-built).

const MINER_ORANGE := Color(0.86, 0.43, 0.13)


func _suit(mat: ShaderMaterial, _color: Color) -> void:
	mat.set_shader_parameter("suit", MINER_ORANGE)
	mat.set_shader_parameter("trim", Color(0.15, 0.13, 0.15))
	mat.set_shader_parameter("stripe", Color(1.0, 0.95, 0.4))
	mat.set_shader_parameter("boots", Color(0.12, 0.1, 0.1))


func _gear() -> Array:
	# Outside, everyone's sealed: the contractor's helmet and life-support
	# pack under the Hollow's hi-vis harness.
	return [["world/merc_helmet", "Head"], ["world/merc_rig", "spine_03"], ["world/militia_harness", "spine_03"]]
