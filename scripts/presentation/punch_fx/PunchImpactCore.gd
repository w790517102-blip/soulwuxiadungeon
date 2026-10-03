extends Node3D
## PunchImpactCore: the tiny, very bright cold-white point where the fist lands. Extremely short: it
## snaps on, with a hair-thin cross of light, and is gone. It also drags afterimages of itself back
## along the line the fist came in on, soft smears of white that fade at once, so the blow reads as
## fast. Presentation only.

const FlashShader = preload("res://scripts/presentation/shaders/hit_flash.gdshader")

## World size of the flash quad; `flash_intensity` scales how far above white it glows.
var impact_scale: float = 1.0
var flash_intensity: float = 3.4
var life: float = 0.06
## +1: the fist came from the left, -1: from the right. `afterimages` ghost copies trail behind.
var travel_dir: float = 1.0
var afterimages: int = 3


func _flash(size: Vector2, intensity: float, flash_life: float, position_offset: Vector3, start_scale: float) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var flash := MeshInstance3D.new()
	flash.mesh = quad
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = FlashShader
	material.set_shader_parameter("angle", randf_range(-0.3, 0.3))
	material.set_shader_parameter("intensity", intensity)
	material.render_priority = 36
	flash.material_override = material
	add_child(flash)
	flash.position = position_offset
	flash.scale = Vector3.ONE * start_scale
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.1, flash_life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# The light drifts back along the blow and, near the end of its life, trembles slightly.
	var drift_to: Vector3 = position_offset - Vector3(travel_dir * impact_scale * 0.35, 0.0, 0.0)
	tween.tween_method(func(value: float) -> void:
		var base: Vector3 = position_offset.lerp(drift_to, value)
		var tremble: float = smoothstep(0.55, 1.0, value) * impact_scale * 0.06
		if is_instance_valid(flash):
			flash.position = base + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * tremble
	, 0.0, 1.0, flash_life)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, flash_life)
	tween.chain().tween_callback(flash.queue_free)


func play() -> void:
	_flash(Vector2.ONE * impact_scale, flash_intensity, life, Vector3.ZERO, 0.35)
	# Afterimages: long soft smears of white left behind along the line of the blow, one after another.
	for index: int in range(afterimages):
		var behind: float = impact_scale * (0.55 + 0.5 * float(index))
		var offset := Vector3(-travel_dir * behind, randf_range(-0.04, 0.04) * impact_scale, 0.0)
		var size := Vector2(impact_scale * (1.9 - 0.25 * float(index)), impact_scale * (0.42 - 0.08 * float(index)))
		var delay: float = 0.012 * float(index + 1)
		get_tree().create_timer(delay, true, false, true).timeout.connect(
			_flash.bind(size, flash_intensity * (0.62 - 0.14 * float(index)), life * 1.6, offset, 0.7))
	get_tree().create_timer(0.4).timeout.connect(queue_free)
