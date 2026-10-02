extends Node2D
## The twin ink dragons drawn with Godot 2D shapes only: two black dragons (the second is the
## first turned 180 degrees) coiling around a black ink vortex ringed by mint-green lightning
## shards. Before that, green rings swirl and flash. `progress` runs 0..1.
## Everything is laid out in a 1250 x 1250 reference square and scaled to `canvas_size`.

const INK := Color(0.03, 0.03, 0.035)
const MINT := Color(0.18, 0.86, 0.62)
const MINT_PALE := Color(0.70, 0.97, 0.88)
const EYE := Color(1.0, 0.72, 0.10)
const REF := 1250.0
const CENTRE := Vector2(625.0, 640.0)

@export var canvas_size: float = 512.0
@export_range(0.0, 1.0) var progress: float = 1.0:
	set(value):
		progress = value
		queue_redraw()

# Phases of `progress`.
const RINGS_END := 0.34
const FLASH_END := 0.44
const DRAGONS_END := 0.78
const FADE_START := 0.93

## Body path of the upper dragon, from the tail tip (at the vortex) to the neck, in reference
## coordinates. The lower dragon is this path turned 180 degrees about CENTRE.
const BODY_POINTS: Array[Vector2] = [
	Vector2(655, 668), Vector2(760, 676), Vector2(870, 656), Vector2(962, 606),
	Vector2(1022, 534), Vector2(1042, 452), Vector2(1004, 386), Vector2(922, 350),
	Vector2(846, 338),
]

var _rng := RandomNumberGenerator.new()
var _path: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	queue_redraw()


func _to_canvas(point: Vector2) -> Vector2:
	return point * (canvas_size / REF)


func _draw() -> void:
	_rng.seed = 11
	var fade: float = 1.0 - clampf((progress - FADE_START) / (1.0 - FADE_START), 0.0, 1.0)
	if fade <= 0.0:
		return
	if progress < FLASH_END:
		_draw_rings(fade)
	if progress >= RINGS_END * 0.9 and progress < FLASH_END + 0.04:
		_draw_flash(fade)
	if progress >= FLASH_END - 0.02:
		_draw_vortex(fade)
		_draw_lightning(fade)
		var grow: float = clampf((progress - FLASH_END) / (DRAGONS_END - FLASH_END), 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - grow, 2.5)
		_draw_dragon(eased, false, fade)
		_draw_dragon(eased, true, fade)


# --- Green swirling rings (first phase) ---------------------------------------------------------

func _draw_rings(fade: float) -> void:
	var t: float = clampf(progress / RINGS_END, 0.0, 1.0)
	var alpha: float = fade * (1.0 - clampf((progress - RINGS_END * 0.8) / (FLASH_END - RINGS_END * 0.8), 0.0, 1.0))
	var centre: Vector2 = _to_canvas(CENTRE)
	var radius: float = 150.0 * canvas_size / REF * 1.0
	# A dark smudge behind the rings.
	for ring: int in range(5):
		var points := PackedVector2Array()
		var tilt: float = float(ring) * 0.62 + t * 3.2
		var squash: float = lerpf(0.35, 0.95, t) * (0.7 + 0.1 * float(ring % 3))
		for step: int in range(61):
			var angle: float = TAU * float(step) / 60.0
			var local := Vector2(cos(angle) * radius, sin(angle) * radius * squash)
			points.append(centre + local.rotated(tilt))
		draw_polyline(points, Color(INK.r, INK.g, INK.b, 0.9 * alpha), 9.0 * canvas_size / REF * 2.0, true)
		draw_polyline(points, Color(MINT.r, MINT.g, MINT.b, alpha), 6.0 * canvas_size / REF * 2.0, true)
		draw_polyline(points, Color(MINT_PALE.r, MINT_PALE.g, MINT_PALE.b, 0.8 * alpha), 2.0 * canvas_size / REF * 2.0, true)


func _draw_flash(fade: float) -> void:
	var t: float = clampf((progress - RINGS_END * 0.9) / (FLASH_END - RINGS_END * 0.9), 0.0, 1.0)
	var centre: Vector2 = _to_canvas(CENTRE)
	var radius: float = 175.0 * canvas_size / REF
	var alpha: float = fade * (1.0 - clampf((progress - FLASH_END) / 0.04, 0.0, 1.0))
	draw_circle(centre, radius * (0.6 + 0.4 * t), Color(INK.r, INK.g, INK.b, alpha))
	draw_circle(centre, radius * (0.56 + 0.4 * t), Color(0.55, 0.92, 0.78, alpha))
	draw_circle(centre, radius * 0.34 * t, Color(INK.r, INK.g, INK.b, alpha))
	draw_circle(centre, radius * 0.08, Color(EYE.r, EYE.g, EYE.b, alpha))


# --- The vortex and the green lightning ring ---------------------------------------------------

func _draw_vortex(fade: float) -> void:
	var scale_f: float = canvas_size / REF
	var appear: float = clampf((progress - (FLASH_END - 0.02)) / 0.08, 0.0, 1.0)
	var centre: Vector2 = _to_canvas(CENTRE)
	var radius: float = 188.0 * scale_f * appear
	# Ragged black disc: a many-pointed blob.
	var edge := PackedVector2Array()
	for step: int in range(72):
		var angle: float = TAU * float(step) / 72.0
		var wobble: float = 1.0 + 0.09 * sin(angle * 5.0 + 1.0) + _rng.randf_range(-0.05, 0.05)
		edge.append(centre + Vector2.from_angle(angle) * radius * wobble)
	draw_colored_polygon(edge, Color(0.06, 0.06, 0.07, fade))
	# Darker swirled arms.
	for arm: int in range(4):
		var points := PackedVector2Array()
		var base: float = TAU * float(arm) / 4.0 + progress * 2.0
		for step: int in range(30):
			var along: float = float(step) / 29.0
			var angle: float = base + along * 2.8
			points.append(centre + Vector2.from_angle(angle) * radius * (0.18 + 0.78 * along))
		draw_polyline(points, Color(INK.r, INK.g, INK.b, fade), 38.0 * scale_f, true)
	# White gaps torn through it: irregular blobs set along spiral arms, bigger and denser
	# toward the middle, like dry-brush paper showing through the ink.
	for index: int in range(34):
		var along: float = float(index) / 63.0
		var arm: float = float(index % 3) * TAU / 3.0
		var angle: float = arm + along * 5.2 + progress * 1.6
		var distance: float = radius * (0.12 + 0.80 * along)
		var centre_blob: Vector2 = centre + Vector2.from_angle(angle) * distance
		var blob_size: float = radius * lerpf(0.17, 0.05, along) * _rng.randf_range(0.6, 1.3)
		var blob := PackedVector2Array()
		var corners: int = 9
		for corner: int in range(corners):
			var corner_angle: float = TAU * float(corner) / float(corners)
			var stretch := Vector2(1.7, 0.8) if corner % 2 == 0 else Vector2(1.0, 1.0)
			var local := Vector2.from_angle(corner_angle) * blob_size * _rng.randf_range(0.55, 1.2)
			blob.append(centre_blob + Vector2(local.x * stretch.x, local.y * stretch.y).rotated(angle + PI * 0.5))
		draw_colored_polygon(blob, Color(0.96, 0.96, 0.96, 0.97 * fade))
	# A clean white eye at the very centre.
	draw_circle(centre, radius * 0.16, Color(0.97, 0.97, 0.97, fade))
	# Dry-brush flecks on the rim.
	for index: int in range(46):
		var angle2: float = _rng.randf_range(0.0, TAU)
		var distance: float = radius * _rng.randf_range(0.92, 1.12)
		draw_circle(centre + Vector2.from_angle(angle2) * distance, _rng.randf_range(2.0, 8.0) * scale_f, Color(INK.r, INK.g, INK.b, 0.9 * fade))


func _draw_lightning(fade: float) -> void:
	var scale_f: float = canvas_size / REF
	var appear: float = clampf((progress - FLASH_END) / 0.10, 0.0, 1.0)
	if appear <= 0.0:
		return
	var centre: Vector2 = _to_canvas(CENTRE)
	var count: int = 11
	for index: int in range(count):
		var base: float = TAU * float(index) / float(count) + progress * 1.4
		var radius: float = (232.0 + 14.0 * sin(float(index) * 2.3)) * scale_f
		var length: float = (0.46 + 0.08 * sin(float(index) * 1.9)) * appear
		# A curved blade lying along the ring: smooth crescent, sharp tips, a spike or two.
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var steps: int = 10
		for step: int in range(steps + 1):
			var along: float = float(step) / float(steps)
			var angle: float = base + along * length
			var bulge: float = sin(PI * along)
			var spike: float = (16.0 if step == 3 or step == 7 else 0.0) * scale_f
			outer.append(centre + Vector2.from_angle(angle) * (radius + bulge * 28.0 * scale_f + spike))
			inner.append(centre + Vector2.from_angle(angle) * (radius - bulge * 7.0 * scale_f))
		var shard := PackedVector2Array()
		shard.append_array(outer)
		for step: int in range(inner.size() - 1, -1, -1):
			shard.append(inner[step])
		draw_colored_polygon(shard, Color(MINT.r, MINT.g, MINT.b, fade))
		draw_polyline(outer, Color(MINT_PALE.r, MINT_PALE.g, MINT_PALE.b, 0.7 * fade), 1.2 * scale_f * 2.0, true)


# --- The dragons --------------------------------------------------------------------------------

## Dense points of a Catmull-Rom spline through `points`.
func _spline(points: Array[Vector2], per_segment: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index: int in range(points.size() - 1):
		var p0: Vector2 = points[maxi(index - 1, 0)]
		var p1: Vector2 = points[index]
		var p2: Vector2 = points[index + 1]
		var p3: Vector2 = points[mini(index + 2, points.size() - 1)]
		for step: int in range(per_segment):
			var t: float = float(step) / float(per_segment)
			var t2: float = t * t
			var t3: float = t2 * t
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	result.append(points[points.size() - 1])
	return result


func _turn(point: Vector2, flipped: bool) -> Vector2:
	if not flipped:
		return point
	return CENTRE * 2.0 - point


## One dragon; `grow` (0..1) is how much of the body has come out of the vortex.
func _draw_dragon(grow: float, flipped: bool, fade: float) -> void:
	if _path.is_empty():
		_path = _spline(BODY_POINTS, 14)
	var count: int = _path.size()
	var visible: int = clampi(int(float(count) * grow), 2, count)
	var scale_f: float = canvas_size / REF
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var back_points := PackedVector2Array()
	var back_normals := PackedVector2Array()
	for index: int in range(visible):
		var t: float = float(index) / float(count - 1)
		var here: Vector2 = _path[index]
		var ahead: Vector2 = _path[mini(index + 1, count - 1)]
		var behind: Vector2 = _path[maxi(index - 1, 0)]
		var tangent: Vector2 = (ahead - behind).normalized()
		var normal: Vector2 = tangent.orthogonal()
		# Thin at the tail, full in the middle, slimmer again at the neck.
		var width: float = 4.0 + 50.0 * pow(sin(PI * clampf(t * 0.92 + 0.02, 0.0, 1.0)), 0.8)
		width *= 0.5 + 0.5 * sin(clampf(t * 1.1, 0.0, 1.0) * PI * 0.5 + 0.2)
		left.append(_to_canvas(_turn(here + normal * width, flipped)))
		right.append(_to_canvas(_turn(here - normal * width * 0.9, flipped)))
		back_points.append(_to_canvas(_turn(here + normal * width, flipped)))
		back_normals.append((_to_canvas(_turn(here + normal * (width + 10.0), flipped)) - _to_canvas(_turn(here + normal * width, flipped))).normalized())
	var body := PackedVector2Array()
	body.append_array(left)
	for index: int in range(right.size() - 1, -1, -1):
		body.append(right[index])
	if body.size() >= 4:
		draw_colored_polygon(body, Color(INK.r, INK.g, INK.b, fade))
	# The head, once the body has reached the neck.
	if grow > 0.55:
		var neck: Vector2 = _path[count - 1]
		var head_fade: float = clampf((grow - 0.55) / 0.3, 0.0, 1.0)
		_draw_head(_turn(neck, flipped), flipped, head_fade * fade)
	# Ink droplets thrown off the body.
	var drops: int = int(26.0 * grow)
	for index: int in range(drops):
		var at: Vector2 = _path[_rng.randi_range(0, visible - 1)] + Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-70.0, 70.0))
		draw_circle(_to_canvas(_turn(at, flipped)), _rng.randf_range(2.0, 9.0) * scale_f, Color(INK.r, INK.g, INK.b, 0.9 * fade))


## The head, in a local frame where one unit is 100 reference pixels and the snout points to -x.
func _draw_head(neck: Vector2, flipped: bool, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var scale_f: float = canvas_size / REF
	var unit: float = 175.0
	var turn: float = PI if flipped else 0.0
	var origin: Vector2 = neck + Vector2(-8.0, 0.0).rotated(turn)
	var ink := Color(INK.r, INK.g, INK.b, alpha)
	var skull: Array[Vector2] = [
		Vector2(0.85, -0.22), Vector2(0.55, -0.42), Vector2(0.15, -0.40), Vector2(-0.20, -0.30),
		Vector2(-0.58, -0.16), Vector2(-0.82, -0.04), Vector2(-0.74, 0.04), Vector2(-0.80, 0.10),
		Vector2(-0.66, 0.10), Vector2(-0.64, 0.19), Vector2(-0.52, 0.12), Vector2(-0.48, 0.21),
		Vector2(-0.36, 0.13), Vector2(-0.20, 0.17), Vector2(0.0, 0.14), Vector2(0.15, 0.12),
		Vector2(0.55, 0.20), Vector2(0.88, 0.26),
	]
	var jaw: Array[Vector2] = [
		Vector2(0.80, 0.30), Vector2(0.30, 0.44), Vector2(-0.22, 0.52), Vector2(-0.52, 0.60),
		Vector2(-0.62, 0.50), Vector2(-0.54, 0.42), Vector2(-0.62, 0.38), Vector2(-0.46, 0.34),
		Vector2(-0.40, 0.40), Vector2(-0.30, 0.30), Vector2(-0.12, 0.30), Vector2(0.20, 0.26),
	]
	var horns: Array = [
		[Vector2(0.45, -0.38), Vector2(1.05, -0.86), Vector2(0.78, -0.30)],
		[Vector2(0.20, -0.40), Vector2(0.55, -0.98), Vector2(0.42, -0.34)],
		[Vector2(-0.05, -0.34), Vector2(0.05, -0.84), Vector2(0.18, -0.32)],
		[Vector2(0.62, -0.30), Vector2(1.28, -0.58), Vector2(0.84, -0.18)],
	]
	for horn: Array in horns:
		var shape := PackedVector2Array()
		for point: Vector2 in horn:
			shape.append(_to_canvas_point_local(origin, point * unit, turn))
		draw_colored_polygon(shape, ink)
	var skull_polygon := PackedVector2Array()
	for point: Vector2 in skull:
		skull_polygon.append(_to_canvas_point_local(origin, point * unit, turn))
	draw_colored_polygon(skull_polygon, ink)
	var jaw_polygon := PackedVector2Array()
	for point: Vector2 in jaw:
		jaw_polygon.append(_to_canvas_point_local(origin, point * unit, turn))
	draw_colored_polygon(jaw_polygon, ink)
	# The open mouth: a sliver of white between jaw and skull.
	var mouth := PackedVector2Array([
		_to_canvas_point_local(origin, Vector2(-0.56, 0.20) * unit, turn),
		_to_canvas_point_local(origin, Vector2(0.10, 0.17) * unit, turn),
		_to_canvas_point_local(origin, Vector2(-0.10, 0.30) * unit, turn),
		_to_canvas_point_local(origin, Vector2(-0.42, 0.32) * unit, turn),
	])
	draw_colored_polygon(mouth, Color(0.92, 0.92, 0.92, alpha * 0.9))
	# Glowing eye.
	var eye_at: Vector2 = _to_canvas_point_local(origin, Vector2(-0.14, -0.17) * unit, turn)
	draw_circle(eye_at, 14.0 * scale_f, Color(EYE.r, EYE.g, EYE.b, alpha * 0.45))
	draw_colored_polygon(PackedVector2Array([eye_at + Vector2(-9, 3).rotated(turn) * scale_f, eye_at + Vector2(6, -5).rotated(turn) * scale_f, eye_at + Vector2(8, 3).rotated(turn) * scale_f]), Color(EYE.r, EYE.g, EYE.b, alpha))


func _to_canvas_point_local(origin: Vector2, local: Vector2, turn: float) -> Vector2:
	return _to_canvas(origin + local.rotated(turn))
