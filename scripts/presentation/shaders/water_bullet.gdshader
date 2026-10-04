shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// A bolt of turbid water spat across the stage. Its surface is moving water: uneven, torn streaks of flow
// running along its length at different speeds, ridged caustic veins, a few dark ink threads (the water of
// a 魘), a white foam rim that breaks up, and a tail that frays into separate strands. Nothing in it is
// even or smooth. UV.x runs from the tail (0) to the head (1); `mode` 0 is the bolt itself, 1 is the long
// trail it drags. Presentation only.

uniform float mode = 0.0;
uniform float fade = 0.0;                 // 0..1: the bolt dissolves
uniform float seed = 0.0;
uniform float flow_speed = 5.0;
uniform vec4 deep_tone : source_color = vec4(0.02, 0.14, 0.20, 1.0);
uniform vec4 mid_tone : source_color = vec4(0.10, 0.40, 0.50, 1.0);
uniform vec4 light_tone : source_color = vec4(0.78, 0.96, 1.0, 1.0);
uniform vec4 ink_tone : source_color = vec4(0.04, 0.02, 0.09, 1.0);

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
		p = p * 2.07 + vec2(5.3, 1.7);
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	float x = UV.x;
	float y = (UV.y - 0.5) * 2.0;
	float t = TIME * flow_speed;
	// Turbulent flow: the water is carried back along the bolt, each lane at its own speed.
	vec2 warp = vec2(fbm(vec2(x * 3.0 - t * 0.35, y * 2.0 + seed)), fbm(vec2(x * 4.0 + 7.0, y * 3.0 - t * 0.25))) - 0.5;
	float lane = floor((y * 0.5 + 0.5) * 7.0 + seed);
	float lane_speed = 0.6 + 0.9 * hash(vec2(lane, seed));
	float flow = fbm(vec2(x * 6.0 + t * lane_speed + warp.x * 2.0, y * 7.0 + warp.y * 2.5 + seed));
	float fine = noise(vec2(x * 22.0 + t * (lane_speed + 0.8) + warp.x * 3.0, y * 26.0 + warp.y * 3.0));
	float ridge = pow(1.0 - abs(2.0 * flow - 1.0), 3.0);

	float shape = 0.0;
	float body_edge = 0.0;
	if (mode < 0.5) {
		// The bolt: a rounded head at the front and a body that narrows toward a frayed tail. The edge
		// is pushed about by the flow so it never forms a clean outline.
		float cap = x > 0.74 ? sqrt(max(1.0 - pow((x - 0.74) / 0.26, 2.0), 0.0)) : 1.0;   // rounded head
		float width = mix(0.18, 1.0, smoothstep(0.0, 0.55, x)) * cap;
		width *= 0.85 + 0.3 * noise(vec2(x * 9.0 + seed, t * 0.1));
		float d = abs(y + (warp.y) * 0.35) - width;
		shape = 1.0 - smoothstep(-0.12, 0.08, d);
		body_edge = exp(-pow(d / 0.10, 2.0));
		// The tail is torn into strands.
		float strands = smoothstep(0.30, 0.65, noise(vec2(x * 4.0 - t * 0.5, y * 13.0 + seed)));
		shape *= mix(strands, 1.0, smoothstep(0.15, 0.5, x));
	} else {
		// The trail: thin streaming strands that fade away toward the tail.
		float strands = smoothstep(0.50, 0.78, noise(vec2(x * 8.0 - t * 0.9, y * 9.0 + seed))) * smoothstep(0.0, 0.7, x);
		float lane_w = 0.55 * smoothstep(0.0, 0.8, x);
		shape = strands * (1.0 - smoothstep(lane_w * 0.6, lane_w + 0.12, abs(y)));
		body_edge = shape * 0.3;
	}
	float foam_break = smoothstep(0.30, 0.7, noise(vec2(x * 15.0 - t * 0.7, y * 11.0)));
	float foam = body_edge * foam_break;
	vec3 colour = mix(deep_tone.rgb, mid_tone.rgb, clamp(flow * 1.3, 0.0, 1.0));
	colour = mix(colour, light_tone.rgb, clamp(ridge * 0.55 + fine * 0.08, 0.0, 1.0) * (0.35 + 0.4 * x));
	// Dark ink threads running through the water.
	float thread = smoothstep(0.72, 0.9, fbm(vec2(x * 5.0 - t * 0.5 + 3.0, y * 4.0 + seed * 2.0)));
	colour = mix(colour, ink_tone.rgb, thread * 0.8);
	colour = mix(colour, vec3(1.0), clamp(foam * 1.4, 0.0, 1.0));
	float alpha = clamp(shape * (mode < 0.5 ? 0.92 : 0.55), 0.0, 1.0) * (1.0 - fade);
	ALBEDO = colour;
	ALPHA = alpha;
	EMISSION = light_tone.rgb * (ridge * 0.25 + foam * 0.9) * alpha * 0.8;
}
