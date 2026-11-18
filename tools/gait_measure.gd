extends SceneTree
## Measures the locomotion clips on a character body: cycle length, the
## ground speed the feet travel at while planted (the speed the clip plays
## at without sliding), when each foot touches down (as a fraction of the
## cycle) and how high the soles stay over the floor (negative: sinking).
##   godot --headless -s res://tools/gait_measure.gd [-- style ...]
## The numbers feed Stride.CLIPS (presentation/characters/stride.gd).

const CLIPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Fwd"]
const FPS := 120.0


func _initialize() -> void:
	var styles := OS.get_cmdline_user_args()
	var slide := styles.has("--slide")
	if slide:
		styles.remove_at(styles.find("--slide"))
	if styles.is_empty():
		styles = PackedStringArray(["sentinel", "vanguard", "operative", "spacer", "armored", "civilian"])
	await process_frame
	for style in styles:
		var rig := CharacterRig.create(style, 0)
		root.add_child(rig)
		rig.setup(Color.WHITE)
		await process_frame
		if slide:
			_slide(style, rig)
		else:
			_measure(style, rig)
		rig.queue_free()
		await process_frame
	quit(0)


func _bone(sk: Skeleton3D, names: Array) -> int:
	for n: String in names:
		var b := sk.find_bone(n)
		if b >= 0:
			return b
	return -1


func _measure(style: String, rig: Node3D) -> void:
	var sks := rig.find_children("*", "Skeleton3D", true, false)
	var players := rig.find_children("*", "AnimationPlayer", true, false)
	var trees := rig.find_children("*", "AnimationTree", true, false)
	if sks.is_empty() or players.is_empty():
		print("GAIT %s: no skeleton or player" % style)
		return
	var sk: Skeleton3D = sks[0]
	var player: AnimationPlayer = players[0]
	for t: AnimationTree in trees:
		t.active = false
	var feet := [_bone(sk, ["foot_l", "LeftFoot"]), _bone(sk, ["foot_r", "RightFoot"])]
	var balls := [_bone(sk, ["ball_l", "LeftToeBase"]), _bone(sk, ["ball_r", "RightToeBase"])]
	var to_rig := rig.global_transform.affine_inverse() * sk.global_transform
	# The soles in the bind pose: the lowest vertex of the skinned mesh.
	var sole := INF
	for mi: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh != null and mi.skin != null:
			var a: AABB = rig.global_transform.affine_inverse() * mi.global_transform * mi.mesh.get_aabb()
			sole = minf(sole, a.position.y)
	var rest_ball := (to_rig * sk.get_bone_global_rest(balls[0])).origin.y
	var rest_foot := (to_rig * sk.get_bone_global_rest(feet[0])).origin.y
	print("GAIT %s: bind sole %.3f, ball %.3f, ankle %.3f (rig scale %s)" % [style, sole, rest_ball, rest_foot, rig.scale])
	for clip: String in CLIPS:
		if not player.has_animation(clip):
			continue
		var len := player.get_animation(clip).length
		player.play(clip)
		var n := int(len * FPS)
		var pos := [[], []]
		for i in n + 1:
			player.seek(len * i / n, true)
			for s in 2:
				pos[s].append((to_rig * sk.get_bone_global_pose(balls[s])).origin)
				pos[s].append((to_rig * sk.get_bone_global_pose(feet[s])).origin)
		var line := "GAIT %s %s: %.3f s" % [style, clip, len]
		for s in 2:
			var low := INF
			var low_ankle := INF
			for i in range(0, pos[s].size(), 2):
				low = minf(low, pos[s][i].y)
				low_ankle = minf(low_ankle, pos[s][i + 1].y)
			# Planted: the ball within 2 cm of its lowest.
			var speeds := []
			var contact := -1.0
			for i in n:
				var a: Vector3 = pos[s][i * 2]
				var b: Vector3 = pos[s][i * 2 + 2]
				var planted := a.y < low + 0.02 and b.y < low + 0.02
				if planted:
					speeds.append(Vector2(b.x - a.x, b.z - a.z).length() * FPS)
				var prev: Vector3 = pos[s][((i - 1 + n) % n) * 2]
				if contact < 0.0 and a.y < low + 0.02 and prev.y >= low + 0.02:
					contact = float(i) / n
			speeds.sort()
			var v: float = speeds[speeds.size() / 2] if not speeds.is_empty() else 0.0
			line += " | %s: plant %.2f m/s, down at %.2f, ball low %+.3f (bind %+.3f), ankle low %.3f" % ["LR"[s], v,
					contact, low, rest_ball, low_ankle]
		print(line)


## Drives the body through animate() at several ground speeds, moving it
## along, and reports how fast a planted boot slides over the floor (0 is
## right) and where in Stride's cycle each boot comes down.
##   godot --headless -s res://tools/gait_measure.gd -- --slide sentinel
func _slide(style: String, rig: CharacterRig) -> void:
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	var balls := [_bone(sk, ["ball_l", "LeftToeBase"]), _bone(sk, ["ball_r", "RightToeBase"])]
	var dt := 1.0 / 60.0
	for v: float in [1.0, 1.8, 3.0, 5.0, 7.2]:
		var s := PlayerSimState.new()
		s.alive = true
		s.move_state = PlayerSimState.Move.GROUND
		s.velocity = Vector3(0, 0, -v)
		rig.position = Vector3.ZERO
		var phase := 0.0
		var samples := [[], []]
		var downs := [[], []]
		for i in 360:
			rig.animate(s, dt, 1.8)
			rig.position.z -= v * dt
			if i > 0:
				phase += Stride.rate(v) * dt
			for side in 2:
				samples[side].append([(sk.global_transform * sk.get_bone_global_pose(balls[side])).origin, phase])
		var line := "SLIDE %s %.1f m/s (rate %.2f, blend %.2f):" % [style, v, Stride.rate(v), Stride.blend(v, rig.call("_strides"))]
		for side in 2:
			var low := INF
			for e: Array in samples[side].slice(60):
				low = minf(low, (e[0] as Vector3).y)
			var slides := []
			for i in range(61, samples[side].size()):
				var a: Vector3 = samples[side][i - 1][0]
				var b: Vector3 = samples[side][i][0]
				if a.y < low + 0.02 and b.y < low + 0.02:
					slides.append(Vector2(b.x - a.x, b.z - a.z).length() / dt)
				elif b.y < low + 0.02 and a.y >= low + 0.02:
					downs[side].append(snappedf(fposmod(float(samples[side][i][1]), 1.0), 0.01))
			slides.sort()
			line += " %s slide %.2f m/s, down at %s;" % ["LR"[side], slides[slides.size() / 2] if not slides.is_empty() else -1.0, downs[side]]
		print(line)
