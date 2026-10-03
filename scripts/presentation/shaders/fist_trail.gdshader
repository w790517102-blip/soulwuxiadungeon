shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// The trail a punch leaves: streaks of cold white and black ink dragged along the path behind the
// fist (uv.x = 0 at the tail, 1 at the fist; uv.y across). All the strands run the same way yet are
// irregular. `fade` takes the white away quickly and the ink slowly. Presentation only.

uniform float fade_white : hint_range(0.0, 1.0) = 0.0;
uniform float fade_ink : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform vec4 ink : source_color = vec4(0.015, 0.015, 0.02, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float x = UV.x;
	float across = (UV.y - 0.5) * 2.0;
	// Taper to a point at the tail, full at the fist.
	float width = pow(x, 0.7);
	// Strands: lanes that run the length of the trail, each at its own length and brightness.
	float lane = floor((across * 0.5 + 0.5) * 9.0);
	float lane_len = 0.35 + 0.65 * hash(vec2(lane, seed));
	float strand_edge = abs(fract((across * 0.5 + 0.5) * 9.0) - 0.5) * 2.0;
	float strand = (1.0 - smoothstep(0.35, 0.85, strand_edge)) * smoothstep(1.0 - lane_len, 1.0, x);
	float wander = (noise(vec2(x * 8.0 + seed, lane)) - 0.5) * 0.25;
	float band = 1.0 - smoothstep(width * 0.9, width, abs(across + wander));
	float flicker = 0.6 + 0.4 * noise(vec2(x * 30.0, lane * 3.0 + seed));
	float white = strand * band * flicker * (1.0 - fade_white);
	// The ink is a wider, darker, longer-lived smear behind the white.
	float ink_strand = smoothstep(0.25, 0.8, noise(vec2(x * 10.0 + seed, across * 6.0)));
	float ink_alpha = band * ink_strand * smoothstep(0.0, 0.5, x) * (1.0 - fade_ink) * 0.9;
	float a_white = white;
	float alpha = a_white + ink_alpha * (1.0 - a_white);
	vec3 colour = (vec3(1.0) * a_white + ink.rgb * ink_alpha * (1.0 - a_white)) / max(alpha, 0.001);
	ALBEDO = colour;
	ALPHA = alpha;
	EMISSION = vec3(1.0) * a_white * 0.5;
}
