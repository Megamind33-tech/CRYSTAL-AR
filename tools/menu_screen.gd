extends Node
## THE HUNT: a screenshot of the home screen.
##   xvfb-run godot --resolution 1280x720 res://tools/menu_screen.tscn -- --out DIR

func _ready() -> void:
	var out := Platform.get_user_arg("--out", "user://")
	add_child((load("res://ui/main_menu/main_menu.tscn") as PackedScene).instantiate())
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("00_home.png"))
	print("MENU SCREEN saved")
	get_tree().quit(0)
