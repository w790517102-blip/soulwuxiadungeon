shader_type spatial;
render_mode unshaded, cull_disabled;
// Character art on its own layer between the ink back and the card face. It is
// cropped inside the frame: `clip_x` is the half-width at the frame's inner edge,
// `clip_top` the card top, and everything below `clip_y` (the information band) is
// discarded, so the art never spills outside the card.

uniform sampler2D art : source_color, filter_linear_mipmap;
uniform float center_x = 0.0;
uniform float center_y = 0.0;
uniform float size = 3.0;
uniform float clip_y = -0.24;
uniform float clip_x = 1.04;
uniform float clip_top = 1.70;

void fragment() {
	float local_y = center_y + (0.5 - UV.y) * size;
	float local_x = center_x + (UV.x - 0.5) * size;
	if (local_y < clip_y || local_y > clip_top || abs(local_x) > clip_x) {
		discard;
	}
	vec4 colour = texture(art, UV);
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
}
