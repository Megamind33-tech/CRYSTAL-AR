shader_type spatial;
// Cel material for the Blender outpost kit (Comic.kit_mesh): flat colours
// from the vertex colours (each piece's Blender materials), comic light
// bands with halftone in the shade, a touch of panel grain from world
// position so big faces aren't flat plastic.
render_mode diffuse_lambert, specular_disabled;

uniform float saturation = 1.15;
// Weathering: a worn-concrete map, desaturated, multiplied in world space
// (triplanar) so the flat colours read as real painted metal and dust.
uniform sampler2D grime_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float grime = 0.85;
uniform float grime_scale = 0.22;
varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	// Panel seams every metre, faint (reads as plating at a distance).
	vec3 g = abs(fract(world_pos) - 0.5);
	float seam = smoothstep(0.47, 0.5, max(g.x, g.z)) * 0.08;
	vec3 w = pow(abs(world_nrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = world_pos * grime_scale;
	vec3 g3 = texture(grime_tex, p.zy).rgb * w.x + texture(grime_tex, p.xz).rgb * w.y + texture(grime_tex, p.xy).rgb * w.z;
	float dirt = dot(g3, vec3(0.333));
	// Darker towards the ground (dust and wear), lighter up high.
	float low = 1.0 - smoothstep(0.0, 2.5, world_pos.y) * 0.25;
	ALBEDO = c * (1.0 - seam) * mix(1.0, clamp(dirt * 1.9 - 0.15, 0.35, 1.1), grime) * mix(1.0, 0.82, 1.0 - low);
	ROUGHNESS = 1.0;
}

#define TOON_HALFTONE
#include "res://presentation/comic/toon_light.gdshaderinc"
