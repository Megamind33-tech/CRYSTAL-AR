class_name MarsLighting
extends RefCounted
## THE HUNT's Mars daylight, shared by Rustwood Yard and Tharsis Gate: one
## low strong sun (two shadow splits), the deep rust sky, sky fill, ACES and
## a light grade, thin dust fog. No SSAO, SSR or volumetrics (phones).


static func add(parent: Node) -> void:
	# A low, strong sun: long hard shadows give the yard shape and depth.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34.0, -30.0, 0.0)
	sun.light_energy = 2.3
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.92
	sun.directional_shadow_max_distance = 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(sun)
	# A deeper sky: dark rust overhead to a bright dusty horizon.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.17, 0.12)
	sky_mat.sky_horizon_color = Color(0.8, 0.5, 0.32)
	sky_mat.sky_curve = 0.18
	sky_mat.ground_horizon_color = Color(0.55, 0.33, 0.21)
	sky_mat.ground_bottom_color = Color(0.16, 0.09, 0.06)
	sky_mat.sun_angle_max = 6.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Less sky fill: the bright orange sky flooded the shadows, which is what
	# washed the picture out. Shade is now darker and a touch cooler.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.5, 0.48, 0.52)
	# ACES: deeper blacks and richer colour than filmic's flat curve.
	# ACES: deeper blacks and richer colour than filmic's flat curve.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.2
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	# Thinner dust: distant sheds keep their shape instead of melting into haze.
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.5, 0.33)
	env.fog_density = 0.0009  # thin: a clear day on Mars still shows the far wall
	env.fog_aerial_perspective = 0.15
	env.fog_sky_affect = 0.4
	# A light grade: contrast and saturation (cheap; part of tonemapping).
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.15
	env.adjustment_brightness = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)



## Phobos and Deimos in the sky: lumpy grey rocks far off, lit by the sun.
static func add_moons(parent: Node) -> void:
	for m: Array in [[Vector3(-0.55, 0.42, -0.72), 26.0, Color(0.55, 0.5, 0.47)], [Vector3(0.7, 0.62, -0.35), 9.0, Color(0.7, 0.64, 0.58)]]:
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = m[1]
		sph.height = float(m[1]) * 1.6  # not a ball: a potato
		sph.radial_segments = 12
		sph.rings = 6
		mi.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = m[2]
		mat.roughness = 1.0
		mat.disable_fog = true
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = (m[0] as Vector3).normalized() * 1400.0
		mi.rotation = Vector3(0.4, 0.9, 0.2)
		parent.add_child(mi)
