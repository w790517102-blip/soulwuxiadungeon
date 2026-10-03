shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// One shock wave of a punch: a circle spreading from the contact point, drawn as a broad band of
// ink with a soft glow riding its outer edge (no thin outline). The band is thickest as it leaves
// and thins as it spreads; its edge is uneven and a little cloudy, but it stays a circle. `t` runs
// 0..1 over the wave's life; every wave of a hit shares the same `t`, so they vanish together. The
// first wave may also darken the centre (`centre_dim`). Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float max_radius = 0.9;           // final radius, as a share of the quad (0..1)
uniform float speed = 2.6;                // how fast it leaves (higher = more explosive, then slows)
uniform float centre_dim = 0.0;           // 0..1: how much the middle darkens
uniform vec4 ink : source_color = vec4(0.015, 0.015, 0.02, 1.0);
uniform vec4 glow : source_color = vec4(0.82, 0.90, 0.96, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float travel = 1.0 - pow(1.0 - t, speed);
	float radius = max_radius * (0.08 + 0.92 * travel);
	// A gentle unevenness of the edge (still a circle).
	float edge_wobble = (noise(vec2(ang * 2.0 + seed, seed)) - 0.5) * 0.05 + (noise(vec2(ang * 5.0 + seed * 2.0, t * 2.0)) - 0.5) * 0.025;
	float d = r - radius - edge_wobble;
	float width = mix(0.22, 0.07, travel);
	// The ink band: dark and broad, soft on both sides.
	float band = exp(-pow(d / width, 2.0) * 1.6);
	// Cloudiness: the band is not a flat dark fill but breaks up softly.
	float cloud = 0.65 + 0.35 * noise(vec2(ang * 4.0 + seed, r * 7.0 - t * 3.0));
	// A glow on the outer side of the band (a wide soft halo rather than a line).
	float halo = exp(-pow((d - width * 0.55) / (width * 1.7), 2.0) * 1.3);
	// The centre dims after the flash.
	float dim = centre_dim * (1.0 - smoothstep(0.0, radius * 0.8, r)) * smoothstep(0.05, 0.25, t);
	float life = 1.0 - smoothstep(0.55, 1.0, t);
	float a_ink = clamp(band * cloud * 0.8 + dim * 0.55, 0.0, 1.0) * life;
	float a_glow = halo * (1.0 - band * 0.6) * 0.55 * life;
	float alpha = a_glow + a_ink * (1.0 - a_glow);
	vec3 colour = (glow.rgb * a_glow + ink.rgb * a_ink * (1.0 - a_glow)) / max(alpha, 0.001);
	ALBEDO = colour;
	ALPHA = alpha;
	EMISSION = glow.rgb * a_glow * 0.9;
}
