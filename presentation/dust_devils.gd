class_name DustDevils
extends Node3D
## Mars' wind, as you see it: the air is thin (a gust barely pushes you) but
## it moves dust. Dust devils (whirling columns 20-40 m tall) wander the
## open ground by day, drifting with the wind, and fine grit streams past
## you (thicker in a storm). Presentation only; a child of the world.

const DEVILS := 3
const NEAR := 90.0
const FAR := 260.0

var wind := Vector3(1, 0, 0.3).normalized()  ## where the wind blows to (turns slowly)
var _devils: Array = []   ## [particles, velocity, seconds left]
var _streaks: GPUParticles3D
var _t: float = 0.0


func _ready() -> void:
	for i in DEVILS:
		var p := _devil()
		add_child(p)
		_devils.append([p, Vector3.ZERO, 0.0])
	_streaks = _make_streaks()
	add_child(_streaks)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	wind = Vector3(cos(_t * 0.01), 0, sin(_t * 0.01)).normalized()
	var daylight := 1.0
	var weather := get_parent().get_node_or_null("Weather") as DustStorms
	if weather != null:
		daylight = weather.daylight
	var under_dome := Vector2(at.x - CityLayout.ORIGIN.x, at.z - CityLayout.ORIGIN.z).length() < WorldLayout.DOME_RADIUS
	for d: Array in _devils:
		var p: GPUParticles3D = d[0]
		d[2] = float(d[2]) - delta
		var far := p.global_position.distance_to(at) > FAR * 1.4
		if float(d[2]) <= 0.0 or far:
			# A new one somewhere out on the dust ahead or around you.
			var a := randf() * TAU
			var r := randf_range(NEAR, FAR)
			var x := at.x + cos(a) * r
			var z := at.z + sin(a) * r
			p.global_position = WorldTerrain.at(x, z)
			d[1] = wind * randf_range(3.0, 7.0) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			d[2] = randf_range(30.0, 80.0)
			p.restart()
		var pos := p.global_position + (d[1] as Vector3) * delta
		p.global_position = Vector3(pos.x, WorldTerrain.surface(pos.x, pos.z), pos.z)
		# Only on open dust, by day (not on the plazas or in the dome).
		var region := WorldLayout.region_at(pos.x, pos.z)
		p.emitting = daylight > 0.4 and region in ["open", "dig", "hollow"] and float(d[2]) > 2.0
	_streaks.global_position = at + wind * -6.0
	var storm := DustStorms.storm
	_streaks.emitting = not under_dome
	_streaks.amount_ratio = clampf(0.25 + storm * 0.75, 0.0, 1.0)
	var pm := _streaks.process_material as ParticleProcessMaterial
	pm.direction = wind
	pm.initial_velocity_min = 6.0 + storm * 14.0
	pm.initial_velocity_max = 10.0 + storm * 20.0


## A dust devil: grit spiralling up a narrow funnel that widens with height.
func _devil() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.5
	pm.emission_ring_inner_radius = 0.5
	pm.emission_ring_height = 0.5
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 8.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3.ZERO
	pm.tangential_accel_min = 18.0
	pm.tangential_accel_max = 26.0
	pm.radial_accel_min = 0.6
	pm.radial_accel_max = 1.4
	pm.scale_min = 1.0
	pm.scale_max = 2.6
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.48, 0.3, 0.0))
	ramp.add_point(0.15, Color(0.78, 0.48, 0.3, 0.5))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 0.55, 0.38, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	p.draw_pass_1 = _puff(1.6)
	p.amount = 90
	p.lifetime = 4.0
	p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 50, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Grit on the wind: thin streaks streaming past you.
func _make_streaks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 4, 14)
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 6.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -0.3, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.65, 0.45, 0.0))
	ramp.add_point(0.3, Color(0.9, 0.65, 0.45, 0.35))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.9, 0.65, 0.45, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.025)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.billboard_keep_scale = true
	q.material = qm
	p.draw_pass_1 = q
	pm.particle_flag_align_y = false
	p.amount = 160
	p.lifetime = 2.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _puff(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	qm.albedo_texture = t
	q.material = qm
	return q
