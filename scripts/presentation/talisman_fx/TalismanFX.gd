extends Node3D
## Talisman (符咒) casting, in the language of the sword's cut: no paper, no props. The caster WRITES
## the talisman in the air with strokes of cinnabar-red blade light (each stroke is a swept ribbon,
## white-gold at its head, red behind, frayed, with a few dark ink strands), then the finished script
## is poured onto the target stroke by stroke as a stream of particles, and each stroke lands on the
## target's card in the same order it was written.
##   1. WRITE    - the strokes of the script appear one after another in front of the caster.
##   2. CHARGE   - the finished script brightens for an instant.
##   3. POUR     - stroke by stroke the script lifts off as streaks of light and flies to the target,
##                 where a matching stroke is branded onto the card (a small white flash each time).
##   4. SEAL     - (attacks) a broken frame tightens inward and crossed sealing tapes are drawn over
##                 the card, with a small square stamp: the target is held.
##   5. END      - the brand burns out into gold dust and cinnabar grit; a faint stamp lingers.
## `blessing` turns the same sequence gold and gentle (buffs on allies): no seal, no shudder.
## Forbidden: dragons, spirit beasts, western circles, hexagrams, blue orbs, fireballs.
## Every number is a plain property (or a key of `defaults()`). Presentation only.

signal landed          # the first stroke has reached the card (the caller shakes the card here)
signal sealed          # the whole script is on the card (the caller presses the card back here)
signal finished

const StrokeShader = preload("res://scripts/presentation/shaders/talisman_stroke.gdshader")
const SealShader = preload("res://scripts/presentation/shaders/talisman_seal.gdshader")
const InkShader = preload("res://scripts/presentation/shaders/ink_stroke.gdshader")
const Core = preload("res://scripts/presentation/punch_fx/PunchImpactCore.gd")
const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")

## The script: {from, to, bow} in a unit box (x right, y DOWN), in the order the strokes are written.
const STROKES: Array = [
	[0.18, 0.10, 0.82, 0.10, 0.02], [0.50, 0.10, 0.50, 0.30, 0.0], [0.25, 0.20, 0.40, 0.28, 0.12],
	[0.75, 0.20, 0.60, 0.28, -0.12], [0.20, 0.36, 0.80, 0.36, -0.02], [0.50, 0.36, 0.50, 0.62, 0.03],
	[0.28, 0.46, 0.72, 0.46, 0.02], [0.30, 0.56, 0.50, 0.62, 0.10], [0.70, 0.56, 0.50, 0.62, -0.10],
	[0.22, 0.70, 0.78, 0.70, 0.0], [0.32, 0.70, 0.32, 0.84, 0.04], [0.68, 0.70, 0.68, 0.84, -0.04],
	[0.32, 0.84, 0.68, 0.84, -0.03], [0.50, 0.88, 0.50, 0.97, 0.0],
]

# --- Tunable parameters ---------------------------------------------------------------------------
var glyph_height: float = 1.5               # height of the script written in the air (world units)
var brand_height: float = 1.9               # height of the script branded onto the target
var stroke_gap: float = 0.05                # seconds between the starts of two strokes being written
var stroke_time: float = 0.10               # seconds one stroke takes to be swept
var charge_time: float = 0.2                # the finished script brightens
var pour_gap: float = 0.045                 # seconds between strokes lifting off
var fly_time: float = 0.30
var streaks_per_stroke: int = 9             # light streaks poured per stroke
var arc_height: float = 0.6
var stroke_width: float = 0.05              # brush width in the air (world units)
var brand_width: float = 0.04
var seal_time: float = 0.6
var burn_time: float = 0.7
var remnant_time: float = 0.75
var dust_count: int = 18
var impact_flash_strength: float = 2.2
var seal_alpha: float = 1.0
var blessing: bool = false
var card_size: Vector2 = Vector2(2.0, 3.0)
var miss: bool = false                      # the script lands wide of the card and is not sealed
var critical: bool = false

var _air: Array[Dictionary] = []
var _brand: Array[Dictionary] = []
var _seal_mesh: MeshInstance3D = null
var _seal_material: ShaderMaterial = null
var _seal_inks: Array[ShaderMaterial] = []
var _seal_ink_meshes: Array[MeshInstance3D] = []
var _seal_shadows: Array[ShaderMaterial] = []
var _seal_shadow_meshes: Array[MeshInstance3D] = []
var _landed_once: bool = false
var _streak_meshes: Array[QuadMesh] = []
var _streak_materials: Array[StandardMaterial3D] = []


static func defaults() -> Dictionary:
	return {
		"stroke_gap": 0.05, "stroke_time": 0.10, "charge_time": 0.2, "pour_gap": 0.045, "fly_time": 0.30,
		"streaks_per_stroke": 9, "arc_height": 0.6, "seal_time": 0.6, "burn_time": 0.7, "remnant_time": 0.75,
		"dust_count": 18, "impact_flash_strength": 2.2, "seal_alpha": 1.0,
	}


## Writes the script in front of the caster at `origin` and pours it onto `target`.
static func play_between(host: Node, origin: Vector3, target: Vector3, params: Dictionary = {}) -> Node3D:
	var fx := new()
	host.add_child(fx)
	for key: String in params.keys():
		fx.set(key, params[key])
	fx.start(origin, target)
	return fx


func start(origin: Vector3, target: Vector3) -> void:
	_run(origin, target)


# --- Strokes ---------------------------------------------------------------------------------------

func _stroke_material(seed_value: float, width: float, stroke_len: float, bend: float, ink_scale: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = StrokeShader
	material.render_priority = 42
	material.set_shader_parameter("seed", seed_value)
	material.set_shader_parameter("ink_amount", (0.25 if blessing else 0.6) * ink_scale)
	material.set_shader_parameter("width", width)
	material.set_shader_parameter("stroke_len", stroke_len)
	material.set_shader_parameter("bend", bend)
	var quad_len: float = stroke_len + width * 5.0
	var quad_wid: float = width * 7.0 + absf(bend) * stroke_len * 2.0
	material.set_shader_parameter("quad_len", quad_len)
	material.set_shader_parameter("quad_wid", quad_wid)
	if blessing:
		material.set_shader_parameter("edge_tone", Color(0.95, 0.62, 0.16))
		material.set_shader_parameter("mid_tone", Color(1.0, 0.86, 0.45))
	return material


## A stroke of the script placed in the world, `glyph_centre` being the middle of the unit box.
func _make_stroke(entry: Array, glyph_centre: Vector3, height: float, width: float, ink_scale: float = 1.0) -> Dictionary:
	var glyph_width: float = height * 0.62
	var a := Vector3((float(entry[0]) - 0.5) * glyph_width, (0.5 - float(entry[1])) * height, 0.0)
	var b := Vector3((float(entry[2]) - 0.5) * glyph_width, (0.5 - float(entry[3])) * height, 0.0)
	var length: float = a.distance_to(b)
	var bend: float = float(entry[4])
	var material := _stroke_material(randf() * 10.0, width, length, bend, ink_scale)
	var quad := QuadMesh.new()
	quad.size = Vector2(float(material.get_shader_parameter("quad_len")), float(material.get_shader_parameter("quad_wid")))
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	add_child(mesh)
	mesh.position = glyph_centre + (a + b) * 0.5
	mesh.rotation.z = atan2(b.y - a.y, b.x - a.x)
	return {"mesh": mesh, "material": material, "a": glyph_centre + a, "b": glyph_centre + b, "bend": bend, "length": length}


## A point along a stroke (s from 0 to 1), including the sideways bow.
func _stroke_point(stroke: Dictionary, s: float) -> Vector3:
	var a: Vector3 = stroke.a
	var b: Vector3 = stroke.b
	var along: Vector3 = a.lerp(b, s)
	var direction: Vector3 = (b - a).normalized()
	var normal := Vector3(-direction.y, direction.x, 0.0)
	return along + normal * float(stroke.bend) * float(stroke.length) * (1.0 - pow(2.0 * s - 1.0, 2.0))


# --- The sequence ----------------------------------------------------------------------------------

func _run(origin: Vector3, target: Vector3) -> void:
	var count: int = STROKES.size()
	var brand_centre: Vector3 = target + Vector3(0.0, card_size.y * 0.02, 0.14)
	if miss:
		brand_centre += Vector3(card_size.x * 0.8 * (1.0 if target.x >= origin.x else -1.0), card_size.y * 0.1, -0.6)
	# 1. WRITE the script in the air.
	for index: int in range(count):
		var stroke: Dictionary = _make_stroke(STROKES[index], origin, glyph_height, stroke_width)
		_air.append(stroke)
		var write := create_tween()
		write.tween_interval(stroke_gap * float(index))
		write.tween_method(func(value: float) -> void: stroke.material.set_shader_parameter("draw", value), 0.0, 1.0, stroke_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(stroke_gap * float(count - 1) + stroke_time + 0.05).timeout
	# 2. CHARGE: the whole script flares for an instant.
	var charge := create_tween().set_parallel(true)
	for stroke: Dictionary in _air:
		charge.tween_method(func(value: float) -> void: stroke.material.set_shader_parameter("glow", value), 1.0, 2.4, charge_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(charge_time + 0.05).timeout
	# 3. POUR the script onto the target, stroke by stroke, in the order it was written.
	_prepare_streaks()
	for index: int in range(count):
		var brand: Dictionary = _make_stroke(STROKES[index], brand_centre, brand_height, brand_width, 0.5)
		(brand.material as ShaderMaterial).set_shader_parameter("draw", 0.0)
		_brand.append(brand)
	var last_arrival: float = 0.0
	for index: int in range(count):
		var delay: float = pour_gap * float(index)
		_pour_stroke(index, delay)
		last_arrival = delay + fly_time
	await get_tree().create_timer(last_arrival + 0.12).timeout
	# 4. SEAL.
	sealed.emit()
	if not miss and not blessing:
		_start_seal(brand_centre)
	_impact(brand_centre, 1.5)
	await get_tree().create_timer(seal_time * (0.9 if not blessing else 0.5)).timeout
	# 5. END
	_finish(brand_centre)
	await get_tree().create_timer(maxf(burn_time * 1.1 + 0.45, remnant_time) + 0.25).timeout
	finished.emit()
	queue_free()


## One stroke lifts off the air: the written stroke fades while a stream of streaks carries its shape
## to the matching place on the card, where the branded stroke is drawn as they arrive.
func _pour_stroke(index: int, delay: float) -> void:
	var air: Dictionary = _air[index]
	var brand: Dictionary = _brand[index]
	var swarm: Array[MeshInstance3D] = []
	var starts: Array[Vector3] = []
	var ends: Array[Vector3] = []
	var controls: Array[Vector3] = []
	var gold: bool = index % 2 == 0
	for k: int in range(streaks_per_stroke):
		var s: float = (float(k) + randf()) / float(streaks_per_stroke)
		var from: Vector3 = _stroke_point(air, s)
		var to: Vector3 = _stroke_point(brand, s)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _streak_meshes[(k + index) % _streak_meshes.size()]
		mesh.material_override = _streak_materials[(k + index) % _streak_materials.size()] if gold else _streak_materials[(k + index + 1) % _streak_materials.size()]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visible = false
		add_child(mesh)
		mesh.position = from
		swarm.append(mesh)
		starts.append(from)
		ends.append(to)
		controls.append(from.lerp(to, 0.5) + Vector3(randf_range(-0.12, 0.12), arc_height * randf_range(0.6, 1.3), 0.35))
	var pour := create_tween()
	pour.tween_interval(delay)
	pour.tween_callback(func() -> void:
		var lift := create_tween()
		lift.tween_method(func(value: float) -> void: air.material.set_shader_parameter("age", value), 0.0, 1.0, 0.22)
		for mesh: MeshInstance3D in swarm:
			mesh.visible = true)
	pour.tween_method(_streak_step.bind(swarm, starts, controls, ends), 0.0, 1.0, fly_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pour.tween_callback(func() -> void:
		for mesh: MeshInstance3D in swarm:
			mesh.queue_free()
		_land_stroke(index))


func _streak_step(u: float, swarm: Array[MeshInstance3D], starts: Array[Vector3], controls: Array[Vector3], ends: Array[Vector3]) -> void:
	for k: int in range(swarm.size()):
		var mesh: MeshInstance3D = swarm[k]
		if not is_instance_valid(mesh):
			continue
		var position_now: Vector3 = _bezier(starts[k], controls[k], ends[k], u)
		var ahead: Vector3 = _bezier(starts[k], controls[k], ends[k], minf(u + 0.04, 1.0))
		mesh.position = position_now
		mesh.rotation.z = atan2(ahead.y - position_now.y, ahead.x - position_now.x)
		mesh.scale = Vector3(lerpf(0.6, 1.5, u), 1.0, 1.0) * (1.0 - 0.5 * u * u)


func _bezier(a: Vector3, b: Vector3, c: Vector3, u: float) -> Vector3:
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


func _prepare_streaks() -> void:
	var unit: float = glyph_height
	var colours: Array = [Color(1.0, 0.92, 0.7, 0.95), Color(1.0, 0.45, 0.2, 0.9), Color(1.0, 0.75, 0.35, 0.95)]
	if blessing:
		colours = [Color(1.0, 0.96, 0.8, 0.95), Color(1.0, 0.78, 0.3, 0.9), Color(1.0, 0.9, 0.55, 0.95)]
	for colour: Color in colours:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(unit * 0.11, unit * 0.014)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = colour
		material.render_priority = 44
		material.no_depth_test = true
		_streak_meshes.append(mesh)
		_streak_materials.append(material)


## The matching stroke is branded onto the card: it is swept in a flash and flares white.
func _land_stroke(index: int) -> void:
	var brand: Dictionary = _brand[index]
	var material: ShaderMaterial = brand.material
	var sweep := create_tween().set_parallel(true)
	sweep.tween_method(func(value: float) -> void: material.set_shader_parameter("draw", value), 0.0, 1.0, 0.07)
	sweep.tween_method(func(value: float) -> void: material.set_shader_parameter("glow", value), 3.2, 1.2, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var middle: Vector3 = _stroke_point(brand, 0.5)
	_particles(middle + Vector3(0.0, 0.0, 0.1), 3, PackedColorArray([Color(1.0, 0.97, 0.85, 1.0), Color(1.0, 0.7, 0.3, 0.8), Color(0.9, 0.2, 0.1, 0.0)]),
		PackedFloat32Array([0.0, 0.4, 1.0]), card_size.y * 0.25, card_size.y * 0.6, 0.22, card_size.y * 0.012, Vector3.ZERO, true, 180.0, 1.0)
	if index % 4 == 0:
		_impact(middle, 0.45)
	if not _landed_once:
		_landed_once = true
		landed.emit()


func _impact(point: Vector3, strength: float) -> void:
	var core := Core.new()
	core.impact_scale = card_size.y * (0.16 if strength < 1.0 else 0.34) * (0.6 if miss else 1.0)
	core.flash_intensity = impact_flash_strength * strength
	core.afterimages = 0
	core.life = 0.06
	core.tremble = false
	core.position = point + Vector3(0.0, 0.0, 0.2)
	add_child(core)
	core.play()


## SEAL: the broken frame, the crossed tapes and the stamp, drawn from the middle outward.
func _start_seal(centre: Vector3) -> void:
	var size := Vector2(card_size.x * 1.22, card_size.y * 1.10)
	var quad := QuadMesh.new()
	quad.size = size
	_seal_mesh = MeshInstance3D.new()
	_seal_mesh.mesh = quad
	_seal_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_seal_material = ShaderMaterial.new()
	_seal_material.shader = SealShader
	_seal_material.render_priority = 40
	_seal_material.set_shader_parameter("aspect", size.x / size.y)
	_seal_material.set_shader_parameter("seed", randf() * 10.0)
	_seal_material.set_shader_parameter("tape_strength", 0.0)
	_seal_material.set_shader_parameter("intensity", seal_alpha * (1.25 if critical else 1.0))
	_seal_mesh.material_override = _seal_material
	add_child(_seal_mesh)
	_seal_mesh.position = Vector3(centre.x, centre.y, centre.z - 0.06)
	var reveal := create_tween().set_parallel(true)
	reveal.tween_method(func(value: float) -> void: _seal_material.set_shader_parameter("t", value), 0.0, 1.0, seal_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_method(func(value: float) -> void: _seal_material.set_shader_parameter("contract", value), 0.0, 1.0, seal_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ink_cross(centre, size)


func _finish(centre: Vector3) -> void:
	var unit: float = card_size.y
	for ink_index: int in range(_seal_inks.size()):
		var ink_material: ShaderMaterial = _seal_inks[ink_index]
		var ink_mesh: MeshInstance3D = _seal_ink_meshes[ink_index]
		var ink_fade := create_tween()
		ink_fade.tween_method(func(value: float) -> void: ink_material.set_shader_parameter("fade", value), 0.0, 1.0, burn_time * 0.8).set_delay(0.1)
		ink_fade.tween_callback(ink_mesh.queue_free)
	# The black shadow outlasts the red ink by a good while.
	for shadow_index: int in range(_seal_shadows.size()):
		var shadow_material: ShaderMaterial = _seal_shadows[shadow_index]
		var shadow_mesh: MeshInstance3D = _seal_shadow_meshes[shadow_index]
		var shadow_fade := create_tween()
		shadow_fade.tween_method(func(value: float) -> void: shadow_material.set_shader_parameter("fade", value), 0.0, 1.0, burn_time * 1.1).set_delay(0.45)
		shadow_fade.tween_callback(shadow_mesh.queue_free)
	var fades := create_tween().set_parallel(true)
	for index: int in range(_brand.size()):
		var brand: Dictionary = _brand[index]
		var material: ShaderMaterial = brand.material
		fades.tween_method(func(value: float) -> void: material.set_shader_parameter("age", value), 0.0, 1.0, burn_time).set_delay(0.03 * float(index)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if index % 2 == 0:
			var point: Vector3 = _stroke_point(brand, 0.5) + Vector3(0.0, 0.0, 0.15)
			var red := Color(0.95, 0.30, 0.15, 1.0) if not blessing else Color(1.0, 0.7, 0.25, 1.0)
			_particles(point, int(float(dust_count) * 0.3), PackedColorArray([red, Color(0.8, 0.15, 0.08, 0.7), Color(0.4, 0.05, 0.03, 0.0)]),
				PackedFloat32Array([0.0, 0.5, 1.0]), unit * 0.08, unit * 0.30, burn_time, unit * 0.014, Vector3(0.0, unit * 0.12, 0.0), true, 40.0, 0.5)
			_particles(point, int(float(dust_count) * 0.4), PackedColorArray([Color(1.0, 0.96, 0.8, 1.0), Color(1.0, 0.82, 0.4, 0.8), Color(1.0, 0.6, 0.2, 0.0)]),
				PackedFloat32Array([0.0, 0.4, 1.0]), unit * 0.06, unit * 0.26, burn_time + 0.3, unit * 0.010, Vector3(0.0, unit * 0.18, 0.0), true, 50.0, 0.4)
	if _seal_material != null:
		var seal_fade := create_tween()
		seal_fade.tween_method(func(value: float) -> void: _seal_material.set_shader_parameter("fade", value), 0.0, 1.0, 0.4)
		seal_fade.tween_method(func(value: float) -> void: _seal_material.set_shader_parameter("intensity", value), seal_alpha, 0.0, remnant_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		seal_fade.tween_callback(_seal_mesh.queue_free)


## One-shot burst of small additive quads (sparks, dust, grit).
func _particles(point: Vector3, count: int, colors: PackedColorArray, offsets: PackedFloat32Array, speed_min: float, speed_max: float,
		life: float, size: float, gravity: Vector3, additive: bool, spread: float = 180.0, damping_ratio: float = 0.0) -> void:
	if count <= 0:
		return
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0) if gravity.y > 0.0 else Vector3.ZERO
	process.spread = spread
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = gravity
	process.damping_min = speed_max * damping_ratio * 2.0
	process.damping_max = speed_max * damping_ratio * 3.5
	process.scale_min = 0.6
	process.scale_max = 1.3
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(card_size.x * 0.10, card_size.y * 0.06, 0.02)
	process.color_ramp = GhostFire._ramp(colors, offsets)
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.render_priority = 43
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.amount = count
	particles.lifetime = life
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	particles.position = point
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(life + 0.4).timeout.connect(particles.queue_free)


## The seal is written with a cinnabar brush: two quick ink strokes, the same brush as the pen's ink
## trace, crossing the card in an X. The second follows the first at once.
func _ink_cross(centre: Vector3, size: Vector2) -> void:
	var spans: Array = [
		[Vector2(-0.38, 0.38), Vector2(0.38, -0.38), 0.05],
		[Vector2(0.38, 0.38), Vector2(-0.38, -0.38), -0.05],
	]
	for index: int in range(spans.size()):
		var span: Array = spans[index]
		var a := Vector3(float((span[0] as Vector2).x) * size.x, float((span[0] as Vector2).y) * size.y, 0.0)
		var b := Vector3(float((span[1] as Vector2).x) * size.x, float((span[1] as Vector2).y) * size.y, 0.0)
		var material := ShaderMaterial.new()
		material.shader = InkShader
		material.render_priority = 45
		material.set_shader_parameter("seed", randf() * 10.0)
		material.set_shader_parameter("ink", Color(0.80, 0.07, 0.04))
		material.set_shader_parameter("sheen_tone", Color(1.0, 0.55, 0.30))
		material.set_shader_parameter("glow", 0.55)
		material.set_shader_parameter("reveal", 0.0)
		var mesh := _ink_strip(a, b, float(span[2]) * size.y, card_size.y * 0.075)
		mesh.material_override = material
		add_child(mesh)
		mesh.position = Vector3(centre.x, centre.y, centre.z + 0.22 + 0.01 * float(index))
		_seal_inks.append(material)
		_seal_ink_meshes.append(mesh)
		# The black ink shadow beneath it: a little wider and offset down and right, written a beat
		# later, and it lingers after the red has gone, which gives the stroke its depth.
		var shadow_material := ShaderMaterial.new()
		shadow_material.shader = InkShader
		shadow_material.render_priority = 44
		shadow_material.set_shader_parameter("seed", randf() * 10.0)
		shadow_material.set_shader_parameter("ink", Color(0.02, 0.005, 0.008))
		shadow_material.set_shader_parameter("sheen_tone", Color(0.25, 0.05, 0.05))
		shadow_material.set_shader_parameter("reveal", 0.0)
		var shadow_mesh := _ink_strip(a, b, float(span[2]) * size.y, card_size.y * 0.105)
		shadow_mesh.material_override = shadow_material
		add_child(shadow_mesh)
		shadow_mesh.position = Vector3(centre.x + card_size.x * 0.028, centre.y - card_size.y * 0.022, centre.z + 0.20 + 0.01 * float(index))
		_seal_shadows.append(shadow_material)
		_seal_shadow_meshes.append(shadow_mesh)
		var shadow_write := create_tween()
		shadow_write.tween_interval(0.09 + 0.13 * float(index))
		shadow_write.tween_method(func(value: float) -> void: shadow_material.set_shader_parameter("reveal", value), 0.0, 1.05, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var write := create_tween()
		write.tween_interval(0.05 + 0.13 * float(index))
		write.tween_method(func(value: float) -> void: material.set_shader_parameter("reveal", value), 0.0, 1.05, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if index == 1:
			write.tween_callback(_ink_dab.bind(centre + Vector3(0.0, 0.0, 0.3)))


## A short flash where the second stroke crosses the first (the brush pressing down).
func _ink_dab(point: Vector3) -> void:
	_impact(point, 0.4)


## A brush ribbon from `a` to `b` bowed sideways by `bow`; UV.x runs along it, UV.y across it.
func _ink_strip(a: Vector3, b: Vector3, bow: float, width: float) -> MeshInstance3D:
	var segments: int = 18
	var direction: Vector3 = (b - a).normalized()
	var normal := Vector3(-direction.y, direction.x, 0.0)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for step: int in range(segments + 1):
		var s: float = float(step) / float(segments)
		var along: Vector3 = a.lerp(b, s) + normal * bow * (1.0 - pow(2.0 * s - 1.0, 2.0))
		vertices.append(along + normal * width * 0.5)
		vertices.append(along - normal * width * 0.5)
		uvs.append(Vector2(s, 0.0))
		uvs.append(Vector2(s, 1.0))
		if step < segments:
			var base: int = step * 2
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
