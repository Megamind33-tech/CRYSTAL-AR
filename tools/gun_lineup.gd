extends Node3D
## A look at the art: every weapon model in a row (comic material). Run:
## godot --resolution 1200x900 res://tools/gun_lineup.tscn -- out.png
## Renders every weapon model in a row (a look at the art).
func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.55, 0.58)
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)
	var i := 0
	for id: StringName in WeaponModels.MODELS:
		var w := WeaponModels.instantiate(id)
		w.rotation_degrees.y = 90
		w.position = Vector3(0, 0.36 - i * 0.12, 0)
		add_child(w)
		i += 1
	var cam := Camera3D.new()
	cam.position = Vector3(-0.02, 0.0, 1.05)
	cam.fov = 45
	add_child(cam)
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
