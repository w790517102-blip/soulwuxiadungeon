extends Node3D
## The guard shield of a card (GUARD): a thin cold membrane of ice-blue and white light standing just
## off the card, breathing slowly; a rare ripple and glint cross it and a few blue-white motes drift
## up through it. It is raised with a flash of cold white and a membrane that opens from the middle,
## it dents and ripples when a blow lands on it, and it is let go like a breath out: the rim draws in,
## the light fades, the motes scatter. A child of the card, so it turns and moves with it.
## Not a glass dome, not a force field. Every number is a plain property. Presentation only.

const ShieldShader = preload("res://scripts/presentation/shaders/guard_shield.gdshader")
const SpaceWarpFX = preload("res://scripts/presentation/punch_fx/SpaceWarpFX.gd")
const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")

# --- Tunable parameters ---------------------------------------------------------------------------
var shield_intensity: float = 0.6           # overall brightness of the membrane
var raise_time: float = 0.7                 # seconds the shield takes to form
var release_time: float = 0.8               # seconds it takes to let go
var hit_ripple_time: float = 0.65           # seconds the ripple of a blow takes to cross
var mote_count: int = 9                     # drifting blue-white motes
var distortion_strength: float = 0.007      # the faint mirage over a blow
var card_size: Vector2 = Vector2(2.3, 3.5)

var _material: ShaderMaterial
var _mesh: MeshInstance3D
var _motes: GPUParticles3D
var _hit_tween: Tween
var _raise_tween: Tween
var _releasing: bool = false


func setup(size: Vector2) -> void:
	card_size = size
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x * 1.26, size.y * 1.20)
	_material = ShaderMaterial.new()
	_material.shader = ShieldShader
	_material.render_priority = 8
	_material.set_shader_parameter("seed", randf() * 10.0)
	_material.set_shader_parameter("intensity", shield_intensity)
	_material.set_shader_parameter("form", 0.0)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = quad
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = _material
	_mesh.position = Vector3(0.0, 0.0, 0.10)
	add_child(_mesh)
	_make_motes()


## Raises the shield: a short cold flash, then the membrane opens out from the middle.
func raise(animated: bool = true) -> void:
	_releasing = false
	if _raise_tween and _raise_tween.is_valid():
		_raise_tween.kill()
	_material.set_shader_parameter("collapse", 0.0)
	if not animated:
		_material.set_shader_parameter("form", 1.0)
		_motes.emitting = true
		return
	_raise_tween = create_tween()
	_raise_tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("form", value), 0.0, 1.0, raise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motes.emitting = true


## Lets the shield go: the rim draws inward, the light fades, the motes scatter, then it frees itself.
func release() -> void:
	if _releasing:
		return
	_releasing = true
	if _raise_tween and _raise_tween.is_valid():
		_raise_tween.kill()
	_motes.emitting = false
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("collapse", value), 0.0, 1.0, release_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## A blow lands on the shield. `direction` is the side it comes from (+1 from the right, -1 from the
## left); `height` is where up the card it lands (-1 low .. 1 high).
func take_hit(direction: float, height: float = 0.0, strength: float = 1.0) -> void:
	if _releasing:
		return
	var point := Vector2(direction * 0.78, clampf(height, -0.8, 0.8) * 0.5)
	_material.set_shader_parameter("hit_pos", point)
	_material.set_shader_parameter("hit_strength", strength)
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("hit_t", value), 0.0, 1.0, hit_ripple_time)
	# Blue-white slivers thrown off the point of contact.
	var local := Vector3(point.x * card_size.x * 0.63, point.y * card_size.y * 0.6, 0.2)
	_hit_sparks(local, direction)
	if distortion_strength > 0.0:
		SpaceWarpFX.play_at(self, local, card_size.y * 0.7, distortion_strength * strength, 0.35, true)


func _hit_sparks(local: Vector3, direction: float) -> void:
	var unit: float = card_size.y
	var ramp: GradientTexture1D = GhostFire._ramp(
		PackedColorArray([Color(0.95, 0.98, 1.0, 1.0), Color(0.55, 0.8, 1.0, 0.8), Color(0.3, 0.55, 0.95, 0.0)]),
		PackedFloat32Array([0.0, 0.4, 1.0]))
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(-direction * 0.4, 0.0, 0.0)
	process.spread = 110.0
	process.initial_velocity_min = unit * 0.35
	process.initial_velocity_max = unit * 0.95
	process.damping_min = unit * 1.4
	process.damping_max = unit * 2.4
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.2
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * unit * 0.016
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.render_priority = 47
	material.albedo_texture = _soft_dot()
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.amount = 9
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	particles.position = local
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


## A few slow translucent motes of blue-white light drifting up through the shield.
func _make_motes() -> void:
	var unit: float = card_size.y
	_motes = GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 25.0
	process.initial_velocity_min = unit * 0.05
	process.initial_velocity_max = unit * 0.14
	process.gravity = Vector3.ZERO
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.25
	process.turbulence_noise_scale = 1.8
	process.scale_min = 0.5
	process.scale_max = 1.2
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(card_size.x * 0.5, card_size.y * 0.42, 0.04)
	process.color_ramp = GhostFire._ramp(
		PackedColorArray([Color(0.7, 0.88, 1.0, 0.0), Color(0.75, 0.9, 1.0, 0.7), Color(0.4, 0.7, 1.0, 0.0)]),
		PackedFloat32Array([0.0, 0.35, 1.0]))
	_motes.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * unit * 0.014
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.render_priority = 9
	material.albedo_texture = _soft_dot()
	mesh.material = material
	_motes.draw_pass_1 = mesh
	_motes.amount = mote_count
	_motes.lifetime = 3.2
	_motes.preprocess = 2.0
	_motes.emitting = false
	_motes.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	_motes.position = Vector3(0.0, -card_size.y * 0.05, 0.12)
	add_child(_motes)


var _dot_texture: Texture2D = null


## A soft round dot (so the motes are glints of light, not squares).
func _soft_dot() -> Texture2D:
	if _dot_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_dot_texture = texture
	return _dot_texture
