shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// The shock ring of a punch: not a perfect circle but a broken ring of ink, thrown outward from the
// contact point as if the paper under the ink had been struck. A black ink band with torn edges and
// gaps, a thin silver-white line on its inner edge. `t` runs 0..1 over the ring's life.
// Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float gaps = 0.45;                // how much of the ring is missing (0 = whole ring)
uniform vec4 ink : source_color = vec4(0.015, 0.015, 0.02, 1.0);
uniform vec4 silver : source_color = vec4(0.88, 0.94, 0.98, 1.0);

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
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// The ring races outward and slows (the force is spent), thinning as it goes.
	float radius = mix(0.12, 0.92, 1.0 - pow(1.0 - t, 2.6));
	float thickness = mix(0.14, 0.03, t);
	// Wobble the radius so it is not a clean circle.
	float wobble = (noise(vec2(ang * 3.0 + seed, t * 2.0)) - 0.5) * 0.14 + (noise(vec2(ang * 9.0, seed)) - 0.5) * 0.05;
	float d = abs(r - radius - wobble);
	// Gaps: the ring breaks into arcs of different lengths and strengths.
	float arc = noise(vec2(ang * 2.2 + seed * 3.0, 0.5)) + 0.5 * noise(vec2(ang * 6.0, seed));
	float present = smoothstep(gaps, gaps + 0.18, arc / 1.5 + 0.12);
	float band = (1.0 - smoothstep(thickness * 0.55, thickness, d)) * present;
	// Torn, inky edge: the band is eaten by noise along its outer side.
	float tear = noise(vec2(ang * 14.0 + seed, r * 12.0));
	band *= smoothstep(0.18, 0.5, tear + (1.0 - t) * 0.35);
	// A thin silver line on the inside of the band.
	float inner_line = (1.0 - smoothstep(0.0, 0.012, abs(r - (radius + wobble - thickness * 0.45)))) * present;
	float life = 1.0 - smoothstep(0.55, 1.0, t);
	float a_ink = band * life * 0.92;
	float a_silver = inner_line * life * (1.0 - t * 0.4);
	float alpha = a_silver + a_ink * (1.0 - a_silver);
	vec3 colour = (silver.rgb * a_silver + ink.rgb * a_ink * (1.0 - a_silver)) / max(alpha, 0.001);
	ALBEDO = colour;
	ALPHA = alpha;
	EMISSION = silver.rgb * a_silver * 1.2;
}
