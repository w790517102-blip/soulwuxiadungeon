extends RefCounted
## Short-lived attack effects for Card Stage, built from the slash and spark shaders.
## Both are plain nodes added under the stage's FX volume; they free themselves.

const SparkShader = preload("res://scripts/presentation/shaders/spark_burst.gdshader")




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


## The supplied sword-slash animation (assets/fx/fx_slash_sword.png: 5 frames, 320 x 500 each,
## the cut runs from lower left to upper right). Played once as a flat card in the FX volume,
## frame by frame, then it fades. `direction` +1 keeps the sheet's slant, -1 mirrors it.
const SLASH_SHEET := "res://assets/fx/fx_slash_sword.png"
const SLASH_FRAMES: int = 5
const SLASH_FRAME_SECONDS: float = 0.055


static func slash(host: Node, centre: Vector3, length: float, direction: float, intensity: float = 1.0, _draw_seconds: float = 0.0) -> void:
	var texture: Texture2D = load(SLASH_SHEET) as Texture2D
	if texture == null:
		return
	var root := Node3D.new()
	host.add_child(root)
	root.position = centre
	var frame_size := Vector2(float(texture.get_width()) / float(SLASH_FRAMES), float(texture.get_height()))
	var height: float = length
	var quad := QuadMesh.new()
	quad.size = Vector2(height * frame_size.x / frame_size.y, height)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 30
	material.albedo_texture = texture
	material.albedo_color = Color(1.0, 1.0, 1.0, intensity)
	material.uv1_scale = Vector3(1.0 / float(SLASH_FRAMES), 1.0, 1.0)
	mesh.material_override = material
	root.add_child(mesh)
	if direction < 0.0:
		root.scale.x = -1.0
	var play := host.create_tween()
	for frame: int in range(SLASH_FRAMES):
		play.tween_callback(func() -> void:
			material.uv1_offset = Vector3(float(frame) / float(SLASH_FRAMES), 0.0, 0.0)
		)
		play.tween_interval(SLASH_FRAME_SECONDS)
	play.tween_callback(root.queue_free)


## Total time the sheet takes to play.
static func slash_duration() -> float:
	return float(SLASH_FRAMES) * SLASH_FRAME_SECONDS


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
