shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// The air a spear pushes ahead of itself: a very transparent, long, narrow cone, tightest at the
// spear's tip and opening out toward the wielder, drawn as faint converging streaks of cold white and
// pale grey that seem to bend the air (a mirage in the dry sense, not a glow). UV.x runs from the
// wide, faint tail (0) to the tip (1); `t` (0..1) is its life. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float strength = 1.0;
uniform vec4 cold_tone : source_color = vec4(0.88, 0.93, 1.0, 1.0);
uniform vec4 grey_tone : source_color = vec4(0.45, 0.47, 0.52, 1.0);

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
	float y = (UV.y - 0.5) * 2.0;
	// Half-width of the cone: wide at the tail, a needle at the tip.
	float half_width = mix(0.95, 0.04, pow(x, 1.25));
	float across = y / max(half_width, 0.001);
	float inside = 1.0 - smoothstep(0.78, 1.0, abs(across));
	// Streaks converge on the tip and slide toward it as the spear goes.
	float streak = noise(vec2(across * 5.0 + seed, x * 7.0 - t * 9.0)) * 0.6 + noise(vec2(across * 13.0 - seed, x * 18.0 - t * 14.0)) * 0.4;
	float lines = smoothstep(0.42, 0.78, streak);
	// The cone's edge is a thin bright line; its middle is almost clear.
	float rim = exp(-pow((abs(across) - 0.82) / 0.10, 2.0));
	float tail_fade = smoothstep(0.0, 0.35, x);
	float life = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.55, 1.0, t));
	float value = (lines * 0.38 + rim * 0.34) * inside * tail_fade * life * strength;
	vec3 colour = mix(grey_tone.rgb, cold_tone.rgb, clamp(rim + lines * 0.5 + x * 0.4, 0.0, 1.0));
	ALBEDO = colour;
	ALPHA = clamp(value, 0.0, 0.85);
	EMISSION = cold_tone.rgb * (rim * 0.5 + x * x * 0.3) * inside * tail_fade * life * strength;
}
