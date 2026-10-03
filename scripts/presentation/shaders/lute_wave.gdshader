shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add;
// The pressure wave of a plucked string: a very thin, bright, cold-white crescent (a wavefront seen
// edge-on), bowed toward the way it travels. Not a missile: it has no body, only a crisp front and a
// faint second echo behind it. The quad faces the camera; the front bows toward +x. `t` (0..1)
// shapes its life; `echo` is the strength of the second, fainter front. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float arc = 0.9;                  // how far around the front curves (0 = nearly straight)
uniform float thickness = 0.012;          // half-thickness of the front, in quad units
uniform float intensity = 2.6;
uniform vec4 colour : source_color = vec4(0.92, 0.96, 1.0, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	// A crescent: the front is a circle arc centred behind the quad, so it bows toward +x.
	float radius = 0.95 / max(arc, 0.05);
	vec2 centre = vec2(0.45 - radius, 0.0);
	float d = length(p - centre) - radius;
	float front = exp(-pow(d / thickness, 2.0));
	float echo = exp(-pow((d + 0.10) / (thickness * 1.8), 2.0)) * 0.35;
	// The front is brightest in the middle of the arc and dies toward its horns.
	float along = 1.0 - smoothstep(0.35, 1.0, abs(p.y));
	// A faint glow either side of the front, like the air itself being squeezed.
	float glow = exp(-pow(d / (thickness * 6.0), 2.0)) * 0.18;
	float life = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.82, 1.0, t));
	float value = (front + echo + glow) * along * life;
	ALBEDO = colour.rgb * value;
	EMISSION = colour.rgb * value * intensity;
}
