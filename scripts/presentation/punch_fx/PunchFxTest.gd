extends Node3D
## A bare test scene for the punch hit FX: a dark backdrop and a dummy target card. Space / click
## plays a heavy hit, Shift+Space / right click a light one, Enter a jab-jab-heavy flurry.
## Open scenes/presentation/punch_fx_test.tscn and run it (F6). Presentation only.

const PunchHitFX = preload("res://scripts/presentation/punch_fx/PunchHitFX.gd")

var _camera: Camera3D
var _target: MeshInstance3D
var _label: Label
var _busy: bool = false


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.07, 0.11)
	environment.glow_enabled = true
	environment.glow_hdr_threshold = 1.0
	environment.glow_intensity = 0.9
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_camera = Camera3D.new()
	_camera.environment = environment
	_camera.position = Vector3(0.0, 0.0, 10.0)
	_camera.fov = 34.0
	add_child(_camera)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 3.8)
	_target = MeshInstance3D.new()
	_target.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.32, 0.12, 0.12)
	_target.material_override = material
	add_child(_target)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.text = "Space / click: heavy punch    Shift+Space / right click: light punch    Enter: jab, jab, heavy"
	_label.position = Vector2(16, 12)
	layer.add_child(_label)


func _input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_hit(not event.shift_pressed)
		elif event.keycode == KEY_ENTER:
			_flurry()
	elif event is InputEventMouseButton and event.pressed:
		_hit(event.button_index == MOUSE_BUTTON_LEFT)


func _hit(heavy: bool) -> void:
	_busy = true
	var params: Dictionary = PunchHitFX.heavy_preset(1.8) if heavy else PunchHitFX.light_preset(1.8)
	PunchHitFX.play_at(self, Vector3(0.2, 0.2, 0.5), params)
	Engine.time_scale = 0.03
	await get_tree().create_timer(float(params.hit_stop_time), true, false, true).timeout
	Engine.time_scale = 1.0
	var home := Vector3.ZERO
	var knock := create_tween()
	knock.tween_property(_target, "position", home + Vector3(float(params.recoil_distance), 0.05, -0.3), 0.07)
	knock.tween_property(_target, "position", home, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.9).timeout
	_busy = false


func _flurry() -> void:
	_busy = true
	for index: int in range(3):
		var heavy: bool = index == 2
		var params: Dictionary = PunchHitFX.heavy_preset(1.8) if heavy else PunchHitFX.light_preset(1.8)
		PunchHitFX.play_at(self, Vector3(0.2 + randf_range(-0.2, 0.2), 0.2 + randf_range(-0.3, 0.3), 0.5), params)
		Engine.time_scale = 0.03
		await get_tree().create_timer(float(params.hit_stop_time), true, false, true).timeout
		Engine.time_scale = 1.0
		var knock := create_tween()
		knock.tween_property(_target, "position", Vector3(float(params.recoil_distance), 0.05, -0.3), 0.06)
		await get_tree().create_timer(0.12).timeout
	var back := create_tween()
	back.tween_property(_target, "position", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.9).timeout
	_busy = false


func _exit_tree() -> void:
	Engine.time_scale = 1.0
