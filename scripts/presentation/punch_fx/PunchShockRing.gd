extends Node3D
## PunchShockRing: one circular wave of ink and glow spreading from the contact point (a broad soft
## band, no thin outline). PunchHitFX fires several of them at once, each tilted to its own plane and
## given its own speed and reach, but all sharing one clock so they vanish at the same moment.
## Presentation only.

const RingShader = preload("res://scripts/presentation/shaders/punch_ring.gdshader")

var ring_scale: float = 1.0
## The shared clock: every ring of a hit is driven by the same 0..1 value.
var life: float = 0.38
var max_radius: float = 0.9
var speed: float = 2.6
var centre_dim: float = 0.0
## The plane the wave lies in, as rotations about x, y and z (radians).
var plane: Vector3 = Vector3.ZERO

var _material: ShaderMaterial


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * ring_scale
	var ring := MeshInstance3D.new()
	ring.mesh = quad
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = RingShader
	_material.set_shader_parameter("seed", randf() * 10.0)
	_material.set_shader_parameter("max_radius", max_radius)
	_material.set_shader_parameter("speed", speed)
	_material.set_shader_parameter("centre_dim", centre_dim)
	_material.render_priority = 35
	ring.material_override = _material
	ring.rotation = plane
	add_child(ring)


## Sets the ring to the shared clock value `t` (0..1).
func set_clock(t: float) -> void:
	if _material != null:
		_material.set_shader_parameter("t", t)
