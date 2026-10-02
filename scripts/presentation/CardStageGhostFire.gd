extends Node3D
## Violet fire off a dying card: many small sparks like those of a campfire, scattering outward
## and upward on turbulent paths, plus purple triangles shooting out from the centre like rays of light,
## the way an early arcade boss explodes. Presentation only.

var _sparks: GPUParticles3D
var _ray_size: Vector2 = Vector2.ONE
var _ray_time_left: float = 0.0
var _ray_wait: float = 0.0



static func _soft_dot() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


static func _ramp(colors: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _glow_material(use_texture: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 24
	if use_texture:
		material.albedo_texture = _soft_dot()
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material


## Starts the fire over the card area `size` (centred on this node). It keeps burning for
## `seconds`, then stops and frees itself once the last spark is gone.
func play(size: Vector2, seconds: float, ray_seconds: float = 0.0) -> void:
	# --- Sparks -------------------------------------------------------------------------------
	_sparks = GPUParticles3D.new()
	var spark_process := ParticleProcessMaterial.new()
	spark_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spark_process.emission_box_extents = Vector3(size.x * 0.5, size.y * 0.5, 0.05)
	spark_process.direction = Vector3(0.0, 1.0, 0.0)
	spark_process.spread = 70.0
	spark_process.initial_velocity_min = 0.5
	spark_process.initial_velocity_max = 2.4
	spark_process.gravity = Vector3(0.0, 0.35, 0.0)
	spark_process.damping_min = 0.2
	spark_process.damping_max = 0.8
	spark_process.turbulence_enabled = true
	spark_process.turbulence_noise_strength = 2.6
	spark_process.turbulence_noise_scale = 1.4
	spark_process.turbulence_noise_speed = Vector3(0.0, 0.4, 0.0)
	spark_process.scale_min = 0.35
	spark_process.scale_max = 1.2
	spark_process.color_ramp = _ramp(
		PackedColorArray([Color(1.0, 0.95, 1.0, 1.0), Color(0.72, 0.32, 1.0, 0.95), Color(0.30, 0.08, 0.55, 0.0)]),
		PackedFloat32Array([0.0, 0.35, 1.0]))
	_sparks.process_material = spark_process
	var spark_quad := QuadMesh.new()
	spark_quad.size = Vector2(0.09, 0.09)
	spark_quad.material = _glow_material(true)
	_sparks.draw_pass_1 = spark_quad
	_sparks.amount = 260
	_sparks.lifetime = 2.6
	_sparks.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	_sparks.emitting = true
	add_child(_sparks)

	# Rays of light: one at a time, in random directions, for `ray_seconds` (see _process).
	_ray_size = size
	_ray_time_left = ray_seconds
	_ray_wait = 0.0
	get_tree().create_timer(seconds).timeout.connect(_stop)


func _stop() -> void:
	if is_instance_valid(_sparks):
		_sparks.emitting = false
	get_tree().create_timer(3.4).timeout.connect(queue_free)


## One wave of purple triangles radiating from the centre point, each a thin spike pointing
## away from it, flying outward fast and fading (like the burst of an early arcade boss).
func ray_burst(size: Vector2, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var reach: float = maxf(size.x, size.y) * 1.6
	var phase: float = rng.randf() * TAU
	for index: int in range(count):
		var angle: float = phase + TAU * float(index) / float(count) + rng.randf_range(-0.09, 0.09)
		var length: float = rng.randf_range(1.05, 2.85)
		var width: float = rng.randf_range(0.05, 0.12)
		var ray := MeshInstance3D.new()
		ray.mesh = _spike_mesh(length, width)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.render_priority = 25
		material.albedo_color = Color(0.66, 0.30, 1.0, 0.95) if index % 4 != 0 else Color(0.88, 0.70, 1.0, 0.95)
		ray.material_override = material
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ray)
		# The spike points along +Y; turn it so its tip faces outward at `angle`.
		ray.rotation = Vector3(0.0, 0.0, angle - PI * 0.5)
		var direction := Vector3(cos(angle), sin(angle), 0.0)
		ray.position = direction * 0.12
		ray.scale = Vector3(0.6, 0.4, 1.0)
		var travel: float = reach * rng.randf_range(0.6, 1.0)
		var seconds: float = rng.randf_range(0.75, 1.1)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(ray, "position", direction * (0.12 + travel), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ray, "scale", Vector3(1.0, 1.7, 1.0), seconds * 0.7)
		tween.tween_property(ray, "transparency", 1.0, seconds * 0.55).set_delay(seconds * 0.45)
		tween.chain().tween_callback(ray.queue_free)


## A thin isosceles triangle: base on the origin, tip `length` along +Y.
func _spike_mesh(length: float, width: float) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-width * 0.5, 0.0, 0.0), Vector3(width * 0.5, 0.0, 0.0), Vector3(0.0, length, 0.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(delta: float) -> void:
	if _ray_time_left <= 0.0:
		return
	_ray_time_left -= delta
	_ray_wait -= delta
	if _ray_wait <= 0.0:
		ray_burst(_ray_size, 1)
		_ray_wait = randf_range(0.105, 0.33)
