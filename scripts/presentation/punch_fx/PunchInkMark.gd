extends Node3D
## PunchInkMark: the black ink a punch leaves behind, in the same black-ink style as the trace of a
## sword or 刀 cut (not a drawn fist, not a cut). It appears at the contact point at once and fades
## away slowly, long after the white light has gone. Presentation only.

const MarkShader = preload("res://scripts/presentation/shaders/punch_mark.gdshader")

var mark_scale: float = 1.0
var life: float = 0.9


func play() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * mark_scale
	var mark := MeshInstance3D.new()
	mark.mesh = quad
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = MarkShader
	material.set_shader_parameter("seed", randf() * 10.0)
	material.render_priority = 33
	mark.material_override = material
	mark.rotation.z = randf() * TAU
	add_child(mark)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, life)
	tween.tween_callback(queue_free)
