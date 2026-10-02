extends Node3D
## Violet ghost fire rising off a dying card: many small sparks like those of a campfire,
## scattering outward and upward on turbulent paths, plus a few long wisps that leave ribbon
## trails like the paths of ghosts. GPU particles; presentation only.

var _sparks: GPUParticles3D
var _wisps: GPUParticles3D


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
func play(size: Vector2, seconds: float) -> void:
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

	# --- Ghost wisps with ribbon trails -----------------------------------------------------------
	_wisps = GPUParticles3D.new()
	var wisp_process := ParticleProcessMaterial.new()
	wisp_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	wisp_process.emission_box_extents = Vector3(size.x * 0.45, size.y * 0.4, 0.05)
	wisp_process.direction = Vector3(0.0, 1.0, 0.0)
	wisp_process.spread = 90.0
	wisp_process.initial_velocity_min = 0.4
	wisp_process.initial_velocity_max = 1.0
	wisp_process.gravity = Vector3(0.0, 0.25, 0.0)
	wisp_process.turbulence_enabled = true
	wisp_process.turbulence_noise_strength = 5.0
	wisp_process.turbulence_noise_scale = 0.7
	wisp_process.turbulence_influence_min = 0.5
	wisp_process.turbulence_influence_max = 0.9
	wisp_process.color_ramp = _ramp(
		PackedColorArray([Color(0.7, 0.35, 1.0, 0.0), Color(0.62, 0.28, 0.95, 0.85), Color(0.3, 0.08, 0.55, 0.0)]),
		PackedFloat32Array([0.0, 0.25, 1.0]))
	_wisps.process_material = wisp_process
	var ribbon := RibbonTrailMesh.new()
	ribbon.size = 0.035
	ribbon.sections = 8
	ribbon.section_length = 0.09
	ribbon.section_segments = 2
	ribbon.material = _glow_material(false)
	_wisps.draw_pass_1 = ribbon
	_wisps.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	_wisps.trail_enabled = true
	_wisps.trail_lifetime = 1.0
	_wisps.amount = 30
	_wisps.lifetime = 2.8
	_wisps.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	_wisps.emitting = true
	add_child(_wisps)

	get_tree().create_timer(seconds).timeout.connect(_stop)


func _stop() -> void:
	if is_instance_valid(_sparks):
		_sparks.emitting = false
	if is_instance_valid(_wisps):
		_wisps.emitting = false
	get_tree().create_timer(3.4).timeout.connect(queue_free)
