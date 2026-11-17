class_name MarsLighting
extends RefCounted
## THE HUNT's daylight on Titan (docs/game-plan.md): the Sun is far and
## small and the thick orange haze scatters what reaches the ground, so the
## light is dim, warm and soft (low shadow contrast), the sky one deep
## orange with no visible Sun disc, Saturn or stars (the haze hides them),
## and the haze closes in with distance. The comic look (ACES, the grade,
## the cel shaders) is unchanged. No SSAO, SSR or volumetrics (phones).


const HAZE := Color(0.8, 0.5, 0.22)


static func add(parent: Node) -> void:
	# A high, weak sun through the haze: soft shadows still give shapes depth.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	sun.light_energy = 1.55
	sun.light_color = Color(1.0, 0.8, 0.55)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.6  # the haze softens every shadow
	sun.directional_shadow_max_distance = 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(sun)
	# The haze: deep orange overhead to a brighter horizon.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.46, 0.27, 0.1)
	sky_mat.sky_horizon_color = Color(0.82, 0.52, 0.22)
	sky_mat.sky_curve = 0.3
	sky_mat.ground_horizon_color = Color(0.62, 0.38, 0.16)
	sky_mat.ground_bottom_color = Color(0.2, 0.12, 0.06)
	sky_mat.sun_angle_max = 0.0  # no disc: the haze hides it
	sky_mat.sun_curve = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Less sky fill: the bright orange sky flooded the shadows, which is what
	# washed the picture out. Shade is now darker and a touch cooler.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0  # the haze lights everything from all round
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_color = Color(0.6, 0.48, 0.4)
	# ACES: deeper blacks and richer colour than filmic's flat curve.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.2
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.fog_enabled = true
	env.fog_light_color = HAZE
	env.fog_density = 0.0028  # Titan's haze: the far side of the valley is a silhouette
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



## Phobos and Deimos (Mars): Titan's haze shows nothing in the sky (no
## moons, no Saturn from the ground), so nothing is added any more.
static func add_moons(_parent: Node) -> void:
	return

