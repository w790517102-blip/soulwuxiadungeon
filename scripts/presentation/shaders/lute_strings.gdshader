shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add;
// A few hair-thin string-like lines of light across the struck card, shivering as strings do after
// a pluck and dying away: the afterglow of the sound. The lines run along the quad's x axis and
// vibrate in y. `t` runs 0..1. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float strings = 5.0;
uniform float intensity = 2.0;
uniform vec4 colour : source_color = vec4(0.88, 0.94, 1.0, 1.0);

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

void fragment() {
	vec2 p = UV;
	float value = 0.0;
	for (int i = 0; i < 8; i++) {
		if (float(i) >= strings) {
			break;
		}
		float k = float(i);
		float base = (k + 0.5) / strings;
		// Each string vibrates with its own pitch; the amplitude decays and a node sits at each end.
		float pitch = 10.0 + 9.0 * hash(k);
		float decay = exp(-t * 3.6);
		float shake = sin(p.x * 3.14159 * (1.0 + floor(hash(k + 3.0) * 3.0))) * sin(t * pitch * 6.28318 + k) * 0.022 * decay;
		float d = abs(p.y - base - shake);
		float line = exp(-pow(d / 0.0045, 2.0));
		// Each line is only as long as the sound that crossed it.
		float start = 0.04 + 0.2 * hash(k + 7.0);
		float stop = 0.76 + 0.2 * hash(k + 11.0);
		float span = smoothstep(start, start + 0.08, p.x) * (1.0 - smoothstep(stop - 0.08, stop, p.x));
		value += line * span * (0.5 + 0.5 * hash(k + 5.0));
	}
	float life = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.55, 1.0, t));
	value *= life;
	ALBEDO = colour.rgb * value;
	EMISSION = colour.rgb * value * intensity;
}
