extends Node3D
## The basic attack of the brush (筆): a brush swung like a whip. In three beats, in this order:
##   1. SWING  - a curved lash of black ink with a visible brush head on the end of it sweeps in and cracks
##               down on the target (a short attack trail, no light);
##   2. HIT    - at contact: a small cold spark and a burst of large ink drops thrown out around the
##               point of impact, with a few short radial lines (calligraphic splatter, not a blast);
##   3. TRACE  - the stroke of ink the brush leaves on the enemy: thick-and-thin, dry-brushed, held for a
##               while and then thinned out; it is written only after the whip has landed.
## Every knob is a plain property (or a key of `defaults()`), so other pen skills can derive their own
## variants. Presentation only.

const InkShader = preload("res://scripts/presentation/shaders/ink_stroke.gdshader")
const Core = preload("res://scripts/presentation/punch_fx/PunchImpactCore.gd")

# --- Tunable parameters ---------------------------------------------------------------------------
var light_duration: float = 0.13        # seconds the whip takes to sweep in and land
var ink_duration: float = 0.30          # seconds the residue stroke is held at full strength
var ink_width: float = 0.22             # half-width of the residue stroke at its fattest (world units)
var ink_length: float = 3.4             # reach of the whip and of the residue stroke (world units)
var ink_fade_time: float = 0.28         # seconds the stroke takes to thin out and disappear
var ink_droplet_count: int = 5          # small drops flung along the lash (3 to 7)
var ink_droplet_speed: float = 3.6      # how far and fast they are thrown (world units per second)
var hit_flash_scale: float = 0.45       # size of the contact flash (a fraction of the fist FX's)
var card_hit_shake: float = 0.05        # how far the struck card shudders sideways (world units)
var lash_angle: float = -0.45           # direction of the lash in the screen plane (radians)
var whip_width: float = 0.20            # half-width of the whip at its head (world units)
var whip_hold: float = 0.10             # seconds the whip stays at full strength after it lands
var burst_scale: float = 4.0            # size of the ink burst at the contact (much bigger than a punch's mark)
var burst_life: float = 0.9             # seconds the burst takes to fade
var direction: float = 1.0              # +1: the lash comes from the left, -1: from the right
var critical: bool = false


## The defaults, as a dictionary, so skills can override single entries.
static func defaults() -> Dictionary:
	return {
		"light_duration": 0.13, "ink_duration": 0.30, "ink_width": 0.22, "ink_length": 3.4,
		"ink_fade_time": 0.28, "ink_droplet_count": 5, "ink_droplet_speed": 3.6, "hit_flash_scale": 0.45,
		"card_hit_shake": 0.05, "whip_width": 0.20, "whip_hold": 0.10, "burst_scale": 4.0, "burst_life": 0.9,
	}


## Plays one lash centred on `centre` (a world position). `params` overrides any knob above.
static func play_at(host: Node, centre: Vector3, params: Dictionary = {}) -> Node3D:
	var fx := new()
	host.add_child(fx)
	fx.position = centre
	for key: String in params.keys():
		fx.set(key, params[key])
	fx.play()
	return fx


# --- Paths -------------------------------------------------------------------------------------------

## The residue stroke left on the enemy: a flowing line swinging past the contact point.
func _stroke_point(s: float) -> Vector2:
	var x: float = lerpf(-0.5, 0.5, s) * ink_length * 0.6
	var y: float = (sin(s * PI * 1.1) * 0.18 - s * 0.05 + (s * s * s) * 0.22) * ink_length * 0.3
	return Vector2(x, y)


## Where along the lash (0..1) it meets the target: the point of sharpest bend, the crack of the whip.
const WHIP_CONTACT := 0.52
## true: the lash's tail sweeps back in a crescent (a C); false: a short sharp hook (the earlier look).
const CRESCENT_TAIL := true
## The share of the swing time at which the lash has reached WHIP_CONTACT (it speeds up as it goes).
const CONTACT_TIME := 0.70
var _whip_cache: PackedVector2Array = PackedVector2Array()


## The lash comes in almost straight, like a cord pulled taut, and bends sharply right where it meets
## the target (the crack of a whip), then the tail sweeps back around in a crescent (a C), drawing the stroke back toward
## where it came from. The contact point is the origin.
func _whip_build() -> void:
	var steps: int = 140
	var step_length: float = ink_length * 0.95 / (float(steps) * WHIP_CONTACT)
	var points := PackedVector2Array()
	var position := Vector2.ZERO
	var heading: float = 0.28
	for index: int in range(steps + 1):
		points.append(position)
		var s: float = float(index) / float(steps)
		var bend: float = exp(-pow((s - WHIP_CONTACT) / 0.07, 2.0))
		position += Vector2(cos(heading), sin(heading)) * step_length
		if CRESCENT_TAIL:
			# The tail sweeps back around in a sustained curve: a crescent (a C).
			heading += -0.012 + (-0.09 * bend) + (-0.029 * smoothstep(WHIP_CONTACT, WHIP_CONTACT + 0.06, s))
		else:
			# The tail snaps back in a short hook.
			heading += -0.012 + (-0.172 * bend)
	var anchor: Vector2 = points[int(round(WHIP_CONTACT * float(steps)))]
	for index: int in range(points.size()):
		points[index] -= anchor
	_whip_cache = points


func _whip_point(s: float) -> Vector2:
	if _whip_cache.is_empty():
		_whip_build()
	var scaled: float = clampf(s, 0.0, 1.0) * float(_whip_cache.size() - 1)
	var low: int = int(floor(scaled))
	var high: int = mini(low + 1, _whip_cache.size() - 1)
	return _whip_cache[low].lerp(_whip_cache[high], scaled - float(low))


func _path_mesh(half_width: float, segments: int, whip: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index: int in range(segments + 1):
		var s: float = float(index) / float(segments)
		var point: Vector2 = _whip_point(s) if whip else _stroke_point(s)
		var ahead: Vector2 = _whip_point(minf(s + 0.01, 1.0)) if whip else _stroke_point(minf(s + 0.01, 1.0))
		var behind: Vector2 = _whip_point(maxf(s - 0.01, 0.0)) if whip else _stroke_point(maxf(s - 0.01, 0.0))
		var tangent: Vector2 = (ahead - behind).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		vertices.append(Vector3(point.x - normal.x * half_width, point.y - normal.y * half_width, 0.0))
		vertices.append(Vector3(point.x + normal.x * half_width, point.y + normal.y * half_width, 0.0))
		uvs.append(Vector2(s, 0.0))
		uvs.append(Vector2(s, 1.0))
		if index < segments:
			var at: int = index * 2
			indices.append_array(PackedInt32Array([at, at + 1, at + 2, at + 1, at + 3, at + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _ink_material(seed_value: float, lash: bool, priority: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.set_shader_parameter("tail_taper", 0.45 if CRESCENT_TAIL else 0.88)
	material.shader = InkShader
	material.set_shader_parameter("seed", seed_value)
	material.set_shader_parameter("reveal", 0.0)
	material.set_shader_parameter("lead_heavy", 1.0 if lash else 0.0)
	material.render_priority = priority
	return material


# --- Playing -----------------------------------------------------------------------------------------

func play() -> void:
	var holder := Node3D.new()
	add_child(holder)
	# The whole lash is laid at the lash angle and mirrored for a lash from the right.
	holder.rotation.z = lash_angle * direction
	holder.scale = Vector3(direction, 1.0, 1.0)
	var seed_value: float = randf() * 10.0
	# 1. SWING: the ink whip, with the brush head riding its tip.
	var whip_material := _ink_material(seed_value + 3.0, true, 31)
	var whip_mesh := MeshInstance3D.new()
	whip_mesh.mesh = _path_mesh(whip_width, 72, true)
	whip_mesh.material_override = whip_material
	whip_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(whip_mesh)
	var crack := create_tween()
	crack.tween_method(func(value: float) -> void: whip_material.set_shader_parameter("reveal", value), 0.0, 1.05, light_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	crack.tween_interval(whip_hold)
	crack.tween_method(func(value: float) -> void: whip_material.set_shader_parameter("fade", value), 0.0, 1.0, ink_fade_time)
	# 3. TRACE: the stroke left on the enemy, written only after the whip has landed.
	var ink_material := _ink_material(seed_value, false, 32)
	var ink_mesh := MeshInstance3D.new()
	ink_mesh.mesh = _path_mesh(ink_width, 56, false)
	ink_mesh.material_override = ink_material
	ink_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ink_mesh.position.z = 0.01
	holder.add_child(ink_mesh)
	var write := create_tween()
	write.tween_interval(light_duration * CONTACT_TIME + 0.05)
	write.tween_method(func(value: float) -> void: ink_material.set_shader_parameter("reveal", value), 0.0, 1.05, 0.05)
	write.tween_interval(ink_duration)
	write.tween_method(func(value: float) -> void: ink_material.set_shader_parameter("fade", value), 0.0, 1.0, ink_fade_time)
	# 2. HIT: a tiny flash and the ink burst, exactly when the whip lands.
	var contact := Core.new()
	contact.impact_scale = hit_flash_scale
	contact.flash_intensity = 2.4
	contact.afterimages = 0
	contact.life = 0.05
	contact.tremble = critical
	add_child(contact)
	get_tree().create_timer(light_duration * CONTACT_TIME).timeout.connect(contact.play)
	get_tree().create_timer(light_duration * CONTACT_TIME).timeout.connect(_ink_burst)
	_fling_drops()
	get_tree().create_timer(light_duration + 0.05 + 0.05 + ink_duration + ink_fade_time + 0.5).timeout.connect(queue_free)


func _soft_disc() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.78, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 48
	texture.height = 48
	return texture


## The ink burst at the contact: large drops of ink thrown out in a ring from the point of impact, each
## clearly seen, with a few short radial lines between them (calligraphic splatter, not a blast). It is
## far larger and looser than a punch's mark, so the two cannot be mistaken for each other.
func _ink_burst() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var soft: GradientTexture2D = _soft_disc()
	var drops: int = 8
	var phase: float = rng.randf() * TAU
	for index: int in range(drops):
		var angle: float = phase + TAU * float(index) / float(drops) + rng.randf_range(-0.22, 0.22)
		var direction_vec := Vector3(cos(angle), sin(angle), 0.0)
		var size: float = burst_scale * rng.randf_range(0.07, 0.17)
		var reach: float = burst_scale * rng.randf_range(0.20, 0.52)
		var seconds: float = rng.randf_range(0.10, 0.17)
		for layer: int in range(1):
			var drop := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(size * rng.randf_range(1.0, 1.25), size)
			drop.mesh = quad
			drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_texture = soft
			material.albedo_color = Color(0.012, 0.012, 0.016, 0.97)
			material.render_priority = 36
			drop.material_override = material
			add_child(drop)
			drop.position = direction_vec * burst_scale * 0.04 + Vector3(0.0, 0.0, 0.05)
			drop.rotation.z = angle
			drop.scale = Vector3.ONE * 0.3
			var tween := create_tween().set_parallel(true)
			tween.tween_property(drop, "position", direction_vec * reach + Vector3(0.0, -reach * 0.08, 0.05), seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tween.tween_property(drop, "scale", Vector3.ONE, seconds * 0.6)
			tween.tween_property(material, "albedo_color:a", 0.0, burst_life * 0.5).set_delay(burst_life * 0.5)
			tween.chain().tween_callback(drop.queue_free)
		# A short radial line of ink between the drops.
		var line := MeshInstance3D.new()
		var line_quad := QuadMesh.new()
		var line_length: float = burst_scale * rng.randf_range(0.18, 0.34)
		line_quad.size = Vector2(line_length, burst_scale * 0.018)
		line.mesh = line_quad
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var line_material := StandardMaterial3D.new()
		line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line_material.albedo_color = Color(0.012, 0.012, 0.016, 0.95)
		line_material.render_priority = 36
		line.material_override = line_material
		add_child(line)
		var line_angle: float = angle + TAU / float(drops) * 0.5
		var line_dir := Vector3(cos(line_angle), sin(line_angle), 0.0)
		line.rotation.z = line_angle
		line.position = line_dir * burst_scale * 0.10
		var line_tween := create_tween().set_parallel(true)
		line_tween.tween_property(line, "position", line_dir * (burst_scale * 0.10 + line_length * 0.8), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		line_tween.tween_property(line_material, "albedo_color:a", 0.0, burst_life * 0.45).set_delay(burst_life * 0.3)
		line_tween.chain().tween_callback(line.queue_free)


## A few small drops of ink thrown off the lash along its line, then a little later gone.
func _fling_drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = clampi(ink_droplet_count, 0, 12)
	var soft: GradientTexture2D = _soft_disc()
	var angle: float = lash_angle * direction
	for index: int in range(count):
		var drop := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var size: float = rng.randf_range(0.04, 0.12)
		quad.size = Vector2(size * rng.randf_range(1.2, 2.0), size)
		drop.mesh = quad
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = soft
		material.albedo_color = Color(0.012, 0.012, 0.016, 0.95)
		material.render_priority = 33
		drop.material_override = material
		add_child(drop)
		# Thrown from along the lash, in the direction it was travelling, with a little scatter.
		var local_point: Vector2 = _whip_point(rng.randf_range(0.55, 0.95))
		var tip: Vector2 = Vector2(local_point.x * direction, local_point.y).rotated(angle)
		var throw_angle: float = (angle if direction >= 0.0 else PI - angle) + rng.randf_range(-0.55, 0.55)
		drop.position = Vector3(tip.x, tip.y, 0.04)
		drop.rotation.z = throw_angle
		var reach: float = ink_droplet_speed * rng.randf_range(0.18, 0.42)
		var seconds: float = rng.randf_range(0.28, 0.42) + ink_duration * 0.4
		var delay: float = light_duration * 0.5
		var tween := create_tween().set_parallel(true)
		tween.tween_property(drop, "position", drop.position + Vector3(cos(throw_angle), sin(throw_angle), 0.0) * reach, seconds).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(material, "albedo_color:a", 0.0, seconds * 0.5).set_delay(delay + seconds * 0.5)
		tween.chain().tween_callback(drop.queue_free)
