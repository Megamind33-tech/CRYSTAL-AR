extends Node
## THE HUNT performance probe: a real offline hunt (match scene, HUD, five
## AI rivals) held at fixed camera poses; for each pose it samples frames
## and prints one JSON line: renderer, FPS and frame time, process and
## physics time, draw calls, objects, primitives, video memory, and the
## server's per-tick cost split into simulation (world.step: movement,
## weapons, physics queries, hunt rules) and AI (bot brains + events).
##
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver vulkan \
##       --resolution 1280x720 res://tools/hunt_perf.tscn -- --label NAME [--frames N]
## On a phone: adb shell am start ... with the same user args.

const MATCH := preload("res://game/match.tscn")
const POSES := [
	["spawn_view", Vector3(6, 0.05, 46), 0.0, -0.05],
	["vault_interior", Vector3(-4, 0.05, 4), 0.785, -0.3],
	["yard_east", Vector3(50, 0.05, 10), 1.57, -0.05],
]

var m: Node
var label := "run"
var frames := 120


func _ready() -> void:
	label = Platform.get_user_arg("--label", label)
	frames = Platform.get_user_arg("--frames", str(frames)).to_int()
	_run.call_deferred()


func _run() -> void:
	Settings.set_value("profile", "mode", "hunt")
	MatchConfig.pending = MatchConfig.make(MatchConfig.Mode.OFFLINE, "Probe")
	m = MATCH.instantiate()
	add_child(m)
	await _frames(180)
	var world: SimWorld = m.server.world
	world.damage_enabled = false  # the posed camera must not die
	var me := world.get_player(ServerSession.LOCAL_PLAYER_ID)
	var meshes := get_tree().root.find_children("*", "MeshInstance3D", true, false).size()
	for pose in POSES:
		world.teleport(me, pose[1])
		me.state.yaw = pose[2]
		m.input.look_yaw = pose[2]
		m.input.look_pitch = pose[3]
		await _frames(30)
		var s := {"fps": [], "frame_ms": [], "process_ms": [], "physics_ms": [], "draw_calls": [], "objects": [],
				"primitives": [], "sim_ms": [], "ai_ms": []}
		for i in frames:
			await RenderingServer.frame_post_draw
			s.fps.append(Performance.get_monitor(Performance.TIME_FPS))
			s.frame_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
					+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			s.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			s.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			s.draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			s.objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
			s.primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			s.sim_ms.append(m.server.last_sim_usec / 1000.0)
			s.ai_ms.append(maxf(m.server.last_step_usec - m.server.last_sim_usec, 0) / 1000.0)
		var row := {"label": label, "pose": pose[0],
				"renderer": RenderingServer.get_current_rendering_method(),
				"driver": RenderingServer.get_current_rendering_driver_name(),
				"adapter": RenderingServer.get_video_adapter_name(),
				"mesh_instances": meshes,
				"vram_mib": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1)}
		for k in s:
			row[k] = _stats(s[k])
		print("HUNT PERF ", JSON.stringify(row))
	get_tree().quit(0)


## Median and 95th percentile.
func _stats(values: Array) -> Dictionary:
	var v := values.duplicate()
	v.sort()
	return {"p50": snappedf(v[v.size() / 2], 0.01), "p95": snappedf(v[int(v.size() * 0.95)], 0.01)}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
