extends Node3D
## The 替身符 glyph, drawn in 3D space with TWO brushes laid down together: a dry black
## brush (narrow, opaque, hard edged, never bleeds) and a wet brush (wider, soft edged,
## bleeding outward as it ages). Presentation only.
##
## The glyph is the cursive (草書) character 韋, written in three strokes with the brush
## lifted between them: a top stroke with a hooked flick, the long vertical that tapers to
## a tail, and the big curved loop on the right. Points are in a -1..1 box (y up); the
## pressure array is the brush weight at every point (0..1).

const STROKES: Array = [
	{"points": [Vector2(-0.51, 0.59), Vector2(-0.22, 0.74), Vector2(0.07, 0.91), Vector2(0.25, 0.94), Vector2(0.44, 0.82), Vector2(0.63, 0.68)],
	"pressure": [0.45, 0.8, 1.0, 0.9, 0.6, 0.2]},
	{"points": [Vector2(0.25, 0.76), Vector2(0.16, 0.32), Vector2(0.10, -0.19), Vector2(0.07, -0.63), Vector2(-0.01, -0.97)],
	"pressure": [0.85, 1.0, 1.0, 0.7, 0.06]},
	{"points": [Vector2(-0.49, 0.03), Vector2(-0.15, 0.0), Vector2(0.22, 0.10), Vector2(0.54, 0.06), Vector2(0.66, -0.15), Vector2(0.49, -0.41), Vector2(0.15, -0.53), Vector2(-0.07, -0.59)],
	"pressure": [0.15, 0.45, 0.7, 0.85, 0.85, 0.75, 0.5, 0.2]},
]
const SAMPLES_PER_STROKE: Array[int] = [55, 75, 80]
const BLEED_SECONDS: float = 0.9
## How long the whole glyph takes to be written (the bleed ages relative to this).
const WRITE_SECONDS: float = 1.9

var size: float = 3.0
## Per stroke: {"points", "pressure", "jitter", "start"}.
var _strokes: Array = []
var _total_samples: int = 0
var _mesh_instance: MeshInstance3D
var _crisp_instance: MeshInstance3D
var _material: StandardMaterial3D
var _progress: float = 0.0
var _clock: float = 0.0
var _pull_in: float = 0.0
var _fade: float = 0.0


func _ready() -> void:
	_build_path()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.render_priority = 20
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)
	# The dry black brush sits just in front of the wet one.
	_crisp_instance = MeshInstance3D.new()
	_crisp_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var crisp_material := _material.duplicate() as StandardMaterial3D
	crisp_material.render_priority = 22
	_crisp_instance.material_override = crisp_material
	_crisp_instance.position.z = 0.01
	add_child(_crisp_instance)


func _build_path() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_total_samples = 0
	for stroke_index: int in range(STROKES.size()):
		var control: Array = STROKES[stroke_index].points
		var weights: Array = STROKES[stroke_index].pressure
		var count: int = SAMPLES_PER_STROKE[stroke_index]
		var points := PackedVector2Array()
		var pressure := PackedFloat32Array()
		var jitter := PackedFloat32Array()
		for sample: int in range(count):
			var t: float = float(sample) / float(count - 1)
			var scaled: float = t * float(control.size() - 1)
			var index: int = mini(int(scaled), control.size() - 2)
			var local: float = scaled - float(index)
			var p0: Vector2 = control[maxi(index - 1, 0)]
			var p1: Vector2 = control[index]
			var p2: Vector2 = control[index + 1]
			var p3: Vector2 = control[mini(index + 2, control.size() - 1)]
			points.append(0.5 * ((2.0 * p1) + (-p0 + p2) * local + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * local * local + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * local * local * local))
			pressure.append(lerpf(float(weights[index]), float(weights[index + 1]), local))
			jitter.append(rng.randf_range(0.9, 1.1))
		_strokes.append({"points": points, "pressure": pressure, "jitter": jitter, "start": _total_samples})
		_total_samples += count


## Writes the glyph over `seconds`, then returns.
func draw_stroke(seconds: float) -> void:
	_clock = 0.0
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _set_progress(value: float) -> void:
	_progress = value
	_rebuild()


func _set_pull_in(value: float) -> void:
	_pull_in = value
	_rebuild()


func _set_fade(value: float) -> void:
	_fade = value
	_rebuild()


## Gathers the mark before it bursts: it swells and draws in a few times, shakily.
func tremble(seconds: float) -> void:
	var tween := create_tween()
	var steps: int = 7
	var home: Vector3 = position
	for step: int in range(steps):
		var swell: float = 1.0 + (0.07 if step % 2 == 0 else -0.05) * (0.5 + float(step) / float(steps))
		var shake := Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), 0.0)
		tween.tween_property(self, "scale", Vector3(swell, swell, 1.0), seconds / float(steps)).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(self, "position", home + shake, seconds / float(steps))
	tween.tween_property(self, "position", home, 0.02)
	await tween.finished


## The mark pulls in tight, then breaks away: used at the moment of the burst.
func contract_and_fade(seconds: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_pull_in, 0.0, 1.0, seconds * 0.6)
	tween.tween_method(_set_fade, 0.0, 1.0, seconds).set_delay(seconds * 0.3)
	await tween.finished


func _process(delta: float) -> void:
	_clock += delta
	if _progress > 0.0 and _fade < 1.0 and _pull_in < 1.0:
		_rebuild()


func _rebuild() -> void:
	if _mesh_instance == null or _progress <= 0.0:
		return
	_mesh_instance.mesh = _build_brush(false)
	if _crisp_instance:
		_crisp_instance.mesh = _build_brush(true)


## `crisp` = the dry black brush. Otherwise the wet brush.
func _build_brush(crisp: bool) -> ArrayMesh:
	var done: int = clampi(int(_progress * float(_total_samples)), 0, _total_samples)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for stroke: Dictionary in _strokes:
		var points: PackedVector2Array = stroke.points
		var visible: int = clampi(done - int(stroke.start), 0, points.size())
		if visible < 2:
			continue
		var first_vertex: int = vertices.size()
		for i: int in range(visible):
			var t: float = float(int(stroke.start) + i) / float(_total_samples - 1)
			var centre: Vector2 = points[i] * (size * 0.5)
			var ahead: Vector2 = points[mini(i + 4, points.size() - 1)] * (size * 0.5)
			var behind: Vector2 = points[maxi(i - 4, 0)] * (size * 0.5)
			var tangent: Vector2 = (ahead - behind).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var pressure: float = stroke.pressure[i]
			var age: float = clampf(_clock - t * WRITE_SECONDS, 0.0, BLEED_SECONDS) / BLEED_SECONDS
			var width: float
			var core_alpha: float
			var edge: float
			if crisp:
				width = size * 0.04 * maxf(pressure, 0.05)
				core_alpha = 1.0 - _fade
				edge = 1.0
			else:
				width = size * 0.05 * maxf(pressure, 0.1) * float(stroke.jitter[i])
				width *= (1.0 + 0.6 * age) * (1.0 - 0.45 * _pull_in)
				core_alpha = (0.9 - 0.25 * age) * (1.0 - _fade)
				edge = 1.45
			var inner: float = 0.95 if not crisp else 1.0
			var rim_alpha: float = core_alpha if crisp else 0.0
			var p_left: Vector2 = centre + normal * width * edge
			var p_right: Vector2 = centre - normal * width * edge
			var p_mid_l: Vector2 = centre + normal * width * inner
			var p_mid_r: Vector2 = centre - normal * width * inner
			vertices.append(Vector3(p_left.x, p_left.y, 0.0))
			colors.append(Color(0.0, 0.0, 0.0, rim_alpha))
			vertices.append(Vector3(p_mid_l.x, p_mid_l.y, 0.0))
			colors.append(Color(0.0, 0.0, 0.0, core_alpha))
			vertices.append(Vector3(p_mid_r.x, p_mid_r.y, 0.0))
			colors.append(Color(0.0, 0.0, 0.0, core_alpha))
			vertices.append(Vector3(p_right.x, p_right.y, 0.0))
			colors.append(Color(0.0, 0.0, 0.0, rim_alpha))
			if i > 0:
				var base: int = first_vertex + i * 4
				for column: int in range(3):
					var a: int = base - 4 + column
					var b: int = base + column
					indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	if vertices.is_empty():
		return ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
