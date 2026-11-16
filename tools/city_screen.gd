extends Node
## Screenshot of the city screen with a sample career (does not touch the
## real profile file: storage is turned off for the run).

var out_dir := "user://city_screen"


func _ready() -> void:
	out_dir = Platform.get_user_arg("--out", out_dir)
	_run.call_deferred()


func _run() -> void:
	Platform.storage_available = false
	var c := Profile.career()
	c.d.wallet = 1240
	c.d.stash = {"vault_relic": 1, "helium3": 2, "stolen_cargo": 1}
	c.d.standing = {"tharsis": 20, "kasei": 10, "ledger": -5}
	c.d.runs = 3
	c.d.last_report = {"items": {"vault_relic": 1, "cargo_case": 1}, "contract": "done", "pay": 260}
	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.12, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var city := CityScreen.new()
	add_child(city)
	for tab in ["contracts", "market", "outfitter"]:
		city._tab = tab
		city.refresh()
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("city_%s.png" % tab))
	get_tree().quit(0)
