extends GutTest
## The walk cycle (Stride): cadence by ground speed, the in-step clip blend
## that keeps planted boots from sliding, and the boot contacts the
## footsteps play on.


func test_cadence_rises_with_speed() -> void:
	assert_eq(Stride.rate(0.0), 0.0)
	var last := 0.0
	for v: float in [0.5, 1.0, 1.8, 3.0, 5.0, 7.2, 9.0]:
		assert_gt(Stride.rate(v), last, "at %.1f m/s" % v)
		last = Stride.rate(v)


func test_cadence_is_human() -> void:
	# Steps a minute: a brisk walk ~110-120, a jog ~125-140, a sprint ~150-175.
	assert_between(Stride.rate(1.8) * 120.0, 105.0, 125.0)
	assert_between(Stride.rate(5.0) * 120.0, 120.0, 140.0)
	assert_between(Stride.rate(7.2) * 120.0, 150.0, 175.0)


func test_blend_covers_the_ground() -> void:
	# The stride the blend gives, times the cadence, is the ground speed.
	for strides: Array in [Stride.MESHY, Stride.ARMORED]:
		for v: float in [1.8, 3.0, 5.0, 7.2]:
			var b := Stride.blend(v, strides)
			var i := mini(int(b), strides.size() - 2)
			var stride := lerpf(strides[i], strides[i + 1], b - i)
			assert_almost_eq(stride * Stride.rate(v), v, 0.01, "at %.1f m/s" % v)


func test_blend_tiers() -> void:
	# The touch gaits: WALK mostly the walk clip, JOG near the jog, RUN past it.
	assert_lt(Stride.blend(1.8, Stride.MESHY), 0.35)
	assert_between(Stride.blend(5.0, Stride.MESHY), 0.8, 1.05)
	assert_gt(Stride.blend(7.2, Stride.MESHY), 1.3)
	# A bigger body takes longer strides: less blend for the same speed.
	assert_lt(Stride.blend(5.0, Stride.MESHY, 1.2), Stride.blend(5.0, Stride.MESHY))


func test_contacts_once_per_boot_per_cycle() -> void:
	assert_eq(Stride.contacts_between(0.0, 1.0), [0, 1] as Array[int])
	assert_eq(Stride.contacts_between(0.5, 1.2), [1, 0] as Array[int])
	assert_eq(Stride.contacts_between(0.1, 0.5), [] as Array[int])
	assert_eq(Stride.contacts_between(0.0, 3.0).size(), 6)
	var n := 0
	var p := 0.0
	for i in 600:
		n += Stride.contacts_between(p, p + 0.013).size()
		p += 0.013
	assert_eq(n, 16)  # 7.8 cycles: 7 whole ones and both contacts of the last
