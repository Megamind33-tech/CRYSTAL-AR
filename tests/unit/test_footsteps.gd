extends GutTest
## Footsteps (GameAudio.update_player): the step rhythm follows the walk, jog
## and run tiers, crouch-walking is quieter, surfaces pick their sound, and
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
	assert_eq(GameAudio.step_tier(2.0, false), "walk")
	assert_eq(GameAudio.step_tier(6.0, false), "jog")
	assert_eq(GameAudio.step_tier(8.5, true), "run")
	assert_eq(GameAudio.step_tier(9.0, false), "run")


func test_interval_follows_tier() -> void:
	assert_almost_eq(GameAudio.step_interval(3.0, false), 0.55, 0.001)
	assert_almost_eq(GameAudio.step_interval(6.0, false), 0.38, 0.001)
	assert_almost_eq(GameAudio.step_interval(8.5, true), 0.30, 0.001)


func test_jog_cadence() -> void:
	# Three seconds of jogging is about 3 / 0.38 steps.
	var audio := _audio()
	_walk(audio, 6.0, 3.0)
	assert_between(audio.steps_played, 7, 9)


func test_run_cadence() -> void:
	# Three seconds of sprinting is about 3 / 0.30 steps.
	var audio := _audio()
	_walk(audio, 8.5, 3.0, PlayerSimState.Stance.STAND, true)
	assert_between(audio.steps_played, 9, 11)


func test_crouch_walking_is_quieter() -> void:
	var stand := _audio()
	_walk(stand, 3.0, 1.0)
	var crouch := _audio()
	_walk(crouch, 3.0, 1.0, PlayerSimState.Stance.CROUCH)
	assert_gt(crouch.steps_played, 0)
	# Crouch is 10 dB under the same walk, jitter is at most 1 dB.
	assert_lt(crouch.last_step.db, stand.last_step.db - 6.0)


func test_outdoor_steps_use_ground_sound() -> void:
	var audio := _audio()
	_walk(audio, 6.0, 0.5)
	assert_string_starts_with(audio.last_step.sound, "footstep_ground_")


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
