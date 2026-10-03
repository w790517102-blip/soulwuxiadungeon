shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// A fist painted in the same language as the sword cut: a silver-white shape with a white-hot core,
// torn ink edges, black cracks and finger lines, and a black ink contour. The fist faces +x and
// the quad is square (uv 0..1). `formed` draws it on from the knuckles back, `charge` is the glow of
// the held fist before the blow, `fade` dissolves it after the hit. Presentation only.

uniform float formed : hint_range(0.0, 1.0) = 1.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float time_value = 0.0;
uniform vec4 core_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge_colour : source_color = vec4(0.72, 0.77, 0.86, 1.0);
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

float sd_round_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float sd_circle(vec2 p, float radius) {
	return length(p) - radius;
}

float sd_capsule(vec2 p, vec2 a, vec2 b, float radius) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - radius;
}

float smin(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * k * 0.25;
}

// The fist shape, facing +x, in a -1..1 square.
float fist_distance(vec2 p) {
	float d = sd_round_box(p - vec2(-0.02, 0.0), vec2(0.34, 0.33), 0.12);
	// Four knuckles along the front.
	for (int i = 0; i < 4; i++) {
		float y = -0.255 + 0.17 * float(i);
		d = smin(d, sd_circle(p - vec2(0.38, y), 0.105), 0.07);
	}
	// The thumb folded across the front of the fingers.
	d = smin(d, sd_capsule(p, vec2(-0.12, -0.31), vec2(0.40, -0.215), 0.085), 0.06);
	// The wrist trailing behind.
	d = smin(d, sd_round_box(p - vec2(-0.66, 0.0), vec2(0.26, 0.18), 0.05), 0.12);
	return d;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	// Drawn on from the knuckles back.
	float reveal = mix(0.55, -1.05, formed);
	if (p.x < reveal - 1.1 * 0.0 && formed < 1.0) {
		discard;
	}
	// Roughen the shape with ink-torn edges.
	float rough = (fbm(p * 6.0 + seed) - 0.5) * 0.07;
	float d = fist_distance(p) + rough;
	float halo = exp(-max(d, 0.0) * 9.0) * charge;
	// The wrist dissolves into the trail.
	float wrist_fade = smoothstep(-0.95, -0.45, p.x);
	float inside = 1.0 - smoothstep(-0.012, 0.012, d);
	float contour = (1.0 - smoothstep(0.0, 0.075, abs(d + 0.04))) * step(d, 0.04);
	// Fill: white-hot toward the middle, silver at the edge, black cracks and finger lines.
	float depth = clamp(-d / 0.28, 0.0, 1.0);
	vec3 fill = mix(edge_colour.rgb * 0.82, core_colour.rgb, smoothstep(0.05, 0.9, depth) * 0.85);
	float cracks = 1.0 - smoothstep(0.0, 0.035, abs(fbm(p * 7.0 + seed * 1.7) - 0.5));
	float finger_lines = 0.0;
	for (int i = 0; i < 3; i++) {
		float y = -0.17 + 0.17 * float(i);
		finger_lines += (1.0 - smoothstep(0.0, 0.026, abs(p.y - y))) * smoothstep(0.08, 0.18, p.x) * (1.0 - smoothstep(0.42, 0.5, p.x));
	}
	float dark = clamp(cracks * 0.8 + finger_lines * 0.9, 0.0, 0.92) * inside;
	vec3 colour = mix(fill, ink.rgb, dark);
	colour = mix(colour, ink.rgb, contour * 0.95);
	float alpha = inside * wrist_fade + contour * 0.9 * wrist_fade;
	// The pre-blow glow: a cold halo that tightens as the charge builds.
	colour = mix(colour, vec3(1.0), halo * 0.6 * (1.0 - inside));
	alpha = max(alpha, halo * 0.55);
	// Dissolve after the hit.
	float gone = fbm(p * 5.0 + seed) ;
	if (gone < fade) {
		discard;
	}
	ALBEDO = colour;
	ALPHA = clamp(alpha, 0.0, 1.0) * (1.0 - fade * 0.4);
	EMISSION = colour * (0.12 + 0.55 * charge) * inside;
}
