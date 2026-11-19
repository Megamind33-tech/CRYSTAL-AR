extends Node3D
## A look at the art: the army kit (tools/blender/build_army_kit.py). Run:
## godot --resolution 1200x700 res://tools/army_lineup.tscn -- out.png
func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.78, 0.68, 0.52)
	e.ambient_light_color = Color(0.9, 0.85, 0.8)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	add_child(sun)
	var items := [["attack_drone", Vector3(-4.5, 3, 0), 1.4], ["scout_drone", Vector3(-2, 3, 0), 1.6], ["emp_drone", Vector3(0.5, 3, 0), 1.3],
		["aegis_drone", Vector3(3, 3, 0), 1.2], ["swarm_drone", Vector3(5.5, 3, 0), 1.8],
		["strike_jet", Vector3(-4, 0, 0), 0.32], ["raptor", Vector3(-1, 0, 0), 0.32], ["nightwing", Vector3(2, 0, 0), 0.32],
		["bomber", Vector3(5, 0, 0), 0.2]]
	for it: Array in items:
		var n := Comic.kit_instance("army/" + str(it[0]), it[1], -35.0, it[2])
		if float(it[2]) > 1.0:
			n.material_override = Comic.kit_material(0.008)
		n.rotation_degrees.x = 25
		add_child(n)
	var cam := Camera3D.new()
	cam.position = Vector3(0.5, 1.5, 9)
	cam.fov = 60
	add_child(cam)
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
