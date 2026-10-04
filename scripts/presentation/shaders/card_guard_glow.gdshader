shader_type canvas_item;
render_mode blend_add;
// The card's own interface while its owner guards: a cold white-blue glow breathing slowly along
// the card's frame, a pale-blue glow in the name and status boxes, and only a faint cold highlight
// over the portrait (the picture stays readable). Drawn over the card face; the rectangle's UV spans
// the card frame. `amount` (0..1) fades the whole thing in and out. Presentation only.

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec2 size_px = vec2(800.0, 1300.0);
uniform vec4 name_rect = vec4(0.0);      // x, y, w, h in UV
uniform vec4 info_rect = vec4(0.0);      // the status / hp boxes
uniform vec4 window_rect = vec4(0.0);    // the portrait window
uniform float seed = 0.0;
uniform vec4 ice_tone : source_color = vec4(0.40, 0.72, 1.0, 1.0);
uniform vec4 white_tone : source_color = vec4(0.82, 0.93, 1.0, 1.0);

float rect_glow(vec2 uv, vec4 r, float soft) {
	if (r.z <= 0.0) {
		return 0.0;
	}
	vec2 c = r.xy + r.zw * 0.5;
	vec2 half_size = r.zw * 0.5;
	vec2 d = abs(uv - c) - half_size;
	float outside = length(max(d, 0.0));
	float inside = min(max(d.x, d.y), 0.0);
	// A glow hugging the box's border, strongest at the edge.
	return exp(-pow((outside + inside * 0.0) / soft, 2.0)) * (1.0 - smoothstep(0.0, 0.5, -inside * 6.0));
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float breath = 0.65 + 0.35 * sin(t * 1.15 + seed);
	float hue = 0.5 + 0.5 * sin(t * 0.62 + seed * 1.7);
	vec3 colour = mix(ice_tone.rgb, white_tone.rgb, hue * 0.7);
	// Frame: distance to the edge in pixels.
	float edge_px = min(min(uv.x * size_px.x, (1.0 - uv.x) * size_px.x), min(uv.y * size_px.y, (1.0 - uv.y) * size_px.y));
	float frame = exp(-edge_px / 16.0) * 0.8 + exp(-edge_px / 46.0) * 0.18;
	float boxes = rect_glow(uv, name_rect, 0.012) * 0.55 + rect_glow(uv, info_rect, 0.012) * 0.45;
	// Over the portrait only a faint cold sheen near its top edge.
	vec2 wc = window_rect.xy + window_rect.zw * 0.5;
	vec2 wd = abs(uv - wc) - window_rect.zw * 0.5;
	float in_window = 1.0 - smoothstep(-0.01, 0.0, max(wd.x, wd.y));
	float sheen = in_window * smoothstep(0.55, 0.0, (uv.y - window_rect.y) / max(window_rect.w, 0.001)) * 0.07;
	float value = (frame + boxes + sheen) * breath * amount;
	COLOR = vec4(colour * value, value);
}
