shader_type spatial;
// Controlled comic ink outline (inverted hull), used as a next_pass on the
// materials that need one: characters, weapons and important structures.
// The shell grows with distance (capped) so the line stays about the same
// on screen without becoming a heavy black blob far away.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 ink : source_color = vec4(0.07, 0.02, 0.09, 1.0);
uniform float width = 0.012;      // metres at 1 m
uniform float max_scale = 5.0;

void vertex() {
	float d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += NORMAL * width * clamp(d * 0.35, 1.0, max_scale);
}

void fragment() {
	ALBEDO = ink.rgb;
}
