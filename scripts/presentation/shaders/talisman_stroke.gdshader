shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// One stroke of a talisman script, drawn the way a sword's cut is drawn in this game: a bright head
// sweeps along the stroke, leaving a tapered ribbon that is white-gold at the front and cinnabar red
// behind, frayed at its edges and streaked with a few dark ink strands. The quad lies along the
// stroke (x axis); `draw` (0..1) is how far the head has travelled, `age` (0..1) removes the stroke,
// `glow` brightens it (charging, or the flash of landing). Presentation only.

uniform float draw : hint_range(0.0, 1.0) = 0.0;
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float glow = 1.0;
uniform float stroke_len = 1.0;           // length of the stroke itself (world units)
uniform float quad_len = 1.2;             // length of the quad (stroke plus padding)
uniform float quad_wid = 0.3;
uniform float width = 0.05;               // brush width at the thickest point
uniform float bend = 0.0;                 // sideways bow of the stroke, as a share of its length
uniform float seed = 0.0;
uniform float ink_amount = 0.6;           // how much dark ink streaks the stroke
uniform float heat_decay = 3.5;           // how fast the white-gold front cools to red behind the head
uniform vec4 core_tone : source_color = vec4(1.0, 0.96, 0.84, 1.0);
uniform vec4 mid_tone : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform vec4 edge_tone : source_color = vec4(0.88, 0.10, 0.05, 1.0);
uniform vec4 ink_tone : source_color = vec4(0.10, 0.01, 0.01, 1.0);

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
	vec2 q = vec2((UV.x - 0.5) * quad_len, (UV.y - 0.5) * quad_wid);
	float s = q.x / stroke_len + 0.5;
	float bow = bend * stroke_len * (1.0 - pow(2.0 * clamp(s, 0.0, 1.0) - 1.0, 2.0));
	float y = q.y - bow;
	float sc = clamp(s, 0.0, 1.0);
	// Brush profile: slim entry, full body, a flicked tail.
	float prof = pow(sin(clamp(sc, 0.03, 0.97) * 3.14159), 0.5);
	prof *= mix(0.6, 1.0, smoothstep(0.0, 0.25, sc));
	float wob = 0.78 + 0.44 * noise(vec2(sc * 7.0 + seed, seed * 1.3));
	float frayed = 0.80 + 0.40 * noise(vec2(sc * 38.0 + seed, y / max(width, 0.001) * 2.5));
	float w = max(width * prof * wob * frayed, 0.0005);
	float over = max(abs(q.x) - stroke_len * 0.5, 0.0);
	float dist = length(vec2(over, y));
	float body = 1.0 - smoothstep(w * 0.55, w, dist);
	float core = 1.0 - smoothstep(0.0, w * 0.5, dist);
	float halo = exp(-pow(dist / (w * 2.6), 2.0));

	// Only what the head has crossed is there.
	float mask = 1.0 - smoothstep(draw - 0.015, draw + 0.015, s);
	float heat = exp(-max(draw - s, 0.0) * heat_decay) * (draw < 0.999 ? 1.0 : 0.55);
	// The head itself: a white spark running ahead of the ribbon.
	float head_x = (draw - 0.5) * stroke_len;
	float flare = exp(-pow(length(vec2(q.x - head_x, y)) / (width * 1.5), 2.0)) * (1.0 - smoothstep(0.92, 1.0, draw)) * step(0.001, draw);
	// Dark ink strands along the stroke, mostly toward its edges.
	float strand = smoothstep(0.55, 0.8, noise(vec2(sc * 4.0 + seed, y / max(w, 0.001) * 1.7 + seed * 2.0)));
	float ink = strand * smoothstep(0.1, 0.9, abs(y) / max(w, 0.001)) * ink_amount;

	float fade = 1.0 - age;
	vec3 colour = mix(edge_tone.rgb, mid_tone.rgb, clamp(heat * 1.1 + core * 0.35, 0.0, 1.0));
	colour = mix(colour, core_tone.rgb, clamp(heat * core * 1.3 + flare, 0.0, 1.0));
	colour = mix(colour, ink_tone.rgb, ink * (1.0 - heat));
	float value = clamp(body * mask + halo * mask * 0.28 + flare, 0.0, 1.0) * fade;
	float light = (0.55 + heat * 1.7 + core * 0.9 + flare * 2.2) * (1.0 - ink * 0.7) * glow;
	ALBEDO = colour;
	ALPHA = value;
	EMISSION = colour * light * value;
}
