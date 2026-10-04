shader_type spatial;
render_mode unshaded, cull_disabled;
// Character art on its own layer behind the card face. It is cropped to the
// template's art window: `clip_rect` is (min_x, min_y, max_x, max_y) in card-local
// units, so the art never spills outside the window, whatever its size.

uniform sampler2D art : source_color, filter_linear_mipmap;
uniform vec2 center = vec2(0.0);
uniform vec2 size = vec2(3.0);
uniform vec4 clip_rect = vec4(-1.0, -1.0, 1.0, 1.0);
// 0..1: the card has had its turn this round - darker and less saturated.
uniform float dim : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 local = center + vec2(UV.x - 0.5, 0.5 - UV.y) * size;
	if (local.x < clip_rect.x || local.x > clip_rect.z || local.y < clip_rect.y || local.y > clip_rect.w) {
		discard;
	}
	vec4 colour = texture(art, UV);
	float grey = dot(colour.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(colour.rgb, vec3(grey), dim * 0.7) * (1.0 - 0.5 * dim);
	ALPHA = colour.a;
}
