extends Node3D
## The sword cut: ONE band of turbulent water texture along a half-circle orbit. Only the texture of
## water (streaks that all run the same way yet are irregular and uncoordinated), no droplets or
## splash. A shader paints it on an arc-shaped strip standing in the stage; the band has a pointed
## head and a tail that thins, breaks into strands and dissolves. Struck from our side toward the
## upper right (mirrored for the other side). Presentation only.

const WaterShader = preload("res://scripts/presentation/shaders/water_slash.gdshader")

const TILT := 0.50
const SWEEP_END := 0.34
const HALF_WIDTH := 0.34          # half the band's width, in units
const SEGMENTS := 72

var duration: float = 0.8
var progress: float = 0.0:
	set(value):
		progress = value
		if _material != null:
			_material.set_shader_parameter("progress", progress)

var _unit: float = 1.0
var _material: ShaderMaterial


## A point on the half-circle orbit at `s` (0 = left end, 1 = right end), in units of `_unit`.
func _orbit(s: float) -> Vector3:
	var phi: float = lerpf(PI + 0.05, TAU - 0.05, s)
	return Vector3(cos(phi), sin(phi) * 0.62 + 0.40, 0.08 * sin(PI * s))


func _tangent(s: float) -> Vector3:
	return (_orbit(minf(s + 0.003, 1.0)) - _orbit(maxf(s - 0.003, 0.0))).normalized()


## `length` is the cut's length in world units, `direction` +1 swings from the left up to the
## right (our side striking), -1 is the mirror image.
func setup(length: float, direction: float) -> void:
	_unit = length * 0.5
	scale.x = 1.0 if direction >= 0.0 else -1.0
	rotation.z = TILT * (1.0 if direction >= 0.0 else -1.0)
	rotation.y = -0.30 * (1.0 if direction >= 0.0 else -1.0)
	_material = ShaderMaterial.new()
	_material.shader = WaterShader
	_material.set_shader_parameter("seed", randf() * 10.0)
	_material.set_shader_parameter("progress", 0.0)
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
