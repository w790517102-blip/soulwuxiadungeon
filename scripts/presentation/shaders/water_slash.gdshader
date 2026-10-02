shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// A sword cut as a blade of flowing water laid along a half-circle arc (UV.x along the arc, UV.y
// across it). The water is a translucent blue band with streaks that run along the arc and keep
// flowing, white foam on its edges and crests, a pointed leading tip, and a tail that thins, breaks
// into strands and dissolves after the head has passed. Presentation only.

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float seed = 0.0;
uniform vec4 water_deep : source_color = vec4(0.04, 0.20, 0.55, 1.0);
uniform vec4 water_mid : source_color = vec4(0.18, 0.55, 0.95, 1.0);
uniform vec4 foam : source_color = vec4(0.92, 0.98, 1.0, 1.0);

const float SWEEP_END = 0.34;

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
	float age = (progress - passed_at) / 0.50;
	if (age < 0.0) {
		discard;
	}
	float end_fade = 1.0 - smoothstep(0.80, 1.0, progress);
	float x = UV.x;
	float across = (UV.y - 0.5) * 2.0;                 // -1 .. 1 across the band
	// Pointed at both ends, fat toward the start; the lead tip is sharpest while the head travels.
	float width = pow(sin(3.14159 * pow(x, 0.55)), 0.9);
	width *= clamp(age * 9.0, 0.18, 1.0);
	// The tail thins out as it ages.
	width *= 1.0 - 0.75 * smoothstep(0.15, 1.0, age);
	// Torn, wavy edges that fray more with age.
	float edge_noise = (fbm(vec2(x * 11.0 - progress * 6.0, across * 2.0 + seed)) - 0.5) * (0.20 + 0.5 * age);
	float mask = 1.0 - smoothstep(width * 0.78, width, abs(across + edge_noise));
	// Turbulent streaks: all run along the arc (same direction) but each lane flows at its own speed
	// and wanders, so the texture is irregular and uncoordinated, like churning water.
	float lane = across * 9.0 + seed;
	float lane_speed = 7.0 + 5.0 * noise(vec2(floor(lane), seed));
	vec2 warp = vec2(fbm(vec2(x * 3.0 - progress * 4.0, across * 3.0 + seed)), fbm(vec2(x * 4.0 + 7.0, across * 4.0 - progress * 3.0))) - 0.5;
	float flow = fbm(vec2(x * 5.0 - progress * lane_speed + warp.x * 1.6, across * 9.0 + warp.y * 2.2 + seed));
	float fine = noise(vec2(x * 24.0 - progress * (11.0 + lane_speed) + warp.x * 3.0, across * 30.0 + warp.y * 4.0 + seed * 2.0));
	// The tail breaks into strands and dissolves.
	float cutoff = smoothstep(0.10, 1.0, age) * 0.75;
	if (flow * 0.6 + fine * 0.4 < cutoff) {
		discard;
	}
	// Colour: deep blue underneath, bright blue in the body, white foam on the edges and crests.
	float body = clamp(flow * 1.2, 0.0, 1.0);
	vec3 colour = mix(water_deep.rgb, water_mid.rgb, smoothstep(0.15, 0.85, body));
	float rim = smoothstep(0.55, 0.98, abs(across) / max(width, 0.001));
	float crest = smoothstep(0.72, 0.92, flow + fine * 0.25);
	float lead = smoothstep(0.10, 0.0, age);
	float foam_amount = clamp(rim * 0.55 + crest * 0.35 + lead * 0.8, 0.0, 1.0);
	colour = mix(colour, foam.rgb, foam_amount);
	// A thin bright line along one edge, like light running on the surface.
	colour = mix(colour, vec3(1.0), smoothstep(0.80, 0.95, across / max(width, 0.001)) * 0.8);
	ALBEDO = colour;
	ALPHA = mask * (0.55 + 0.4 * foam_amount) * (1.0 - 0.5 * smoothstep(0.4, 1.0, age)) * end_fade;
	EMISSION = colour * 0.35 * mask;
}
