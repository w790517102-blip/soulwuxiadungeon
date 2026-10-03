shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add;
// Resonance rings on the struck card: one or two incomplete rings of clean cold-white light, drawn
// as thin arcs with a faint inner echo, spreading from the contact and settling. Not water ripples:
// the rings break into arcs of different lengths and shiver slightly as they spread. `t` runs 0..1;
// `rings` (1 or 2) is how many. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float rings = 2.0;
uniform float intensity = 2.2;
uniform vec4 colour : source_color = vec4(0.90, 0.95, 1.0, 1.0);

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

float ring_value(vec2 p, float radius, float line, float ring_seed) {
	float r = length(p);
	float ang = atan(p.y, p.x);
	// A slight shiver of the radius, as if the string were still ringing.
	float shiver = (noise(vec2(ang * 5.0 + ring_seed, t * 14.0)) - 0.5) * 0.014;
	float d = abs(r - radius - shiver);
	float core = exp(-pow(d / line, 2.0));
	// Broken into arcs: gaps of different lengths.
	float gap = noise(vec2(ang * 2.4 + ring_seed * 3.0, ring_seed));
	float present = smoothstep(0.34, 0.5, gap);
	float echo = exp(-pow((r - radius * 0.86) / (line * 2.4), 2.0)) * 0.28;
	return (core + echo) * present;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float life = 1.0 - smoothstep(0.55, 1.0, t);
	float first_radius = 0.18 + 0.72 * (1.0 - pow(1.0 - t, 2.2));
	float value = ring_value(p, first_radius, mix(0.020, 0.010, t), seed) * life;
	if (rings > 1.5) {
		float second_t = clamp((t - 0.16) / 0.84, 0.0, 1.0);
		float second_radius = 0.14 + 0.66 * (1.0 - pow(1.0 - second_t, 2.2));
		float second_life = smoothstep(0.16, 0.26, t) * (1.0 - smoothstep(0.62, 1.0, t));
		value += ring_value(p, second_radius, mix(0.016, 0.008, second_t), seed + 4.0) * second_life * 0.75;
	}
	ALBEDO = colour.rgb * value;
	EMISSION = colour.rgb * value * intensity;
}
