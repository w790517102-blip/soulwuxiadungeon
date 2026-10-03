extends Node3D
## PunchShockRing: the broken ring of ink that bursts out of the contact point. Not a perfect circle:
## it has gaps, torn edges and a thin silver line inside, like ink on paper shaken by the blow.
## Presentation only.

const RingShader = preload("res://scripts/presentation/shaders/punch_ring.gdshader")

var ring_scale: float = 1.0
var life: float = 0.34
## How much of the ring is missing (0 whole, 1 almost nothing left).
var gaps: float = 0.45


func play() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * ring_scale
	var ring := MeshInstance3D.new()
	ring.mesh = quad
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = RingShader
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("gaps", gaps)
	material.render_priority = 35
	ring.material_override = material
	ring.rotation.z = randf() * TAU
	add_child(ring)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, life)
	tween.tween_callback(queue_free)
