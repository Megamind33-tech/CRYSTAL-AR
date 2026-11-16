shader_type spatial;
// A graphic comic burst (muzzle flash, impact, explosion): a spiky star in
// a bold colour with a white-hot core and an ink rim, facing the camera.
// Procedural (no texture), unshaded, alpha-blended so the ink reads.
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform vec4 ink : source_color = vec4(0.07, 0.02, 0.09, 1.0);
uniform float spikes = 9.0;
uniform float sharp = 0.45;   // spike depth (0 = a disc)
uniform float rot = 0.0;
instance uniform float fade = 1.0;

void vertex() {
	// Billboard, keeping the node's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x) + rot;
	float wave = pow(abs(cos(a * spikes * 0.5)), 3.0);
	float edge = mix(1.0 - sharp, 1.0, wave);
	float d = length(p) / edge;
	if (d > 1.0) {
		discard;
	}
	vec3 c = color.rgb;
	c = mix(c, vec3(1.0, 0.98, 0.9), smoothstep(0.5, 0.3, d));   // hot core
	c = mix(c, ink.rgb, step(0.84, d));                          // ink rim
	ALBEDO = c;
	ALPHA = fade;
}
