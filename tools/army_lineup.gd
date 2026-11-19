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
	if OS.get_cmdline_user_args().has("--ground"):
		for c in get_children():
			if c is MeshInstance3D:
				c.queue_free()
		var hv := HuntVisuals.new()
		add_child(hv)
		var tank := Comic.kit_instance("army/tank", Vector3(-7.5, -1.5, 0), 215.0, 0.9)
		tank.add_child(Comic.kit_instance("army/tank_turret", Vector3(0, 1.36, 0.15), 20.0))
		add_child(tank)
		add_child(Comic.kit_instance("army/crawler", Vector3(-2.0, -1.5, -1.5), 215.0, 0.75))
		var t := hv._turret_model(Vector3(3.0, -1.5, 0))
		t.rotation_degrees.y = 200
		hv.add_child(t)
		hv.add_child(hv._flak_model(Vector3(7.5, -1.5, 0.5), false))
		hv.add_child(hv._flak_model(Vector3(13.0, -1.5, -1.0), true))
		for f: Array in hv._flak:
			(f[1] as Node3D).rotation.y = PI - 0.6
			(f[2] as Node3D).rotation.x = 0.5
	if OS.get_cmdline_user_args().has("--heavy"):  # the tank and Halden's Bastion side by side
		for c in get_children():
			if c is MeshInstance3D or c is HuntVisuals:
				c.queue_free()
		for q: Array in [["tank", "tank_turret", Vector3(-3.0, -1.5, 0), Vector3(0, 1.36, 0.15)],
				["bastion", "bastion_turret", Vector3(3.5, -1.5, 0), Vector3(0, 1.62, 0.25)]]:
			var hull := Comic.kit_instance("army/" + str(q[0]), q[2], 215.0)
			hull.add_child(Comic.kit_instance("army/" + str(q[1]), q[3], 15.0))
			add_child(hull)
	var cam := Camera3D.new()
	cam.position = Vector3(0.5, 1.5, 9) if not OS.get_cmdline_user_args().has("--ground") else Vector3(2.5, 4.5, 15)
	if OS.get_cmdline_user_args().has("--heavy"):
		cam.position = Vector3(0.3, 3.5, 11)
	cam.fov = 60
	if OS.get_cmdline_user_args().has("--ground") or OS.get_cmdline_user_args().has("--heavy"):
		cam.rotation_degrees.x = -14
	add_child(cam)
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
