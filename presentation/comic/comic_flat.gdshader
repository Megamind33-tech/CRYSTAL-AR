shader_type spatial;
// Cel material for the Blender kits (Comic.kit_mesh): flat colours from the
// vertex colours (each piece's Blender materials), comic light bands with
// halftone in the shade, panel grain and weathering from world position.
// The vertex alpha says what a surface is (Comic.surface_tag):
//   1.0  painted panels and concrete: weathered, darker near the ground
//   0.75 bare steel/chrome: clean, with a hint of the sky in it
//   0.5  lights and neon: they glow (brighter at night)
//   0.25 glass: reflects the Mars sky (stronger at grazing angles), and at
//        night random rooms behind it are lit
render_mode diffuse_lambert, specular_disabled;

uniform float saturation = 1.15;
uniform sampler2D grime_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float grime = 0.85;
uniform float grime_scale = 0.22;
global uniform float night_glow;
varying vec3 world_pos;
varying vec3 world_nrm;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// The sky seen in a reflection (Mars day: butterscotch horizon, dusky zenith;
// night: deep violet), and the ground below the horizon.
vec3 sky(vec3 r) {
	vec3 day = mix(vec3(0.95, 0.66, 0.45), vec3(0.52, 0.4, 0.46), smoothstep(0.0, 0.7, r.y));
	vec3 night = mix(vec3(0.16, 0.1, 0.18), vec3(0.03, 0.03, 0.08), smoothstep(0.0, 0.7, r.y));
	vec3 s = mix(day, night, night_glow);
	vec3 ground = mix(vec3(0.42, 0.24, 0.16), vec3(0.08, 0.06, 0.08), night_glow);
	return mix(ground, s, smoothstep(-0.08, 0.04, r.y));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float tag = COLOR.a;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	vec3 w = pow(abs(world_nrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = world_pos * grime_scale;
	vec3 g3 = texture(grime_tex, p.zy).rgb * w.x + texture(grime_tex, p.xz).rgb * w.y + texture(grime_tex, p.xy).rgb * w.z;
	float dirt = clamp(dot(g3, vec3(0.333)) * 1.9 - 0.15, 0.35, 1.1);
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	if (tag < 0.4) {
		// Glass: tinted, mostly sky; mullion lines every 1.5 m; lit rooms at night.
		vec3 cell = floor(world_pos / vec3(3.0, 3.6, 3.0));
		vec3 g = abs(fract(world_pos / vec3(1.5, 3.6, 1.5)) - 0.5);
		float mullion = smoothstep(0.46, 0.49, max(max(g.x, g.z) * (1.0 - w.y), g.y * 0.98));
		vec3 refl = sky(r);
		vec3 base = c * 0.5;
		ALBEDO = mix(base, refl * vec3(0.75, 0.82, 0.95), 0.3 + 0.55 * fres) * (1.0 - mullion * 0.6);
		float lit = step(0.42, hash(cell)) * (1.0 - w.y);
		vec3 room = mix(vec3(1.0, 0.78, 0.5), vec3(0.6, 0.85, 1.0), step(0.8, hash(cell + 7.0)));
		EMISSION = room * lit * night_glow * 1.1 * (1.0 - mullion) + refl * 0.08 * (1.0 - night_glow);
	} else if (tag < 0.6) {
		// Lights and neon.
		ALBEDO = c;
		EMISSION = c * (0.7 + 1.6 * night_glow);
	} else if (tag < 0.9) {
		// Bare metal: brushed, a little of the sky in it.
		float brushed = 0.92 + 0.08 * hash(floor(world_pos * vec3(1.0, 24.0, 1.0)));
		ALBEDO = mix(c * brushed * mix(1.0, dirt, 0.25), sky(r), 0.18 + 0.3 * fres);
	} else {
		// Painted panels: seams every metre, weathering, darker near the ground.
		vec3 g = abs(fract(world_pos) - 0.5);
		float seam = smoothstep(0.47, 0.5, max(g.x, g.z)) * 0.08;
		float low = 1.0 - smoothstep(0.0, 2.5, world_pos.y) * 0.25;
		ALBEDO = c * (1.0 - seam) * mix(1.0, dirt, grime) * mix(1.0, 0.82, 1.0 - low);
		// Panel edges catch a little of the sky at grazing angles.
		ALBEDO += sky(r) * fres * 0.06;
	}
	ROUGHNESS = 1.0;
}

#define TOON_HALFTONE
#include "res://presentation/comic/toon_light.gdshaderinc"
