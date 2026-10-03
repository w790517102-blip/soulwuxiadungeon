extends Node3D
## PunchImpactCore: the tiny, very bright cold-white point where the fist lands. Extremely short:
## it snaps on, with a hair-thin cross of light, and is gone. Presentation only.

const FlashShader = preload("res://scripts/presentation/shaders/hit_flash.gdshader")

## World size of the flash quad; `flash_intensity` scales how far above white it glows.
var impact_scale: float = 1.0
var flash_intensity: float = 3.4
var life: float = 0.09


func play() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * impact_scale
	var flash := MeshInstance3D.new()
	flash.mesh = quad
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = FlashShader
	material.set_shader_parameter("angle", randf_range(-0.3, 0.3))
	material.set_shader_parameter("intensity", flash_intensity)
	material.render_priority = 36
	flash.material_override = material
	add_child(flash)
	flash.scale = Vector3.ONE * 0.35
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.1, life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, life)
	tween.chain().tween_callback(queue_free)
