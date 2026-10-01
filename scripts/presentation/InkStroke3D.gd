extends Node3D
## One unbroken brush stroke drawn in 3D space (the 替身符 glyph). Soft-edged ink, not a
## crayon line: the stroke swells and thins like a pressed brush, each part slowly
## bleeds outward after it is laid down, and the whole mark then pulls back in.
## Presentation only.

## The supplied glyph, traced as ONE continuous stroke (-1..1 box, y up): a thin tail that
## sweeps in from the left, the heavy triangle at the top right, the thick diagonal, a lower
## swing, and a thin trailing flick. `WIDTHS` is the brush pressure at each point (0..1).
const GLYPH: Array[Vector2] = [
	Vector2(-0.94, 0.47), Vector2(-0.70, 0.36), Vector2(-0.39, 0.29), Vector2(-0.04, 0.29),
	Vector2(0.36, 0.34), Vector2(0.71, 0.46), Vector2(0.81, 0.58), Vector2(0.68, 0.78),
	Vector2(0.43, 0.89), Vector2(0.21, 0.96), Vector2(0.16, 0.81), Vector2(0.11, 0.59),
	Vector2(-0.04, 0.28), Vector2(-0.20, 0.03), Vector2(-0.45, -0.14), Vector2(-0.51, -0.21),
	Vector2(-0.26, -0.22), Vector2(0.11, -0.29), Vector2(0.33, -0.38), Vector2(0.30, -0.48),
	Vector2(0.02, -0.54), Vector2(-0.23, -0.58), Vector2(-0.14, -0.69), Vector2(0.08, -0.81),
	Vector2(0.23, -0.96),
]
const WIDTHS: Array[float] = [
	0.08, 0.15, 0.25, 0.35, 0.5, 0.7, 0.9, 1.0, 1.0, 0.85, 0.9, 0.95, 1.0, 1.0, 1.0, 1.0,
	0.75, 0.6, 0.5, 0.45, 0.45, 0.4, 0.3, 0.2, 0.05,
]
const SAMPLES: int = 150
const BLEED_SECONDS: float = 0.9

var size: float = 3.0
var _points: PackedVector2Array = PackedVector2Array()
var _jitter: PackedFloat32Array = PackedFloat32Array()
var _pressure: PackedFloat32Array = PackedFloat32Array()
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
	for sample: int in range(SAMPLES):
		var t: float = float(sample) / float(SAMPLES - 1)
		var scaled: float = t * float(GLYPH.size() - 1)
		var index: int = mini(int(scaled), GLYPH.size() - 2)
		var local: float = scaled - float(index)
		var p0: Vector2 = GLYPH[maxi(index - 1, 0)]
		var p1: Vector2 = GLYPH[index]
		var p2: Vector2 = GLYPH[index + 1]
		var p3: Vector2 = GLYPH[mini(index + 2, GLYPH.size() - 1)]
		_points.append(0.5 * ((2.0 * p1) + (-p0 + p2) * local + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * local * local + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * local * local * local))
		_jitter.append(rng.randf_range(0.9, 1.1))
		_pressure.append(lerpf(WIDTHS[index], WIDTHS[index + 1], local))


## Lays the stroke down over `seconds`, then returns.
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
	# Two brushes laid down together: a solid black one that never bleeds, and a wet one
	# that spreads and softens over the top of it.
	_mesh_instance.mesh = _build_brush(false)
	if _crisp_instance:
		_crisp_instance.mesh = _build_brush(true)


## `crisp` = the dry black brush: narrow, fully opaque, hard edge, never bleeds or pulls in
## softly. Otherwise the wet brush: wide, soft-edged, bleeds outward as it ages.
func _build_brush(crisp: bool) -> ArrayMesh:
	var count: int = clampi(int(_progress * float(SAMPLES)), 2, SAMPLES)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i: int in range(count):
		var t: float = float(i) / float(SAMPLES - 1)
		var centre: Vector2 = _points[i] * (size * 0.5)
		var ahead: Vector2 = _points[mini(i + 4, SAMPLES - 1)] * (size * 0.5)
		var behind: Vector2 = _points[maxi(i - 4, 0)] * (size * 0.5)
		var tangent: Vector2 = (ahead - behind).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var pressure: float = _pressure[i]
		var age: float = clampf(_clock - t * 0.9, 0.0, BLEED_SECONDS) / BLEED_SECONDS
		var width: float
		var core_alpha: float
		var edge: float
		if crisp:
			# Fixed line: no bleed with age; it simply goes when the mark breaks.
			width = size * 0.045 * maxf(pressure, 0.05)
			core_alpha = 1.0 - _fade
			edge = 1.0
		else:
			width = size * 0.052 * maxf(pressure, 0.1) * _jitter[i]
			width *= (1.0 + 0.6 * age) * (1.0 - 0.45 * _pull_in)
			core_alpha = (0.9 - 0.25 * age) * (1.0 - _fade)
			edge = 1.45
		var inner: float = 0.95 if not crisp else 1.0
		var p_left: Vector2 = centre + normal * width * edge
		var p_right: Vector2 = centre - normal * width * edge
		var p_mid_l: Vector2 = centre + normal * width * inner
		var p_mid_r: Vector2 = centre - normal * width * inner
		var rim_alpha: float = core_alpha if crisp else 0.0
		vertices.append(Vector3(p_left.x, p_left.y, 0.0))
		colors.append(Color(0.0, 0.0, 0.0, rim_alpha))
		vertices.append(Vector3(p_mid_l.x, p_mid_l.y, 0.0))
		colors.append(Color(0.0, 0.0, 0.0, core_alpha))
		vertices.append(Vector3(p_mid_r.x, p_mid_r.y, 0.0))
		colors.append(Color(0.0, 0.0, 0.0, core_alpha))
		vertices.append(Vector3(p_right.x, p_right.y, 0.0))
		colors.append(Color(0.0, 0.0, 0.0, rim_alpha))
		if i > 0:
			var base: int = i * 4
			for column: int in range(3):
				var a: int = base - 4 + column
				var b: int = base + column
				indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
