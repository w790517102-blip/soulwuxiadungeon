shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;
// A sharp, irregular, jagged star of sparks. `burst` (0..1) throws it outward from the
// centre; `vanish` (0..1) then removes it from the inside outward, leaving an outward-moving
// ring of sparks that thins away. Two layers are stacked: a translucent dark red base and a
// smaller goose-yellow top.

uniform vec4 color : source_color = vec4(0.55, 0.04, 0.05, 0.6);
uniform float burst = 0.0;
uniform float vanish = 0.0;
uniform float reach = 1.0;
uniform float seed = 0.0;

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 31.7) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x) + 3.14159265;
	const float N = 13.0;
	float k = angle / 6.2831853 * N;
	float i = floor(k);
	float f = fract(k);
	// Each bin is one spike with its own random length; the spike is a narrow point at the
	// middle of the bin, so the outline is a ragged star rather than a flower.
	float length_i = mix(0.35, 1.0, hash(i));
	float point = pow(clamp(1.0 - abs(f - 0.5) * 2.0, 0.0, 1.0), 1.7);
	float extent = (0.14 + length_i * point) * reach;
	float grown = extent * (1.0 - pow(1.0 - clamp(burst, 0.0, 1.0), 3.0));
	float inside = 1.0 - smoothstep(grown - 0.015, grown, r);
	// Gone from the centre outward.
	float inner_cut = vanish * grown * 1.05;
	float remaining = smoothstep(inner_cut - 0.02, inner_cut + 0.03, r);
	ALBEDO = color.rgb;
	ALPHA = inside * remaining * color.a * step(0.001, burst);
}
