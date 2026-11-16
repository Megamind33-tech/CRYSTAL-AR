shader_type spatial;
// Mars colonists (CivilianRig): the base human body in a work jumpsuit.
// COLOR.r holds each vertex's rest-pose height (0..1 of 1.81 m, baked at
// load), so the suit, belt, collar and boots stay on the body in any pose;
// above the collar, the skin and hair textures. Comic light bands.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D skin_tex : source_color, filter_linear_mipmap;
uniform vec3 suit : source_color = vec3(0.85, 0.45, 0.15);
uniform vec3 trim : source_color = vec3(0.12, 0.1, 0.12);   // belt and collar
uniform vec3 boots : source_color = vec3(0.16, 0.13, 0.16);
uniform vec3 stripe : source_color = vec3(0.9, 0.9, 0.9);   // chest band
uniform float collar = 0.866;  // fraction of height where the suit ends (a high collar)
uniform vec3 gloves : source_color = vec3(0.1, 0.09, 0.1);

// A work suit that reads as clothes, not paint: gloves, a high collar, a
// zip, chest pockets, a yoke over the shoulders, knee pads, reflective
// bands. COLOR.g: distance out along the arms; COLOR.b: front (>0.5) / back.
void fragment() {
	float h = COLOR.r;
	float side = COLOR.g;
	float front = COLOR.b - 0.5;
	vec3 c = suit;
	c = mix(c, suit * 0.78, step(0.79, h) * step(side, 0.2));                // shoulder yoke
	c = mix(c, trim, step(abs(h - 0.53), 0.02));                            // belt
	c = mix(c, boots, step(h, 0.075));                                      // boots
	c = mix(c, stripe, step(abs(h - 0.74), 0.009));                         // chest band
	c = mix(c, stripe, step(abs(h - 0.165), 0.009));                        // shin band
	c = mix(c, stripe, step(abs(side - 0.235), 0.007) * step(0.7, h));      // arm bands
	c = mix(c, trim, step(abs(h - 0.285), 0.03) * step(0.0, front));        // knee pads
	c = mix(c, trim, step(side, 0.004) * step(0.02, front) * step(0.54, h) * step(h, 0.86)); // zip
	float pocket = step(abs(h - 0.705), 0.03) * step(0.03, side) * step(side, 0.075) * step(0.035, front);
	c = mix(c, suit * 0.62, pocket);                                        // chest pockets
	c = mix(c, trim, step(abs(h - collar + 0.008), 0.008));                 // collar band
	c = mix(c, gloves, step(0.36, side) * step(0.6, h));                    // gloves
	vec3 skin = texture(skin_tex, UV).rgb;
	ALBEDO = mix(c, skin, step(collar, h));
	ROUGHNESS = 1.0;
}

#include "res://presentation/comic/toon_light.gdshaderinc"
