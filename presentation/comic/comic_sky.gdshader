shader_type sky;
// THE HUNT's Titan sky in comic bands: flat colour stripes with hard edges
// instead of a smooth gradient (a few cheap ops per pixel, no texture). The
// haze reads as three inked bands over the horizon; the ground is two. Set
// from DustStorms by day, dusk and night (night shifts the bands together).
uniform vec4 top_color : source_color = vec4(0.4, 0.31, 0.17, 1.0);
uniform vec4 mid_color : source_color = vec4(0.62, 0.5, 0.3, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.8, 0.7, 0.5, 1.0);
uniform vec4 ground_color : source_color = vec4(0.58, 0.48, 0.32, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.16, 0.13, 0.09, 1.0);
uniform float mid_edge = 0.22;     // sky height where the mid band ends
uniform float top_edge = 0.55;     // sky height where the top band starts
uniform float ground_edge = -0.12; // below this, the dark ground band

void sky() {
	float y = EYEDIR.y;
	if (y >= 0.0) {
		if (y < mid_edge) {
			COLOR = horizon_color.rgb;
		} else if (y < top_edge) {
			COLOR = mid_color.rgb;
		} else {
			COLOR = top_color.rgb;
		}
	} else if (y > ground_edge) {
		COLOR = ground_color.rgb;
	} else {
		COLOR = ground_bottom_color.rgb;
	}
}
