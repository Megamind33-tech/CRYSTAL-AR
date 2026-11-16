// THE HUNT's comic lighting, shared by the cel materials: light falls in
// three bold bands (lit, mid, shade) with crisp edges; a printed halftone
// dot screen appears only inside the mid/shade transition (per pixel, in the
// material: no full-screen pass); a small hard highlight. Shadows (in
// ATTENUATION) land in the bands too. Include it after the uniforms; define
// TOON_HALFTONE before including to keep the dots (structures, ground).

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	if (!LIGHT_IS_DIRECTIONAL) {
		// Small lights (flashes, beacons) stay soft: hard bands made blobs.
		DIFFUSE_LIGHT += LIGHT_COLOR * ndl * 0.8 / PI;
	} else {
		// Bands: 0.32 in the shade, 0.7 mid, 1.0 lit (crisp, slightly soft edges).
		float band = 0.32 + 0.38 * smoothstep(0.08, 0.13, ndl) + 0.3 * smoothstep(0.46, 0.51, ndl);
#ifdef TOON_HALFTONE
		// Dots in the transition zone only (shade side of the mid band).
		float tone = smoothstep(0.42, 0.06, ndl) * step(0.02, ndl);
		float a = 0.3927;
		vec2 cell = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * (FRAGCOORD.xy / 6.0);
		float r = sqrt(tone) * 0.55;
		float dots = 1.0 - smoothstep(r - 0.07, r + 0.07, length(fract(cell) - 0.5));
		band -= dots * 0.22;
#endif
		DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
		// A hard comic highlight.
		vec3 h = normalize(LIGHT + VIEW);
		float spec = smoothstep(0.965, 0.975, dot(NORMAL, h)) * ATTENUATION;
		SPECULAR_LIGHT += LIGHT_COLOR * spec * 0.12 / PI;
	}
}
