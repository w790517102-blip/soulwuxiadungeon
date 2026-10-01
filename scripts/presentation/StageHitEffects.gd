extends RefCounted
## Short-lived attack effects for Card Stage, built from the slash and spark shaders.
## Both are plain nodes added under the stage's FX volume; they free themselves.

const SlashShader = preload("res://scripts/presentation/shaders/slash_mark.gdshader")
const SparkShader = preload("res://scripts/presentation/shaders/spark_burst.gdshader")

const WHITE := Color(1.0, 1.0, 1.0)
const BLUE := Color(0.12, 0.45, 1.0)
const BLUE_FLASH := Color(0.7, 0.9, 1.0)


static func _layer(shader: Shader, size: Vector2, priority: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = size
	instance.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	instance.material_override = material
	return instance


## A diagonal cut (袈裟斬) across `centre`. `direction` is +1 for a cut that falls from the
## upper left to the lower right, -1 for the mirror. Two brushes: soft white outside, hard
## blue inside; the blue flickers once the cut is two thirds drawn. A faint white afterimage
## lingers. Awaitable: returns when the mark has faded.
static func slash(host: Node, centre: Vector3, length: float, direction: float, intensity: float = 1.0, draw_seconds: float = 0.16) -> void:
	var root := Node3D.new()
	host.add_child(root)
	root.position = centre
	# +x of the quad is the blade's path: pointing down-right for direction = +1.
	root.rotation = Vector3(0.0, 0.0, -deg_to_rad(52.0) * direction)
	if direction < 0.0:
		root.rotation.z = deg_to_rad(52.0)
		root.scale.x = -1.0
	var thickness: float = length * 0.2
	var outer: MeshInstance3D = _layer(SlashShader, Vector2(length, thickness), 30)
	var inner: MeshInstance3D = _layer(SlashShader, Vector2(length, thickness), 31)
	root.add_child(outer)
	root.add_child(inner)
	var outer_material := outer.material_override as ShaderMaterial
	var inner_material := inner.material_override as ShaderMaterial
	outer_material.set_shader_parameter("color", WHITE)
	outer_material.set_shader_parameter("width_scale", 0.95)
	outer_material.set_shader_parameter("softness", 0.5)
	outer_material.set_shader_parameter("alpha_mul", 0.9 * intensity)
	inner_material.set_shader_parameter("color", BLUE)
	inner_material.set_shader_parameter("width_scale", 0.38)
	inner_material.set_shader_parameter("softness", 0.04)
	inner_material.set_shader_parameter("alpha_mul", intensity)
	var set_reveal := func(value: float) -> void:
		outer_material.set_shader_parameter("reveal", value)
		inner_material.set_shader_parameter("reveal", value)
	var draw := host.create_tween()
	draw.tween_method(set_reveal, 0.0, 1.12, draw_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# At two thirds of the cut the blue flickers between its colour and a near-white flash.
	var flicker := host.create_tween()
	flicker.tween_interval(draw_seconds * (2.0 / 3.0))
	for step: int in range(5):
		var flash: bool = step % 2 == 0
		flicker.tween_callback(func() -> void:
			inner_material.set_shader_parameter("color", BLUE_FLASH if flash else BLUE)
		)
		flicker.tween_interval(0.035)
	await draw.finished
	await host.get_tree().create_timer(0.14).timeout
	# After the cut: the blue goes, a pale afterimage of the white lingers and thins.
	var after := host.create_tween().set_parallel(true)
	after.tween_method(func(value: float) -> void: inner_material.set_shader_parameter("alpha_mul", value), intensity, 0.0, 0.12)
	after.tween_method(func(value: float) -> void: outer_material.set_shader_parameter("alpha_mul", value), 0.9 * intensity, 0.0, 0.4)
	after.tween_method(func(value: float) -> void: outer_material.set_shader_parameter("width_scale", value), 0.95, 0.4, 0.4)
	await after.finished
	root.queue_free()


## A burst of jagged sparks at `centre`: thrown outward from the middle, then removed from
## the inside outward. Not awaited by callers (it plays on its own).
static func spark(host: Node, centre: Vector3, size: float = 1.7, heavy: bool = false) -> void:
	var root := Node3D.new()
	host.add_child(root)
	root.position = centre
	var seed: float = randf() * 50.0
	var scale_up: float = 1.35 if heavy else 1.0
	var base: MeshInstance3D = _layer(SparkShader, Vector2(size, size) * scale_up, 32)
	var top: MeshInstance3D = _layer(SparkShader, Vector2(size, size) * scale_up, 33)
	root.add_child(base)
	root.add_child(top)
	var base_material := base.material_override as ShaderMaterial
	var top_material := top.material_override as ShaderMaterial
	base_material.set_shader_parameter("color", Color(0.55, 0.04, 0.05, 0.6))
	base_material.set_shader_parameter("reach", 1.0)
	base_material.set_shader_parameter("seed", seed)
	top_material.set_shader_parameter("color", Color(1.0, 0.93, 0.55, 1.0))
	top_material.set_shader_parameter("reach", 0.62)
	top_material.set_shader_parameter("seed", seed)
	var tween := host.create_tween().set_parallel(true)
	for material: ShaderMaterial in [base_material, top_material]:
		tween.tween_method(func(value: float) -> void: material.set_shader_parameter("burst", value), 0.0, 1.0, 0.14)
		tween.tween_method(func(value: float) -> void: material.set_shader_parameter("vanish", value), 0.0, 1.0, 0.3).set_delay(0.1)
	tween.chain().tween_callback(root.queue_free)
