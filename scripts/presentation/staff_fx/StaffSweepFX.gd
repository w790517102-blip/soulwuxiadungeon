extends Node3D
## The basic attack of the long staff (棍): a heavy flat sweep. In order:
##   1. SWEEP  - a wide, soft, mostly transparent band of air (staff_wind.gdshader) is dragged across
##               the stage along an arc: tight at its head, opening into a broad ghost behind it, with a
##               thread of cold-white along its outer edge, pale smoke and a few grains of dust.
##   2. IMPACT - when the head passes the target: a short, wide, cold-white flash; thick short bars of
##               pressed air thrown left and right; a few grey-white motes; a very faint, quick, ragged
##               blunt shock ring; a light warp of the space. (The stage shoves the card sideways here.)
## Not a sword crescent, not a fist burst: one long staff sweeping a whole slab of air.
## Every number is a plain property (or a key of `defaults()`). Presentation only.

signal impact          # the head of the sweep has reached the target

const BladeShader = preload("res://scripts/presentation/shaders/blade_slash.gdshader")
const RingShader = preload("res://scripts/presentation/shaders/lute_burst_ring.gdshader")
const SpaceWarpFX = preload("res://scripts/presentation/punch_fx/SpaceWarpFX.gd")
const Core = preload("res://scripts/presentation/punch_fx/PunchImpactCore.gd")
const Mark = preload("res://scripts/presentation/punch_fx/PunchInkMark.gd")
const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")

# --- Tunable parameters ---------------------------------------------------------------------------
var staff_arc_width: float = 1.0            # thickness of the wind band (1 = default)
var impact_swell: float = 0.7                # how much the trace suddenly widens at the point of impact
var swoosh_depth: float = 1.0               # how deep the swoosh curls under itself after the hit (1 = default)
var origin_offset: Vector3 = Vector3(-8.0, 0.0, 0.0)   # where the wielder stands, relative to the target (set by the stage)
var camera_offset: Vector3 = Vector3(0.0, 2.0, 14.0)   # where the camera is, relative to the target (set by the stage)
var sweep_end_share: float = 0.30          # share of the effect time the heads take to cross (smaller = faster)
var effect_time: float = 0.95               # life of the whole sweep (the light, then the ink that lingers)
var dust_amount: int = 14
var impact_width: float = 1.0               # width of the impact flash and air bars (1 = default)
var shockwave_strength: float = 1.0         # visibility of the blunt shock ring
var warp_strength: float = 0.0
var direction: float = 1.0                  # +1 sweeps left to right
var card_size: Vector2 = Vector2(2.0, 3.0)
var critical: bool = false

var mark_strength: float = 1.0              # how strongly the hit leaves a dark trace on the card
var mark_fade_time: float = 0.9             # seconds the dark trace takes to fade


static func defaults() -> Dictionary:
	return {
		"staff_arc_width": 1.0, "impact_swell": 0.7, "swoosh_depth": 1.0, "sweep_end_share": 0.30, "effect_time": 0.95,
		"mark_strength": 1.0, "mark_fade_time": 0.9, "dust_amount": 14, "impact_width": 1.0, "shockwave_strength": 1.0,
		"warp_strength": 0.0,
	}


## Plays the sweep across the target at `centre`. The swing passes through the target's middle.
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
	var impact_reach: float = _swoosh()
	_dust_trail()
	# The head's time to reach the point of impact (the shader's accelerating sweep).
	get_tree().create_timer(sweep_end_share * effect_time * pow(impact_reach, 0.6)).timeout.connect(_impact)
	get_tree().create_timer(effect_time + mark_fade_time + 0.5).timeout.connect(queue_free)


## The path of the staff's head across the whole stage, in this node's space (the target's middle is
## the origin, `direction` is the way the sweep travels): it leaves the wielder low and thin, runs
## across to the target (the point of impact), carries on past it, then curls down and back under
## itself in one big swoosh. Returns the share of the path's length at which the target is hit.
func _swoosh_points() -> PackedVector3Array:
	var h: float = card_size.y
	var w: float = card_size.x
	var run: float = maxf(absf(origin_offset.x), h * 2.5)
	var side: float = direction
	var rise: float = origin_offset.y
	var anchors: Array = [
		Vector3(-side * run * 0.97, rise * 0.7 + h * 0.10, 0.0),
		Vector3(-side * run * 0.62, rise * 0.4 + h * 0.34, 0.0),
		Vector3(-side * run * 0.30, h * 0.30, 0.0),
		Vector3(0.0, h * 0.15, 0.0),                                  # the point of impact
		Vector3(side * w * 0.95, -h * 0.05, 0.0),
		Vector3(side * w * 1.25, -h * 0.40 * swoosh_depth, 0.0),
		Vector3(side * w * 0.55, -h * 0.62 * swoosh_depth, 0.0),
		Vector3(-side * w * 0.60, -h * 0.68 * swoosh_depth, 0.0),
		Vector3(-side * run * 0.30, -h * 0.62 * swoosh_depth, 0.0),
	]
	# Depth: the swoosh starts far from the camera and is swept toward it (so perspective alone makes it
	# thin where it begins and broad where it ends). The sideways positions above are where it should
	# APPEAR on screen, so each is pushed out or in from the camera's axis to compensate.
	var distance: float = maxf(camera_offset.z, 4.0)
	var depths: Array[float] = [-0.60, -0.46, -0.28, 0.0, 0.10, 0.22, 0.34, 0.44, 0.50]
	for index: int in range(anchors.size()):
		var anchor: Vector3 = anchors[index]
		var z: float = depths[index] * distance + (0.35 if index == 3 else 0.0)
		var scale: float = (distance - z) / distance
		var axis := Vector3(camera_offset.x, camera_offset.y, 0.0)
		anchors[index] = Vector3(axis.x + (anchor.x - axis.x) * scale, axis.y + (anchor.y - axis.y) * scale, z)
	# Catmull-Rom through the anchors.
	var points := PackedVector3Array()
	var count: int = anchors.size()
	for index: int in range(count - 1):
		var p0: Vector3 = anchors[maxi(index - 1, 0)]
		var p1: Vector3 = anchors[index]
		var p2: Vector3 = anchors[index + 1]
		var p3: Vector3 = anchors[mini(index + 2, count - 1)]
		for step: int in range(24):
			var u: float = float(step) / 24.0
			var u2: float = u * u
			var u3: float = u2 * u
			points.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
	points.append(anchors[count - 1])
	return points


## Builds the swoosh from the path (resampled by length so the shader's UV.x is a share of the
## length) and paints it with the sword's own blade shader. Returns where along it the target is hit.
func _swoosh() -> float:
	var raw: PackedVector3Array = _swoosh_points()
	var lengths: Array[float] = [0.0]
	for index: int in range(1, raw.size()):
		lengths.append(lengths[index - 1] + raw[index].distance_to(raw[index - 1]))
	var total: float = lengths[lengths.size() - 1]
	# The impact anchor is the fourth of nine: 3 of 8 spans, 24 samples per span.
	var impact_index: int = 3 * 24
	var impact_reach: float = lengths[impact_index] / total
	var segments: int = 120
	var centre_line := PackedVector3Array()
	var cursor: int = 0
	for step: int in range(segments + 1):
		var target_length: float = total * float(step) / float(segments)
		while cursor < lengths.size() - 2 and lengths[cursor + 1] < target_length:
			cursor += 1
		var span: float = maxf(lengths[cursor + 1] - lengths[cursor], 0.0001)
		var along: float = clampf((target_length - lengths[cursor]) / span, 0.0, 1.0)
		centre_line.append(raw[cursor].lerp(raw[cursor + 1], along))
	var half_width: float = card_size.y * 0.30 * staff_arc_width
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for step: int in range(segments + 1):
		var s: float = float(step) / float(segments)
		var before: Vector3 = centre_line[maxi(step - 1, 0)]
		var after: Vector3 = centre_line[mini(step + 1, segments)]
		var tangent: Vector3 = (after - before).normalized()
		var normal := Vector3(-tangent.y, tangent.x, 0.0)
		var base: Vector3 = centre_line[step] + Vector3(0.0, 0.0, 0.05 * sin(PI * s))
		vertices.append(base - normal * half_width)
		vertices.append(base + normal * half_width)
		uvs.append(Vector2(s, 0.0))
		uvs.append(Vector2(s, 1.0))
		if step < segments:
			var at: int = step * 2
			indices.append_array(PackedInt32Array([at, at + 1, at + 2, at + 1, at + 3, at + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = BladeShader
	material.render_priority = 28
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("sweep_end", sweep_end_share)
	material.set_shader_parameter("reverse_taper", 1.0)
	material.set_shader_parameter("accelerate", 1.0)
	material.set_shader_parameter("head_floor", 1.0)
	material.set_shader_parameter("bulge_amount", impact_swell)
	material.set_shader_parameter("bulge_at", impact_reach)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		material.set_shader_parameter("progress", value)
		if critical and value > 0.45:
			instance.position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * card_size.y * 0.012 * smoothstep(0.45, 0.9, value), 0.0, 1.0, effect_time)
	tween.tween_callback(instance.queue_free)
	return impact_reach


## Dust and grey motes shaken loose along the path of the sweep.
func _dust_trail() -> void:
	if dust_amount <= 0:
		return
	var ramp: GradientTexture1D = GhostFire._ramp(
		PackedColorArray([Color(0.9, 0.92, 0.95, 0.0), Color(0.78, 0.8, 0.84, 0.55), Color(0.5, 0.52, 0.56, 0.0)]),
		PackedFloat32Array([0.0, 0.25, 1.0]))
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(direction, 0.15, 0.0)
	process.spread = 35.0
	process.initial_velocity_min = card_size.y * 0.5
	process.initial_velocity_max = card_size.y * 1.3
	process.damping_min = card_size.y * 0.8
	process.damping_max = card_size.y * 1.6
	process.gravity = Vector3(0.0, -card_size.y * 0.15, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(card_size.y * 0.7, card_size.y * 0.06, 0.1)
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * card_size.y * 0.02
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.render_priority = 41
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.amount = dust_amount
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.35
	particles.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	particles.position = Vector3(-direction * card_size.y * 0.2, 0.0, 0.4)
	add_child(particles)
	particles.emitting = true
	var drift := create_tween()
	drift.tween_property(particles, "position:x", direction * card_size.y * 0.35, sweep_end_share * effect_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# --- Impact ----------------------------------------------------------------------------------------

func _impact() -> void:
	impact.emit()
	var unit: float = card_size.y
	# A short, wide, cold-white flash.
	var core := Core.new()
	core.impact_scale = unit * 0.4 * impact_width
	core.flash_intensity = 2.4 if not critical else 3.4
	core.afterimages = 0
	core.life = 0.07
	core.tremble = critical
	core.position = Vector3(0.0, 0.0, 0.7)
	core.scale = Vector3(1.9, 0.75, 1.0)
	add_child(core)
	core.play()
	_air_bars()
	_hit_marks()
	_blunt_ring()
	_dust_burst()
	if warp_strength > 0.0:
		SpaceWarpFX.play_at(self, Vector3(0.0, 0.0, 0.8), unit * 1.2, warp_strength * (2.0 if critical else 1.0), 0.4, true)


## Thick, short bars of pressed air thrown to the left and right of the contact.
func _air_bars() -> void:
	var unit: float = card_size.y
	var count: int = 7 if critical else 5
	for index: int in range(count):
		var side: float = 1.0 if index % 2 == 0 else -1.0
		var bar := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var length: float = unit * randf_range(0.22, 0.42) * impact_width
		quad.size = Vector2(length, unit * randf_range(0.035, 0.07))
		bar.mesh = quad
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = _bar_texture()
		material.albedo_color = Color(0.86, 0.90, 0.96, 0.7)
		material.render_priority = 42
		bar.material_override = material
		add_child(bar)
		var y: float = (float(index) / float(maxi(count - 1, 1)) - 0.5) * unit * 0.34 + randf_range(-0.03, 0.03) * unit
		bar.position = Vector3(side * unit * 0.1, y, 0.6)
		bar.scale = Vector3(0.5, 1.0, 1.0)
		bar.rotation.z = randf_range(-0.12, 0.12)
		var reach: float = unit * randf_range(0.45, 0.85) * impact_width
		var seconds: float = randf_range(0.16, 0.26)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(bar, "position:x", side * reach, seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(bar, "scale", Vector3(1.4, 0.8, 1.0), seconds)
		tween.tween_property(material, "albedo_color:a", 0.0, seconds * 0.7).set_delay(seconds * 0.3)
		tween.chain().tween_callback(bar.queue_free)


var _bar_tex: Texture2D = null


## A soft horizontal streak: bright in the middle, fading to nothing at both ends and at the top and bottom.
func _bar_texture() -> Texture2D:
	if _bar_tex == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 16
		_bar_tex = texture
	return _bar_tex


## One very faint, fast, ragged blunt ring (stretched wide), gone almost at once.
func _blunt_ring() -> void:
	if shockwave_strength <= 0.0:
		return
	var material := ShaderMaterial.new()
	material.shader = RingShader
	material.render_priority = 39
	material.set_shader_parameter("tone", Color(0.85, 0.88, 0.94))
	material.set_shader_parameter("ring_alpha", 0.32 * shockwave_strength)
	material.set_shader_parameter("emission_strength", 0.3)
	material.set_shader_parameter("reach", 0.9)
	material.set_shader_parameter("ease_power", 3.0)
	material.set_shader_parameter("width_start", 0.07)
	material.set_shader_parameter("width_end", 0.12)
	material.set_shader_parameter("raggedness", 0.8)
	material.set_shader_parameter("seed", randf() * 10.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * card_size.y * 1.4
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	mesh.position = Vector3(0.0, 0.0, 0.65)
	mesh.scale = Vector3(1.5, 0.8, 1.0)
	add_child(mesh)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, 0.24)
	tween.tween_callback(mesh.queue_free)


func _dust_burst() -> void:
	var unit: float = card_size.y
	var ramp: GradientTexture1D = GhostFire._ramp(
		PackedColorArray([Color(0.95, 0.96, 1.0, 0.9), Color(0.75, 0.77, 0.82, 0.6), Color(0.5, 0.52, 0.56, 0.0)]),
		PackedFloat32Array([0.0, 0.4, 1.0]))
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.2, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = unit * 0.5
	process.initial_velocity_max = unit * 1.6
	process.damping_min = unit * 1.6
	process.damping_max = unit * 3.0
	process.gravity = Vector3(0.0, -unit * 0.2, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.3
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * unit * 0.022
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.render_priority = 43
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.amount = 14 if critical else 9
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	particles.position = Vector3(0.0, 0.0, 0.7)
	add_child(particles)
	particles.emitting = true


## The shadow the blow leaves on the struck card, handled like a fist's mark: black ink splashes in
## the sword's black-ink language that appear at once at the contact and fade away slowly, long
## after the light has gone. One big splash in the middle and a smaller one either side along the swing.
func _hit_marks() -> void:
	if mark_strength <= 0.0:
		return
	var unit: float = card_size.y
	# Offsets are in card half-widths along the swing; sizes in card heights. Two stacked marks in the middle make it black.
	var specs: Array = [[0.0, 1.0], [0.0, 0.8], [-1.0, 0.65], [1.0, 0.65], [-1.7, 0.45], [1.7, 0.45]]
	for spec: Array in specs:
		var mark := Mark.new()
		mark.mark_scale = unit * float(spec[1]) * mark_strength * (1.25 if critical else 1.0)
		mark.life = mark_fade_time + (0.25 if float(spec[0]) == 0.0 else 0.0)
		mark.position = Vector3(float(spec[0]) * direction * card_size.x * 0.42, float(spec[0]) * unit * 0.03, 0.58 + 0.005 * float(spec[1]))
		add_child(mark)
		mark.play()
