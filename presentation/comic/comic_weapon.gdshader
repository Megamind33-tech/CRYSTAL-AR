shader_type spatial;
// THE HUNT's guns in the comic style (WeaponModels): the model's own texture
// read as shapes, not as photo detail. Its brightness falls into three flat
// gunmetal tones; the bigger light panels take the weapon's livery colour;
// saturated parts of the texture (energy lines, coils) glow in its accent
// colour. Lit in the comic bands (toon_light.gdshaderinc), inked by the
// outline pass.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec4 livery : source_color = vec4(0.85, 0.55, 0.2, 1.0);
uniform vec4 accent : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform vec4 metal : source_color = vec4(0.2, 0.22, 0.25, 1.0);
// How much of the light panels the livery takes (0: none).
uniform float livery_amount = 0.9;
// The brightness where the livery starts: per weapon, from its texture.
uniform float livery_cut = 0.25;
uniform float glow = 2.2;
// The model's own space (source units: muzzle at -0.95 along x, top +y):
// below `under` (the handle's height) is grip, magazine, trigger: bare
// metal; in front of `barrel` (x) too.
uniform float under = -0.12;
uniform float barrel = -0.7;
// Above `over` (scopes, sights, top rails): bare metal too.
uniform float over = 0.24;
varying vec3 obj;

void vertex() {
	obj = VERTEX;
}

void fragment() {
	// Shapes from a blurred read (big flat areas, no photo grain); the
	// sharp read only for the energy lines.
	vec3 t = texture(albedo_tex, UV).rgb;
	vec3 tb = textureLod(albedo_tex, UV, 6.0).rgb;
	float l = dot(tb, vec3(0.299, 0.587, 0.114));
	float sat = max(max(t.r, t.g), t.b) - min(min(t.r, t.g), t.b);
	float lt = dot(t, vec3(0.299, 0.587, 0.114));
	// Three flat steel tones from the texture's brightness (crisp steps).
	float tone = 0.6 + 0.4 * smoothstep(livery_cut * 0.6 - 0.02, livery_cut * 0.6 + 0.02, l) + 0.35 * smoothstep(livery_cut * 1.5 - 0.02, livery_cut * 1.5 + 0.02, l);
	vec3 c = metal.rgb * tone;
	// The livery on the lighter panels.
	float body = step(under, obj.y) * step(barrel, obj.x) * step(obj.y, over);
	c = mix(c, livery.rgb * (0.82 + 0.18 * tone), livery_amount * body * smoothstep(livery_cut - 0.015, livery_cut + 0.015, l));
	// A little of the surface's own detail back (worn edges, plates).
	c *= mix(0.85, 1.12, smoothstep(0.1, 0.5, lt));
	// Panel lines: the sharp read's dark seams, inked.
	c *= mix(0.55, 1.0, smoothstep(0.05, 0.11, lt));
	// Energy parts: the texture's coloured bits glow in the accent.
	float energy = smoothstep(0.2, 0.32, sat) * smoothstep(0.18, 0.32, lt);
	c = mix(c, accent.rgb, energy);
	ALBEDO = c;
	EMISSION = accent.rgb * energy * glow;
	ROUGHNESS = 0.6;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.6;
	}
}

#include "res://presentation/comic/toon_light.gdshaderinc"
