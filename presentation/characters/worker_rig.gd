@tool
class_name WorkerRig
extends MercenaryRig
## Colonists outside the domes (Dust Hollow's workers, the Ledger's dealer):
## their work suit colour, sealed: the pressure helmet and the life-support
## pack. Inside a dome or Deep Furrow people go bare-headed (CivilianRig).


func _suit(mat: ShaderMaterial, color: Color) -> void:
	mat.set_shader_parameter("suit", color)
	mat.set_shader_parameter("stripe", color.lerp(Color.WHITE, 0.6))
