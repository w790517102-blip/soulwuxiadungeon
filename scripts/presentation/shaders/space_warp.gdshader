shader_type canvas_item;
// A mirage / heat-haze warp of the picture behind a rectangle: the finished frame (3D stage, cards
// and all, since this is a canvas pass drawn after the 3D world) is sampled through a wavering
// offset, shaped as a shock wave: a ring of strong distortion spreading from the centre, with a
// gentle wobble inside it. `t` runs 0..1 over its life. Presentation only.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float strength = 0.01;         // how far the picture is pushed (share of the screen)
uniform float seed = 0.0;
uniform float max_radius = 0.95;
uniform float ring_only = 0.0;         // 1: only the spreading ring bends the space (a mirage ring, nothing inside it)
uniform vec2 aspect = vec2(1.0, 1.0);  // the screen's width/height ratio, so the push is round

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
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float radius = max_radius * (1.0 - pow(1.0 - t, 2.4));
	float width = mix(0.28, 0.12, t);
	float ring = exp(-pow((r - radius) / width, 2.0) * 1.5);
	float inside = (1.0 - smoothstep(radius * 0.4, radius, r)) * 0.35 * (1.0 - ring_only);
	float life = 1.0 - smoothstep(0.5, 1.0, t);
	vec2 wave = vec2(noise(p * 5.0 + vec2(t * 6.0, seed)) - 0.5, noise(p * 5.0 + vec2(seed, -t * 6.0)) - 0.5) * 2.0;
	vec2 outward = normalize(p + vec2(0.0001)) * ring;
	vec2 offset = (wave * (ring + inside) + outward * 0.8) * strength * life * aspect;
	vec3 colour = texture(screen_texture, SCREEN_UV + offset).rgb;
	float edge = 1.0 - smoothstep(0.82, 1.0, r);
	COLOR = vec4(colour, edge * clamp((ring + inside) * life * 1.6, 0.0, 1.0));
}
