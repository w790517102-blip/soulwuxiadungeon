extends Control
## Ink that hits the camera lens, out of focus: a few drops burst into radial splats (a
## ragged star with flung satellite specks, like a water drop bursting), the splat fades
## away, and a smaller run of ink slides down from where it landed with a rounded
## (half-circle) head. No highlight. Everything is drawn as soft stacked layers so it
## reads as blurred glass-side ink. Adds itself to a CanvasLayer; frees itself when done.

const SOFT_LAYERS: int = 5

class Splat:
	var centre: Vector2
	var radius: float
	var spikes: PackedFloat32Array = PackedFloat32Array()
	var specks: Array = []
	var delay: float = 0.0
	var age: float = 0.0
	var fade_start: float = 0.55
	var fade_time: float = 0.9

class Run:
	var position: Vector2
	var start: Vector2
	var width: float
	var speed: float
	var delay: float
	var age: float = 0.0
	var life: float


var splats: Array[Splat] = []
var runs: Array[Run] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func splash(count: int = 4) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var screen: Vector2 = get_viewport_rect().size
	for index: int in range(count):
		var splat := Splat.new()
		splat.centre = Vector2(rng.randf_range(screen.x * 0.22, screen.x * 0.78), rng.randf_range(screen.y * 0.1, screen.y * 0.42))
		splat.radius = rng.randf_range(26.0, 54.0)
		splat.delay = rng.randf_range(0.0, 0.18)
		# Ragged radial outline: long thin spikes alternate with short lobes.
		var arms: int = rng.randi_range(11, 17)
		for arm: int in range(arms):
			splat.spikes.append(rng.randf_range(0.45, 1.0) if arm % 2 == 0 else rng.randf_range(1.2, 2.6))
		for speck: int in range(rng.randi_range(7, 12)):
			var angle: float = rng.randf_range(0.0, TAU)
			splat.specks.append([Vector2(cos(angle), sin(angle)) * splat.radius * rng.randf_range(1.9, 3.4), rng.randf_range(2.5, 7.0)])
		splats.append(splat)
		# A smaller run slides down from near the splat once it has landed.
		var run := Run.new()
		run.start = splat.centre + Vector2(rng.randf_range(-splat.radius * 0.35, splat.radius * 0.35), splat.radius * 0.4)
		run.position = run.start
		run.width = rng.randf_range(7.0, 12.0)
		run.speed = rng.randf_range(55.0, 105.0)
		run.delay = splat.delay + 0.18
		run.life = rng.randf_range(1.5, 2.1)
		runs.append(run)


func _process(delta: float) -> void:
	var alive := false
	for splat: Splat in splats:
		if splat.delay > 0.0:
			splat.delay -= delta
			alive = true
			continue
		splat.age += delta
		alive = alive or splat.age < splat.fade_start + splat.fade_time
	for run: Run in runs:
		if run.delay > 0.0:
			run.delay -= delta
			alive = true
			continue
		run.age += delta
		# Starts slow and slides faster; the streak behind it stays thin.
		run.position.y += run.speed * delta * (0.3 + run.age * 1.1)
		alive = alive or run.age < run.life
	queue_redraw()
	if not alive:
		queue_free()


func _draw() -> void:
	for splat: Splat in splats:
		if splat.delay > 0.0:
			continue
		var alpha: float = 1.0 - clampf((splat.age - splat.fade_start) / splat.fade_time, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		# The burst opens in a flash: it grows over its first tenth of a second.
		var grow: float = clampf(splat.age / 0.1, 0.25, 1.0)
		_draw_soft_splat(splat, grow, alpha)
	for run: Run in runs:
		if run.delay > 0.0 or run.age >= run.life:
			continue
		var alpha: float = clampf(1.0 - maxf(run.age - run.life * 0.4, 0.0) / (run.life * 0.6), 0.0, 1.0) * 0.8
		_draw_soft_run(run, alpha)


func _draw_soft_splat(splat: Splat, grow: float, alpha: float) -> void:
	for layer: int in range(SOFT_LAYERS):
		var spread: float = 1.0 + float(layer) * 0.07
		var layer_alpha: float = alpha * (0.2 if layer < SOFT_LAYERS - 1 else 0.55)
		var points := PackedVector2Array()
		var arms: int = splat.spikes.size()
		for arm: int in range(arms):
			var angle_a: float = TAU * float(arm) / float(arms)
			var angle_b: float = TAU * (float(arm) + 0.5) / float(arms)
			var tip: float = splat.radius * splat.spikes[arm] * grow * spread
			points.append(splat.centre + Vector2(cos(angle_a), sin(angle_a)) * tip)
			points.append(splat.centre + Vector2(cos(angle_b), sin(angle_b)) * splat.radius * 0.55 * grow * spread)
		draw_colored_polygon(points, Color(0.01, 0.01, 0.015, layer_alpha))
		for speck: Array in splat.specks:
			var offset: Vector2 = speck[0] * grow
			var speck_size: float = float(speck[1]) * spread
			draw_circle(splat.centre + offset, speck_size, Color(0.01, 0.01, 0.015, layer_alpha * 0.8))


func _draw_soft_run(run: Run, alpha: float) -> void:
	var length: float = run.position.y - run.start.y
	for layer: int in range(SOFT_LAYERS):
		var spread: float = 1.0 + float(layer) * 0.35
		var layer_alpha: float = alpha * (0.16 if layer < SOFT_LAYERS - 1 else 0.5)
		var half: float = run.width * 0.5 * spread
		# A thin trail behind a half-circle head.
		if length > half:
			draw_rect(Rect2(run.position.x - half * 0.6, run.start.y, half * 1.2, length), Color(0.01, 0.01, 0.015, layer_alpha * 0.7))
		var head := PackedVector2Array()
		for step: int in range(0, 13):
			var angle: float = PI * float(step) / 12.0
			head.append(run.position + Vector2(cos(angle) * half, sin(angle) * half))
		draw_colored_polygon(head, Color(0.01, 0.01, 0.015, layer_alpha))
