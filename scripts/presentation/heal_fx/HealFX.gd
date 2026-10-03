extends Node3D
## Healing (HEAL): green breath poured upward into the card, with soft light motes and real 3D leaves
## drifting up around it.
##   - STREAMS : soft vertical strands of green light climb from the card's feet to its head, with a
##               glow pooled at the base (heal_qi.gdshader).
##   - MOTES   : small green-white specks rise through the streams, swirling a little.
##   - LEAVES  : a dozen small leaves (real 3D meshes, double-sided) are lifted up around the card,
##               swaying and tumbling on all three axes as they rise, then fading.
## No flashes, no crosses, no hearts. Every number is a plain property (or a key of `defaults()`).
## Presentation only.

const QiShader = preload("res://scripts/presentation/shaders/heal_qi.gdshader")
const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")

# --- Tunable parameters ---------------------------------------------------------------------------
var duration: float = 1.5                   # seconds the streams last
var qi_intensity: float = 0.6
var mote_count: int = 36
var leaf_count: int = 12
var leaf_size: float = 0.07                 # leaf length as a share of the card height
var leaf_rise: float = 1.1                  # how far (in card heights) a leaf climbs
var leaf_sway: float = 0.22                 # sideways drift (in card widths)
var card_size: Vector2 = Vector2(2.0, 3.0)

const LEAF_COLOURS := [Color(0.35, 0.85, 0.35), Color(0.55, 0.95, 0.45), Color(0.25, 0.72, 0.38), Color(0.72, 0.95, 0.5)]


static func defaults() -> Dictionary:
	return {"duration": 1.5, "qi_intensity": 0.6, "mote_count": 36, "leaf_count": 12, "leaf_size": 0.07, "leaf_rise": 1.1, "leaf_sway": 0.22}


## Plays the heal on the card whose middle is `centre`.
static func play_at(host: Node, centre: Vector3, size: Vector2, params: Dictionary = {}) -> Node3D:
	var fx := new()
	host.add_child(fx)
	fx.position = centre
	fx.card_size = size
	for key: String in params.keys():
		fx.set(key, params[key])
	fx.play()
	return fx


func play() -> void:
	_streams()
	_motes()
	_leaves()
	get_tree().create_timer(duration + leaf_rise * 0.6 + 0.8).timeout.connect(queue_free)


func _streams() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(card_size.x * 1.15, card_size.y * 1.3)
	var material := ShaderMaterial.new()
	material.shader = QiShader
	material.render_priority = 38
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("intensity", qi_intensity)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	mesh.position = Vector3(0.0, card_size.y * 0.1, 0.0)
	add_child(mesh)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, duration)
	tween.tween_callback(mesh.queue_free)


func _motes() -> void:
	if mote_count <= 0:
		return
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 12.0
	process.initial_velocity_min = card_size.y * 0.45
	process.initial_velocity_max = card_size.y * 0.95
	process.gravity = Vector3.ZERO
	process.damping_min = card_size.y * 0.08
	process.damping_max = card_size.y * 0.25
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.5
	process.turbulence_noise_scale = 1.6
	process.scale_min = 0.5
	process.scale_max = 1.3
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(card_size.x * 0.40, card_size.y * 0.03, 0.05)
	process.color_ramp = GhostFire._ramp(
		PackedColorArray([Color(0.88, 1.0, 0.82, 0.0), Color(0.55, 1.0, 0.55, 0.7), Color(0.30, 0.85, 0.40, 0.4), Color(0.2, 0.7, 0.3, 0.0)]),
		PackedFloat32Array([0.0, 0.15, 0.7, 1.0]))
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * card_size.y * 0.028
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.render_priority = 43
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.amount = mote_count
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 0.0
	particles.preprocess = 0.0
	particles.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	particles.position = Vector3(0.0, -card_size.y * 0.42, 0.1)
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(2.8).timeout.connect(particles.queue_free)


## A leaf: a slim pointed oval along its length with a lighter midrib, built as a strip of segments.
func _leaf_mesh(length: float) -> ArrayMesh:
	var segments: int = 6
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for step: int in range(segments + 1):
		var s: float = float(step) / float(segments)
		var y: float = (s - 0.5) * length
		var half: float = sin(s * PI) * length * 0.26 * (1.0 - 0.25 * s)
		# midrib vertex between the two edge vertices
		vertices.append(Vector3(-half, y, 0.0))
		colours.append(Color(0.5, 0.85, 0.4, 1.0))
		vertices.append(Vector3(0.0, y, 0.004 * length))
		colours.append(Color(0.95, 1.0, 0.8, 1.0))
		vertices.append(Vector3(half, y, 0.0))
		colours.append(Color(0.5, 0.85, 0.4, 1.0))
		if step < segments:
			var base: int = step * 3
			indices.append_array(PackedInt32Array([base, base + 1, base + 3, base + 1, base + 4, base + 3, base + 1, base + 2, base + 4, base + 2, base + 5, base + 4]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _leaves() -> void:
	var length: float = card_size.y * leaf_size
	var mesh_template: ArrayMesh = _leaf_mesh(length)
	for index: int in range(leaf_count):
		var leaf := MeshInstance3D.new()
		leaf.mesh = mesh_template
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = LEAF_COLOURS[index % LEAF_COLOURS.size()]
		material.emission_enabled = true
		material.emission = Color(0.2, 0.6, 0.25)
		material.emission_energy_multiplier = 0.6
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.render_priority = 44
		leaf.material_override = material
		add_child(leaf)
		var start := Vector3(randf_range(-0.5, 0.5) * card_size.x * 0.95, -card_size.y * randf_range(0.45, 0.30), randf_range(0.0, 0.3))
		var phase: float = randf() * TAU
		var spin := Vector3(randf_range(-2.4, 2.4), randf_range(-3.0, 3.0), randf_range(-1.6, 1.6))
		var sway: float = card_size.x * leaf_sway * randf_range(0.5, 1.0)
		var rise: float = card_size.y * leaf_rise * randf_range(0.65, 1.0)
		var seconds: float = randf_range(1.2, 1.8)
		leaf.position = start
		leaf.visible = false
		var tween := create_tween()
		tween.tween_interval(randf() * 0.7)
		tween.tween_callback(func() -> void: leaf.visible = true)
		tween.tween_method(_leaf_step.bind(leaf, material, start, phase, spin, sway, rise), 0.0, 1.0, seconds)
		tween.tween_callback(leaf.queue_free)


func _leaf_step(u: float, leaf: MeshInstance3D, material: StandardMaterial3D, start: Vector3, phase: float, spin: Vector3, sway: float, rise: float) -> void:
	if not is_instance_valid(leaf):
		return
	# Rises fast at first, then drifts (the breath lifting it, then letting it float).
	var lift: float = 1.0 - pow(1.0 - u, 1.8)
	leaf.position = start + Vector3(sin(u * 5.0 + phase) * sway, lift * rise, cos(u * 4.0 + phase) * sway * 0.5)
	leaf.rotation = spin * u * 2.2 + Vector3(sin(u * 6.0 + phase) * 0.6, 0.0, 0.0)
	var alpha: float = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.62, 1.0, u))
	material.albedo_color.a = alpha
