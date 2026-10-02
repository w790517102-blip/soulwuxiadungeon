shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// A sword cut as a cold silver-white blade of light that tears the air open (UV.x along the arc,
// UV.y across it): a sharp crescent, white-hot at its core, torn along the edges and cracked across
// by black fracture lines, with a trail of black ink strands dragged out behind and around it. High
// contrast, black and white only. All the streaks run along the cut in the same direction but are
// irregular and uncoordinated, like turbulent air. Presentation only.

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float seed = 0.0;
uniform vec4 light_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 light_cool : source_color = vec4(0.80, 0.84, 0.90, 1.0);
uniform vec4 ink : source_color = vec4(0.015, 0.015, 0.02, 1.0);

const float SWEEP_END = 0.21;

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
	// When the head reached this point of the arc (inverse of the sweep easing), and how long ago.
	float reach = clamp((UV.x + 0.05) / 1.10, 0.0, 0.999);
	float passed_at = SWEEP_END * (1.0 - pow(1.0 - reach, 1.0 / 2.2));
	float since = progress - passed_at;
	float age = since / 0.34;                          // the white blade: lasts about as long as before
	float age_ink = since / 0.77;                      // the black ink: lingers and fades slowly
	if (since < 0.0) {
		discard;
	}
	float end_fade = 1.0 - smoothstep(0.92, 1.0, progress);
	float x = UV.x;
	float across = (UV.y - 0.5) * 2.0;

	// The crescent: pointed at both ends, fat toward the start, sharpest at the head, thinning with age.
	float shape = pow(sin(3.14159 * pow(x, 0.55)), 0.9);
	float light_width = shape * clamp(age * 10.0, 0.14, 1.0) * (1.0 - 0.70 * smoothstep(0.12, 1.0, age)) * 0.24;
	float ink_width = shape * (1.0 - 0.30 * smoothstep(0.3, 1.0, age_ink)) * 0.52;

	// Turbulent streaks: they all run along the arc but each lane flows at its own speed and wanders.
	float lane = across * 8.0 + seed;
	float lane_speed = 6.0 + 6.0 * noise(vec2(floor(lane), seed));
	vec2 warp = vec2(fbm(vec2(x * 3.0 - progress * 4.0, across * 3.0 + seed)), fbm(vec2(x * 4.0 + 7.0, across * 4.0 - progress * 3.0))) - 0.5;
	float flow = fbm(vec2(x * 5.0 - progress * lane_speed + warp.x * 1.8, across * 9.0 + warp.y * 2.4 + seed));
	float fine = noise(vec2(x * 26.0 - progress * (10.0 + lane_speed) + warp.x * 3.0, across * 32.0 + warp.y * 4.0 + seed * 2.0));

	// Torn edges.
	float tear = (fbm(vec2(x * 13.0 - progress * 7.0, across * 2.5 + seed)) - 0.5) * (0.22 + 0.55 * age);
	float light_mask = 1.0 - smoothstep(light_width * 0.80, light_width, abs(across + tear));
	float ink_mask = 1.0 - smoothstep(ink_width * 0.70, ink_width, abs(across + tear * 1.4));

	// The blade dissolves into strands as it ages; the ink lingers a little longer.
	float breakup = smoothstep(0.08, 1.0, age) * 0.78;
	if (flow * 0.6 + fine * 0.4 < breakup && light_mask > 0.0) {
		light_mask *= 0.0;
	}
	// The ink is dragged out as separate strands (the dry-brush streaks of the stroke).
	float strands = smoothstep(0.22 + 0.34 * age_ink, 0.55 + 0.28 * age_ink, flow * 0.7 + fine * 0.5);
	ink_mask *= strands;

	// Cracks of black across the light: the air splitting along thin jagged lines.
	vec2 crack_p = vec2(x * 9.0 - across * 3.5 + seed, across * 6.0 + x * 2.0);
	float crack_noise = fbm(crack_p * 1.4 + warp * 1.5);
	float cracks = (1.0 - smoothstep(0.0, 0.035, abs(crack_noise - 0.5))) * smoothstep(0.1, 0.5, light_mask);
	float inner_dark = smoothstep(0.62, 0.86, 1.0 - flow) * (0.25 + 0.55 * age);

	// Colour: white-hot core, cool silver toward the edges, black cracks and ink strands.
	float edge = clamp(abs(across + tear) / max(light_width, 0.001), 0.0, 1.0);
	vec3 light_colour = mix(light_core.rgb, light_cool.rgb, smoothstep(0.35, 1.0, edge) * 0.8);
	light_colour = mix(light_colour, ink.rgb, clamp(cracks * 0.95 + inner_dark, 0.0, 0.92));

	float light_alpha = light_mask;
	float ink_alpha = ink_mask * 0.95 * (1.0 - smoothstep(0.30, 1.0, age_ink));
	// A faint silver glint along the ink edges so the black mark still reads on a dark stage.
	float ink_rim = smoothstep(0.10, 0.35, ink_mask) * (1.0 - smoothstep(0.35, 0.75, ink_mask));
	vec3 ink_colour = mix(ink.rgb, vec3(0.62, 0.65, 0.72), ink_rim * 0.85 * (1.0 - 0.5 * smoothstep(0.2, 1.0, age_ink)));
	// Light over ink.
	float alpha = light_alpha + ink_alpha * (1.0 - light_alpha);
	vec3 colour = (light_colour * light_alpha + ink_colour * ink_alpha * (1.0 - light_alpha)) / max(alpha, 0.001);
	ALBEDO = colour;
	ALPHA = alpha * end_fade;
	EMISSION = light_colour * light_alpha * 0.5;
}
