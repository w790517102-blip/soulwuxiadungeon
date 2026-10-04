shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
// The guard of a martial artist: breath drawn in and held, a thin cold membrane of ice-blue and
// white light standing a little off the body. Nothing like a glass dome or a force-field: it is
// nearly clear, its edge is a thin brighter line, and its inside carries slow moonlight-on-water
// ripples that drift. It breathes: brightness and colour (ice blue <-> cold white-blue) swell and
// ebb slowly. From time to time a faint ripple crosses it and a thin cold-white glint slides over
// its surface. `form` (0..1) raises it, `collapse` (0..1) lets it go (the rim draws inward and the
// light fades), and a hit (`hit_pos`, `hit_t`) dents it, flashes at the point and sends a ring
// outward. Presentation only.

uniform float form : hint_range(0.0, 1.0) = 1.0;
uniform float collapse : hint_range(0.0, 1.0) = 0.0;
uniform vec2 hit_pos = vec2(1.0, 0.0);      // where the blow lands, in -1..1 quad space
uniform float hit_t : hint_range(0.0, 1.0) = 1.0;   // 0 at the instant of the hit, 1 when it has gone
uniform float hit_strength = 1.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;
uniform float shape_power = 3.0;            // 2 = ellipse, higher = squarer (a card-shaped membrane)
uniform vec4 ice_tone : source_color = vec4(0.40, 0.72, 1.0, 1.0);
uniform vec4 white_tone : source_color = vec4(0.82, 0.93, 1.0, 1.0);

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

float ridged(vec2 p) {
	float n = noise(p);
	return pow(1.0 - abs(2.0 * n - 1.0), 3.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	// Raising: the membrane opens from the middle; letting go: its rim draws inward.
	float rise = 1.0 - pow(1.0 - form, 3.0);
	float scale = mix(0.35, 1.0, rise) * mix(1.0, 0.72, collapse);
	// A local dent where it is struck: the surface is pushed inward around the hit.
	vec2 to_hit = p - hit_pos;
	float hit_dist = length(to_hit);
	float dent = exp(-pow(hit_dist / 0.38, 2.0)) * (1.0 - smoothstep(0.0, 0.35, hit_t)) * hit_strength * 0.12;
	float shaped = pow(pow(abs(p.x), shape_power) + pow(abs(p.y), shape_power), 1.0 / shape_power);
	float d = shaped / scale + dent;
	float rim_pos = 0.88;
	float rim = exp(-pow((d - rim_pos) / 0.06, 2.0));
	float outer_glow = exp(-pow(max(d - rim_pos, 0.0) / 0.10, 2.0)) * 0.22 * step(rim_pos, d);
	float inside = 1.0 - smoothstep(rim_pos, rim_pos + 0.03, d);

	// Moonlight on water: slow caustic ripples drifting through the membrane.
	float t = TIME;
	float water = ridged(p * 3.2 + vec2(t * 0.09, -t * 0.06) + seed) * 0.6 + ridged(p * 6.5 - vec2(t * 0.07, t * 0.11) + seed * 2.0) * 0.4;
	float edge_lift = smoothstep(0.35, rim_pos, d);
	float body = water * edge_lift * 0.62 + edge_lift * edge_lift * 0.16;

	// Breathing: slow swell of brightness and drift of colour.
	float breath = 0.78 + 0.22 * sin(t * 1.15 + seed);
	float hue = 0.5 + 0.5 * sin(t * 0.62 + seed * 1.7);

	// Now and then a faint ripple and a thin glint over the surface.
	float cycle = t / 6.5 + seed;
	float spot_seed = floor(cycle);
	vec2 spot = vec2(hash(vec2(spot_seed, 1.0)) - 0.5, hash(vec2(spot_seed, 2.0)) - 0.5) * 1.1;
	float idle_r = fract(cycle) * 1.3;
	float idle_ripple = exp(-pow((length(p - spot) - idle_r) / 0.06, 2.0)) * (1.0 - fract(cycle)) * 0.35;
	float glint_phase = fract(t / 5.0 + seed * 0.37);
	float glint_pos = glint_phase * 3.4 - 1.7;
	float glint = exp(-pow((p.x * 0.6 + p.y * 0.8 - glint_pos) / 0.05, 2.0)) * smoothstep(0.0, 0.6, edge_lift + 0.25) * 0.55 * step(glint_phase, 0.55);

	// A blow: a small bright burst at the point, then a ring spreading over the membrane.
	float burst = exp(-pow(hit_dist / 0.10, 2.0)) * (1.0 - smoothstep(0.0, 0.22, hit_t)) * 1.8 * hit_strength;
	float ring_r = hit_t * 1.5;
	float ring = exp(-pow((hit_dist - ring_r) / 0.07, 2.0)) * (1.0 - hit_t) * 1.0 * hit_strength;
	// The compressed patch glows a little while it is pushed in.
	float pressed = exp(-pow(hit_dist / 0.42, 2.0)) * (1.0 - smoothstep(0.0, 0.5, hit_t)) * 0.45 * hit_strength;

	float surface = (body + idle_ripple + glint + ring + pressed) * inside;
	float value = (surface + rim * (0.42 + ring * 0.0) * (0.85 + 0.15 * breath) + outer_glow + burst * inside) * breath;
	// A flash along the rim as it forms.
	value += rim * (1.0 - smoothstep(0.0, 0.5, form)) * 1.2 * step(form, 0.999);
	float life = form * (1.0 - collapse);
	vec3 base = mix(ice_tone.rgb, white_tone.rgb, hue * 0.7);
	vec3 colour = mix(base, vec3(1.0), clamp(burst * 0.5 + rim * 0.08 + glint * 0.6, 0.0, 1.0));
	ALBEDO = colour * value * life * intensity * 1.3;
	ALPHA = 1.0;
}
