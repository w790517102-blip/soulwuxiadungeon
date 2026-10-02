extends Node2D
## A sword cut drawn entirely with Godot 2D shapes (no bitmap), swung from our side toward the
## upper right. It is not one smooth crescent but a stack of "envelope" surfaces, each with its
## own scalloped, surging edge like cloud or wave crests, so the cut reads as an impact. The
## whole body is squashed along the line of force like a dodgeball flattened by a hit (never a
## round ball), the contour lines jitter, leave afterimages and change thickness along their length.
##
## Set `progress` from 0 to 1 (sweep, hold, fade). `canvas_size` is the square it is drawn in.
## Presentation only.

const MINT_PALE := Color(0.80, 0.97, 0.91)
const MINT := Color(0.40, 0.84, 0.66)
const MINT_DEEP := Color(0.22, 0.60, 0.50)
const RED := Color(0.55, 0.07, 0.17)
const RED_DARK := Color(0.30, 0.02, 0.08)
const WHITE := Color(1.0, 1.0, 1.0)
const INK := Color(0.05, 0.05, 0.06)

@export var canvas_size: float = 512.0
@export_range(0.0, 1.0) var progress: float = 1.0:
	set(value):
		progress = value
		queue_redraw()
## Tilt of the cut (radians; negative = leaning up to the right, the way our side strikes).
@export var tilt: float = -0.42

const SWEEP_END := 0.34
const RED_START := 0.20
const RED_END := 0.50
const FADE_START := 0.80
## Afterimages of the contour, as how far back in `progress` each one trails.
const GHOSTS: Array[float] = [0.035, 0.07, 0.11]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	queue_redraw()


func _centre() -> Vector2:
	return Vector2(canvas_size * 0.5, canvas_size * 0.50)


func _eased(value: float) -> float:
	return 1.0 - pow(1.0 - clampf(value, 0.0, 1.0), 3.0)


## 0..1..0 hump over the sweep: how hard the cut is being squashed by the blow.
func _squash(at: float) -> float:
	var t: float = clampf(at / 0.5, 0.0, 1.0)
	return sin(t * PI) * (1.0 - clampf((at - 0.5) / 0.4, 0.0, 1.0))


## Ellipse radii: long along the cut and flattened across it (never a ball), flatter still at
## the instant of impact and springing back afterwards.
func _radii(at: float) -> Vector2:
	var s: float = canvas_size / 512.0
	var flat: float = 1.0 - 0.38 * _squash(at)
	return Vector2(232.0 * s * (1.0 + 0.06 * _squash(at)), 88.0 * s * flat)


func _point(u: float, radii: Vector2, shift: Vector2 = Vector2.ZERO) -> Vector2:
	return _centre() + shift + Vector2(cos(u) * radii.x, sin(u) * radii.y).rotated(tilt)


func _inward(u: float, radii: Vector2) -> Vector2:
	return Vector2(-cos(u) / radii.x, -sin(u) / radii.y).normalized().rotated(tilt)


## Scalloped cloud/wave crest: rounded lobes with cusps between them, drifting with `phase`.
func _crest(u: float, lobes: float, phase: float) -> float:
	return pow(absf(sin(u * lobes + phase)), 0.55)


## One envelope: the points of its outer and inner edge. `layer` shifts its size, lobes and phase,
## `reveal_u` is the sweep head (the tip is pointed while it travels).
func _envelope(layer: Dictionary, at: float, reveal_u: float) -> Array:
	var radii: Vector2 = _radii(at)
	var s: float = canvas_size / 512.0
	var from_u: float = layer.from
	var to_u: float = layer.to
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps: int = 70
	for index: int in range(steps + 1):
		var t: float = float(index) / float(steps)
		var u: float = lerpf(from_u, to_u, t)
		if u < reveal_u:
			break
		var profile: float = pow(sin(PI * pow(t, 0.5)), 1.25)
		var taper: float = clampf((u - reveal_u) / 0.28, 0.0, 1.0)
		var thickness: float = float(layer.thick) * s * profile * taper
		# The edge surges: lobes ride along the cut as it is swung, strongest where it is fat.
		var surge: float = float(layer.surge) * s * profile * taper * _crest(u, float(layer.lobes), float(layer.phase) + at * 9.0)
		var base: Vector2 = _point(u, radii, Vector2(layer.shift) * s)
		var inward: Vector2 = _inward(u, radii)
		outer.append(base - inward * (thickness * (1.0 - float(layer.bias)) + surge))
		inner.append(base + inward * (thickness * float(layer.bias) - surge * 0.35))
	return [outer, inner]


func _polygon(edges: Array) -> PackedVector2Array:
	var outer: PackedVector2Array = edges[0]
	var inner: PackedVector2Array = edges[1]
	var polygon := PackedVector2Array()
	polygon.append_array(outer)
	for index: int in range(inner.size() - 1, -1, -1):
		polygon.append(inner[index])
	return polygon


func _layers() -> Array:
	return [
		# Outermost, palest, widest: the shock-wave of the cut.
		{"from": 3.55, "to": -0.35, "thick": 118.0, "surge": 22.0, "lobes": 9.0, "phase": 0.0, "shift": Vector2(8, -6), "bias": 0.5, "color": Color(MINT_PALE.r, MINT_PALE.g, MINT_PALE.b, 0.72)},
		{"from": 3.45, "to": -0.25, "thick": 96.0, "surge": 17.0, "lobes": 7.0, "phase": 1.7, "shift": Vector2(3, -2), "bias": 0.52, "color": MINT},
		{"from": 3.30, "to": -0.05, "thick": 72.0, "surge": 12.0, "lobes": 11.0, "phase": 3.1, "shift": Vector2(0, 2), "bias": 0.55, "color": MINT_DEEP},
		{"from": 3.15, "to": 0.30, "thick": 50.0, "surge": 8.0, "lobes": 6.0, "phase": 4.4, "shift": Vector2(-3, 6), "bias": 0.7, "color": RED, "late": true},
		{"from": 3.00, "to": 0.70, "thick": 22.0, "surge": 5.0, "lobes": 8.0, "phase": 5.2, "shift": Vector2(-3, 8), "bias": 0.8, "color": RED_DARK, "late": true},
	]


func _draw() -> void:
	_rng.seed = 7
	var fade: float = 1.0 - clampf((progress - FADE_START) / (1.0 - FADE_START), 0.0, 1.0)
	if fade <= 0.0:
		return
	# The cut is struck from the lower left toward the upper right: mirror vertically so the
	# tilted ellipse starts low on our side.
	draw_set_transform(Vector2(0.0, canvas_size), 0.0, Vector2(1.0, -1.0))
	var sweep: float = _eased(progress / SWEEP_END)
	_draw_speed_lines(sweep, fade)
	_draw_far_arc(sweep, fade)
	# Afterimages first (behind): only their contours, faint and trailing.
	for ghost_index: int in range(GHOSTS.size()):
		var at: float = progress - GHOSTS[ghost_index]
		if at > 0.02:
			var ghost_alpha: float = fade * (0.34 - 0.09 * float(ghost_index))
			_draw_cut(at, ghost_alpha, true)
	_draw_cut(progress, fade, false)
	_draw_burst(sweep, fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The whole cut at progress `at`. `ghost` draws only the contours.
func _draw_cut(at: float, alpha: float, ghost: bool) -> void:
	var s: float = canvas_size / 512.0
	var head_progress: float = _eased(at / SWEEP_END)
	var layers: Array = _layers()
	for layer_index: int in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		var head: float
		if bool(layer.get("late", false)):
			var late_progress: float = _eased((at - RED_START) / (RED_END - RED_START))
			if late_progress <= 0.0:
				continue
			head = lerpf(float(layer.from), float(layer.to), late_progress)
		else:
			head = lerpf(float(layer.from), float(layer.to), head_progress)
		var edges: Array = _envelope(layer, at, head)
		var polygon: PackedVector2Array = _polygon(edges)
		if polygon.size() < 6:
			continue
		var colour: Color = layer.color
		if not ghost:
			draw_colored_polygon(polygon, Color(colour.r, colour.g, colour.b, colour.a * alpha))
		# Contour: jittered, in a few passes, with a thickness that varies along its length.
		var passes: int = 1 if ghost else 3
		for pass_index: int in range(passes):
			var jitter := Vector2(_rng.randf_range(-1.6, 1.6), _rng.randf_range(-1.6, 1.6)) * s * (1.0 if pass_index > 0 else 0.0)
			var line_alpha: float = alpha * (1.0 if pass_index == 0 else 0.38)
			_variable_line(edges[0], INK, 3.4 * s, line_alpha, jitter, layer_index * 3 + pass_index)
			if layer_index <= 2:
				_variable_line(edges[1], INK, 2.2 * s, line_alpha * 0.8, jitter, layer_index * 5 + pass_index + 11)
	if ghost:
		return
	# Pale streak along the leading edge of the mint layers.
	var streak_edges: Array = _envelope({"from": 3.40, "to": -0.15, "thick": 12.0, "surge": 3.0, "lobes": 12.0, "phase": 0.7, "shift": Vector2(2, -12), "bias": 0.25}, at, lerpf(3.40, -0.15, head_progress))
	var streak: PackedVector2Array = _polygon(streak_edges)
	if streak.size() >= 6:
		draw_colored_polygon(streak, Color(WHITE.r, WHITE.g, WHITE.b, 0.8 * alpha))


## A polyline whose width changes along its length (thick here, hair-thin there), drawn
## segment by segment with rounded joints.
func _variable_line(points: PackedVector2Array, colour: Color, base_width: float, alpha: float, jitter: Vector2, seed_offset: int) -> void:
	if points.size() < 2:
		return
	var tone := Color(colour.r, colour.g, colour.b, alpha)
	for index: int in range(points.size() - 1):
		var wave: float = 0.55 + 0.45 * sin(float(index) * 0.43 + float(seed_offset) * 1.7) + 0.35 * sin(float(index) * 1.31 + float(seed_offset))
		var width: float = maxf(0.6, base_width * wave)
		var a: Vector2 = points[index] + jitter
		var b: Vector2 = points[index + 1] + jitter
		draw_line(a, b, tone, width, true)
		draw_circle(b, width * 0.5, tone)


## The faint far side of the ring and a few flecks.
func _draw_far_arc(sweep: float, fade: float) -> void:
	if sweep <= 0.3:
		return
	var s: float = canvas_size / 512.0
	var alpha: float = clampf((sweep - 0.3) / 0.7, 0.0, 1.0) * fade
	var radii: Vector2 = _radii(progress) * Vector2(1.04, 1.12)
	var points := PackedVector2Array()
	for index: int in range(40):
		points.append(_point(lerpf(-0.10, -2.0, float(index) / 39.0), radii))
	_variable_line(points, Color(0.2, 0.2, 0.22), 2.6 * s, 0.6 * alpha, Vector2.ZERO, 3)
	for index: int in range(30):
		var jitter := Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-12.0, 12.0)) * s
		draw_circle(_point(_rng.randf_range(-1.8, -0.05), radii) + jitter, _rng.randf_range(0.8, 3.4) * s, Color(INK.r, INK.g, INK.b, 0.85 * alpha))


func _draw_speed_lines(sweep: float, fade: float) -> void:
	var s: float = canvas_size / 512.0
	var impact: float = clampf((sweep - 0.45) / 0.55, 0.0, 1.0)
	if impact <= 0.0:
		return
	var centre: Vector2 = _centre() + Vector2(14, 14) * s
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
func _draw_burst(sweep: float, fade: float) -> void:
	var s: float = canvas_size / 512.0
	var impact: float = clampf((sweep - 0.4) / 0.6, 0.0, 1.0)
	if impact <= 0.0:
		return
	var centre: Vector2 = _centre() + Vector2(18, 8) * s
	var spacing: float = 7.0 * s
	for row: int in range(-11, 12):
		for column: int in range(-11, 12):
			var offset := Vector2(float(column) * spacing + (spacing * 0.5 if row % 2 != 0 else 0.0), float(row) * spacing * 0.87)
			var distance: float = offset.length()
			var reach: float = 88.0 * s * impact
			if distance > reach:
				continue
			var radius: float = (1.0 - distance / reach) * 3.0 * s
			if radius > 0.4:
				draw_circle(centre + offset, radius, Color(0.25, 0.27, 0.28, 0.75 * fade))
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
	for index: int in range(14):
		var angle2: float = _rng.randf_range(0.0, TAU)
		var distance2: float = _rng.randf_range(20.0, 120.0) * s * impact
		draw_circle(centre + Vector2.from_angle(angle2) * distance2, _rng.randf_range(1.0, 3.5) * s, Color(MINT.r, MINT.g, MINT.b, 0.9 * fade))
