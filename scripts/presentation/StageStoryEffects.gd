extends RefCounted
## Effects for the Molin Yanjiang / Zuo Yin encounter on Card Stage: the 語魅 being drawn into
## the boss (the same atlas and inward-particle idea as the stalactite-cave cutscene), purple
## shell shards when the 語魅 is broken, and Zuo Yin's three crescent blades. Presentation only.

const AtlasSheet = "res://assets/fx/yumei_absorption_particles_atlas_4x3_lowres_v2_transparent.png"
## The two cloud frames used by scenes/fx/yumei_element.tscn.
const ATLAS_REGIONS: Array[Rect2] = [Rect2(777, 410, 372, 330), Rect2(1126, 415, 322, 335)]
const CrescentShader = preload("res://scripts/presentation/shaders/crescent_slash.gdshader")

const PURPLE := Color(0.55, 0.2, 0.85)
const DEEP_PURPLE := Color(0.28, 0.035, 0.38)


static func _soft_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	gradient.colors = PackedColorArray([Color(0.86, 0.42, 1.0, 1.0), Color(0.33, 0.03, 0.48, 0.9), Color(0.05, 0.0, 0.08, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture


## The 語魅 pours into `target` from every side: converging particles plus the supplied cloud
## frames flying in. Returns after `seconds`; everything frees itself.
static func absorption(host: Node, target: Vector3, seconds: float = 1.7) -> void:
	var root := Node3D.new()
	host.add_child(root)
	root.position = target
	var soft: Texture2D = _soft_texture()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = soft
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 26
	var directions: int = 10
	for index: int in range(directions):
		var angle: float = TAU * float(index) / float(directions)
		var start := Vector3(cos(angle) * 4.2, sin(angle) * 2.6 + 0.2, randf_range(-0.5, 1.0))
		var particles := CPUParticles3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.22, 0.22)
		particles.mesh = quad
		particles.material_override = material
		particles.amount = 9
		particles.lifetime = 0.85
		particles.preprocess = 0.85
		particles.randomness = 0.35
		particles.direction = -start.normalized()
		particles.spread = 9.0
		particles.gravity = Vector3.ZERO
		var speed: float = start.length() / particles.lifetime
		particles.initial_velocity_min = speed * 0.88
		particles.initial_velocity_max = speed * 1.08
		particles.scale_amount_min = 0.7
		particles.scale_amount_max = 1.5
		particles.color = Color(0.5, 0.12, 0.8, 0.85)
		particles.position = start
		particles.emitting = true
		root.add_child(particles)
	# The supplied cloud frames, thrown inward in waves.
	var sheet: Texture2D = load(AtlasSheet) as Texture2D
	if sheet != null:
		var waves: int = maxi(2, int(seconds / 0.5))
		for wave: int in range(waves):
			for index: int in range(5):
				var angle: float = TAU * (float(index) / 5.0 + float(wave) * 0.11)
				var cloud := Sprite3D.new()
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = ATLAS_REGIONS[(index + wave) % ATLAS_REGIONS.size()]
				cloud.texture = atlas
				cloud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				cloud.shaded = false
				cloud.double_sided = true
				cloud.no_depth_test = true
				cloud.render_priority = 27
				cloud.pixel_size = 0.0021
				cloud.modulate = Color(0.72, 0.42, 0.94, 0.0)
				var start := Vector3(cos(angle) * 4.4, sin(angle) * 2.7, randf_range(0.0, 0.8))
				cloud.position = start
				cloud.rotation.z = (-start).angle_to(Vector3.RIGHT) * 0.0
				root.add_child(cloud)
				var tween := host.create_tween().set_parallel(true)
				tween.tween_property(cloud, "position", Vector3.ZERO, 0.8).set_delay(float(wave) * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tween.tween_property(cloud, "modulate:a", 0.8, 0.25).set_delay(float(wave) * 0.45)
				tween.tween_property(cloud, "modulate:a", 0.0, 0.2).set_delay(float(wave) * 0.45 + 0.6)
				tween.tween_property(cloud, "scale", Vector3.ONE * 0.3, 0.8).set_delay(float(wave) * 0.45)
	host.get_tree().create_timer(seconds + 0.9).timeout.connect(root.queue_free)


## The purple shell cracks and falls apart: many triangular shards peel off the card.
static func shell_shatter(host: Node, card_position: Vector3, card_size: Vector2) -> void:
	var holder := Node3D.new()
	host.add_child(holder)
	holder.position = card_position
	var particles := CPUParticles3D.new()
	# A small triangle as the particle mesh.
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, -0.4, 0.0), Vector3(0.5, -0.3, 0.0), Vector3(0.05, 0.6, 0.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var triangle := ArrayMesh.new()
	triangle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	particles.mesh = triangle
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 28
	particles.material_override = material
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.amount = 90
	particles.lifetime = 1.3
	particles.randomness = 0.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(card_size.x * 0.5, card_size.y * 0.5, 0.05)
	particles.direction = Vector3(0.0, -0.4, 1.0)
	particles.spread = 75.0
	particles.gravity = Vector3(0.0, -2.2, 0.0)
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 2.4
	particles.angular_velocity_min = -280.0
	particles.angular_velocity_max = 280.0
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.34
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(0.62, 0.3, 0.92, 1.0), Color(0.3, 0.06, 0.45, 0.9), Color(0.08, 0.0, 0.12, 0.0)])
	particles.color_ramp = ramp
	holder.add_child(particles)
	particles.emitting = true
	host.get_tree().create_timer(2.0).timeout.connect(holder.queue_free)


## One thrown crescent blade from `from` to `to`. It is stretched along its flight and
## shimmers; `brightness` and `opacity` set how strong it is. Awaitable (until it lands).
static func crescent(host: Node, from: Vector3, to: Vector3, brightness: float, seconds: float = 0.2, size: float = 1.5) -> void:
	var instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	instance.mesh = quad
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = CrescentShader
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("flicker", 0.55)
	material.set_shader_parameter("time_offset", randf() * 6.0)
	material.render_priority = 29
	instance.material_override = material
	host.add_child(instance)
	instance.position = from
	var heading: Vector3 = to - from
	instance.rotation.z = atan2(heading.y, heading.x)
	instance.scale = Vector3(0.4, 0.6, 1.0)
	var tween := host.create_tween().set_parallel(true)
	tween.tween_property(instance, "position", to, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Deform in flight: it lengthens and thins as it speeds up, then flattens on arrival.
	tween.tween_property(instance, "scale", Vector3(1.7, 0.7, 1.0), seconds * 0.8)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("brightness", value), brightness, brightness * 0.35, 0.1).set_delay(seconds)
	tween.chain().tween_callback(instance.queue_free)
	await host.get_tree().create_timer(seconds).timeout
