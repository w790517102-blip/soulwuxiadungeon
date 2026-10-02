extends Node2D
## The sword cut as a real-time effect: a shader paints the stroke (dry-brush bristles, torn
## cloud, shaking contours), GPU particles throw mist and ink flecks, CPU particles throw
## the few larger shards. Struck from our side toward the upper right.
##
## play() runs the whole effect; `progress` can also be set by hand (for stills). `canvas_size` is
## the square it occupies. Presentation only.

const SlashShader = preload("res://scripts/presentation/shaders/ink_slash.gdshader")
const TILT := 0.42

@export var canvas_size: float = 512.0
@export var duration: float = 0.9
@export_range(0.0, 1.0) var progress: float = 0.0:
	set(value):
		progress = value
		if _material != null:
			_material.set_shader_parameter("progress", progress)

var _quad: ColorRect
var _material: ShaderMaterial
var _mist: GPUParticles2D
var _flecks: GPUParticles2D
var _shards: CPUParticles2D
var _trail_tween: Tween


func _ready() -> void:
	_build()


func _build() -> void:
	if _quad != null:
		return
	_material = ShaderMaterial.new()
	_material.shader = SlashShader
	_material.set_shader_parameter("angle", TILT)
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("time_seed", randf() * 10.0)
	_quad = ColorRect.new()
	_quad.size = Vector2(canvas_size, canvas_size)
	_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quad.material = _material
	add_child(_quad)
	_mist = _make_mist()
	add_child(_mist)
	_flecks = _make_flecks()
	add_child(_flecks)
	_shards = _make_shards()
	add_child(_shards)


## Screen position of the cut's head (x in -1..1 along the cut) in this node's space.
func point_on_cut(x: float) -> Vector2:
	var half: float = canvas_size * 0.5
	var along := Vector2(x * 0.92, (-0.20 * (1.0 - x * x)) * 0.92)
	var rotated := Vector2(along.x * cos(TILT) - along.y * sin(TILT), along.x * sin(TILT) + along.y * cos(TILT))
	return Vector2(half + rotated.x * half, half - rotated.y * half)


func _soft_dot() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


## Pale mint mist puffs that spill back from the leading edge (GPU particles).
func _make_mist() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(-1.0, 0.0, 0.0)
	process.spread = 70.0
	process.initial_velocity_min = 20.0
	process.initial_velocity_max = 90.0
	process.gravity = Vector3.ZERO
	process.damping_min = 30.0
	process.damping_max = 60.0
	process.scale_min = 0.5
	process.scale_max = 1.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(0.86, 0.98, 0.93, 0.0), Color(0.80, 0.97, 0.90, 0.55), Color(0.55, 0.85, 0.75, 0.0)])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(1.0, 1.4))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	process.scale_curve = scale_texture
	particles.process_material = process
	particles.texture = _soft_dot()
	particles.amount = 90
	particles.lifetime = 0.7
	particles.emitting = false
	particles.local_coords = true
	return particles


## A burst of small black ink dots at the impact (GPU particles).
func _make_flecks() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = 120.0
	process.initial_velocity_max = 420.0
	process.gravity = Vector3(0.0, 140.0, 0.0)
	process.damping_min = 40.0
	process.damping_max = 120.0
	process.scale_min = 0.05
	process.scale_max = 0.22
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(0.04, 0.04, 0.05, 1.0), Color(0.04, 0.04, 0.05, 0.9), Color(0.04, 0.04, 0.05, 0.0)])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	particles.process_material = process
	particles.texture = _soft_dot()
	particles.amount = 120
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.emitting = false
	return particles


## A few larger angular shards, mint and ink (CPU particles).
func _make_shards() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	var shard := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	shard.fill(Color(0, 0, 0, 0))
	for row: int in range(16):
		for column: int in range(16):
			if column <= row and column >= 8 - row / 2 and column <= 15 - row / 4:
				shard.set_pixel(column, row, Color.WHITE)
	particles.texture = ImageTexture.create_from_image(shard)
	particles.amount = 26
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector2(1.0, -0.4)
	particles.spread = 150.0
	particles.gravity = Vector2(0.0, 260.0)
	particles.initial_velocity_min = 180.0
	particles.initial_velocity_max = 520.0
	particles.angular_velocity_min = -540.0
	particles.angular_velocity_max = 540.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.7
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(0.40, 0.84, 0.66, 1.0), Color(0.05, 0.05, 0.06, 1.0), Color(0.05, 0.05, 0.06, 0.0)])
	particles.color_ramp = ramp
	particles.emitting = false
	return particles


## Plays the cut once.
func play() -> void:
	_build()
	progress = 0.0
	if _trail_tween and _trail_tween.is_valid():
		_trail_tween.kill()
	_mist.position = point_on_cut(-1.0)
	_mist.restart()
	_mist.emitting = true
	_trail_tween = create_tween().set_parallel(true)
	_trail_tween.tween_property(self, "progress", 1.0, duration)
	# The mist emitter rides the sweep head; the burst fires at the impact.
	_trail_tween.tween_method(func(value: float) -> void: _mist.position = point_on_cut(lerpf(-1.0, 1.0, 1.0 - pow(1.0 - clampf(value / 0.34, 0.0, 1.0), 3.0))), 0.0, 1.0, duration)
	get_tree().create_timer(duration * 0.34).timeout.connect(_burst)
	get_tree().create_timer(duration * 0.5).timeout.connect(func() -> void: _mist.emitting = false)


func _burst() -> void:
	var impact: Vector2 = point_on_cut(0.18) + Vector2(10.0, 4.0)
	_flecks.position = impact
	_flecks.restart()
	_flecks.emitting = true
	_shards.position = impact
	_shards.restart()
	_shards.emitting = true
