shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_add;
// A sharp half-moon (crescent) blade of silver-white energy. The quad's +X is the direction of
// travel; the crescent's points trail behind and its belly leads, so it is thrown point-first.
// `stretch` lengthens the blade along its flight, `flicker` is a fast brightness shimmer.

uniform vec3 tint : source_color = vec3(0.86, 0.92, 1.0);
uniform float brightness = 1.0;
uniform float flicker = 0.0;
uniform float time_offset = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	// Outer disc and an offset inner disc: what is left is a crescent with sharp tips.
	float outer_d = length(p) - 0.95;
	float inner_d = length(p - vec2(-0.42, 0.0)) - 0.78;
	float outer_m = 1.0 - smoothstep(-0.02, 0.0, outer_d);
	float inner_m = smoothstep(-0.02, 0.0, inner_d);
	float body = outer_m * inner_m;
	// Hot core along the belly's edge.
	float rim = smoothstep(0.35, 0.0, abs(inner_d)) * body;
	float shimmer = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 90.0 + time_offset));
	vec3 colour = mix(tint, vec3(1.0), rim);
	ALBEDO = colour * brightness * shimmer;
	ALPHA = clamp(body * (0.55 + 0.45 * rim) * brightness, 0.0, 1.0);
}
