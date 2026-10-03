extends Node3D
## The basic attack of the lute (琴): a plucked string sets the air shaking, and the struck card
## resonates. Clean and sparing, the opposite of a blast:
##   1. PLUCK   - one very thin cold-white pressure front leaves the player's card and crosses the
##                stage depth toward the enemy (a wavefront in the air, not a missile);
##   2. RESONATE - at the enemy, one or two incomplete rings of light spread over the card, a few
##                hair-thin string lines shiver across it, a mild warp ripples the space and a very
##                few fine sparks and thin black shiver marks flicker;
##   3. AFTERGLOW - the rings and strings ring on a moment and fade.
## Every knob is a plain property (or a key of `defaults()`) so other lute skills can derive from it.
## Presentation only.

const WaveShader = preload("res://scripts/presentation/shaders/lute_wave.gdshader")
const RingShader = preload("res://scripts/presentation/shaders/lute_resonance.gdshader")
const StringShader = preload("res://scripts/presentation/shaders/lute_strings.gdshader")
const SpaceWarpFX = preload("res://scripts/presentation/punch_fx/SpaceWarpFX.gd")
const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")
const SparkShader = preload("res://scripts/presentation/shaders/hit_spark_particle.gdshader")

# --- Tunable parameters ---------------------------------------------------------------------------
var wave_speed: float = 0.20            # seconds the pressure front takes to cross to the target
var wave_width: float = 1.6             # height of the front (world units)
var wave_arc: float = 0.9               # how far the front bows (0 = nearly straight)
var resonance_radius: float = 2.4       # size of the resonance rings on the struck card (world units)
var resonance_duration: float = 0.55    # seconds the rings take to spread and settle
var afterglow_time: float = 0.55        # seconds the string lines ring on
var distortion_strength: float = 0.008  # the mild warp of the space (0 = none)
var spark_count: int = 6                # a very few fine sparks
var ring_count: int = 2                 # one or two resonance rings
var string_count: int = 5               # hair-thin string lines across the card
var shiver_marks: int = 3               # thin black shiver marks
var card_width: float = 2.0             # width of the struck card (for the string lines)
var card_height: float = 3.0
var critical: bool = false


static func defaults() -> Dictionary:
	return {
		"wave_speed": 0.20, "wave_width": 1.6, "wave_arc": 0.9, "resonance_radius": 2.4, "resonance_duration": 0.55,
		"afterglow_time": 0.55, "distortion_strength": 0.008, "spark_count": 6, "ring_count": 2,
		"string_count": 5, "shiver_marks": 3,
	}


## Plays the pluck from `origin` to `target` (world positions) and the resonance at the target.
static func play_between(host: Node, origin: Vector3, target: Vector3, params: Dictionary = {}) -> Node3D:
	var fx := new()
	host.add_child(fx)
	fx.position = target
	for key: String in params.keys():
		fx.set(key, params[key])
	fx.play(origin - target)
	return fx


func _quad(size: Vector2, material: Material, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if material is ShaderMaterial:
		(material as ShaderMaterial).render_priority = priority
	mesh.material_override = material
	return mesh


func play(origin_offset: Vector3) -> void:
	# 1. PLUCK: the front crosses from the player's card to the target.
	var wave_material := ShaderMaterial.new()
	wave_material.shader = WaveShader
	wave_material.set_shader_parameter("arc", wave_arc)
	wave_material.set_shader_parameter("thickness", 0.011)
	var wave := _quad(Vector2(wave_width * 0.55, wave_width), wave_material, 38)
	add_child(wave)
	var toward: Vector3 = -origin_offset
	wave.position = origin_offset
	# The front faces the way it travels: +x of the quad points at the target on screen.
	wave.rotation.z = atan2(toward.y, toward.x) if toward.x >= 0.0 else atan2(toward.y, toward.x)
	var travel := create_tween().set_parallel(true)
	travel.tween_property(wave, "position", Vector3.ZERO, wave_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel.tween_method(func(value: float) -> void: wave_material.set_shader_parameter("t", value), 0.0, 1.0, wave_speed)
	travel.chain().tween_callback(wave.queue_free)
	# 2. RESONATE: when the front arrives.
	get_tree().create_timer(wave_speed * 0.92).timeout.connect(_resonate)
	get_tree().create_timer(wave_speed + maxf(resonance_duration, afterglow_time) + 0.4).timeout.connect(queue_free)


func _resonate() -> void:
	var seed_value: float = randf() * 10.0
	# The rings.
	var ring_material := ShaderMaterial.new()
	ring_material.shader = RingShader
	ring_material.set_shader_parameter("seed", seed_value)
	ring_material.set_shader_parameter("rings", float(ring_count))
	ring_material.set_shader_parameter("intensity", 2.8 if critical else 2.2)
	var rings := _quad(Vector2.ONE * resonance_radius * (1.25 if critical else 1.0), ring_material, 36)
	rings.position = Vector3(0.0, 0.0, 0.4)
	rings.rotation.z = randf() * TAU
	add_child(rings)
	var ring_tween := create_tween()
	ring_tween.tween_method(func(value: float) -> void: ring_material.set_shader_parameter("t", value), 0.0, 1.0, resonance_duration)
	ring_tween.tween_callback(rings.queue_free)
	# The string lines across the card.
	var string_material := ShaderMaterial.new()
	string_material.shader = StringShader
	string_material.set_shader_parameter("seed", seed_value)
	string_material.set_shader_parameter("strings", float(string_count))
	var strings := _quad(Vector2(card_width * 1.05, card_height * 0.8), string_material, 37)
	strings.position = Vector3(0.0, 0.0, 0.45)
	add_child(strings)
	var string_tween := create_tween()
	string_tween.tween_method(func(value: float) -> void: string_material.set_shader_parameter("t", value), 0.0, 1.0, afterglow_time)
	string_tween.tween_callback(strings.queue_free)
	# A mild warp of the space (the sound shaking the air).
	if distortion_strength > 0.0:
		SpaceWarpFX.play_at(self, Vector3(0.0, 0.0, 0.7), resonance_radius * 1.3, distortion_strength * (2.0 if critical else 1.0), 0.4)
	_sparks()
	_shiver_marks(seed_value)


## A very few fine white sparks.
func _sparks() -> void:
	if spark_count <= 0:
		return
	var ramp: GradientTexture1D = GhostFire._ramp(
		PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.84, 0.91, 0.98, 0.85), Color(0.66, 0.76, 0.92, 0.0)]),
		PackedFloat32Array([0.0, 0.45, 1.0]))
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.ZERO
	process.spread = 180.0
	process.initial_velocity_min = resonance_radius * 0.5
	process.initial_velocity_max = resonance_radius * 1.4
	process.damping_min = resonance_radius * 1.6
	process.damping_max = resonance_radius * 2.8
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 1.0
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.014, 0.17)
	var material := ShaderMaterial.new()
	material.shader = SparkShader
	material.render_priority = 39
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	particles.amount = spark_count
	particles.lifetime = 0.34
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	particles.position = Vector3(0.0, 0.0, 0.5)
	add_child(particles)
	particles.emitting = true


## Thin black shiver marks: short fine arcs of ink lying around the contact, as the paper shakes.
func _shiver_marks(seed_value: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_value * 1000.0)
	for index: int in range(shiver_marks):
		var arc_mesh := ImmediateMesh.new()
		var radius: float = resonance_radius * rng.randf_range(0.18, 0.4)
		var start: float = rng.randf() * TAU
		var span: float = rng.randf_range(0.5, 1.1)
		arc_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for step: int in range(13):
			var a: float = start + span * float(step) / 12.0
			arc_mesh.surface_add_vertex(Vector3(cos(a) * radius, sin(a) * radius, 0.0))
		arc_mesh.surface_end()
		var instance := MeshInstance3D.new()
		instance.mesh = arc_mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.015, 0.015, 0.02, 0.9)
		material.render_priority = 35
		instance.material_override = material
		instance.position = Vector3(0.0, 0.0, 0.42)
		add_child(instance)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(instance, "scale", Vector3(1.6, 1.6, 1.0), resonance_duration)
		tween.tween_property(material, "albedo_color:a", 0.0, resonance_duration).set_delay(resonance_duration * 0.2)
		tween.chain().tween_callback(instance.queue_free)
