shader_type spatial;
render_mode unshaded, cull_disabled;
// Character art on its own layer behind the card face. It is cropped to the
// template's art window: `clip_rect` is (min_x, min_y, max_x, max_y) in card-local
// units, so the art never spills outside the window, whatever its size.

uniform sampler2D art : source_color, filter_linear_mipmap;
uniform vec2 center = vec2(0.0);
uniform float size = 3.0;
uniform vec4 clip_rect = vec4(-1.0, -1.0, 1.0, 1.0);

void fragment() {
	vec2 local = center + vec2(UV.x - 0.5, 0.5 - UV.y) * size;
	if (local.x < clip_rect.x || local.x > clip_rect.z || local.y < clip_rect.y || local.y > clip_rect.w) {
		discard;
	}
	vec4 colour = texture(art, UV);
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
}
