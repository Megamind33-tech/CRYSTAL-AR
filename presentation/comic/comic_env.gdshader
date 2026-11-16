shader_type spatial;
// Cel-shaded environment material (THE HUNT): the Mars PBR albedo, world
// triplanar, under the comic bands (toon_light.gdshaderinc) with halftone
// in the shade. No normal map: flat faces keep the bands bold and graphic
// (and it is cheaper on phones).
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float uv_scale = 0.25;
uniform float saturation = 1.2;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(world_nrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = world_pos * uv_scale;
	vec3 c = texture(albedo_tex, p.zy).rgb * w.x + texture(albedo_tex, p.xz).rgb * w.y + texture(albedo_tex, p.xy).rgb * w.z;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(l), c, saturation) * tint.rgb;
	ROUGHNESS = 1.0;
}

#define TOON_HALFTONE
#include "res://presentation/comic/toon_light.gdshaderinc"
