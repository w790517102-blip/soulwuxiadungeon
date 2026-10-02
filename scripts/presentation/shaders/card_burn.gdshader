shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// A fire that climbs a card from its bottom edge and leaves it charred black. It is drawn as a
// sheet laid over the card (same size as the card image): where the fire has passed the sheet
// is charcoal with a few glowing embers, along the front it burns violet-white, and a flickering
// glow licks above the front. The sheet only covers the card's own shape (its image plus its art
// window). Presentation only.

uniform sampler2D face_tex : source_color, filter_linear;
uniform vec4 window = vec4(0.0, 0.0, 1.0, 1.0);   // art window in uv: x0, y0, x1, y1
uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 3.0;
uniform float time_value = 0.0;
uniform vec4 flame_core : source_color = vec4(0.95, 0.88, 1.0, 1.0);
uniform vec4 flame_edge : source_color = vec4(0.60, 0.22, 0.95, 1.0);

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
	for (int i = 0; i < 5; i++) {
		value += amp * noise(p);
		p = p * 2.07 + vec2(11.3, 5.9);
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	float in_window = step(window.x, uv.x) * step(uv.x, window.z) * step(window.y, uv.y) * step(uv.y, window.w);
	float mask = max(texture(face_tex, uv).a, in_window);
	float height = 1.0 - uv.y;                       // 0 at the bottom edge, 1 at the top
	float n = fbm(uv * vec2(5.0, 7.0) + seed);
	float field = height * 0.78 + n * 0.46;          // the front climbs where this is smallest
	float t = burn * 1.34 - field;                   // > 0: already burnt
	vec3 colour = vec3(0.0);
	float alpha = 0.0;
	if (t > 0.0) {
		// Charcoal, with embers still glowing in the fresh char.
		float ember = smoothstep(0.55, 0.9, fbm(uv * 14.0 + seed * 2.0 + time_value * 0.6));
		float fresh = 1.0 - smoothstep(0.0, 0.35, t);
		colour = vec3(0.015, 0.012, 0.02) + flame_edge.rgb * ember * fresh * 0.55;
		alpha = 1.0;
		// The burning edge itself.
		float band = 1.0 - smoothstep(0.0, 0.10, t);
		colour = mix(colour, mix(flame_edge.rgb, flame_core.rgb, band * band), band);
	} else {
		// A flickering glow above the front, licking up the unburnt card.
		float lick = exp(t * 11.0);
		float flicker = 0.55 + 0.45 * noise(vec2(uv.x * 18.0, time_value * 7.0 + seed));
		colour = flame_edge.rgb * 1.2;
		alpha = lick * flicker * 0.75 * step(0.001, burn);
	}
	ALBEDO = colour;
	ALPHA = alpha * mask;
}
