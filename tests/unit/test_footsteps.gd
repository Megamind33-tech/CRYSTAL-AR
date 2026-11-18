extends GutTest
## Footsteps (GameAudio.update_player): steps come at the walk cycle's boot
## contacts (Stride), crouch-walking is quieter, surfaces pick their sound, and
## other players' steps far away are not played.

const DT := 1.0 / 60.0


## A player walking along +x at `speed` for `seconds`, one frame at a time.
func _walk(audio: GameAudio, speed: float, seconds: float, stance: int = PlayerSimState.Stance.STAND,
		sprinting: bool = false, ally: bool = false) -> void:
	var s := PlayerSimState.new()
	s.alive = true
	s.move_state = PlayerSimState.Move.GROUND
	s.stance = stance
	s.sprinting = sprinting
	s.position = Vector3.ZERO
	s.velocity = Vector3(speed, 0.0, 0.0)
	audio.update_player(7, s, false, ally, DT)
	for i in roundi(seconds / DT):
		s.position.x += speed * DT
		audio.update_player(7, s, false, ally, DT)


func _audio() -> GameAudio:
	var audio := GameAudio.new()
	add_child_autofree(audio)
	return audio


func test_walking_makes_footsteps() -> void:
	var audio := _audio()
	_walk(audio, 6.0, 1.0)
	assert_gt(audio.steps_played, 0)


func test_tiers_by_speed() -> void:
	assert_eq(GameAudio.step_tier(1.8, false), "walk")
	assert_eq(GameAudio.step_tier(5.0, false), "jog")
	assert_eq(GameAudio.step_tier(7.2, true), "run")
	assert_eq(GameAudio.step_tier(9.0, false), "run")


func test_interval_is_half_the_walk_cycle() -> void:
	assert_almost_eq(GameAudio.step_interval(1.8), 0.5 / Stride.rate(1.8), 0.001)
	assert_gt(GameAudio.step_interval(1.8), GameAudio.step_interval(5.0))
	assert_gt(GameAudio.step_interval(5.0), GameAudio.step_interval(7.2))


func test_steps_follow_the_cadence() -> void:
	# Two steps a walk cycle: Stride.rate(v) * 2 a second.
	for v: float in [1.8, 5.0, 7.2]:
		var audio := _audio()
		_walk(audio, v, 3.0, PlayerSimState.Stance.STAND, v > 7.0)
		var want := Stride.rate(v) * 2.0 * 3.0
		assert_between(float(audio.steps_played), floorf(want) - 1.0, ceilf(want) + 1.0, "at %.1f m/s" % v)


func test_first_step_comes_with_the_first_contact() -> void:
	# Starting off, the cycle starts at 0 and the left boot is down at
	# CONTACTS[0]: the first step follows within a few frames, as the body's.
	var audio := _audio()
	_walk(audio, 5.0, Stride.CONTACTS[0] / Stride.rate(5.0) + DT)
	assert_eq(audio.steps_played, 1)


func test_standing_plays_no_steps() -> void:
	var audio := _audio()
	_walk(audio, 0.1, 2.0)
	assert_eq(audio.steps_played, 0)


func test_takes_never_repeat_back_to_back() -> void:
	var audio := _audio()
	var s := PlayerSimState.new()
	s.alive = true
	s.move_state = PlayerSimState.Move.GROUND
	s.velocity = Vector3(5.0, 0.0, 0.0)
	audio.update_player(7, s, false, false, DT)
	var last := ""
	var played := 0
	var repeats := 0
	for i in 600:
		audio.update_player(7, s, false, false, DT)
		if audio.steps_played > played:
			played = audio.steps_played
			repeats += 1 if audio.last_step.sound == last else 0
			last = audio.last_step.sound
	assert_gt(audio.steps_played, 10)
	assert_eq(repeats, 0)


func test_surfaces_by_shape_and_place() -> void:
	assert_eq(GameAudio.surface_of(null, Vector3(5000, 0, 5000)), "sand")
	assert_eq(GameAudio.surface_of(null, CityLayout.ORIGIN), "concrete")
	assert_eq(GameAudio.surface_of(BoxShape3D.new(), Vector3.ZERO), "metal")
	assert_eq(GameAudio.surface_of(KitCollision.shape("districts/galleria"), Vector3.ZERO), "wood")
	assert_eq(GameAudio.surface_of(KitCollision.shape("titan/hab_r14"), Vector3.ZERO), "metal")


func test_every_surface_has_its_takes() -> void:
	for surface in ["wood", "metal", "concrete", "sand"]:
		for i in range(1, GameAudio.STEP_VARIANTS + 1):
			assert_true(ResourceLoader.exists(GameAudio.DIR + "footstep_%s_%d.wav" % [surface, i]), "%s %d" % [surface, i])


func test_crouch_walking_is_quieter() -> void:
	var stand := _audio()
	_walk(stand, 3.0, 1.0)
	var crouch := _audio()
	_walk(crouch, 3.0, 1.0, PlayerSimState.Stance.CROUCH)
	assert_gt(crouch.steps_played, 0)
	# Crouch is 10 dB under the same walk, jitter is at most 1 dB.
	assert_lt(crouch.last_step.db, stand.last_step.db - 6.0)


func test_outdoor_steps_use_the_sand_set() -> void:
	var audio := _audio()
	_walk(audio, 6.0, 0.5)
	assert_string_starts_with(audio.last_step.sound, "footstep_sand_")


func test_allies_use_the_soft_set() -> void:
	var audio := _audio()
	_walk(audio, 6.0, 0.5, PlayerSimState.Stance.STAND, false, true)
	assert_string_starts_with(audio.last_step.sound, "footstep_ally_")


func test_far_enemy_steps_are_not_played() -> void:
	var audio := _audio()
	var listener := Node3D.new()
	add_child_autofree(listener)
	listener.global_position = Vector3(-200.0, 0.0, 0.0)
	audio.listener = listener
	_walk(audio, 6.0, 1.0)
	assert_eq(audio.steps_played, 0)
