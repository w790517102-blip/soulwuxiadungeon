extends Node3D
## Buffs and debuffs on a card, read by colour:
##   attack   - red breath rising             defense  - blue breath rising
##   speed    - sky cyan breath rising        accuracy - yellow breath rising
##   crit     - orange and red breath rising
##   debuff   - violet and black: a violet drizzle and a heavy curtain of black smoke that sinks
##              from the card's head down to its feet.
## The rising kinds reuse the heal streams (heal_qi.gdshader) and motes without leaves; the debuff
## adds dark dust falling with the smoke. Every number is a plain property. Presentation only.

const QiShader = preload("res://scripts/presentation/shaders/heal_qi.gdshader")
const SmokeShader = preload("res://scripts/presentation/shaders/debuff_smoke.gdshader")
const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")

## tone / core / accent of the streams, the mote colour and the scroll speed.
const THEMES: Dictionary = {
	"attack": {"tone": Color(1.0, 0.18, 0.12), "core": Color(1.0, 0.85, 0.75), "accent": Color(1.0, 0.35, 0.2), "mote": Color(1.0, 0.4, 0.3), "speed": 1.0},
	"defense": {"tone": Color(0.2, 0.45, 1.0), "core": Color(0.8, 0.9, 1.0), "accent": Color(0.35, 0.6, 1.0), "mote": Color(0.45, 0.7, 1.0), "speed": 0.7},
	"speed": {"tone": Color(0.2, 0.85, 1.0), "core": Color(0.85, 1.0, 1.0), "accent": Color(0.4, 0.95, 0.95), "mote": Color(0.6, 0.95, 1.0), "speed": 1.9},
	"accuracy": {"tone": Color(1.0, 0.85, 0.15), "core": Color(1.0, 0.98, 0.8), "accent": Color(1.0, 0.95, 0.4), "mote": Color(1.0, 0.92, 0.45), "speed": 1.2},
	"crit": {"tone": Color(1.0, 0.5, 0.08), "core": Color(1.0, 0.9, 0.7), "accent": Color(1.0, 0.15, 0.1), "mote": Color(1.0, 0.55, 0.2), "speed": 1.4},
	"debuff": {"tone": Color(0.5, 0.15, 0.85), "core": Color(0.85, 0.7, 1.0), "accent": Color(0.2, 0.05, 0.35), "mote": Color(0.3, 0.1, 0.45), "speed": 0.8},
}

# --- Tunable parameters ---------------------------------------------------------------------------
var kind: String = "attack"
var duration: float = 1.4
var qi_intensity: float = 0.75
var mote_count: int = 30
var smoke_density: float = 0.85
var card_size: Vector2 = Vector2(2.0, 3.0)


static func defaults() -> Dictionary:
	return {"duration": 1.4, "qi_intensity": 0.75, "mote_count": 30, "smoke_density": 0.85}


static func play_at(host: Node, centre: Vector3, size: Vector2, effect_kind: String, params: Dictionary = {}) -> Node3D:
	var fx := new()
	host.add_child(fx)
	fx.position = centre
	fx.card_size = size
	fx.kind = effect_kind if THEMES.has(effect_kind) else "attack"
	for key: String in params.keys():
		fx.set(key, params[key])
	fx.play()
	return fx


func play() -> void:
	var debuff: bool = kind == "debuff"
	_streams(debuff)
	if debuff:
		_smoke()
	_motes(debuff)
	get_tree().create_timer(duration + 1.6).timeout.connect(queue_free)


func _streams(debuff: bool) -> void:
	var theme: Dictionary = THEMES[kind]
	var quad := QuadMesh.new()
	quad.size = Vector2(card_size.x * 1.15, card_size.y * 1.3)
	var material := ShaderMaterial.new()
	material.shader = QiShader
	material.render_priority = 38
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("intensity", qi_intensity)
	material.set_shader_parameter("tone", theme.tone)
	material.set_shader_parameter("core_tone", theme.core)
	material.set_shader_parameter("accent_tone", theme.accent)
	material.set_shader_parameter("scroll_speed", theme.speed)
	material.set_shader_parameter("down", 1.0 if debuff else 0.0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	mesh.position = Vector3(0.0, card_size.y * 0.1, 0.0)
	add_child(mesh)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, duration)
	tween.tween_callback(mesh.queue_free)


## The debuff's black smoke curtain, sinking from the head.
func _smoke() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(card_size.x * 1.25, card_size.y * 1.3)
	var material := ShaderMaterial.new()
	material.shader = SmokeShader
	material.render_priority = 39
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("density", smoke_density)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	mesh.position = Vector3(0.0, card_size.y * 0.1, 0.05)
	add_child(mesh)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, duration * 1.15)
	tween.tween_callback(mesh.queue_free)


func _motes(debuff: bool) -> void:
	if mote_count <= 0:
		return
	var theme: Dictionary = THEMES[kind]
	var mote_colour: Color = theme.mote
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, -1.0 if debuff else 1.0, 0.0)
	process.spread = 14.0
	process.initial_velocity_min = card_size.y * (0.2 if debuff else 0.45) * float(theme.speed)
	process.initial_velocity_max = card_size.y * (0.5 if debuff else 0.95) * float(theme.speed)
	process.gravity = Vector3.ZERO
	process.damping_min = card_size.y * 0.08
	process.damping_max = card_size.y * 0.25
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.5
	process.turbulence_noise_scale = 1.6
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(card_size.x * 0.40, card_size.y * 0.03, 0.05)
	var ramp_colours := PackedColorArray([Color(mote_colour, 0.0), Color(mote_colour, 0.8), Color(mote_colour.darkened(0.3), 0.45), Color(mote_colour.darkened(0.5), 0.0)])
	process.color_ramp = GhostFire._ramp(ramp_colours, PackedFloat32Array([0.0, 0.15, 0.7, 1.0]))
	particles.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * card_size.y * (0.034 if debuff else 0.028)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if debuff else BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.render_priority = 43
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.amount = mote_count
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 0.0
	particles.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	particles.position = Vector3(0.0, card_size.y * (0.46 if debuff else -0.42), 0.1)
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(2.8).timeout.connect(particles.queue_free)
