shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;
// The 替身符 glyph, revealed in writing order. `progress_tex` stores, for every pixel, how far
// into the writing it gets inked (0..1); `mask_tex` is the glyph itself.
//   crisp = true  : the dry black brush: hard edge, never bleeds.
//   crisp = false : the wet brush: blurred (mip levels), spreads as each part ages.

uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D progress_tex : filter_linear_mipmap, repeat_disable;
uniform bool crisp = true;
uniform float reveal = 0.0;
uniform float extra_age = 0.0;
uniform float fade = 0.0;
uniform float pull = 0.0;
uniform float alpha_mul = 1.0;

void fragment() {
	float progress = textureLod(progress_tex, UV, crisp ? 0.0 : 1.0).r;
	float drawn = crisp ? step(progress, reveal) : step(progress, reveal + 0.012);
	float alpha;
	if (crisp) {
		float m = texture(mask_tex, UV).r;
		alpha = smoothstep(0.42, 0.62, m);
	} else {
		float age = clamp((reveal - progress) * 3.0 + extra_age, 0.0, 1.0);
		float m = textureLod(mask_tex, UV, mix(1.2, 3.4, age)).r;
		float threshold = mix(0.30, 0.10, age) + 0.22 * pull;
		alpha = smoothstep(threshold, threshold + 0.35, m) * 0.85;
	}
	ALBEDO = vec3(0.0);
	ALPHA = alpha * drawn * (1.0 - fade) * alpha_mul;
}
