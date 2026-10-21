extends Node3D
## The basic attack of the spear (槍): ALL the force gathered in one point, driven down one very
## narrow line, and carried on THROUGH the target. In order:
##   1. TIP      - a tiny, very bright cold-white glint at the spear's point (not an energy ball).
##   2. THRUST   - a thin, straight, fast line painted with the sword's own blade shader (cold white
##                 core, black fracture cracks, ink strands), narrow here, with two or three thinner
##                 afterimages trailing it, a faint glint riding its head, and around it a long,
##                 narrow, nearly clear cone of compressed air (tightest at the tip).
##   3. IMPACT   - small but very bright: a short flash stretched along the axis, a thin flare forward
##                 and back along it, a few white specks, a faint oval ring, a small black pierce mark.
##   4. THROUGH  - the line does not stop on the card: it runs on behind the target and lingers a
##                 moment longer than the thrust itself before fading.
## Not a laser, not a beam, not a crescent, not a staff's wind. Every number is a plain property (or a
## key of `defaults()`); lengths are in card heights. Presentation only.

signal impact          # the head of the thrust has reached the target

const BladeShader = preload("res://scripts/presentation/shaders/blade_slash.gdshader")
const ConeShader = preload("res://scripts/presentation/shaders/spear_cone.gdshader")
const RingShader = preload("res://scripts/presentation/shaders/lute_burst_ring.gdshader")
const Core = preload("res://scripts/presentation/punch_fx/PunchImpactCore.gd")
const Mark = preload("res://scripts/presentation/punch_fx/PunchInkMark.gd")
const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")

# --- Tunable parameters ---------------------------------------------------------------------------
var spear_tip_flash_size: float = 0.13
var spear_tip_flash_duration: float = 0.09
var thrust_width: float = 0.11              # half-width of the line's strip (card heights); narrow
var thrust_speed: float = 0.18              # share of the effect time the head takes to cross (smaller = faster)
var effect_time: float = 0.6                # life of the thrust line
var afterimage_count: int = 2
var afterimage_spacing: float = 0.03        # distance between afterimages (card heights)
var pressure_cone_length: float = 1.7
var pressure_cone_width: float = 0.34
var impact_flash_size: float = 0.5
var impact_ring_scale: float = 1.0
var penetration_extension: float = 1.15     # how far the line runs on behind the target (card heights)
var penetration_fade_time: float = 0.7      # how long the part behind the target lingers
var card_size: Vector2 = Vector2(2.0, 3.0)
var critical: bool = false

var start_point: Vector3 = Vector3.ZERO
var target_point: Vector3 = Vector3.ZERO
var _axis: Vector3 = Vector3.RIGHT
var _end_point: Vector3 = Vector3.ZERO
var _angle: float = 0.0
var _streak_texture: Texture2D = null
var _dot_texture: Texture2D = null


static func defaults() -> Dictionary:
	return {
		"spear_tip_flash_size": 0.13, "spear_tip_flash_duration": 0.09, "thrust_width": 0.11, "thrust_speed": 0.18,
		"effect_time": 0.6, "afterimage_count": 2, "afterimage_spacing": 0.03, "pressure_cone_length": 1.7,
		"pressure_cone_width": 0.34, "impact_flash_size": 0.5, "impact_ring_scale": 1.0,
		"penetration_extension": 1.15, "penetration_fade_time": 0.7,
	}


## Thrusts from `start` (the spear's point) at `target` (the middle of the target card), both in the
## host's space, and on through it.
static func play_between(host: Node, start: Vector3, target: Vector3, size: Vector2, params: Dictionary = {}) -> Node3D:
	var fx := new()
	host.add_child(fx)
	fx.card_size = size
	fx.start_point = start
	fx.target_point = target
	for key: String in params.keys():
		fx.set(key, params[key])
	fx.play()
	return fx


func play() -> void:
	var h: float = card_size.y
	_axis = (target_point - start_point).normalized()
	_angle = atan2(_axis.y, _axis.x)
	# The line runs on behind the target and a little deeper into the stage.
	_end_point = target_point + _axis * h * penetration_extension + Vector3(0.0, 0.0, -h * 0.35 if penetration_extension > 0.0 else 0.0)
	var reach: float = start_point.distance_to(target_point) / maxf(start_point.distance_to(_end_point), 0.001)
	var hit_time: float = thrust_speed * effect_time * pow(reach, 0.6)
	_tip_flash()
	_thrust_line(0, 0.0)
	for index: int in range(1, afterimage_count + 1):
		_thrust_line(index, 0.02 * float(index))
	_pressure_cone(hit_time)
	_head_glint(hit_time)
	get_tree().create_timer(hit_time).timeout.connect(_impact)
	get_tree().create_timer(effect_time + penetration_fade_time + 1.0).timeout.connect(queue_free)


func _soft_dot() -> Texture2D:
	if _dot_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_dot_texture = texture
	return _dot_texture


## A soft horizontal streak: bright in the middle, fading to nothing at both ends and at the sides.
func _streak() -> Texture2D:
	if _streak_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 16
		_streak_texture = texture
	return _streak_texture


func _additive_sprite(texture: Texture2D, size: Vector2, colour: Color, priority: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = texture
	material.albedo_color = colour
	material.no_depth_test = true
	material.render_priority = priority
	mesh.material_override = material
	add_child(mesh)
	return mesh


# --- 1. The glint at the point ---------------------------------------------------------------------

func _tip_flash() -> void:
	var size: float = card_size.y * spear_tip_flash_size
	var dot := _additive_sprite(_soft_dot(), Vector2.ONE * size, Color(0.92, 0.96, 1.0, 1.0), 45)
	dot.position = start_point + Vector3(0.0, 0.0, 0.5)
	var glint := _additive_sprite(_streak(), Vector2(size * 3.6, size * 0.45), Color(1.0, 1.0, 1.0, 0.9), 45)
	glint.position = dot.position
	glint.rotation.z = _angle
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dot, "scale", Vector3.ONE * 0.2, spear_tip_flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(glint, "scale", Vector3(1.6, 0.3, 1.0), spear_tip_flash_duration)
	tween.chain().tween_callback(dot.queue_free)
	tween.chain().tween_callback(glint.queue_free)


# --- 2. The thrust line and its afterimages --------------------------------------------------------

## A straight strip from the spear's point to the far end, painted with the sword's blade shader.
## Index 0 is the line itself; the others are thinner, fainter afterimages set a little to either side
## of it and started a moment later.
func _thrust_line(index: int, delay: float) -> void:
	var h: float = card_size.y
	var segments: int = 48
	var width: float = h * thrust_width * (1.0 if index == 0 else 0.55)
	var normal := Vector3(-_axis.y, _axis.x, 0.0)
	var side: float = (1.0 if index % 2 == 1 else -1.0) * float((index + 1) / 2)
	var offset: Vector3 = normal * h * afterimage_spacing * side if index > 0 else Vector3.ZERO
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for step: int in range(segments + 1):
		var s: float = float(step) / float(segments)
		var base: Vector3 = start_point.lerp(_end_point, s) + offset + Vector3(0.0, 0.0, 0.4)
		vertices.append(base - normal * width)
		vertices.append(base + normal * width)
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
	material.render_priority = 28 - index
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("sweep_end", thrust_speed)
	material.set_shader_parameter("accelerate", 1.0)
	material.set_shader_parameter("head_floor", 1.0)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.transparency = 0.0 if index == 0 else 0.45 + 0.15 * float(index - 1)
	add_child(instance)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 1.0, effect_time)
	tween.tween_callback(instance.queue_free)


# --- Pressure cone and head glint ------------------------------------------------------------------

## The long, nearly clear cone of compressed air riding just behind the spear's point.
func _pressure_cone(hit_time: float) -> void:
	var h: float = card_size.y
	var length: float = h * pressure_cone_length
	var quad := QuadMesh.new()
	quad.size = Vector2(length, h * pressure_cone_width)
	var material := ShaderMaterial.new()
	material.shader = ConeShader
	material.render_priority = 30
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("strength", 1.3 if critical else 1.0)
	var cone := MeshInstance3D.new()
	cone.mesh = quad
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.material_override = material
	cone.rotation.z = _angle
	add_child(cone)
	# Its tip rides the head of the thrust; it stops where the spear strikes and dies away there.
	var tween := create_tween().set_parallel(true)
	var from_tip: Vector3 = start_point + Vector3(0.0, 0.0, 0.45)
	var to_tip: Vector3 = target_point + Vector3(0.0, 0.0, 0.45)
	tween.tween_method(func(value: float) -> void:
		var tip: Vector3 = from_tip.lerp(to_tip, value)
		cone.position = tip - _axis * length * 0.5, 0.0, 1.0, hit_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, hit_time + 0.2)
	tween.chain().tween_callback(cone.queue_free)


## A tiny bright glint riding the head of the thrust.
func _head_glint(hit_time: float) -> void:
	var size: float = card_size.y * 0.07
	var glint := _additive_sprite(_soft_dot(), Vector2.ONE * size, Color(1.0, 1.0, 1.0, 1.0), 46)
	glint.position = start_point + Vector3(0.0, 0.0, 0.5)
	var tween := create_tween()
	tween.tween_property(glint, "position", target_point + Vector3(0.0, 0.0, 0.5), hit_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if penetration_extension > 0.0:
		tween.tween_property(glint, "position", _end_point + Vector3(0.0, 0.0, 0.5), penetration_extension * 0.12).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(glint.queue_free)


# --- 3. Impact and 4. going through ---------------------------------------------------------------

func _impact() -> void:
	impact.emit()
	var h: float = card_size.y
	var spot: Vector3 = target_point + Vector3(0.0, 0.0, 0.7)
	# Small and very bright, stretched along the axis.
	var core := Core.new()
	core.impact_scale = h * impact_flash_size * 0.5
	core.flash_intensity = 3.4 if not critical else 4.4
	core.afterimages = 0
	core.life = 0.06
	core.tremble = critical
	core.position = spot
	core.rotation.z = _angle
	core.scale = Vector3(2.6, 0.5, 1.0)
	add_child(core)
	core.play()
	# A thin flare forward and back along the axis.
	var flare := _additive_sprite(_streak(), Vector2(h * 1.5 * impact_flash_size * 2.0, h * 0.045), Color(1.0, 1.0, 1.0, 0.95), 46)
	flare.position = spot
	flare.rotation.z = _angle
	var flare_tween := create_tween().set_parallel(true)
	flare_tween.tween_property(flare, "scale", Vector3(1.5, 0.3, 1.0), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	flare_tween.tween_property(flare.material_override, "albedo_color:a", 0.0, 0.16)
	flare_tween.chain().tween_callback(flare.queue_free)
	_specks(spot)
	_oval_ring(spot)
	_pierce_mark(spot)
	_through()


## A few white specks thrown forward and back along the axis.
func _specks(spot: Vector3) -> void:
	var h: float = card_size.y
	var ramp: GradientTexture1D = GhostFire._ramp(
		PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.84, 0.91, 0.98, 0.8), Color(0.66, 0.76, 0.92, 0.0)]),
		PackedFloat32Array([0.0, 0.4, 1.0]))
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = _axis
	process.spread = 22.0
	process.initial_velocity_min = h * 0.6
	process.initial_velocity_max = h * 1.8
	process.damping_min = h * 2.0
	process.damping_max = h * 3.4
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.0
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2(h * 0.012, h * 0.075)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.render_priority = 47
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	particles.amount = 10 if critical else 6
	particles.lifetime = 0.26
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	particles.position = spot
	add_child(particles)
	particles.emitting = true


## A very faint, quick, oval ring, narrower along the axis than across it.
func _oval_ring(spot: Vector3) -> void:
	var material := ShaderMaterial.new()
	material.shader = RingShader
	material.render_priority = 39
	material.set_shader_parameter("tone", Color(0.88, 0.92, 1.0))
	material.set_shader_parameter("ring_alpha", 0.3)
	material.set_shader_parameter("emission_strength", 0.4)
	material.set_shader_parameter("reach", 0.9)
	material.set_shader_parameter("ease_power", 3.0)
	material.set_shader_parameter("width_start", 0.05)
	material.set_shader_parameter("width_end", 0.09)
	material.set_shader_parameter("raggedness", 0.7)
	material.set_shader_parameter("seed", randf() * 10.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * card_size.y * 0.9 * impact_ring_scale
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	mesh.position = spot
	mesh.rotation.z = _angle
	mesh.scale = Vector3(0.55, 1.0, 1.0)
	add_child(mesh)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, 0.22)
	tween.tween_callback(mesh.queue_free)


## A small black ink mark where the point went in (the sword's black ink, kept small).
func _pierce_mark(spot: Vector3) -> void:
	var mark := Mark.new()
	mark.mark_scale = card_size.y * 0.42
	mark.life = 0.85
	mark.position = Vector3(spot.x, spot.y, 0.58)
	add_child(mark)
	mark.play()


## The force does not stop at the card: from the point of impact the line carries on behind the
## target, lingering longer than the thrust did.
func _through() -> void:
	var h: float = card_size.y
	var segments: int = 32
	var normal := Vector3(-_axis.y, _axis.x, 0.0)
	var width: float = h * thrust_width * 0.8
	var from_point: Vector3 = target_point
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for step: int in range(segments + 1):
		var s: float = float(step) / float(segments)
		var base: Vector3 = from_point.lerp(_end_point, s) + Vector3(0.0, 0.0, 0.45)
		vertices.append(base - normal * width)
		vertices.append(base + normal * width)
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
	material.render_priority = 27
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("sweep_end", 0.3)
	material.set_shader_parameter("head_floor", 1.0)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 1.0, penetration_fade_time)
	tween.tween_callback(instance.queue_free)
