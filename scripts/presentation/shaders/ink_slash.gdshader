shader_type canvas_item;
// A sword cut painted by a shader: a dry-brush stroke whose bristles part toward the tail, a cloud
// layer that the blow tears open (the clouds are shoved aside and trail off behind), jittering
// black contours with afterimages, a dark-red core, halftone dots and speed lines at the impact.
// The quad it is drawn on spans the whole effect (uv 0..1, y down). Presentation only.

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform float angle = 0.42;            // the cut leans up to the right (radians, y up)
uniform float time_seed = 0.0;
uniform vec4 mint : source_color = vec4(0.40, 0.84, 0.66, 1.0);
uniform vec4 mint_deep : source_color = vec4(0.20, 0.58, 0.48, 1.0);
uniform vec4 mint_pale : source_color = vec4(0.86, 0.98, 0.93, 1.0);
uniform vec4 red : source_color = vec4(0.55, 0.06, 0.16, 1.0);
uniform vec4 ink : source_color = vec4(0.04, 0.04, 0.05, 1.0);

const float SWEEP_END = 0.34;
const float FADE_START = 0.80;

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

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amp * noise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return value;
}

float ease_out(float t) {
	t = clamp(t, 0.0, 1.0);
	return 1.0 - pow(1.0 - t, 3.0);
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Cut space: x runs along the cut (-1 start .. +1 end), y across it; the centre line bows
// downward so the belly faces the lower right, like a blade swung up and forward.
float centre_line(float x) {
	return -0.20 * (1.0 - x * x);
}

// Width of the stroke at x (fat in the first third, a long thin tail).
float width_at(float x, float scale) {
	float t = clamp((x + 1.0) * 0.5, 0.0, 1.0);
	return scale * pow(sin(3.14159 * pow(t, 0.52)), 1.2);
}

struct Stroke {
	float mask;      // 0..1 coverage
	float bristle;   // 0..1: how much the dry-brush gaps have eaten at this spot
	float side;      // -1 (lower edge) .. 1 (upper edge) across the stroke
	float t;         // 0 start .. 1 end along the cut
};

// The brush body at sweep head `head`; `jitter` shakes it, `thick` scales its width.
Stroke stroke_at(vec2 q, float head, float thick, float jitter_seed, float shift) {
	Stroke s;
	float x = q.x;
	float yc = centre_line(x) + shift;
	float d = q.y - yc;
	float w = width_at(x, 0.19 * thick);
	// Torn edge: the contour is eaten by noise that grows toward the tail.
	float t = clamp((x + 1.0) * 0.5, 0.0, 1.0);
	float tear = (fbm(vec2(x * 5.0, d * 3.0) + jitter_seed) - 0.5) * (0.04 + 0.16 * t);
	float norm = (d + tear) / max(w, 0.0001);
	// Head taper: the leading tip is pointed while the stroke is travelling.
	float ahead = clamp((head - x) / 0.25, 0.0, 1.0);
	norm /= max(ahead, 0.0001);
	float inside = 1.0 - smoothstep(0.82, 1.0, abs(norm));
	// Dry-brush bristles: parallel streaks along the cut that separate toward the tail.
	float strands = noise(vec2(norm * (7.0 + 5.0 * t), x * 1.4 + jitter_seed * 0.3));
	strands = 0.55 * strands + 0.45 * noise(vec2(norm * 17.0, x * 3.0 + jitter_seed));
	float cutoff = mix(0.08, 0.46, pow(t, 1.3));
	float bristle = smoothstep(cutoff - 0.07, cutoff + 0.07, strands);
	s.mask = inside * (x < head ? 1.0 : 0.0) * mix(1.0, bristle, smoothstep(0.1, 0.6, t));
	s.bristle = bristle;
	s.side = clamp(norm, -1.0, 1.0);
	s.t = t;
	return s;
}

vec4 over(vec4 below, vec4 above) {
	float a = above.a + below.a * (1.0 - above.a);
	vec3 c = (above.rgb * above.a + below.rgb * below.a * (1.0 - above.a)) / max(a, 0.0001);
	return vec4(c, a);
}

void fragment() {
	float fade = 1.0 - smoothstep(FADE_START, 1.0, progress);
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0;           // y up
	float step_time = floor(progress * 36.0);               // contours shake at ~36 fps
	vec2 shake = (vec2(hash(vec2(step_time, 1.3)), hash(vec2(step_time, 7.1))) - 0.5) * 0.012;
	vec2 q = rot(p + shake, -angle) * vec2(1.0 / 0.92, 1.0 / 0.92);

	float sweep = ease_out(progress / SWEEP_END);
	float head = mix(-1.15, 1.10, sweep);
	// The body is squashed along the blow like a ball flattened by an impact: thicker across
	// at the moment of the hit, then springing back.
	float squash = sin(clamp(progress / 0.5, 0.0, 1.0) * 3.14159) * (1.0 - smoothstep(0.5, 0.9, progress));
	float thick = 1.0 + 0.30 * squash;

	vec4 col = vec4(0.0);

	// --- Cloud layer torn open by the blow ---------------------------------------------------
	// Clouds are pushed away from the cut line and trail off behind the head.
	float yc = centre_line(q.x);
	float dist = q.y - yc;
	float behind = clamp((head - q.x), 0.0, 2.5);
	float push = exp(-dist * dist * 7.0) * 0.55 * smoothstep(-0.2, 0.4, behind) * sign(dist + 0.0001);
	vec2 cloud_p = vec2(q.x * 2.2 - progress * 1.2, (q.y + push) * 3.4) + vec2(3.0, time_seed);
	float cloud = fbm(cloud_p + fbm(cloud_p * 1.7) * 1.2);
	float reach = exp(-abs(dist) * 3.2) * smoothstep(-1.2, head, q.x) * (1.0 - smoothstep(head - 0.1, head + 0.3, q.x));
	float cloud_alpha = smoothstep(0.42, 0.62, cloud) * reach * 0.85;
	// Soft puffy shading and a dark rim where a cloud ends.
	float rim = smoothstep(0.42, 0.46, cloud) - smoothstep(0.50, 0.58, cloud);
	vec4 cloud_col = vec4(mix(mint_pale.rgb, vec3(0.62, 0.9, 0.82), cloud), cloud_alpha);
	col = over(col, cloud_col);
	col = over(col, vec4(ink.rgb, rim * reach * 0.18));

	// --- Afterimages (contours only, trailing behind) -------------------------------------------
	for (int g = 1; g <= 3; g++) {
		float lag = float(g) * 0.045;
		float old_head = mix(-1.15, 1.10, ease_out(max(progress - lag, 0.0) / SWEEP_END));
		Stroke ghost = stroke_at(q + vec2(-0.02 * float(g), 0.012 * float(g)), old_head, thick * (1.0 + 0.03 * float(g)), 3.1 * float(g), 0.0);
		float edge = smoothstep(0.05, 0.3, ghost.mask) - smoothstep(0.35, 0.8, ghost.mask);
		col = over(col, vec4(ink.rgb, edge * (0.38 - 0.09 * float(g))));
	}

	// --- Pale outer wash, the mint body, the white streak and the red core --------------------
	Stroke wash = stroke_at(q, head, thick * 1.30, 1.7, 0.02);
	col = over(col, vec4(mint_pale.rgb, wash.mask * 0.55));
	Stroke body = stroke_at(q, head, thick, 0.0, 0.0);
	vec3 body_col = mix(mint_deep.rgb, mint.rgb, smoothstep(-0.9, 0.2, body.side));
	col = over(col, vec4(body_col, body.mask));
	float streak_zone = smoothstep(0.35, 0.7, body.side) * (1.0 - smoothstep(0.78, 0.95, body.side));
	col = over(col, vec4(1.0, 1.0, 1.0, body.mask * streak_zone * 0.9 * (1.0 - body.t * 0.6)));

	float red_progress = ease_out((progress - 0.20) / 0.30);
	float red_head = mix(-0.85, 0.55, red_progress);
	Stroke core = stroke_at(q, red_head, thick * 0.40, 4.4, -0.035);
	col = over(col, vec4(red.rgb, core.mask * step(0.0001, red_progress)));
	// dark inner shading of the core
	Stroke core_inner = stroke_at(q, red_head, thick * 0.14, 5.1, -0.05);
	col = over(col, vec4(red.rgb * 0.45, core_inner.mask * step(0.0001, red_progress)));

	// --- Shaking contour, thick in places and hair-thin in others ---------------------------------
	float width_noise = 0.5 + 0.5 * noise(vec2(q.x * 7.0, q.y * 4.0) + step_time * 0.2);
	float inner_edge = 0.34 + 0.22 * width_noise;
	for (int pass = 0; pass < 2; pass++) {
		vec2 qq = q + (vec2(hash(vec2(step_time, float(pass))), hash(vec2(float(pass), step_time))) - 0.5) * 0.012 * float(pass);
		Stroke outline = stroke_at(qq, head, thick, 0.0, 0.0);
		float band = smoothstep(0.02, inner_edge * 0.6, outline.mask) - smoothstep(inner_edge, inner_edge + 0.5, outline.mask);
		col = over(col, vec4(ink.rgb, band * (pass == 0 ? 0.95 : 0.4)));
	}

	// --- Impact: speed lines and a halftone patch ---------------------------------------------------
	vec2 centre = rot(vec2(0.18, centre_line(0.18) + 0.02), angle);
	vec2 from_centre = p - centre;
	float radius = length(from_centre);
	float impact = clamp((sweep - 0.45) / 0.55, 0.0, 1.0);
	float ang = atan(from_centre.y, from_centre.x);
	float line_noise = noise(vec2(ang * 22.0, floor(progress * 12.0)));
	float lines = smoothstep(0.84, 0.93, line_noise) * smoothstep(0.30, 0.55, radius) * (1.0 - smoothstep(0.55, 1.0, radius - impact * 0.4));
	col = over(col, vec4(vec3(0.15), lines * impact * 0.55));
	vec2 grid = from_centre * 38.0;
	grid.x += floor(grid.y) * 0.5;
	float dots_radius = (1.0 - radius / (0.45 * max(impact, 0.01))) * 0.45;
	float dot_pattern = 1.0 - smoothstep(dots_radius - 0.06, dots_radius, length(fract(grid) - 0.5));
	col = over(col, vec4(vec3(0.22), dot_pattern * step(0.01, dots_radius) * 0.8 * impact));

	col.a *= fade;
	COLOR = col;
}
