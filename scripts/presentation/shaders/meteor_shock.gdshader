shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add;
// The air a meteor tears through: a bow of compressed air just ahead of the head, the thin cone of the
// shock front spreading back from it, and a faint ring of condensation where the air snaps back. Drawn in
// the head's own frame: the head is at the origin, "behind" is -x, one unit is the bullet's length. The
// quad covers x in [-3.0, 1.0] and y in [-1.2, 1.2]. Presentation only.

uniform float strength = 1.0;
uniform float seed = 0.0;
uniform vec4 tone : source_color = vec4(0.82, 0.92, 1.0, 1.0);

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
	vec2 p = vec2(mix(-3.0, 1.0, UV.x), (UV.y - 0.5) * 2.4);
	float back = -p.x;
	// The bow wave: a parabola curving back from just ahead of the head.
	float bow_x = 0.42 - 1.5 * p.y * p.y;
	float bow = exp(-pow((p.x - bow_x) / 0.045, 2.0)) * (1.0 - smoothstep(0.45, 0.62, abs(p.y)));
	// The shock cone: two lines running back from the head, with the air between them lightly filled.
	float spread = 0.42 * max(back, 0.0) + 0.12;
	float edge = exp(-pow((abs(p.y) - spread) / 0.05, 2.0)) * step(0.0, back) * (1.0 - smoothstep(1.6, 2.9, back));
	float inside = (1.0 - smoothstep(spread * 0.6, spread, abs(p.y))) * step(0.0, back) * (1.0 - smoothstep(0.4, 2.6, back)) * 0.16;
	// The air snaps back in a ring of condensation behind the head.
	float ring_x = -1.35;
	float ring = exp(-pow((length(vec2((p.x - ring_x) * 1.9, p.y / 0.85)) - 0.42) / 0.07, 2.0)) * 0.55;
	// Everything shimmers a little.
	float flutter = 0.65 + 0.35 * noise(vec2(p.x * 7.0 + seed, p.y * 9.0 - TIME * 14.0));
	float value = (bow * 1.2 + edge * 0.75 + inside + ring) * flutter * strength;
	ALBEDO = tone.rgb * value;
	ALPHA = clamp(value, 0.0, 1.0);
}
