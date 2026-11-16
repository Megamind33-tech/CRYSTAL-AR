shader_type spatial;
// Kasei Valley's ground: the Blender terrain's vertex colours (dust, rock
// strata, ice, roads) with a triplanar sand and rock detail, under the comic
// light bands with halftone in the shade.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail = 0.7;
varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy).rgb * w.x + texture(t, p.xz).rgb * w.y + texture(t, p.xy).rgb * w.z;
}

void fragment() {
	vec3 w = pow(abs(world_nrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float steep = smoothstep(0.85, 0.6, world_nrm.y);
	vec3 sand = tri(sand_tex, world_pos * 0.12, w);
	vec3 rock = tri(rock_tex, world_pos * 0.06, w);
	float d = dot(mix(sand, rock, steep), vec3(0.333));
	// glTF vertex colours arrive linear (Blender converts its sRGB bytes).
	ALBEDO = COLOR.rgb * mix(1.0, clamp(d * 2.0, 0.5, 1.3), detail);
	ROUGHNESS = 1.0;
}

#define TOON_HALFTONE
#include "res://presentation/comic/toon_light.gdshaderinc"
