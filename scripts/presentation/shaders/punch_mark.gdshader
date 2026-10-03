shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// The black mark a punch leaves where it landed, in the style of the black ink a sword cut leaves
// behind (not a drawn fist and not a cut): an irregular dry-brush burst of ink, strands dragged
// outward from the contact point, torn edges. It appears at once and then fades slowly.
// `t` runs 0..1 over its life. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
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

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amp * noise(p);
		p = p * 2.07 + vec2(11.3, 5.9);
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// The burst opens in the first instant and then holds.
	float pop = 1.0 - exp(-t * 40.0);
	float reach = (0.30 + 0.10 * (1.0 - t)) * pop;
	// Torn core: the radius changes sharply with the angle, like a splash.
	float spike = pow(noise(vec2(ang * 3.0 + seed, seed)), 2.0) * 0.28 + (noise(vec2(ang * 9.0, seed * 2.0)) - 0.5) * 0.08;
	float core = 1.0 - smoothstep(reach * 0.55, reach + spike, r);
	core *= smoothstep(0.2, 0.55, fbm(p * 5.0 + seed) + 0.35);
	// Dry-brush strands dragged outward, each its own length, all running away from the contact point.
	float lane = floor(ang * 5.0 + seed);
	float strand_len = (0.35 + 0.6 * hash(vec2(lane, seed))) * 0.85 * pop;
	float strand_ang = abs(fract(ang * 5.0 + seed) - 0.5) * 2.0;
	float strand = (1.0 - smoothstep(0.0, 0.16, strand_ang)) * (1.0 - smoothstep(reach * 0.6, strand_len, r)) * smoothstep(reach * 0.3, reach * 0.7, r);
	strand *= smoothstep(0.25, 0.7, noise(vec2(r * 14.0, lane + seed)));
	// A few flecks around it.
	vec2 cell = floor(p * 9.0 + seed);
	vec2 local = fract(p * 9.0 + seed) - 0.5;
	float fleck_on = step(0.86, hash(cell)) * step(r, 0.9) * step(reach * 0.9, r);
	float fleck = fleck_on * (1.0 - smoothstep(0.05, 0.16, length(local)));
	float shape = clamp(core + strand * 0.85 + fleck * 0.9, 0.0, 1.0);
	// It fades slowly, thinning from the edges in.
	float life = 1.0 - smoothstep(0.55, 1.0, t);
	float erode = t * 0.45 * noise(p * 6.0 + seed);
	float alpha = clamp(shape - erode, 0.0, 1.0) * life * 0.95;
	ALBEDO = ink.rgb;
	ALPHA = alpha;
}
