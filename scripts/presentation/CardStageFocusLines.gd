extends Control
## A few manga-style focus lines that burst outward from the point of impact and fade. Timed in
## real time (not slowed by Engine.time_scale), so they stay snappy during the slow motion.

const LIFETIME := 0.55

var _centre: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _lines: Array[Dictionary] = []


static func burst(parent: Node, centre: Vector2, count: int = 26) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	parent.add_child(layer)
	var lines := new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.size = parent.get_viewport().get_visible_rect().size
	lines._centre = centre
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var height: float = lines.size.y
	for index: int in range(count):
		lines._lines.append({
			"angle": TAU * float(index) / float(count) + rng.randf_range(-0.07, 0.07),
			"start": rng.randf_range(0.10, 0.20) * height,
			"travel": rng.randf_range(0.30, 0.55) * height,
			"length": rng.randf_range(0.16, 0.34) * height,
			"width": rng.randf_range(2.0, 5.5),
		})
	layer.add_child(lines)


func _process(delta: float) -> void:
	_age += delta / maxf(Engine.time_scale, 0.001)
	if _age >= LIFETIME:
		get_parent().queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_age / LIFETIME, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var alpha: float = (1.0 - t) * 0.85
	for line: Dictionary in _lines:
		var direction := Vector2.from_angle(float(line.angle))
		var near: float = float(line.start) + float(line.travel) * eased
		var far: float = near + float(line.length) * (1.0 - 0.5 * t)
		var normal: Vector2 = direction.orthogonal() * float(line.width) * 0.5 * (1.0 - t)
		var a: Vector2 = _centre + direction * near
		var b: Vector2 = _centre + direction * far
		draw_colored_polygon(PackedVector2Array([a + normal, b, a - normal]), Color(0.96, 0.93, 1.0, alpha))
