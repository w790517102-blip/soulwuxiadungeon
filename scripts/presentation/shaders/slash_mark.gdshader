shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;
// A long thin diagonal cut. UV.x runs along the blade's path (0 = where it enters, 1 = where
// it leaves), UV.y across. The mark is thickest in the middle and tapers to points at both
// ends; `reveal` draws it from the entry point. Two instances are layered: a soft white one
// outside and a hard blue one inside.

uniform vec3 color : source_color = vec3(1.0);
uniform float reveal = 0.0;
uniform float width_scale = 0.9;
uniform float softness = 0.35;
uniform float alpha_mul = 1.0;

void fragment() {
	float t = clamp(UV.x, 0.0, 1.0);
	float taper = pow(sin(3.14159265 * t), 0.75);
	float half_width = width_scale * taper;
	float d = abs(UV.y - 0.5) * 2.0;
	float body = 1.0 - smoothstep(half_width - softness, half_width + 0.002, d);
	body *= step(0.002, half_width);
	// The head of the stroke is a little soft so the cut reads as moving, not wiping.
	float drawn = smoothstep(reveal, reveal - 0.06, t);
	ALBEDO = color;
	ALPHA = body * drawn * alpha_mul;
}
