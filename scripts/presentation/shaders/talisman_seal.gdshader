shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// The seal that unfolds across a card once the paper has stuck to it. Not a magic circle: a broken
// frame that tightens inward like a pressing hand, two crossed strips of sealing tape with tick
// marks, and a small stamp in the middle. Cinnabar red with gold-white cores. It is drawn in broken
// pieces, never complete. `t` (0..1) reveals it from the spot where the paper stuck (`origin`),
// `contract` tightens the frame, `fade` removes everything but, optionally, the stamp (`remnant`).
// Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float contract : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float remnant = 0.5;             // how much of the stamp survives the fade
uniform float aspect = 0.7;              // width / height of the quad
uniform vec2 origin = vec2(0.0, 0.0);    // where the paper landed, in -1..1 quad space
uniform float seed = 0.0;
uniform float tape_strength = 1.0;       // 0 removes the crossed tapes (the caller draws them in ink instead)
uniform float intensity = 1.0;
uniform vec4 red_tone : source_color = vec4(0.88, 0.12, 0.07, 1.0);
uniform vec4 gold_tone : source_color = vec4(1.0, 0.84, 0.42, 1.0);
uniform vec4 core_tone : source_color = vec4(1.0, 0.97, 0.88, 1.0);

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

float box_sd(vec2 p, vec2 half_size) {
	vec2 d = abs(p) - half_size;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.x *= aspect;                      // square units, so the marks keep their proportions
	vec2 o = origin * vec2(aspect, 1.0);
	float reach = t * 2.4;              // how far the reveal has travelled from the landing spot

	// 1. The broken frame, tightening inward.
	vec2 half_size = vec2(aspect, 1.0) * mix(1.02, 0.80, contract);
	float fd = abs(box_sd(p, half_size));
	float frame = exp(-pow(fd / 0.012, 2.0));
	float ang = atan(p.y, p.x);
	float piece = floor((ang + 3.14159) / 6.28318 * 9.0);
	float present = step(hash(vec2(piece, seed)), 0.62);            // some pieces are missing
	float frame_reveal = 1.0 - smoothstep(reach - 0.4, reach, length(p - o));
	frame *= present * frame_reveal;
	// Short inward ticks on the frame (pressing marks).
	float tick_phase = fract(ang * 9.0 / 6.28318 * 3.0);
	float ticks = exp(-pow((fd - 0.045) / 0.010, 2.0)) * step(0.45, tick_phase) * step(tick_phase, 0.58) * present * frame_reveal * 0.8;

	// 2. Two crossed strips of sealing tape from corner to corner.
	float tape = 0.0;
	float tape_core = 0.0;
	for (int i = 0; i < 2; i++) {
		vec2 dir = normalize(vec2(aspect * (i == 0 ? 1.0 : -1.0), 1.0));
		vec2 nrm = vec2(-dir.y, dir.x);
		float along = dot(p, dir);
		float across = dot(p, nrm);
		float jitter = (noise(vec2(along * 9.0 + seed, float(i) * 4.0)) - 0.5) * 0.02;
		float width = mix(0.062, 0.050, contract);
		float inside = 1.0 - smoothstep(width - 0.008, width + 0.004, abs(across + jitter));
		float edge_line = exp(-pow((abs(across + jitter) - width) / 0.007, 2.0));
		// Revealed along the strip from the landing point, and broken in two places.
		float travelled = 1.0 - smoothstep(reach - 0.5, reach, abs(along - dot(o, dir)));
		float gap = smoothstep(0.1, 0.4, noise(vec2(along * 3.0 + seed * 2.0, float(i) * 7.0)));
		float cross_ticks = step(0.5, fract(along * 7.0)) * step(abs(across), width * 0.7) * 0.55;
		tape += (inside * 0.22 + edge_line * 0.85 + cross_ticks * inside) * travelled * gap * tape_strength;
		tape_core += edge_line * travelled * gap * tape_strength;
	}

	// 3. The stamp in the middle: a square seal with a cross, appearing late.
	float stamp_t = smoothstep(0.45, 0.85, t);
	float stamp_size = mix(0.2, 0.15, contract);
	float stamp_d = abs(box_sd(p, vec2(stamp_size)));
	float stamp = exp(-pow(stamp_d / 0.012, 2.0));
	float stamp_cross = max(exp(-pow(p.x / 0.010, 2.0)) * step(abs(p.y), stamp_size), exp(-pow(p.y / 0.010, 2.0)) * step(abs(p.x), stamp_size)) * 0.9;
	float stamp_all = (stamp + stamp_cross) * stamp_t;

	float line = clamp(frame + ticks, 0.0, 1.0);
	float body = clamp(line + tape, 0.0, 1.0);
	float core = clamp(line * 0.5 + tape_core * 0.7 + stamp_all * 0.55, 0.0, 1.0);
	float keep = mix(1.0, 0.0, fade);
	float shown = body * keep + stamp_all * remnant * fade;
	vec3 colour = mix(red_tone.rgb, gold_tone.rgb, clamp(core * 1.2, 0.0, 1.0));
	colour = mix(colour, core_tone.rgb, clamp(core - 0.5, 0.0, 1.0) * 1.4);
	float value = clamp(shown + stamp_all * keep, 0.0, 1.0);
	// A flash as each part is drawn: the freshest edge of the reveal glows brighter.
	float fresh = exp(-pow((length(p - o) - reach) / 0.25, 2.0)) * (1.0 - fade) * 0.7;
	ALBEDO = colour;
	ALPHA = value * 0.9;
	EMISSION = colour * value * (1.1 + fresh + core) * intensity;
}
