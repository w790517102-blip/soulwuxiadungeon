shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// Black-and-violet smoke sinking down a card from its head: a heavy, billowing curtain that spreads
// as it falls, thick at the top and fraying into wisps toward its lower edge, with a dim violet rim
// where it thins out. `t` (0..1) is the life of the effect. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float density = 0.8;
uniform vec4 smoke_tone : source_color = vec4(0.03, 0.01, 0.05, 1.0);
uniform vec4 rim_tone : source_color = vec4(0.42, 0.14, 0.62, 1.0);

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

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amp;
		p = p * 2.03 + 11.7;
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	float x = UV.x;
	float d = UV.y;                             // 0 at the head, 1 at the feet
	float envelope = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.66, 1.0, t));
	// The smoke front sinks over time; nothing exists below it yet.
	float front = t * 1.5;
	float reached = 1.0 - smoothstep(front - 0.18, front, d);
	// Billowing body that drifts downward and spreads wider as it falls.
	float billow = fbm(vec2(x * 3.2 + seed, d * 2.6 - t * 1.9));
	float half_width = mix(0.24, 0.52, smoothstep(0.0, 0.9, d));
	float lane = 1.0 - smoothstep(half_width * 0.55, half_width, abs(x - 0.5) + (billow - 0.5) * 0.18);
	float thick = billow + (0.55 - d) * 0.55;       // thicker near the head
	float body = smoothstep(0.34, 0.72, thick) * lane * reached * (1.0 - smoothstep(0.78, 1.0, d));
	// Wisps hanging below the body.
	float wisp = smoothstep(0.5, 0.85, fbm(vec2(x * 9.0 - seed, d * 6.0 - t * 3.0))) * lane * reached * 0.45;
	float value = clamp(body + wisp * smoothstep(0.2, 0.7, d), 0.0, 1.0) * envelope * density;
	float rim = clamp(1.0 - body * 1.3, 0.0, 1.0);
	vec3 colour = mix(smoke_tone.rgb, rim_tone.rgb, rim * 0.8);
	ALBEDO = colour;
	ALPHA = value;
	EMISSION = rim_tone.rgb * rim * value * 0.5;
}
