extends Node3D
## A punch, in the same language as the sword and 刀 cuts (silver-white, black ink, cracks, a lingering
## ink trail). The fist is formed first, held for a beat (a tap: it shudders and glows), then bursts
## forward: it is at full speed the moment it moves and loses it only as it lands (a sudden jump,
## not a slow wind-up), dragging white strands and ink behind it. Emits `impact` when it lands.
## Presentation only.

signal impact

const FistShader = preload("res://scripts/presentation/shaders/fist_strike.gdshader")
const TrailShader = preload("res://scripts/presentation/shaders/fist_trail.gdshader")

const FORM_SECONDS := 0.12
const PUNCH_SECONDS := 0.085
const TRAIL_THICKNESS := 0.28   # fraction of the fist size

var tap_seconds: float = 0.28     # the beat held before the blow (0 for follow-up blows of a flurry)

var _start: Vector3 = Vector3.ZERO
var _end: Vector3 = Vector3.ZERO
var _size: float = 1.0
var _fist: MeshInstance3D
var _trail: MeshInstance3D
var _fist_material: ShaderMaterial
var _trail_material: ShaderMaterial
var _clock: float = 0.0
var _trail_on: bool = false
var _fist_pos: Vector3 = Vector3.ZERO


## `target` is where the fist lands, `travel` the way it goes (unit, screen plane), `distance` how
## far back it starts, `size` the fist's size in world units.
func setup(target: Vector3, travel: Vector2, distance: float, size: float) -> void:
	_size = size
	_end = target
	_start = target - Vector3(travel.x, travel.y, 0.0) * distance
	_fist_pos = _start
	var angle: float = atan2(travel.y, travel.x)
	var flip: float = -1.0 if travel.x < 0.0 else 1.0
	rotation.z = angle if travel.x >= 0.0 else angle - PI
	scale = Vector3(1.0, flip, 1.0)
	_fist_material = ShaderMaterial.new()
	_fist_material.shader = FistShader
	_fist_material.set_shader_parameter("seed", randf() * 10.0)
	_fist_material.set_shader_parameter("formed", 0.0)
	_fist_material.render_priority = 30
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * 2.0
	_fist = MeshInstance3D.new()
	_fist.mesh = quad
	_fist.material_override = _fist_material
	_fist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fist)
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = TrailShader
	_trail_material.set_shader_parameter("seed", randf() * 10.0)
	_trail_material.render_priority = 29
	var trail_quad := QuadMesh.new()
	trail_quad.size = Vector2.ONE
	_trail = MeshInstance3D.new()
	_trail.mesh = trail_quad
	_trail.material_override = _trail_material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.visible = false
	add_child(_trail)
	position = _start
	# The fist and the trail live in world space (the node itself only carries the facing).
	_fist.position = Vector3.ZERO


func _process(delta: float) -> void:
	_clock += delta
	_fist_material.set_shader_parameter("time_value", _clock)
	if _trail_on:
		_update_trail()


func _update_trail() -> void:
	# The trail runs from where the punch started to where the fist is now, in this node's frame.
	var back: float = (position - _start).length()
	var length: float = maxf(back + _size * 0.6, 0.01)
	(_trail.mesh as QuadMesh).size = Vector2(length, _size * TRAIL_THICKNESS)
	_trail.position = Vector3(-length * 0.5 + _size * 0.3, 0.0, -0.02)


func play() -> void:
	# 1. The fist is formed out of ink and light.
	var form := create_tween().set_parallel(true)
	form.tween_method(func(value: float) -> void: _fist_material.set_shader_parameter("formed", value), 0.0, 1.0, FORM_SECONDS)
	_fist.scale = Vector3.ONE * 0.6
	form.tween_property(_fist, "scale", Vector3.ONE, FORM_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await form.finished
	# 2. A tap: it glows and shudders for a beat.
	if tap_seconds > 0.0:
		var hold := create_tween().set_parallel(true)
		hold.tween_method(func(value: float) -> void: _fist_material.set_shader_parameter("charge", value), 0.0, 1.0, tap_seconds)
		hold.tween_method(func(value: float) -> void: _fist.position = Vector3(sin(value * 60.0), cos(value * 71.0), 0.0) * _size * 0.025 * value, 0.0, 1.0, tap_seconds)
		await hold.finished
		_fist.position = Vector3.ZERO
	# 3. The blow: full speed at once, easing only as it lands (inertia carries it in).
	_trail.visible = true
	_trail_on = true
	var blow := create_tween()
	blow.tween_property(self, "position", _end, PUNCH_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await blow.finished
	impact.emit()
	# 4. It stays pressed in for a heartbeat, then breaks up; the white strands go quickly, the ink slowly.
	var squash := create_tween().set_parallel(true)
	squash.tween_property(_fist, "scale", Vector3(0.88, 1.08, 1.0), 0.06)
	_fist_material.set_shader_parameter("charge", 0.0)
	await get_tree().create_timer(0.08).timeout
	var vanish := create_tween().set_parallel(true)
	vanish.tween_method(func(value: float) -> void: _fist_material.set_shader_parameter("fade", value), 0.0, 1.0, 0.16)
	vanish.tween_method(func(value: float) -> void: _trail_material.set_shader_parameter("fade_white", value), 0.0, 1.0, 0.22)
	vanish.tween_method(func(value: float) -> void: _trail_material.set_shader_parameter("fade_ink", value), 0.0, 1.0, 0.8)
	await vanish.finished
	queue_free()
