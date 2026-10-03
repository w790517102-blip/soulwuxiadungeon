shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add;
// Green breath poured upward into a card: soft vertical streams of light that climb from the feet to
// the head, strongest at the bottom and thinning out above, with a glow pooling at the card's base.
// The streams are made of drifting strands, never a solid pillar. `t` (0..1) is the life of the
// effect. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;
uniform vec4 tone : source_color = vec4(0.30, 0.95, 0.42, 1.0);
uniform vec4 core_tone : source_color = vec4(0.88, 1.0, 0.82, 1.0);
uniform vec4 accent_tone : source_color = vec4(0.30, 0.95, 0.42, 1.0);   // a second colour the strands drift toward
uniform float down = 0.0;               // 1: the streams fall from the head instead of rising from the feet
uniform float scroll_speed = 1.0;

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
	float h = mix(1.0 - UV.y, UV.y, down);   // 0 at the start of the flow, 1 at its end
	float envelope = smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.62, 1.0, t));
	// Strands scrolling upward; a second, finer layer moves faster.
	float scroll = t * 3.2 * scroll_speed;
	float coarse = noise(vec2(x * 7.0 + seed, h * 2.2 - scroll));
	float fine = noise(vec2(x * 19.0 - seed, h * 4.5 - scroll * 1.6));
	float strands = smoothstep(0.42, 0.82, coarse * 0.65 + fine * 0.35);
	// Where the stream is: wide at the base, drawing in toward the middle as it climbs.
	float centre_pull = mix(0.5, 0.36, smoothstep(0.1, 1.0, h));
	float lane = 1.0 - smoothstep(centre_pull * 0.6, centre_pull, abs(x - 0.5));
	float height_fade = (1.0 - smoothstep(0.50, 1.0, h)) * smoothstep(0.0, 0.06, h);
	// A bright front travelling up the card at the start, so it reads as being poured in.
	float front_h = clamp(t * 2.2, 0.0, 1.2);
	float front = exp(-pow((h - front_h) / 0.10, 2.0)) * (1.0 - smoothstep(0.35, 0.6, t)) * lane * 0.8;
	float stream = strands * lane * height_fade;
	float soft = lane * height_fade * 0.22;
	// Glow pooled at the feet.
	float pool = exp(-pow((h - 0.035) / 0.05, 2.0)) * (1.0 - smoothstep(0.30, 0.5, abs(x - 0.5))) * 0.9;
	float value = (stream + soft + front + pool) * envelope;
	vec3 base_colour = mix(tone.rgb, accent_tone.rgb, smoothstep(0.35, 0.7, noise(vec2(x * 3.0 + seed * 2.0, h * 1.5 - scroll * 0.3))));
	vec3 colour = mix(base_colour, core_tone.rgb, clamp(stream * 0.7 + front + pool * 0.5, 0.0, 1.0));
	ALBEDO = colour * value * intensity;
	EMISSION = colour * value * intensity * 1.4;
}
