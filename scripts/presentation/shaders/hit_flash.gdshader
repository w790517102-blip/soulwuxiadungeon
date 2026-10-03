shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
// The core flash of a hit: a tiny white-hot burst with a short cross of cracking light. Drawn on a
// camera-facing quad (uv 0..1) and brighter than white (HDR) so the stage's glow picks it up.
// `t` runs 0..1 over the flash's life. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float angle = 0.5;           // the cross is turned this much (radians)
uniform float intensity = 3.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float c = cos(angle);
	float s = sin(angle);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	float r = length(p);
	// A white-hot core that shrinks as it fades.
	float core = exp(-r * r * mix(10.0, 26.0, t));
	// A cross of thin cracks of light: sharp, long on one diagonal axis, short on the other.
	float bar_a = exp(-abs(q.y) * 55.0) * (1.0 - smoothstep(0.0, 0.95, abs(q.x)));
	float bar_b = exp(-abs(q.x) * 70.0) * (1.0 - smoothstep(0.0, 0.55, abs(q.y)));
	float flare = (bar_a + 0.7 * bar_b) * (1.0 - t);
	float life = 1.0 - smoothstep(0.35, 1.0, t);
	float value = clamp(core + flare, 0.0, 1.0) * life;
	vec3 colour = mix(vec3(0.85, 0.92, 1.0), vec3(1.0), core);
	ALBEDO = colour * value;
	EMISSION = colour * value * intensity;
}
