shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// A calligraphy stroke written into the air: a black brush stroke (UV.x along it, UV.y across) that
// presses in at the start, swells and thins as it goes, tears into dry-brush streaks (飛白) toward the
// end and lifts off in a pointed tip. It is drawn on as the whip passes (`reveal`) and then stays; it
// is not a liquid: its edges are rough, it has paper-dry gaps and it is never glossy. `fade` (0..1)
// erodes and removes it. Presentation only.

uniform float reveal : hint_range(0.0, 1.2) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float lead_heavy = 0.0;        // 1: a lash, fat at its head and thin where it began (0: a written stroke)
uniform vec4 ink : source_color = vec4(0.012, 0.012, 0.016, 1.0);

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
	float across = (UV.y - 0.5) * 2.0;
	if (x > reveal) {
		discard;
	}
	// Width: the brush is pressed down at the start, swells and thins along the way (like a real
	// stroke), then the tip lifts off to a point.
	float press = smoothstep(0.0, 0.10, x) * 0.55 + 0.45;
	float swell = 0.78 + 0.22 * sin(x * 9.0 + seed) + 0.12 * sin(x * 21.0 + seed * 2.0);
	float lift = pow(1.0 - smoothstep(0.62, 1.0, x), 0.85);
	float width = press * swell * lift;
	if (lead_heavy > 0.5) {
		// A lash: thin where it began, swelling toward the head, ending in a blunt brush head.
		width = pow(smoothstep(0.0, 0.85, x), 0.8) * (0.9 + 0.1 * sin(x * 15.0 + seed)) * (1.0 - smoothstep(0.96, 1.0, x) * 0.5);
	}
	// Rough edges, like bristles on paper.
	float rough = (noise(vec2(x * 38.0 + seed, across * 4.0)) - 0.5) * 0.22 * (0.4 + x);
	float body = 1.0 - smoothstep(width * 0.82, width, abs(across + rough));
	// Dry brush: streaks along the stroke open up toward the end, so paper shows through.
	float streak = noise(vec2(across * 16.0 + seed, x * 3.5)) * 0.6 + noise(vec2(across * 41.0, x * 9.0 + seed)) * 0.4;
	float dryness = smoothstep(0.30, 1.0, x) * 0.62;
	float gaps = smoothstep(dryness - 0.08, dryness + 0.08, streak);
	// The very start is solid (the press), the drying only begins after it.
	float solid = 1.0 - smoothstep(0.0, 0.3, x);
	float mask = body * mix(gaps, 1.0, solid);
	// Fading: the stroke thins from its dry end and breaks up before it is gone.
	float eroded = smoothstep(fade * 1.3 - 0.3, fade * 1.3, noise(vec2(x * 9.0, across * 7.0 + seed)) * 0.6 + x * 0.4);
	float alpha = mask * mix(1.0, eroded, smoothstep(0.0, 0.2, fade)) * (1.0 - smoothstep(0.7, 1.0, fade));
	// A faint cold-grey sheen along the stroke's upper edge so the black still reads against a dark stage.
	float sheen = smoothstep(0.55, 0.95, -across / max(width, 0.001)) * (1.0 - smoothstep(0.0, 0.5, fade)) * 0.55;
	ALBEDO = mix(ink.rgb, vec3(0.62, 0.66, 0.74), sheen);
	ALPHA = clamp(alpha, 0.0, 1.0) * 0.96;
}
