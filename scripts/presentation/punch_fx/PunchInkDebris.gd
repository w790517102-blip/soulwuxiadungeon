extends Node3D
## PunchInkDebris: a few flecks and drops of black ink thrown out by the blow. Kept few, so the
## contact point stays readable. Presentation only.

var ink_amount: int = 4
var debris_size: float = 1.8


func play() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index: int in range(ink_amount):
		var fleck := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var round_drop: bool = rng.randf() < 0.5
		if round_drop:
			quad.size = Vector2(debris_size * rng.randf_range(0.03, 0.06), debris_size * rng.randf_range(0.03, 0.06))
		else:
			quad.size = Vector2(debris_size * rng.randf_range(0.05, 0.11), debris_size * rng.randf_range(0.012, 0.03))
		fleck.mesh = quad
		fleck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.015, 0.015, 0.02, 0.95)
		material.render_priority = 34
		fleck.material_override = material
		add_child(fleck)
		var angle: float = rng.randf() * TAU
		var direction := Vector3(cos(angle), sin(angle), 0.0)
		fleck.rotation.z = angle
		fleck.position = direction * debris_size * 0.06
		var travel: float = debris_size * rng.randf_range(0.28, 0.62)
		var seconds: float = rng.randf_range(0.34, 0.5)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(fleck, "position", direction * travel + Vector3(0.0, -debris_size * 0.06, 0.0), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(material, "albedo_color:a", 0.0, seconds * 0.6).set_delay(seconds * 0.4)
		tween.chain().tween_callback(fleck.queue_free)
	get_tree().create_timer(0.8).timeout.connect(queue_free)
