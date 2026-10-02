extends Node3D
## The sword cut as a blade of flowing water along a half-circle orbit. A shader paints the water
## on an arc-shaped strip standing in the stage (flowing streaks, foam, a pointed head, a tail that
## breaks into strands); GPU particles throw droplets off the head and splash at the impact. Struck
## from our side toward the upper right (mirrored for the other side). Presentation only.

const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")
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
var _head: Node3D
var _droplets: GPUParticles3D
var _splash: GPUParticles3D


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
	_head = Node3D.new()
	add_child(_head)
	_droplets = _make_droplets()
	_head.add_child(_droplets)
	_splash = _make_splash()
	add_child(_splash)


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


func _droplet_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = GhostFire._soft_dot()
	material.render_priority = 29
	return material


## Droplets and spray flung off the head as it sweeps (GPU particles, pulled down by gravity).
func _make_droplets() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 70.0
	process.initial_velocity_min = _unit * 0.5
	process.initial_velocity_max = _unit * 1.6
	process.gravity = Vector3(0.0, -_unit * 2.6, 0.0)
	process.damping_min = _unit * 0.1
	process.damping_max = _unit * 0.4
	process.scale_min = 0.3
	process.scale_max = 1.1
	process.color_ramp = GhostFire._ramp(
		PackedColorArray([Color(0.95, 0.99, 1.0, 1.0), Color(0.55, 0.80, 1.0, 0.9), Color(0.25, 0.55, 0.95, 0.0)]),
		PackedFloat32Array([0.0, 0.4, 1.0]))
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(_unit * 0.05, _unit * 0.05)
	quad.material = _droplet_material()
	particles.draw_pass_1 = quad
	particles.amount = 140
	particles.lifetime = 0.8
	particles.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	particles.emitting = false
	return particles


## A burst of splash at the impact (GPU particles).
func _make_splash() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.3, 1.0, 0.0)
	process.spread = 100.0
	process.initial_velocity_min = _unit * 0.8
	process.initial_velocity_max = _unit * 2.4
	process.gravity = Vector3(0.0, -_unit * 3.2, 0.0)
	process.damping_min = _unit * 0.2
	process.damping_max = _unit * 0.6
	process.scale_min = 0.4
	process.scale_max = 1.5
	process.color_ramp = GhostFire._ramp(
		PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.60, 0.82, 1.0, 0.9), Color(0.25, 0.55, 0.95, 0.0)]),
		PackedFloat32Array([0.0, 0.4, 1.0]))
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(_unit * 0.07, _unit * 0.07)
	quad.material = _droplet_material()
	particles.draw_pass_1 = quad
	particles.amount = 90
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	particles.emitting = false
	return particles


## Plays the cut once; frees itself at the end. Awaitable.
func play() -> void:
	progress = 0.0
	_head.position = _orbit(0.0) * _unit
	_droplets.emitting = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "progress", 1.0, duration)
	tween.tween_method(func(value: float) -> void: _head.position = _orbit(1.0 - pow(1.0 - clampf(value / SWEEP_END, 0.0, 1.0), 2.2)) * _unit, 0.0, 1.0, duration)
	get_tree().create_timer(duration * SWEEP_END * 0.55).timeout.connect(_impact)
	get_tree().create_timer(duration * SWEEP_END).timeout.connect(func() -> void: _droplets.emitting = false)
	await tween.finished
	await get_tree().create_timer(0.6).timeout
	queue_free()


func _impact() -> void:
	_splash.position = _orbit(0.58) * _unit
	_splash.restart()
	_splash.emitting = true
