extends Node3D
## The basic attack of the lute (琴): a plucked string compresses the air in front of the player and
## the compressed air strikes the enemy. In order:
##   1. PRELUDE  - a short cold-white line flickers in front of the player's card (the string).
##   2. WAVE     - a soft, translucent half-moon of silver-white air, with a ghosted trail and a thin
##                 layer of black shadow lying under it, slides across the stage to the target.
##                 At the same time a fainter ring of air around the target collapses inward, timed
##                 to reach the centre exactly when the wave lands (the air caves in first).
##   3. BURST    - at that instant a small, strong white burst: silver light and pale black ink
##                 shatter outward with a few fine specks.
##   4. ECHO     - a ring-shaped mirage (a blurred refraction of the air, not a drawn circle) spreads
##                 from the spot, with a few faint string-like lines and thin black shiver marks, then
##                 everything fades.
## No crosshair, no water, no musical notes. Every knob is a plain property (or a key of
## `defaults()`). Presentation only.

const WaveShader = preload("res://scripts/presentation/shaders/lute_wave.gdshader")
const ContractShader = preload("res://scripts/presentation/shaders/lute_contract.gdshader")
const StringShader = preload("res://scripts/presentation/shaders/lute_strings.gdshader")
const BurstRingShader = preload("res://scripts/presentation/shaders/lute_burst_ring.gdshader")
const SpaceWarpFX = preload("res://scripts/presentation/punch_fx/SpaceWarpFX.gd")
const Core = preload("res://scripts/presentation/punch_fx/PunchImpactCore.gd")
const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")
const SparkShader = preload("res://scripts/presentation/shaders/hit_spark_particle.gdshader")

# --- Tunable parameters ---------------------------------------------------------------------------
var wave_speed: float = 0.26                # seconds the wave takes to reach the target
var wave_width: float = 1.8                 # height of the half-moon (world units)
var wave_arc: float = 0.95                  # how far the half-moon curves
var wave_opacity: float = 0.95              # how opaque the silver wave is
var shadow_trail_strength: float = 0.55     # opacity of the black shadow under the wave
var shadow_lag: float = 1.5                 # the shadow takes this many times as long as the light (Doppler feel)
var outer_ring_scale_start: float = 1.0     # radius of the collapsing ring at the start (share of its quad)
var outer_ring_scale_end: float = 0.03      # radius it collapses to
var outer_ring_alpha: float = 0.4           # how visible the collapsing ring is
var outer_ring_size: float = 4.0            # size of the collapsing ring's quad (world units)
var impact_flash_strength: float = 3.0      # brightness of the burst
var mirage_ring_duration: float = 0.5       # seconds the mirage ring takes to spread
var distortion_strength: float = 0.012      # how far the mirage ring bends the picture
var afterglow_duration: float = 0.5         # seconds the string lines / shiver marks linger
var halo_alpha: float = 0.8                 # the halo thrown outward once the air has been gathered
var halo_duration: float = 0.36
var shadow_ring_alpha: float = 0.5          # the ring-shaped shadow trace creeping outward
var shadow_ring_duration: float = 0.85
var spark_count: int = 8                    # fine white specks
var string_count: int = 0                   # faint string-like lines across the card
var shiver_marks: int = 3                   # thin black shiver marks
var card_width: float = 2.0
var card_height: float = 3.0
var critical: bool = false


static func defaults() -> Dictionary:
	return {
		"wave_speed": 0.26, "wave_width": 1.8, "wave_arc": 0.95, "wave_opacity": 0.95, "shadow_trail_strength": 0.55, "shadow_lag": 1.5,
		"outer_ring_scale_start": 1.0, "outer_ring_scale_end": 0.03, "outer_ring_alpha": 0.4, "outer_ring_size": 4.0,
		"impact_flash_strength": 3.0, "mirage_ring_duration": 0.5, "distortion_strength": 0.012,
		"afterglow_duration": 0.5, "spark_count": 8, "string_count": 0, "shiver_marks": 3,
	}


## Plays the attack from `origin` to `target` (world positions).
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
	if material != null:
		mesh.material_override = material
	return mesh


func _wave_material(tone: Color, opacity: float, trail: float, priority: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WaveShader
	material.set_shader_parameter("arc", wave_arc)
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("tone", tone)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("trail", trail)
	material.render_priority = priority
	return material


func play(origin_offset: Vector3) -> void:
	var toward: Vector3 = -origin_offset
	var heading: float = atan2(toward.y, toward.x)
	# 1. PRELUDE: a short cold-white line at the string.
	var line := _quad(Vector2(wave_width * 0.5, wave_width * 0.02), null, 40)
	add_child(line)
	line.position = origin_offset + toward.normalized() * 0.2
	line.rotation.z = heading + PI * 0.5
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	line_material.albedo_color = Color(0.95, 0.98, 1.0, 0.9)
	line_material.emission_enabled = true
	line_material.emission = Color(0.9, 0.95, 1.0)
	line_material.emission_energy_multiplier = 2.4
	line_material.render_priority = 40
	line.material_override = line_material
	var line_tween := create_tween()
	line_tween.tween_property(line_material, "albedo_color:a", 0.0, 0.08)
	line_tween.tween_callback(line.queue_free)
	# 2a. WAVE: the sound-light races ahead; the sound-shadow (a black half-moon, wider and ragged)
	# lags behind and lands later, so the two slide apart like a Doppler shift.
	var shadow_speed: float = wave_speed * shadow_lag
	var shadow_material := _wave_material(Color(0.02, 0.02, 0.03), shadow_trail_strength, 0.9, 37)
	shadow_material.set_shader_parameter("thickness", 0.16)
	shadow_material.set_shader_parameter("raggedness", 0.75)
	shadow_material.set_shader_parameter("emission_strength", 0.0)
	shadow_material.set_shader_parameter("rim_strength", 0.85)
	var wave_material := _wave_material(Color(0.93, 0.96, 1.0), wave_opacity, 0.8, 38)
	var shadow := _quad(Vector2(wave_width * 0.6, wave_width * 1.1), shadow_material, 37)
	var wave := _quad(Vector2(wave_width * 0.6, wave_width), wave_material, 38)
	for body: MeshInstance3D in [shadow, wave]:
		add_child(body)
		body.position = origin_offset
		body.rotation.z = heading
	var shadow_end := Vector3(0.0, -0.05, -0.02) - toward.normalized() * 0.05
	var travel := create_tween().set_parallel(true)
	travel.tween_property(wave, "position", Vector3.ZERO, wave_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel.tween_property(shadow, "position", shadow_end, shadow_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	travel.tween_method(func(value: float) -> void: wave_material.set_shader_parameter("t", value), 0.0, 1.0, wave_speed)
	travel.tween_method(func(value: float) -> void: shadow_material.set_shader_parameter("t", value), 0.0, 1.0, shadow_speed)
	travel.chain().tween_callback(wave.queue_free)
	travel.chain().tween_callback(shadow.queue_free)
	# 2b. COLLAPSE: the air around the target caves in, arriving as the wave lands.
	var contract_material := ShaderMaterial.new()
	contract_material.shader = ContractShader
	contract_material.set_shader_parameter("start_scale", outer_ring_scale_start)
	contract_material.set_shader_parameter("end_scale", outer_ring_scale_end)
	contract_material.set_shader_parameter("ring_alpha", outer_ring_alpha)
	contract_material.set_shader_parameter("seed", randf() * 10.0)
	var contract := _quad(Vector2.ONE * outer_ring_size * (1.2 if critical else 1.0), contract_material, 36)
	contract.position = Vector3(0.0, 0.0, 0.5)
	add_child(contract)
	var collapse := create_tween()
	collapse.tween_method(func(value: float) -> void: contract_material.set_shader_parameter("t", value), 0.0, 1.0, wave_speed)
	collapse.tween_callback(contract.queue_free)
	# 3. BURST and 4. ECHO: the instant the wave lands.
	get_tree().create_timer(wave_speed).timeout.connect(_burst)
	get_tree().create_timer(wave_speed * maxf(shadow_lag, 1.0) + maxf(maxf(mirage_ring_duration, afterglow_duration), shadow_ring_duration) + 0.4).timeout.connect(queue_free)


## The burst: a small strong white flash, silver specks and pale-black shards flying apart, then the
## echo (the mirage ring, a few faint strings and shiver marks).
func _burst() -> void:
	var seed_value: float = randf() * 10.0
	var core := Core.new()
	core.impact_scale = outer_ring_size * 0.32
	core.flash_intensity = impact_flash_strength
	core.afterimages = 0
	core.life = 0.07
	core.tremble = critical
	core.position = Vector3(0.0, 0.0, 0.7)
	add_child(core)
	core.play()
	_specks()
	_shards()
	_halo_burst()
	# ECHO
	if distortion_strength > 0.0:
		SpaceWarpFX.play_at(self, Vector3(0.0, 0.0, 0.8), outer_ring_size * 0.9, distortion_strength * (2.0 if critical else 1.0), mirage_ring_duration, true)
	if string_count > 0:
		var string_material := ShaderMaterial.new()
		string_material.shader = StringShader
		string_material.set_shader_parameter("seed", seed_value)
		string_material.set_shader_parameter("strings", float(string_count))
		string_material.set_shader_parameter("intensity", 1.4)
		var strings := _quad(Vector2(card_width * 1.05, card_height * 0.8), string_material, 37)
		strings.position = Vector3(0.0, 0.0, 0.45)
		add_child(strings)
		var string_tween := create_tween()
		string_tween.tween_method(func(value: float) -> void: string_material.set_shader_parameter("t", value), 0.0, 1.0, afterglow_duration)
		string_tween.tween_callback(strings.queue_free)
	_shiver_marks(seed_value)


## A few fine white specks thrown out by the burst.
func _specks() -> void:
	if spark_count <= 0:
		return
	var ramp: GradientTexture1D = GhostFire._ramp(
		PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.84, 0.91, 0.98, 0.85), Color(0.66, 0.76, 0.92, 0.0)]),
		PackedFloat32Array([0.0, 0.45, 1.0]))
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.ZERO
	process.spread = 180.0
	process.initial_velocity_min = outer_ring_size * 0.4
	process.initial_velocity_max = outer_ring_size * 1.1
	process.damping_min = outer_ring_size * 1.2
	process.damping_max = outer_ring_size * 2.2
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.0
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.016, 0.1)
	var material := ShaderMaterial.new()
	material.shader = SparkShader
	material.render_priority = 41
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	particles.amount = spark_count * (2 if critical else 1)
	particles.lifetime = 0.32
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	particles.position = Vector3(0.0, 0.0, 0.7)
	add_child(particles)
	particles.emitting = true


## Pale-black shards scattered with the burst (the shadow that rode under the wave breaking up).
func _shards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = 7 if critical else 5
	for index: int in range(count):
		var angle: float = rng.randf() * TAU
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var size: float = outer_ring_size * rng.randf_range(0.02, 0.05)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-size * 0.5, -size * 0.35, 0.0), Vector3(size * 0.5, -size * 0.2, 0.0), Vector3(0.0, size * 0.8, 0.0)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var shard := MeshInstance3D.new()
		shard.mesh = mesh
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.03, 0.03, 0.04, 0.62)
		material.render_priority = 40
		shard.material_override = material
		add_child(shard)
		shard.position = Vector3(0.0, 0.0, 0.7)
		shard.rotation.z = rng.randf() * TAU
		var reach: float = outer_ring_size * rng.randf_range(0.10, 0.26)
		var seconds: float = rng.randf_range(0.20, 0.32)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(shard, "position", Vector3(cos(angle), sin(angle), 0.0) * reach + Vector3(0.0, 0.0, 0.7), seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "rotation:z", shard.rotation.z + rng.randf_range(-2.0, 2.0), seconds)
		tween.tween_property(material, "albedo_color:a", 0.0, seconds * 0.6).set_delay(seconds * 0.4)
		tween.chain().tween_callback(shard.queue_free)


## Thin black shiver marks: short fine arcs lying around the contact, as the paper shakes.
func _shiver_marks(seed_value: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_value * 1000.0)
	for index: int in range(shiver_marks):
		var arc_mesh := ImmediateMesh.new()
		var radius: float = outer_ring_size * rng.randf_range(0.10, 0.22)
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
		material.albedo_color = Color(0.015, 0.015, 0.02, 0.8)
		material.render_priority = 35
		instance.material_override = material
		instance.position = Vector3(0.0, 0.0, 0.42)
		add_child(instance)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(instance, "scale", Vector3(1.7, 1.7, 1.0), afterglow_duration)
		tween.tween_property(material, "albedo_color:a", 0.0, afterglow_duration).set_delay(afterglow_duration * 0.2)
		tween.chain().tween_callback(instance.queue_free)


## The gathered air bursts back out: a bright ragged halo thrown outward fast, and a ring-shaped
## shadow trace that creeps outward slowly behind it.
func _halo_burst() -> void:
	var rings: Array = [
		{"tone": Color(0.93, 0.96, 1.0), "alpha": halo_alpha * (1.2 if critical else 1.0), "seconds": halo_duration, "reach": 0.8, "ease": 2.6, "emit": 1.8, "w0": 0.05, "w1": 0.11, "z": 0.75, "prio": 41},
		{"tone": Color(0.02, 0.02, 0.03), "alpha": shadow_ring_alpha, "seconds": shadow_ring_duration, "reach": 0.95, "ease": 1.8, "emit": 0.0, "w0": 0.06, "w1": 0.12, "z": 0.6, "prio": 39},
	]
	for entry: Dictionary in rings:
		var material := ShaderMaterial.new()
		material.shader = BurstRingShader
		material.set_shader_parameter("tone", entry.tone)
		material.set_shader_parameter("ring_alpha", entry.alpha)
		material.set_shader_parameter("reach", entry.reach)
		material.set_shader_parameter("ease_power", entry.ease)
		material.set_shader_parameter("emission_strength", entry.emit)
		material.set_shader_parameter("width_start", entry.w0)
		material.set_shader_parameter("width_end", entry.w1)
		material.set_shader_parameter("seed", randf() * 10.0)
		material.render_priority = entry.prio
		var quad := _quad(Vector2.ONE * outer_ring_size * (1.3 if critical else 1.1), material, entry.prio)
		quad.position = Vector3(0.0, 0.0, entry.z)
		add_child(quad)
		var tween := create_tween()
		tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, entry.seconds)
		tween.tween_callback(quad.queue_free)
