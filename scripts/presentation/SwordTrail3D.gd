extends Node3D
## A transient, procedural ribbon in world space; it never applies combat damage.

var path_history: PackedVector3Array = PackedVector3Array()
var last_endpoint: Vector3 = Vector3.ZERO
var _ribbon: MeshInstance3D
var _material: StandardMaterial3D
var _playing: bool = false


func play(from: Vector3, target: Vector3, hit: bool) -> void:
	if _playing:
		return
	_playing = true
	path_history.clear()
	_setup_ribbon()
	var endpoint: Vector3 = target
	if not hit:
		var horizontal_sign: float = signf(target.x - from.x)
		if is_zero_approx(horizontal_sign):
			horizontal_sign = 1.0
		endpoint += Vector3(horizontal_sign * 3.2, 0.28, -3.0)
	last_endpoint = endpoint
	var flight: Tween = create_tween()
	flight.tween_method(_advance.bind(from, target, endpoint, hit), 0.0, 1.0, 0.32 if hit else 0.57).set_trans(Tween.TRANS_LINEAR)
	await flight.finished
	if hit:
		_spawn_impact(target)
	var fade: Tween = create_tween()
	fade.tween_property(_material, "albedo_color:a", 0.0, 0.24)
	await fade.finished
	_playing = false
	_ribbon.visible = false


func _setup_ribbon() -> void:
	if _ribbon == null:
		_ribbon = MeshInstance3D.new()
		_ribbon.name = "SwordRibbonVolume"
		_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ribbon)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Color(0.58, 0.91, 1.0, 1.0)
	_material.emission_enabled = true
	_material.emission = Color(0.12, 0.42, 0.62)
	_material.emission_energy_multiplier = 1.7
	_ribbon.material_override = _material
	_ribbon.visible = true


func _path_point(progress: float, from: Vector3, target: Vector3, endpoint: Vector3, hit: bool) -> Vector3:
	if hit:
		return from.lerp(target, progress) + Vector3(0.0, sin(progress * PI) * 0.38, sin(progress * PI) * 0.25)
	# The target plane is crossed before the last third; a miss visibly travels behind it.
	const CROSSING: float = 0.64
	if progress <= CROSSING:
		var approach: float = progress / CROSSING
		return from.lerp(target, approach) + Vector3(0.0, sin(approach * PI) * 0.38, sin(approach * PI) * 0.25)
	return target.lerp(endpoint, (progress - CROSSING) / (1.0 - CROSSING))


func _advance(progress: float, from: Vector3, target: Vector3, endpoint: Vector3, hit: bool) -> void:
	var head: Vector3 = _path_point(progress, from, target, endpoint, hit)
	path_history.append(head)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var start: float = maxf(0.0, progress - 0.38)
	const SAMPLES: int = 18
	# Two crossing ribbons make a thin volume, rather than a camera-facing overlay.
	for strip: int in range(2):
		var base_index: int = vertices.size()
		for sample: int in range(SAMPLES):
			var section: float = float(sample) / float(SAMPLES - 1)
			var position_t: float = lerpf(start, progress, section)
			var point: Vector3 = _path_point(position_t, from, target, endpoint, hit)
			var next_t: float = minf(position_t + 0.002, 1.0)
			var previous_t: float = maxf(position_t - 0.002, 0.0)
			var tangent: Vector3 = (_path_point(next_t, from, target, endpoint, hit) - _path_point(previous_t, from, target, endpoint, hit)).normalized()
			var side: Vector3 = Vector3.UP if strip == 0 else tangent.cross(Vector3.UP).normalized()
			var width: float = (0.018 + sin(section * PI) * 0.13) * (1.0 if strip == 0 else 0.55)
			vertices.append(to_local(point - side * width))
			vertices.append(to_local(point + side * width))
			var color := Color(0.8, 0.97, 1.0, section * 0.95)
			colors.append(color)
			colors.append(color)
			if sample > 0:
				var offset: int = base_index + sample * 2
				indices.append_array(PackedInt32Array([offset - 2, offset - 1, offset, offset - 1, offset + 1, offset]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var ribbon_mesh := ArrayMesh.new()
	ribbon_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ribbon.mesh = ribbon_mesh


func _spawn_impact(world_position: Vector3) -> void:
	for index: int in range(9):
		var spark := MeshInstance3D.new()
		spark.name = "ImpactSpark%d" % index
		var shape := BoxMesh.new()
		shape.size = Vector3(0.035, 0.22, 0.035)
		spark.mesh = shape
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.albedo_color = Color(1.0, 0.88, 0.51, 1.0)
		spark.material_override = glow
		add_child(spark)
		spark.global_position = world_position
		var angle: float = float(index) * TAU / 9.0
		var outward := Vector3(cos(angle), sin(angle), sin(angle * 2.0) * 0.85)
		spark.rotation = Vector3(angle * 0.3, angle, angle - PI * 0.5)
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(spark, "global_position", world_position + outward * 0.7, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(glow, "albedo_color:a", 0.0, 0.2)
		tween.chain().tween_callback(spark.queue_free)
