shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// What the collapsing air does once it has been gathered to a point: it bursts back out as a ragged
// halo. Used twice: bright and fast (the halo of sound-light) and dark and slow (the ring-shaped
// shadow trace creeping outward). Torn into arcs with a streaky edge, never a clean outline.
// `t` runs 0..1. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float reach = 0.9;                // radius the ring ends at (share of the quad)
uniform float ease_power = 2.4;           // higher = bursts out fast then crawls
uniform float width_start = 0.07;
uniform float width_end = 0.14;
uniform float ring_alpha = 0.7;
uniform float emission_strength = 1.8;
uniform float raggedness = 0.6;
uniform float seed = 0.0;
uniform vec4 tone : source_color = vec4(0.93, 0.96, 1.0, 1.0);

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
	float radius = reach * (1.0 - pow(1.0 - t, ease_power));
	// Torn edge: the radius wobbles with the angle.
	float wobble = (noise(vec2(ang * 5.0 + seed, t * 3.0)) - 0.5) * 0.12 * raggedness
		+ (noise(vec2(ang * 19.0 + seed * 2.0, 1.0)) - 0.5) * 0.04 * raggedness;
	float width = mix(width_start, width_end, t);
	float d = r - radius - wobble;
	// Sharp on the outside, trailing softly inward: a halo thrown outward.
	float edge = d > 0.0 ? exp(-pow(d / (width * 0.45), 2.0)) : exp(-pow(d / width, 2.0));
	// Strands running radially and breaks along the circle.
	float strands = mix(1.0, smoothstep(0.25, 0.75, noise(vec2(ang * 14.0 + seed, 3.0))), raggedness);
	float gaps = mix(1.0, smoothstep(0.2, 0.55, noise(vec2(ang * 3.0 + seed * 1.3, 8.0))), raggedness * 0.9);
	float fade = (1.0 - smoothstep(0.35, 1.0, t)) * smoothstep(0.0, 0.04, t);
	float value = edge * strands * gaps * fade;
	ALBEDO = tone.rgb;
	ALPHA = value * ring_alpha;
	EMISSION = tone.rgb * value * ring_alpha * emission_strength;
}
