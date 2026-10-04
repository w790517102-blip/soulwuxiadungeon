extends Node3D
## A bolt of turbid water (the 墨鱗魘將's 水彈). In order:
##   1. SPIT   - a few drops fly off at the mouth as the bolt is spat.
##   2. FLIGHT - the bolt crosses the stage, accelerating: a rounded head whose body narrows into a frayed
##               tail, drawn with the uneven flowing-water texture (torn streaks, ridged veins, dark ink
##               threads, a broken foam rim), dragging a long trail of separate strands.
##   3. SPLASH - it bursts on the target: the bolt dissolves, droplets are thrown back and up, a ragged
##               ripple spreads from the spot, and the target is drenched: water streams down its card.
## Every number is a plain property (or a key of `defaults()`); lengths are in card heights. Presentation only.

signal impact          # the bolt has reached the target

const BoltShader = preload("res://scripts/presentation/shaders/water_bullet.gdshader")
const RingShader = preload("res://scripts/presentation/shaders/lute_burst_ring.gdshader")
const QiShader = preload("res://scripts/presentation/shaders/heal_qi.gdshader")
const SpaceWarpFX = preload("res://scripts/presentation/punch_fx/SpaceWarpFX.gd")
const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")

# --- Tunable parameters ---------------------------------------------------------------------------
var bolt_length: float = 0.62
var bolt_height: float = 0.34
var trail_length: float = 1.5
var flight_time: float = 0.36
var splash_count: int = 22
var ripple_strength: float = 1.0
var drench_time: float = 1.3
var drench_intensity: float = 0.55
var warp_strength: float = 0.007
var card_size: Vector2 = Vector2(2.0, 3.0)
var start_point: Vector3 = Vector3.ZERO
var target_point: Vector3 = Vector3.ZERO
var missed: bool = false

var _dot_texture: Texture2D = null


static func defaults() -> Dictionary:
	return {"bolt_length": 0.62, "bolt_height": 0.34, "trail_length": 1.5, "flight_time": 0.36, "splash_count": 22,
		"ripple_strength": 1.0, "drench_time": 1.3, "drench_intensity": 0.55, "warp_strength": 0.007}


static func play_between(host: Node, start: Vector3, target: Vector3, size: Vector2, params: Dictionary = {}) -> Node3D:
	var fx := new()
	host.add_child(fx)
	fx.card_size = size
	fx.start_point = start
	fx.target_point = target
	for key: String in params.keys():
		fx.set(key, params[key])
	fx.play()
	return fx


func _soft_dot() -> Texture2D:
	if _dot_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_dot_texture = texture
	return _dot_texture


func play() -> void:
	var h: float = card_size.y
	var direction: Vector3 = (target_point - start_point).normalized()
	var angle: float = atan2(direction.y, direction.x)
	_droplets(start_point, direction, 8, 0.6)
	# The bolt is a node that travels; its body and trail are laid out behind its head.
	var bolt := Node3D.new()
	add_child(bolt)
	bolt.position = start_point
	bolt.rotation.z = angle
	var seed_value: float = randf() * 10.0
	var body_length: float = h * bolt_length
	var body_material := _bolt_material(0.0, seed_value)
	var body := _quad(Vector2(body_length, h * bolt_height), body_material)
	body.position = Vector3(-body_length * 0.5, 0.0, 0.0)
	bolt.add_child(body)
	var trail_size: float = h * trail_length
	var trail_material := _bolt_material(1.0, seed_value + 3.0)
	var trail := _quad(Vector2(trail_size, h * bolt_height * 0.9), trail_material)
	trail.position = Vector3(-body_length - trail_size * 0.5 + body_length * 0.15, 0.0, -0.01)
	bolt.add_child(trail)
	var tween := create_tween()
	tween.tween_property(bolt, "position", target_point, flight_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_burst.bind(bolt, body_material, trail_material, direction))


func _bolt_material(mode: float, seed_value: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BoltShader
	material.render_priority = 44
	material.set_shader_parameter("mode", mode)
	material.set_shader_parameter("seed", seed_value)
	return material


func _quad(size: Vector2, material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	return mesh


func _burst(bolt: Node3D, body_material: ShaderMaterial, trail_material: ShaderMaterial, direction: Vector3) -> void:
	impact.emit()
	var spot: Vector3 = target_point + Vector3(0.0, 0.0, 0.3)
	# The bolt dissolves into the splash.
	var dissolve := create_tween()
	dissolve.tween_method(func(value: float) -> void:
		body_material.set_shader_parameter("fade", value)
		trail_material.set_shader_parameter("fade", value), 0.0, 1.0, 0.16)
	dissolve.tween_callback(bolt.queue_free)
	if missed:
		_droplets(spot, direction, splash_count / 2, 1.0)
		get_tree().create_timer(1.0).timeout.connect(queue_free)
		return
	_droplets(spot, -direction, splash_count, 1.0)
	_ripple(spot)
	_drench()
	if warp_strength > 0.0:
		SpaceWarpFX.play_at(self, spot + Vector3(0.0, 0.0, 0.4), card_size.y * 0.8, warp_strength, 0.35, true)
	get_tree().create_timer(drench_time + 0.8).timeout.connect(queue_free)


## Drops thrown from `point`, mostly along `direction`, falling with gravity.
func _droplets(point: Vector3, direction: Vector3, count: int, power: float) -> void:
	if count <= 0:
		return
	var h: float = card_size.y
	var ramp: GradientTexture1D = GhostFire._ramp(
		PackedColorArray([Color(0.9, 1.0, 1.0, 0.95), Color(0.35, 0.75, 0.85, 0.85), Color(0.08, 0.3, 0.4, 0.0)]),
		PackedFloat32Array([0.0, 0.4, 1.0]))
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = direction + Vector3(0.0, 0.5, 0.0)
	process.spread = 70.0
	process.initial_velocity_min = h * 0.5 * power
	process.initial_velocity_max = h * 1.6 * power
	process.damping_min = h * 0.4
	process.damping_max = h * 1.0
	process.gravity = Vector3(0.0, -h * 1.8, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * h * 0.03
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _soft_dot()
	material.render_priority = 46
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.amount = count
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	particles.position = point
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)


## A ragged ring of ripples spreading from the splash.
func _ripple(spot: Vector3) -> void:
	var material := ShaderMaterial.new()
	material.shader = RingShader
	material.render_priority = 40
	material.set_shader_parameter("tone", Color(0.45, 0.85, 0.95))
	material.set_shader_parameter("ring_alpha", 0.75 * ripple_strength)
	material.set_shader_parameter("emission_strength", 0.8)
	material.set_shader_parameter("reach", 0.95)
	material.set_shader_parameter("ease_power", 2.2)
	material.set_shader_parameter("width_start", 0.06)
	material.set_shader_parameter("width_end", 0.13)
	material.set_shader_parameter("raggedness", 0.85)
	material.set_shader_parameter("seed", randf() * 10.0)
	var mesh := _quad(Vector2.ONE * card_size.y * 1.2, material)
	mesh.position = spot
	add_child(mesh)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, 0.55)
	tween.tween_callback(mesh.queue_free)


## The target is drenched: water streams down its card.
func _drench() -> void:
	var material := ShaderMaterial.new()
	material.shader = QiShader
	material.render_priority = 38
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("intensity", drench_intensity)
	material.set_shader_parameter("tone", Color(0.12, 0.55, 0.7))
	material.set_shader_parameter("core_tone", Color(0.8, 0.97, 1.0))
	material.set_shader_parameter("accent_tone", Color(0.06, 0.3, 0.45))
	material.set_shader_parameter("scroll_speed", 1.1)
	material.set_shader_parameter("down", 1.0)
	var mesh := _quad(Vector2(card_size.x * 1.1, card_size.y * 1.3), material)
	mesh.position = target_point + Vector3(0.0, card_size.y * 0.1, 0.3)
	add_child(mesh)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, drench_time)
	tween.tween_callback(mesh.queue_free)
