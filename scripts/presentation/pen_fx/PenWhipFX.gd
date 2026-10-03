extends Node3D
## The basic attack of the brush (筆): the brush is cracked like a whip. A very short cold-white
## streak of light runs the length of the stroke and dies at once; what stays is the stroke of black
## ink the brush wrote in the air: thick-and-thin, dry-brushed, ending in a pointed lift-off, held for
## a while and then thinned out. A few drops of ink are flung off along the line of the stroke, and
## the point of contact gets only a tiny flash (the blow is a lash, not an explosion).
##
## Short light -> lash -> long ink -> flung drops. Every knob is a plain property (or a key of
## `defaults()`), so other pen skills can derive their own variants. Presentation only.

const InkShader = preload("res://scripts/presentation/shaders/ink_stroke.gdshader")
const LightShader = preload("res://scripts/presentation/shaders/pen_light.gdshader")
const Core = preload("res://scripts/presentation/punch_fx/PunchImpactCore.gd")
const Mark = preload("res://scripts/presentation/punch_fx/PunchInkMark.gd")

# --- Tunable parameters ---------------------------------------------------------------------------
var light_duration: float = 0.11        # seconds the white streak takes to run and die
var light_width: float = 0.08           # half-width of the white streak (world units)
var ink_duration: float = 0.30          # seconds the stroke is held at full strength
var ink_width: float = 0.22             # half-width of the ink stroke at its fattest (world units)
var ink_length: float = 3.4             # length of the stroke (world units)
var ink_fade_time: float = 0.28         # seconds the stroke takes to thin out and disappear
var ink_droplet_count: int = 5          # drops flung off by the lash (3 to 7)
var ink_droplet_speed: float = 3.6      # how far and fast they are thrown (world units per second)
var hit_flash_scale: float = 0.45       # size of the contact flash (a fraction of the fist FX's)
var card_hit_shake: float = 0.05        # how far the struck card shudders sideways (world units)
var lash_angle: float = -0.45           # direction of the stroke in the screen plane (radians)
var whip_width: float = 0.16          # half-width of the ink whip at its fattest (world units)
var whip_hold: float = 0.10            # seconds the whip stays at full strength after it lands
var burst_scale: float = 3.0           # size of the radial ink burst at the contact (bigger than a punch's)
var burst_life: float = 0.9            # seconds it takes to fade
var direction: float = 1.0              # +1: the lash comes from the left, -1: from the right
var critical: bool = false


## The defaults, as a dictionary, so skills can override single entries.
static func defaults() -> Dictionary:
	return {
		"light_duration": 0.11, "light_width": 0.08, "ink_duration": 0.30, "ink_width": 0.22, "ink_length": 3.4,
		"ink_fade_time": 0.28, "ink_droplet_count": 5, "ink_droplet_speed": 3.6, "hit_flash_scale": 0.45,
		"card_hit_shake": 0.05,
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


# --- The stroke's centre line ----------------------------------------------------------------------

## A point on the stroke at `s` (0 = where the brush begins, 1 = the tip): a long flowing line that
## swings past the target and flicks at the very end, like the crack of a whip. In local units.
func _stroke_point(s: float) -> Vector2:
	var x: float = lerpf(-0.5, 0.5, s) * ink_length * 0.6
	var y: float = (sin(s * PI * 1.1) * 0.18 - s * 0.05 + (s * s * s) * 0.22) * ink_length * 0.3
	return Vector2(x, y)


func _whip_point(s: float) -> Vector2:
	# The lash of the brush: a long curved whip that starts low behind the attacker, rises in a wide
	# S-shaped sweep and cracks down onto the target. In local units, centred on the contact point.
	var x: float = lerpf(-1.0, 0.18, s) * ink_length * 1.25
	var y: float = (sin(s * PI * 1.35) * 0.55 - s * 0.35 + 0.1 * sin(s * PI * 3.0)) * ink_length * 0.5
	return Vector2(x, y)


func _stroke_mesh(half_width: float, segments: int = 56, whip: bool = false) -> ArrayMesh:
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


# --- Playing -----------------------------------------------------------------------------------------

func play() -> void:
	var holder := Node3D.new()
	add_child(holder)
	# The whole lash is laid at the lash angle and mirrored for a lash from the right.
	holder.rotation.z = lash_angle * direction
	holder.scale = Vector3(direction, 1.0, 1.0)
	var seed_value: float = randf() * 10.0
	# 1. The ink whip: a long curved lash of black ink only (no light), cracking down onto the target.
	var whip_material := ShaderMaterial.new()
	whip_material.shader = InkShader
	whip_material.set_shader_parameter("seed", seed_value + 3.0)
	whip_material.set_shader_parameter("reveal", 0.0)
	whip_material.render_priority = 31
	var whip_mesh := MeshInstance3D.new()
	whip_mesh.mesh = _stroke_mesh(whip_width, 72, true)
	whip_mesh.material_override = whip_material
	whip_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(whip_mesh)
	var crack := create_tween()
	crack.tween_method(func(value: float) -> void: whip_material.set_shader_parameter("reveal", value), 0.0, 1.05, light_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	crack.tween_interval(whip_hold)
	crack.tween_method(func(value: float) -> void: whip_material.set_shader_parameter("fade", value), 0.0, 1.0, ink_fade_time)
	# 2. The stroke left on the enemy where it was struck (the mark of the blow): written as the whip
	# lands, and kept longer than the whip.
	var ink_material := ShaderMaterial.new()
	ink_material.shader = InkShader
	ink_material.set_shader_parameter("seed", seed_value)
	ink_material.set_shader_parameter("reveal", 0.0)
	ink_material.render_priority = 32
	var ink_mesh := MeshInstance3D.new()
	ink_mesh.mesh = _stroke_mesh(ink_width)
	ink_mesh.material_override = ink_material
	ink_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ink_mesh.position.z = 0.01
	holder.add_child(ink_mesh)
	var write := create_tween()
	write.tween_interval(light_duration * 0.9)
	write.tween_method(func(value: float) -> void: ink_material.set_shader_parameter("reveal", value), 0.0, 1.05, 0.05)
	write.tween_interval(ink_duration)
	write.tween_method(func(value: float) -> void: ink_material.set_shader_parameter("fade", value), 0.0, 1.0, ink_fade_time)
	# 3. The contact: a tiny flash, the radial ink burst (bigger and rougher than a punch's mark), and
	# the cold spark (added by the caller).
	var contact := Core.new()
	contact.impact_scale = hit_flash_scale
	contact.flash_intensity = 2.4
	contact.afterimages = 0
	contact.life = 0.05
	contact.tremble = critical
	add_child(contact)
	get_tree().create_timer(light_duration * 0.95).timeout.connect(contact.play)
	get_tree().create_timer(light_duration * 0.95).timeout.connect(_ink_burst)
	_fling_drops()
	get_tree().create_timer(light_duration + whip_hold + ink_duration + ink_fade_time + 0.5).timeout.connect(queue_free)


## The radial burst of ink at the contact: the same black ink-burst style as a punch's mark but larger
## and with long splayed streaks, so the two cannot be mistaken for each other.
func _ink_burst() -> void:
	var mark := Mark.new()
	mark.mark_scale = burst_scale
	mark.life = burst_life
	add_child(mark)
	mark.play()



## A few drops of ink thrown off the tip along the line of the stroke, then a little later gone.
func _fling_drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = clampi(ink_droplet_count, 0, 12)
	var soft := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	soft.gradient = gradient
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 32
	soft.height = 32
	var angle: float = lash_angle * direction
	for index: int in range(count):
		var drop := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var size: float = rng.randf_range(0.04, 0.13)
		# Drops are slightly stretched along the throw.
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
		# Thrown from near the tip, in the direction of the stroke with a little scatter.
		var local_tip: Vector2 = _stroke_point(rng.randf_range(0.8, 1.0))
		var tip: Vector2 = Vector2(local_tip.x * direction, local_tip.y).rotated(angle)
		# The holder is mirrored for a lash from the right, so the throw runs along its mirrored line.
		var throw_angle: float = (angle if direction >= 0.0 else PI - angle * -1.0 * -1.0) + rng.randf_range(-0.55, 0.55)
		drop.position = Vector3(tip.x, tip.y, 0.04)
		drop.rotation.z = throw_angle
		var reach: float = ink_droplet_speed * rng.randf_range(0.18, 0.42)
		var seconds: float = rng.randf_range(0.28, 0.42) + ink_duration * 0.4
		var delay: float = light_duration * 0.6
		var tween := create_tween().set_parallel(true)
		tween.tween_property(drop, "position", drop.position + Vector3(cos(throw_angle), sin(throw_angle), 0.0) * reach, seconds).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(material, "albedo_color:a", 0.0, seconds * 0.5).set_delay(delay + seconds * 0.5)
		tween.chain().tween_callback(drop.queue_free)
