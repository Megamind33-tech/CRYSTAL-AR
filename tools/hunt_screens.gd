extends Node
## THE HUNT screenshots: starts a real offline hunt (the match scene, HUD
## and all), poses the local hunter and saves what the screen shows.
##
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##       --resolution 1280x720 res://tools/hunt_screens.tscn -- --out DIR

const MATCH := preload("res://game/match.tscn")

var out_dir := "user://hunt_screens"
var m: Node


func _ready() -> void:
	out_dir = Platform.get_user_arg("--out", out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Settings.set_value("profile", "mode", "hunt")
	var config := MatchConfig.make(MatchConfig.Mode.OFFLINE, "You")
	MatchConfig.pending = config
	m = MATCH.instantiate()
	add_child(m)
	await _frames(240)
	var world: SimWorld = m.server.world
	# Software rendering runs at a few frames a second: keep the bots from
	# shooting the posed camera (screenshots only).
	world.damage_enabled = false
	# Shoot the phone layout (what players see): touch controls, radar top left.
	m.hunt_hud.touch = true
	m.touch.visible = true
	m.hud._touch = true
	m.hud.get_node("%PauseButton").visible = true
	m._kill_feed.offset_top = 300.0
	var me := world.get_player(ServerSession.LOCAL_PLAYER_ID)
	var h := world.hunt
	# 1. The yard from the south: the vault, its grand-treasure beam, sheds.
	await _pose(me, Vector3(6, 0.05, 46), 0.0, -0.05)
	await _shot("01_yard_from_spawn")
	# 2. Walking up to one of our own treasures (green case and beam).
	var own: HuntRules.Treasure = h.assignments_of(me.net_id)[0]
	var away := own.home + (Vector3(0, 0, 0) - own.home).normalized() * 5.0
	await _pose(me, away + Vector3(0, 0.05, 0), _yaw_to(away, own.home), -0.25)
	m.hunt_hud.banner(tr("HUNT_BANNER_EXTRACTED"), tr("HUNT_BANNER_REWARD") % [100, 50], HuntHud.GRAND)
	await _frames(25)
	await _shot("02_own_treasure")
	# 3. Inside the vault, the grand treasure (put back if a bot took it).
	var grand := h.grand()
	grand.carrier = 0
	grand.banked = false
	grand.available_tick = 0
	grand.position = grand.home
	await _pose(me, Vector3(-4, 0.05, 4), _yaw_to(Vector3(-4, 0, 4), Vector3.ZERO), -0.3)
	await _shot("03_vault_grand_treasure")
	# 4. Carrying it onto an extraction pad: the objective line counts down.
	grand.carrier = me.net_id
	var zone: Vector3 = h.zones[2]
	await _pose(me, zone + Vector3(0, 0.05, 2.5), 0.0, -0.1)
	await _frames(60)
	await _shot("04_extracting_grand")
	# 5. Overhead: the whole 150 m yard.
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 165, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.fov = 55.0
	cam.current = true
	for we: WorldEnvironment in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		we.environment.fog_enabled = false
	m.hud.visible = false
	await _frames(30)
	await _shot("05_overhead_yard")
	cam.current = false
	m.hud.visible = true
	# 6. Among the rivals: the nearest bot, from behind cover distance.
	var nearest: SimPlayer = null
	for p: SimPlayer in world.players.values():
		if p != me and p.state.alive and (nearest == null or p.state.position.length() < nearest.state.position.length()):
			nearest = p
	if nearest != null:
		var at := nearest.state.position + Vector3(7, 0.05, 7)
		await _pose(me, at, _yaw_to(at, nearest.state.position), -0.05)
		m.effects.hit_burst(nearest.state.position + Vector3(0, 1.3, 0), true)
		m.effects.muzzle_flash(nearest.state.position + Vector3(-0.4, 1.4, 0.6), Color(1.0, 0.85, 0.3))
		await _frames(4)
		await _shot("06_rival_hunter")
	# 6b. The outpost beyond the fence (Blender kit): habitats to the west,
	# tanks to the north.
	await _pose(me, Vector3(-56, 0.05, 22), PI * 0.5 - 0.35, 0.18)
	await _shot("09_outpost_kit")
	await _pose(me, Vector3(-18, 0.05, -40), -0.1, 0.16)
	await _shot("10_tanks_north")
	# 7. The hunter's phone: home screen, then the CREW app.
	m.hunt_menu.toggle()
	await _frames(40)
	await _shot("07_phone")
	m.hunt_menu.open_tab("crew")
	await _frames(20)
	await _shot("08_phone_crew")
	m.hunt_menu.toggle()
	print("HUNT SCREENS: saved to %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit(0)


func _pose(me: SimPlayer, at: Vector3, yaw: float, pitch: float) -> void:
	m.server.world.teleport(me, at)
	me.state.yaw = yaw
	m.input.look_yaw = yaw
	m.input.look_pitch = pitch
	await _frames(45)


func _yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("HUNT SCREENS: %s" % name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
