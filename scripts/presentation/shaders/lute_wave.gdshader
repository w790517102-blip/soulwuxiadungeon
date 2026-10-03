shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// The body of a plucked string's pressure wave: a thin, translucent half-moon of silver-white light
// with a ragged, streaked texture (torn like a sword's slash trace, never an even halo) and a ghosted
// trail behind it. Drawn twice: once white (the sound-light) and once dark (the sound-shadow, which
// rides slower so the two slide apart like a Doppler shift). The quad faces the camera and the
// crescent bows toward +x. `t` (0..1) shapes its life. Presentation only.

uniform float t : hint_range(0.0, 1.0) = 0.0;
uniform float arc = 0.9;                  // how far around the crescent curves
uniform float thickness = 0.10;           // thickness of the half-moon at its middle, in quad units
uniform float opacity = 0.7;              // overall opacity of the wave
uniform float trail = 0.8;                // how much of a ghosted trail follows behind it
uniform float emission_strength = 1.5;
uniform float raggedness = 0.55;          // how irregular the edge and body are
uniform float seed = 0.0;
uniform vec4 tone : source_color = vec4(0.93, 0.96, 1.0, 1.0);

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
	float radius = 0.95 / max(arc, 0.05);
	vec2 front_centre = vec2(0.5 - radius, 0.0);
	// Distance from the bowed front, positive ahead of the wave. The front itself is jittered so the
	// leading edge is torn rather than smooth.
	float tear = (noise(vec2(p.y * 7.0 + seed, seed * 1.7)) - 0.5) * 0.09 * raggedness
		+ (noise(vec2(p.y * 21.0 + seed * 3.0, 4.0)) - 0.5) * 0.035 * raggedness;
	float d = length(p - front_centre) - radius + tear;
	float along = 1.0 - smoothstep(0.30, 1.0, abs(p.y));
	float horn = pow(along, 0.8);
	// Thin band hugging the front.
	float band = exp(-pow((d + thickness * 0.5) / (thickness * 0.75), 2.0));
	// Streaks: strands running along the wave's travel (x), as in a brush stroke or a blade trace.
	float strands = noise(vec2(p.y * 26.0 + seed, 0.5)) * 0.65 + noise(vec2(p.y * 61.0 - seed, 2.0)) * 0.35;
	float streak = mix(1.0, smoothstep(0.22, 0.78, strands), raggedness);
	// Breaks along the arc: parts of the band dim or go missing.
	float gaps = mix(1.0, smoothstep(0.18, 0.55, noise(vec2(p.y * 5.0 + seed * 2.0, 9.0))), raggedness * 0.9);
	float body = band * streak * gaps * horn;
	// Ghost copies pulled out behind the front; they are streakier still and fray into the air.
	float ghost = 0.0;
	for (int i = 1; i <= 3; i++) {
		float k = float(i);
		float lag = exp(-pow((d + thickness * 0.5 + 0.10 * k) / (thickness * 0.8 + 0.025 * k), 2.0));
		float frayed = smoothstep(0.30, 0.75, noise(vec2(p.y * (30.0 + 9.0 * k) + seed * k, k * 3.1)));
		ghost += lag * mix(1.0, frayed, raggedness) * horn * (0.5 / k) * trail;
	}
	float life = smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.86, 1.0, t));
	float value = clamp(body + ghost, 0.0, 1.0) * life;
	ALBEDO = tone.rgb;
	ALPHA = value * opacity;
	EMISSION = tone.rgb * value * emission_strength * opacity;
}
