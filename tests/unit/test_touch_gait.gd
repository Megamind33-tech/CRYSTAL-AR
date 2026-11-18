extends GutTest
## Touch gait (walk / jog / run buttons): the stick's full push goes at the
## chosen gait, a partial push still scales, run holds sprint while moving.

const Gait := InputAdapter.Gait
const Held := PlayerCommand.Held


func test_walk_caps_stick_at_a_stroll() -> void:
	var v := InputAdapter.gait_stick(Vector2(0, 1), Gait.WALK, 6.0)
	assert_almost_eq(v.length() * 6.0, InputAdapter.WALK_MPS, 0.001)


func test_walk_keeps_analog_scaling() -> void:
	var half := InputAdapter.gait_stick(Vector2(0, 0.5), Gait.WALK, 6.0)
	assert_almost_eq(half.length(), 0.5 * 1.8 / 6.0, 0.001)


func test_jog_and_run_pass_the_stick_through() -> void:
	for g: int in [Gait.JOG, Gait.RUN]:
		assert_eq(InputAdapter.gait_stick(Vector2(0.3, 0.4), g), Vector2(0.3, 0.4))
		assert_almost_eq(InputAdapter.gait_stick(Vector2(2, 0), g).length(), 1.0, 0.001)


func test_only_run_sprints_and_only_when_pushed() -> void:
	assert_true(InputAdapter.gait_sprints(Vector2(0, 0.6), Gait.RUN))
	assert_false(InputAdapter.gait_sprints(Vector2.ZERO, Gait.RUN))
	assert_false(InputAdapter.gait_sprints(Vector2(0, 1), Gait.JOG))
	assert_false(InputAdapter.gait_sprints(Vector2(0, 1), Gait.WALK))


func test_command_carries_gait() -> void:
	var a := InputAdapter.new()
	add_child_autofree(a)
	a.touch_move = Vector2(0, 1)
	a.gait = Gait.WALK
	var c := a.build_command(1)
	assert_lt(c.move_vector().length(), 0.4)
	assert_false(c.is_held(Held.SPRINT))
	a.gait = Gait.RUN
	c = a.build_command(2)
	assert_almost_eq(c.move_vector().length(), 1.0, 0.02)
	assert_true(c.is_held(Held.SPRINT))


func test_chips_change_gait_and_crouch_toggles() -> void:
	var tc := TouchControls.new()
	add_child_autofree(tc)
	var a := InputAdapter.new()
	add_child_autofree(a)
	tc.input = a
	tc.visible = true
	var pos := tc._gait_center("walk")
	assert_eq(tc.gait_at(pos), "walk")
	tc._on_down(0, pos)
	assert_eq(a.gait, Gait.WALK)
	tc._on_up(0)
	tc._on_down(1, tc._gait_center("crouch"))
	assert_true(tc.crouch_on)
	assert_true((a.touch_held & Held.CROUCH) != 0)
	tc._on_up(1)
	tc._on_down(2, tc._gait_center("crouch"))
	assert_false(tc.crouch_on)
	assert_eq(a.touch_held & Held.CROUCH, 0)
