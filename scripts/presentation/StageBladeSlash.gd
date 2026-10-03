extends Node3D
## The sword cut (with `saber` the 刀 cut, with `impact` the 拳 impact mark): ONE sharp crescent of cold silver-white light that tears the air, with black ink
## strands dragged behind it and black fracture cracks across it (high contrast, no blue, no water).
## The streaks all run along the cut in the same direction yet are irregular and uncoordinated.
## A shader paints it on an arc-shaped strip standing in the stage; the cut swings from the upper
## left down to the lower right (mirrored for the other side). Presentation only.

const BladeShader = preload("res://scripts/presentation/shaders/blade_slash.gdshader")

const TILT := 0.50
const SWEEP_END := 0.15
const HALF_WIDTH := 0.34          # half the band's width, in units
const SEGMENTS := 72

var duration: float = 1.3
var progress: float = 0.0:
	set(value):
		progress = value
		if _material != null:
			_material.set_shader_parameter("progress", progress)

var _unit: float = 1.0
## 刀: a straight cut (not the sword's curve) in vermilion mixed with white, crossing very fast.
var _saber: bool = false
var _material: ShaderMaterial


## A point on the half-circle orbit at `s` (0 = left end, 1 = right end), in units of `_unit`.
func _orbit(s: float) -> Vector3:
	if _saber:
		return Vector3(lerpf(-1.0, 1.0, s), 0.0, 0.05 * sin(PI * s))
	var phi: float = lerpf(PI + 0.05, TAU - 0.05, s)
	# The upper arc of a flattened ellipse (a frown), centred on the pivot; the whole cut is then
	# turned to descend from the upper left to the lower right.
	return Vector3(cos(phi), -sin(phi) * 0.62 - 0.31, 0.08 * sin(PI * s))


func _tangent(s: float) -> Vector3:
	return (_orbit(minf(s + 0.003, 1.0)) - _orbit(maxf(s - 0.003, 0.0))).normalized()


## `length` is the cut's length in world units, `direction` +1 swings from the left up to the
## right (our side striking), -1 is the mirror image.
func setup(length: float, direction: float, variant: int = 0, saber: bool = false, impact: bool = false) -> void:
	_unit = length * 0.5
	_saber = saber or impact
	# Every cut of a flurry goes a different way: 0 down-and-across (upper left to lower right),
	# 1 backhand up (lower left to upper right), 2 a steep downward chop, 3 the mirror of the first
	# (upper right to lower left).
	var kind: int = variant % 4
	var travel: float = -direction if kind == 3 else direction
	var side: float = 1.0 if travel >= 0.0 else -1.0
	scale.x = side
	scale.y = -1.0 if kind == 1 else 1.0
	var tilt_by_kind: Array[float] = [-TILT, TILT * 0.9, -1.15, -TILT]
	rotation.z = tilt_by_kind[kind] * side
	rotation.y = (0.12 if kind == 2 else 0.30) * side
	if _saber:
		# One straight stroke from the upper left to the lower right (mirrored for the other side).
		scale = Vector3(1.0 if direction >= 0.0 else -1.0, 1.0, 1.0)
		rotation.z = -0.78 * (1.0 if direction >= 0.0 else -1.0)
		rotation.y = 0.18 * (1.0 if direction >= 0.0 else -1.0)
	_material = ShaderMaterial.new()
	_material.shader = BladeShader
	_material.set_shader_parameter("seed", randf() * 10.0)
	_material.set_shader_parameter("progress", 0.0)
	if _saber:
		_material.set_shader_parameter("sweep_end", 0.06)
		_material.set_shader_parameter("edge_mix", 1.0)
		_material.set_shader_parameter("light_core", Color(1.0, 0.95, 0.92))
		_material.set_shader_parameter("light_cool", Color(0.90, 0.14, 0.07))
		_material.set_shader_parameter("ink", Color(0.12, 0.01, 0.01))
	if impact:
		# 拳: not a cut but an impact mark, a short thick straight streak driven at the target in pale
		# cyan-white cold light (not saturated blue).
		scale = Vector3(1.0 if direction >= 0.0 else -1.0, 1.55, 1.0)
		rotation.z = -0.20 * (1.0 if direction >= 0.0 else -1.0)
		rotation.y = 0.10 * (1.0 if direction >= 0.0 else -1.0)
		_material.set_shader_parameter("sweep_end", 0.05)
		_material.set_shader_parameter("edge_mix", 1.0)
		_material.set_shader_parameter("light_core", Color(0.97, 1.0, 1.0))
		_material.set_shader_parameter("light_cool", Color(0.58, 0.86, 0.94))
		_material.set_shader_parameter("ink", Color(0.02, 0.07, 0.09))
	_material.render_priority = 28
	var strip := MeshInstance3D.new()
	strip.mesh = _build_strip()
	strip.material_override = _material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)


## The arc strip: centred on the orbit, UV.y running across it.
func _build_strip() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index: int in range(SEGMENTS + 1):
		var s: float = float(index) / float(SEGMENTS)
		var base: Vector3 = _orbit(s)
		var tangent: Vector3 = _tangent(s)
		var normal := Vector3(-tangent.y, tangent.x, 0.0).normalized()
		vertices.append((base - normal * HALF_WIDTH) * _unit)
		vertices.append((base + normal * HALF_WIDTH) * _unit)
		uvs.append(Vector2(s, 0.0))
		uvs.append(Vector2(s, 1.0))
		if index < SEGMENTS:
			var at: int = index * 2
			indices.append_array(PackedInt32Array([at, at + 1, at + 2, at + 1, at + 3, at + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Plays the cut once; frees itself at the end. Awaitable.
func play() -> void:
	progress = 0.0
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, duration)
	await tween.finished
	queue_free()
