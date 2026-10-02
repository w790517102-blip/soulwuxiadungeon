extends Node2D
## A sword cut drawn entirely with Godot 2D shapes (no bitmap): a mint-green crescent with a
## dark-red core under it, black contour lines, a burst of ink flecks with a halftone patch, and
## speed lines radiating across the frame. Meant as a flat, hand-inked "comic" slash.
##
## Set `progress` from 0 to 1 to animate it (sweep, hold, fade). `canvas_size` is the square it
## is drawn in; everything scales with it. Presentation only.

const MINT := Color(0.40, 0.84, 0.66)
const MINT_DARK := Color(0.25, 0.62, 0.50)
const MINT_LIGHT := Color(0.86, 0.98, 0.93)
const RED := Color(0.55, 0.07, 0.17)
const RED_DARK := Color(0.30, 0.02, 0.08)
const INK := Color(0.05, 0.05, 0.06)

@export var canvas_size: float = 512.0
@export_range(0.0, 1.0) var progress: float = 1.0:
	set(value):
		progress = value
		queue_redraw()
## Tilt of the whole cut (radians, screen coordinates: positive leans down to the right).
@export var tilt: float = 0.40

var _rng := RandomNumberGenerator.new()

# Sweep timing (fractions of `progress`).
const SWEEP_END := 0.34
const RED_START := 0.22
const RED_END := 0.50
const FADE_START := 0.80


func _ready() -> void:
	queue_redraw()


func _centre() -> Vector2:
	return Vector2(canvas_size * 0.5, canvas_size * 0.52)


## A point on the cut's ellipse. `u` is the angle in the ellipse's own frame (PI = left end,
## PI/2 = bottom, 0 = right end); `grow` scales the radii, `shift` moves the whole ellipse.
func _ellipse_point(u: float, rx: float, ry: float, shift: Vector2 = Vector2.ZERO) -> Vector2:
	var local := Vector2(cos(u) * rx, sin(u) * ry)
	return _centre() + shift + local.rotated(tilt)


func _ellipse_normal_inward(u: float, rx: float, ry: float) -> Vector2:
	var local_inward := Vector2(-cos(u) / rx, -sin(u) / ry).normalized()
	return local_inward.rotated(tilt)


## A tapered band hugging the ellipse between angles `from_u` (start, larger) and `to_u` (end).
## `reveal_u` cuts the band off early (the sweep head). Returns [outer, inner] point lists.
func _band(from_u: float, to_u: float, reveal_u: float, rx: float, ry: float, thickness: float, shift: Vector2, bias: float) -> Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps: int = 56
	for index: int in range(steps + 1):
		var t: float = float(index) / float(steps)
		var u: float = lerpf(from_u, to_u, t)
		if u < reveal_u:
			break
		# Fat toward the start, a long thin tail at the end; the head is pointed while sweeping.
		var width: float = thickness * pow(sin(PI * pow(t, 0.5)), 1.35)
		var head_taper: float = clampf((u - reveal_u) / 0.30, 0.0, 1.0)
		width *= head_taper
		var base: Vector2 = _ellipse_point(u, rx, ry, shift)
		var inward: Vector2 = _ellipse_normal_inward(u, rx, ry)
		outer.append(base - inward * width * (1.0 - bias))
		inner.append(base + inward * width * bias)
	return [outer, inner]


func _polygon_from_band(band: Array) -> PackedVector2Array:
	var outer: PackedVector2Array = band[0]
	var inner: PackedVector2Array = band[1]
	var polygon := PackedVector2Array()
	polygon.append_array(outer)
	for index: int in range(inner.size() - 1, -1, -1):
		polygon.append(inner[index])
	return polygon


func _eased(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _draw() -> void:
	_rng.seed = 7
	var fade: float = 1.0 - clampf((progress - FADE_START) / (1.0 - FADE_START), 0.0, 1.0)
	if fade <= 0.0:
		return
	var s: float = canvas_size / 512.0
	var sweep: float = _eased(progress / SWEEP_END)
	var rx: float = 225.0 * s
	var ry: float = 112.0 * s

	_draw_speed_lines(sweep, fade, s)
	_draw_far_arc(sweep, fade, rx, ry, s)

	# Mint crescent.
	var head: float = lerpf(3.45, -0.25, sweep)
	var green_band: Array = _band(3.45, -0.25, head, rx, ry, 74.0 * s, Vector2.ZERO, 0.55)
	_fill_band(green_band, MINT, INK, fade, 2.2 * s)
	_draw_highlight(green_band, fade, s)
	# Dark red core inside the green, nearer its inner edge (appears a little later).
	var red_sweep: float = _eased((progress - RED_START) / (RED_END - RED_START))
	if red_sweep > 0.0:
		var red_head: float = lerpf(3.05, 0.75, red_sweep)
		var red_band: Array = _band(3.05, 0.75, red_head, rx * 0.97, ry * 0.97, 44.0 * s, Vector2(2, 5) * s, 0.85)
		_fill_band(red_band, RED, RED_DARK, fade, 1.6 * s)
	_draw_edge_whiskers(sweep, fade, rx, ry, s)

	_draw_burst(sweep, fade, s)


func _fill_band(band: Array, fill: Color, line: Color, fade: float, line_width: float) -> void:
	var polygon: PackedVector2Array = _polygon_from_band(band)
	if polygon.size() < 4:
		return
	var faded_fill := Color(fill.r, fill.g, fill.b, fill.a * fade)
	var faded_line := Color(line.r, line.g, line.b, fade)
	draw_colored_polygon(polygon, faded_fill)
	var outer: PackedVector2Array = band[0]
	var inner: PackedVector2Array = band[1]
	if outer.size() > 1:
		draw_polyline(outer, faded_line, line_width, true)
		draw_polyline(inner, faded_line, line_width * 0.6, true)


## The pale streak along the upper edge of the green band.
func _draw_highlight(band: Array, fade: float, s: float) -> void:
	var outer: PackedVector2Array = band[0]
	var inner: PackedVector2Array = band[1]
	if outer.size() < 6:
		return
	var streak := PackedVector2Array()
	var back := PackedVector2Array()
	var count: int = outer.size()
	for index: int in range(2, count - 6):
		var t: float = float(index) / float(count)
		var edge: Vector2 = outer[index].lerp(inner[index], 0.06)
		var in_edge: Vector2 = outer[index].lerp(inner[index], 0.06 + 0.16 * sin(PI * t))
		streak.append(edge)
		back.append(in_edge)
	if streak.size() < 3:
		return
	var polygon := PackedVector2Array()
	polygon.append_array(streak)
	for index: int in range(back.size() - 1, -1, -1):
		polygon.append(back[index])
	draw_colored_polygon(polygon, Color(MINT_LIGHT.r, MINT_LIGHT.g, MINT_LIGHT.b, 0.92 * fade))


## Little curled barbs and slivers that peel off the leading end of the cut.
func _draw_edge_whiskers(sweep: float, fade: float, rx: float, ry: float, s: float) -> void:
	if sweep < 0.2:
		return
	var color := Color(MINT.r, MINT.g, MINT.b, fade)
	var line := Color(INK.r, INK.g, INK.b, fade)
	for index: int in range(6):
		var u: float = lerpf(3.25, 2.4, float(index) / 5.0)
		var base: Vector2 = _ellipse_point(u, rx, ry)
		var inward: Vector2 = _ellipse_normal_inward(u, rx, ry)
		var tangent: Vector2 = (_ellipse_point(u - 0.05, rx, ry) - base).normalized()
		var length: float = (26.0 + 18.0 * sin(float(index) * 1.7)) * s * sweep
		var tip: Vector2 = base - inward * length * 0.9 - tangent * length * 0.5
		var left: Vector2 = base + tangent * 3.0 * s
		var right: Vector2 = base - tangent * 5.0 * s
		draw_colored_polygon(PackedVector2Array([left, tip, right]), color)
		draw_polyline(PackedVector2Array([left, tip, right]), line, 1.2 * s, true)


## The faint far side of the ring: a thin double contour with scattered flecks.
func _draw_far_arc(sweep: float, fade: float, rx: float, ry: float, s: float) -> void:
	if sweep <= 0.3:
		return
	var alpha: float = clampf((sweep - 0.3) / 0.7, 0.0, 1.0) * fade
	var points := PackedVector2Array()
	for index: int in range(40):
		var u: float = lerpf(-0.15, -1.9, float(index) / 39.0)
		points.append(_ellipse_point(u, rx * 1.02, ry * 1.05))
	draw_polyline(points, Color(0.2, 0.2, 0.22, 0.55 * alpha), 1.4 * s, true)
	for index: int in range(28):
		var u: float = _rng.randf_range(-1.7, -0.1)
		var jitter := Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-12.0, 12.0)) * s
		var radius: float = _rng.randf_range(0.8, 3.2) * s
		draw_circle(_ellipse_point(u, rx * 1.02, ry * 1.05) + jitter, radius, Color(INK.r, INK.g, INK.b, 0.85 * alpha))


func _draw_speed_lines(sweep: float, fade: float, s: float) -> void:
	var impact: float = clampf((sweep - 0.45) / 0.55, 0.0, 1.0)
	if impact <= 0.0:
		return
	var centre: Vector2 = _centre() + Vector2(-18, -18) * s
	for index: int in range(46):
		var angle: float = TAU * float(index) / 46.0 + _rng.randf_range(-0.05, 0.05)
		var direction := Vector2.from_angle(angle)
		var start: float = _rng.randf_range(0.40, 0.74) * canvas_size * 0.5
		var length: float = _rng.randf_range(0.14, 0.42) * canvas_size * impact
		var width: float = _rng.randf_range(1.0, 4.2) * s
		var tone: float = _rng.randf_range(0.1, 0.55)
		var normal := direction.orthogonal()
		var a: Vector2 = centre + direction * start
		var b: Vector2 = centre + direction * (start + length)
		draw_colored_polygon(PackedVector2Array([a + normal * width * 0.5, b, a - normal * width * 0.5]), Color(tone, tone, tone, 0.9 * fade))


## Ink fragments and a halftone patch at the point of impact.
func _draw_burst(sweep: float, fade: float, s: float) -> void:
	var impact: float = clampf((sweep - 0.4) / 0.6, 0.0, 1.0)
	if impact <= 0.0:
		return
	var centre: Vector2 = _centre() + Vector2(-16, -10) * s
	# Halftone: a hex grid of dots that shrink away from the centre.
	var spacing: float = 7.0 * s
	for row: int in range(-9, 10):
		for column: int in range(-9, 10):
			var offset := Vector2(float(column) * spacing + (spacing * 0.5 if row % 2 != 0 else 0.0), float(row) * spacing * 0.87)
			var distance: float = offset.length()
			var reach: float = 88.0 * s * impact
			if distance > reach:
				continue
			var radius: float = (1.0 - distance / reach) * 3.0 * s
			if radius > 0.4:
				draw_circle(centre + offset, radius, Color(0.25, 0.27, 0.28, 0.75 * fade))
	# Jagged ink flecks thrown outwards, with a few near the cut.
	for index: int in range(80):
		var angle: float = _rng.randf_range(0.0, TAU)
		var distance: float = pow(_rng.randf(), 1.5) * 200.0 * s * impact + 8.0 * s
		var size: float = _rng.randf_range(1.5, 7.5) * s * (1.2 - distance / (230.0 * s))
		var point: Vector2 = centre + Vector2.from_angle(angle) * distance
		var shard := PackedVector2Array()
		var corners: int = _rng.randi_range(3, 5)
		for corner: int in range(corners):
			var corner_angle: float = TAU * float(corner) / float(corners) + _rng.randf_range(-0.4, 0.4)
			shard.append(point + Vector2.from_angle(corner_angle) * size * _rng.randf_range(0.5, 1.5))
		draw_colored_polygon(shard, Color(INK.r, INK.g, INK.b, 0.95 * fade))
	# A few mint specks mixed in.
	for index: int in range(14):
		var angle2: float = _rng.randf_range(0.0, TAU)
		var distance2: float = _rng.randf_range(20.0, 120.0) * s * impact
		draw_circle(centre + Vector2.from_angle(angle2) * distance2, _rng.randf_range(1.0, 3.5) * s, Color(MINT.r, MINT.g, MINT.b, 0.9 * fade))
