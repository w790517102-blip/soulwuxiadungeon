extends Node3D
## PunchWhiteSpark: light that has been shattered: short cold-white streaks thrown out fast from the
## contact point (GPU particles, additive, brighter than white so the stage glow picks them up).
## Not star shapes, not confetti. Presentation only.

const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")
const SparkShader = preload("res://scripts/presentation/shaders/hit_spark_particle.gdshader")

var spark_count: int = 14
var spark_size: float = 1.8
var life: float = 0.3


func play() -> void:
	var ramp: GradientTexture1D = GhostFire._ramp(
		PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.84, 0.91, 0.98, 0.9), Color(0.66, 0.76, 0.92, 0.0)]),
		PackedFloat32Array([0.0, 0.45, 1.0]))
	var streaks := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.ZERO
	process.spread = 180.0
	process.initial_velocity_min = spark_size * 1.7
	process.initial_velocity_max = spark_size * 4.6
	process.damping_min = spark_size * 3.0
	process.damping_max = spark_size * 6.0
	process.gravity = Vector3(0.0, -spark_size * 0.5, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.3
	process.color_ramp = ramp
	streaks.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2(spark_size * 0.020, spark_size * 0.28)
	var material := ShaderMaterial.new()
	material.shader = SparkShader
	material.render_priority = 37
	mesh.material = material
	streaks.draw_pass_1 = mesh
	streaks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	streaks.amount = maxi(spark_count, 1)
	streaks.lifetime = life
	streaks.one_shot = true
	streaks.explosiveness = 1.0
	streaks.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	add_child(streaks)
	streaks.emitting = true
	get_tree().create_timer(life + 0.4).timeout.connect(queue_free)
