shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// The air around the target collapsing inward: a very faint, thin, translucent ring that starts wide
// and shrinks to the centre, arriving exactly as the pressure wave hits (the moment `t` reaches 1).
// It is the air caving in, not a ripple spreading out, so it gets brighter as it tightens. The ring
// is soft and broken by a slow shimmer, never a clean target-line. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float start_scale = 1.0;          // starting radius (share of the quad)
uniform float end_scale = 0.03;           // radius when the wave lands
uniform float ring_alpha = 0.5;
uniform float seed = 0.0;
uniform vec4 tone : source_color = vec4(0.88, 0.93, 1.0, 1.0);

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
	// Accelerating collapse: slow at first, rushing in at the end.
	float radius = mix(start_scale, end_scale, pow(t, 2.2));
	float width = mix(0.09, 0.03, t);
	float ring = exp(-pow((r - radius) / width, 2.0));
	// Soft shimmer breaks the ring up a little.
	float shimmer = smoothstep(0.25, 0.7, noise(vec2(ang * 4.0 + seed, t * 5.0))) * (0.6 + 0.4 * noise(vec2(ang * 17.0 + seed, 2.0)));
	float build = smoothstep(0.0, 0.25, t);
	float vanish = 1.0 - smoothstep(0.92, 1.0, t);
	float value = ring * shimmer * build * vanish * mix(0.45, 1.0, t);
	ALBEDO = tone.rgb;
	ALPHA = value * ring_alpha * 0.8;
	EMISSION = tone.rgb * value * ring_alpha * 1.3;
}
