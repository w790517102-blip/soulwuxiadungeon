shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
// A bright white spark particle: its colour (and fade) come from the particle's colour ramp, and it
// is emitted brighter than white (HDR) so the stage's glow makes it shine. Presentation only.

uniform float intensity = 2.6;

void fragment() {
	// Soft round falloff when drawn on a square quad (dots); streak quads simply use the same fade.
	vec2 p = (UV - 0.5) * 2.0;
	float soft = 1.0 - smoothstep(0.55, 1.0, length(vec2(p.x * 0.6, p.y * 0.35)));
	float value = COLOR.a * clamp(soft * 1.6, 0.0, 1.0);
	ALBEDO = COLOR.rgb * value;
	EMISSION = COLOR.rgb * value * intensity;
}
