shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add;
// The brush-whip light: a very short, thin, cold-white streak like the tip of a whip, running along
// the stroke (UV.x along it, UV.y across). A bright head sweeps the length of the strip in an instant
// and the light behind it dies at once. `reveal` is the head's position (0..1) and `fade` (0..1)
// takes the light away. Presentation only.

uniform float reveal : hint_range(0.0, 1.2) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float intensity = 3.4;
uniform vec4 colour : source_color = vec4(0.94, 0.97, 1.0, 1.0);

void fragment() {
	float x = UV.x;
	float across = abs(UV.y - 0.5) * 2.0;
	// The lit part is only a short tail behind the head, brightest right at it.
	float behind = reveal - x;
	float lit = step(0.0, behind) * exp(-behind * 5.0);
	float core = 1.0 - smoothstep(0.0, 0.55, across);
	float tip = smoothstep(0.0, 0.08, x) * (1.0 - smoothstep(0.9, 1.0, x));
	float value = lit * core * tip * (1.0 - fade);
	ALBEDO = colour.rgb * value;
	EMISSION = colour.rgb * value * intensity;
}
