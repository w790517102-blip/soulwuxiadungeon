shader_type spatial;
render_mode unshaded, cull_disabled;
// Procedural ink-wash paper for the back layer of a Card Stage card: dark ink with
// soft grey washes and vertical brush streaks. No texture assets; per-card seed.

uniform float seed = 0.0;
uniform vec4 ink_dark : source_color = vec4(0.030, 0.038, 0.052, 1.0);
uniform vec4 wash_light : source_color = vec4(0.26, 0.29, 0.34, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 p = UV * vec2(2.0, 3.0) + vec2(seed * 7.13, seed * 3.71);
	vec2 q = vec2(fbm(p), fbm(p + vec2(5.2, 1.3)));
	float wash = fbm(p + 2.4 * q);
	float streak = smoothstep(0.46, 0.78, fbm(vec2(UV.x * 1.4, UV.y * 6.0) + q * 1.6 + seed));
	vec3 colour = mix(ink_dark.rgb, wash_light.rgb, clamp(wash * wash * 1.25, 0.0, 1.0));
	colour = mix(colour, ink_dark.rgb, streak * 0.55);
	float vignette = smoothstep(0.98, 0.30, length(UV - vec2(0.5)) * 1.15);
	colour *= mix(0.50, 1.0, vignette);
	ALBEDO = colour;
}
