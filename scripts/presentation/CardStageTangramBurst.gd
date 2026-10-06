extends "res://scripts/presentation/CardStageShardBurst.gd"
## The shell falling apart along the tangram cuts instead of a radial star of cracks: the seven pieces pop out of
## the card, tumble and fall like the radial shards do (same physics and the same landing / fading rules of the
## parent). Presentation only.

const Tangram = preload("res://scripts/presentation/CardStageTangram.gd")


func setup_tangram(card: Node3D, card_size: Vector2, floor_y: float, palette: Array[Color]) -> void:
	_floor_y = floor_y
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for polygon_any: Variant in Tangram.pieces_in_card_plane(card_size):
		var polygon: Array = polygon_any
		var centroid := Vector2.ZERO
		for point: Vector2 in polygon:
			centroid += point
		centroid /= float(polygon.size())
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = _polygon_mesh(polygon, centroid)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = palette[rng.randi_range(0, palette.size() - 1)]
		material.render_priority = 27
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
		mesh_instance.global_position = card.to_global(Vector3(centroid.x, centroid.y, 0.06))
		mesh_instance.global_rotation = card.global_rotation
		# Each piece pops away from the middle of the card, the small ones faster.
		var direction: Vector2 = centroid.normalized() if centroid.length() > 0.01 else Vector2.UP
		var area_factor: float = clampf(2.2 / maxf(card_size.x * card_size.y * 0.05, 0.5), 0.8, 1.4)
		var speed: float = rng.randf_range(1.6, 3.4) * area_factor
		_pieces.append({
			"node": mesh_instance,
			"velocity": Vector3(direction.x * speed, direction.y * speed + rng.randf_range(0.8, 1.8), rng.randf_range(0.5, 2.2)),
			"spin": Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0), rng.randf_range(-8.0, 8.0)),
			"bounces": 2 if rng.randf() < BOUNCY_SHARE else 0,
			"state": "air",
			"rest": 0.0,
			"floor": floor_y + rng.randf_range(0.0, 0.05),
		})


## A convex polygon as a triangle fan around its first vertex, centred on `centroid`.
func _polygon_mesh(polygon: Array, centroid: Vector2) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for point: Vector2 in polygon:
		var local: Vector2 = (point - centroid) * 0.97
		vertices.append(Vector3(local.x, local.y, 0.0))
	var indices := PackedInt32Array()
	for index: int in range(1, polygon.size() - 1):
		indices.append_array([0, index, index + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
