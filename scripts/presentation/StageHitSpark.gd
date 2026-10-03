extends Node3D
## The hit spark: a bright white-blade burst, in the same visual language as the sword cut (high
## contrast, silver-white, a little black ink), not a cartoon star. Three layers:
##   1. Core flash   - a white-hot burst with a short cross of cracking light (about 0.1 s).
##   2. Spark particles - a handful of small cold-white streaks and chips thrown outward fast.
##   3. Residual trace - a few thin cracks of light and black ink flecks along the direction of the
##      cut, which linger a little longer so the hit reads as the blade's, not as a separate icon.
## Materials are brighter than white (HDR) so the stage's glow makes them shine. Presentation only.

const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")
const FlashShader = preload("res://scripts/presentation/shaders/hit_flash.gdshader")
const SparkShader = preload("res://scripts/presentation/shaders/hit_spark_particle.gdshader")

## The way the sword cut travels on screen (upper left to lower right), used for the residual trace.
const CUT_ANGLE := -0.52


## Plays a hit spark at `centre` (it frees itself). `size` scales the whole thing; `heavy` is bigger.
static func play(host: Node, centre: Vector3, size: float = 1.8, heavy: bool = false) -> void:
	var spark := new()
	host.add_child(spark)
	spark.position = centre
	spark._run(size * (1.35 if heavy else 1.0), heavy)


func _run(size: float, heavy: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_core_flash(size, heavy, rng)
	_spark_particles(size, heavy)
	_residual_trace(size, heavy, rng)
	get_tree().create_timer(0.9).timeout.connect(queue_free)


# --- 1. Core flash ------------------------------------------------------------------------------

func _core_flash(size: float, heavy: bool, rng: RandomNumberGenerator) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * 1.35
	var flash := MeshInstance3D.new()
	flash.mesh = quad
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = FlashShader
	material.set_shader_parameter("angle", CUT_ANGLE + rng.randf_range(-0.25, 0.25))
	material.set_shader_parameter("intensity", 3.4 if heavy else 2.8)
	material.render_priority = 33
	flash.material_override = material
	add_child(flash)
	# Billboard it by facing the camera each frame is overkill for 0.1 s: the stage camera is square-on.
	var life: float = 0.14 if heavy else 0.10
	flash.scale = Vector3.ONE * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.25, life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, life)
	tween.chain().tween_callback(flash.queue_free)


# --- 2. Spark particles -------------------------------------------------------------------------

func _spark_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SparkShader
	material.render_priority = 34
	return material


func _spark_particles(size: float, heavy: bool) -> void:
	var ramp: GradientTexture1D = GhostFire._ramp(
		PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.82, 0.90, 1.0, 0.9), Color(0.65, 0.75, 0.95, 0.0)]),
		PackedFloat32Array([0.0, 0.45, 1.0]))
	# Short streaks flying outward, aligned with their motion.
	var streaks := GPUParticles3D.new()
	var streak_process := ParticleProcessMaterial.new()
	streak_process.direction = Vector3(0.0, 0.0, 0.0)
	streak_process.spread = 180.0
	streak_process.initial_velocity_min = size * 1.8
	streak_process.initial_velocity_max = size * (5.6 if heavy else 4.6)
	streak_process.damping_min = size * 3.0
	streak_process.damping_max = size * 6.0
	streak_process.gravity = Vector3(0.0, -size * 0.5, 0.0)
	streak_process.scale_min = 0.6
	streak_process.scale_max = 1.3
	streak_process.color_ramp = ramp
	streaks.process_material = streak_process
	var streak_mesh := QuadMesh.new()
	streak_mesh.size = Vector2(size * 0.022, size * 0.30)
	streak_mesh.material = _spark_material()
	streaks.draw_pass_1 = streak_mesh
	streaks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	streaks.amount = 22 if heavy else 16
	streaks.lifetime = 0.3
	streaks.one_shot = true
	streaks.explosiveness = 1.0
	streaks.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	add_child(streaks)
	streaks.emitting = true
	# A few round chips of light, slower.
	var dots := GPUParticles3D.new()
	var dot_process := ParticleProcessMaterial.new()
	dot_process.direction = Vector3(0.0, 0.0, 0.0)
	dot_process.spread = 180.0
	dot_process.initial_velocity_min = size * 0.6
	dot_process.initial_velocity_max = size * 3.0
	dot_process.damping_min = size * 2.0
	dot_process.damping_max = size * 4.5
	dot_process.gravity = Vector3(0.0, -size * 1.4, 0.0)
	dot_process.scale_min = 0.5
	dot_process.scale_max = 1.2
	dot_process.color_ramp = ramp
	dots.process_material = dot_process
	var dot_mesh := QuadMesh.new()
	dot_mesh.size = Vector2(size * 0.065, size * 0.065)
	var dot_material := _spark_material()
	dot_mesh.material = dot_material
	dots.draw_pass_1 = dot_mesh
	dots.amount = 14 if heavy else 10
	dots.lifetime = 0.34
	dots.one_shot = true
	dots.explosiveness = 1.0
	dots.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	add_child(dots)
	dots.emitting = true


# --- 3. Residual slash trace --------------------------------------------------------------------

func _residual_trace(size: float, heavy: bool, rng: RandomNumberGenerator) -> void:
	# Thin cracks of light along the line of the cut.
	var crack_count: int = 4 if heavy else 3
	for index: int in range(crack_count):
		var crack := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var length: float = size * rng.randf_range(0.55, 1.15)
		quad.size = Vector2(length, size * rng.randf_range(0.006, 0.014))
		crack.mesh = quad
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = Color(0.92, 0.96, 1.0, 0.95)
		material.emission_enabled = true
		material.emission = Color(0.9, 0.95, 1.0)
		material.emission_energy_multiplier = 2.2
		material.render_priority = 32
		crack.material_override = material
		add_child(crack)
		crack.rotation.z = CUT_ANGLE + rng.randf_range(-0.22, 0.22)
		crack.position = Vector3(rng.randf_range(-0.1, 0.1) * size, rng.randf_range(-0.1, 0.1) * size, 0.0)
		var life: float = rng.randf_range(0.22, 0.38)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(crack, "scale", Vector3(1.5, 0.3, 1.0), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(material, "albedo_color:a", 0.0, life)
		tween.tween_property(material, "emission_energy_multiplier", 0.0, life)
		tween.chain().tween_callback(crack.queue_free)
	# A few black ink flecks that stay a little longer.
	for index: int in range(5 if heavy else 3):
		var fleck := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(size * rng.randf_range(0.035, 0.09), size * rng.randf_range(0.012, 0.03))
		fleck.mesh = quad
		fleck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.02, 0.02, 0.03, 0.9)
		material.render_priority = 31
		fleck.material_override = material
		add_child(fleck)
		var angle: float = CUT_ANGLE + rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0)
		fleck.rotation.z = angle
		fleck.position = Vector3(cos(angle), sin(angle), 0.0) * size * 0.1
		var travel: float = size * rng.randf_range(0.25, 0.6)
		var life: float = rng.randf_range(0.4, 0.62)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(fleck, "position", Vector3(cos(angle), sin(angle), 0.0) * travel, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(material, "albedo_color:a", 0.0, life).set_delay(life * 0.35)
		tween.chain().tween_callback(fleck.queue_free)
