extends "res://scripts/presentation/CardStageTangramBurst.gd"
## Convex fragments cut by crossing slashes. They shear apart before tumbling to the floor.

const SpatialCuts = preload("res://scripts/presentation/CardStageSpatialCuts.gd")
var _card_size: Vector2 = Vector2.ONE


func setup_spatial(card: Node3D, card_size: Vector2, floor_y: float, palette: Array[Color]) -> void:
	_floor_y = floor_y
	_card_size = card_size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for polygon: Array in SpatialCuts.pieces_in_card_plane(card_size):
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
		material.albedo_texture = card.card_viewport.get_texture()
		material.albedo_color = palette[rng.randi_range(0, palette.size() - 1)].lightened(0.15)
		# Pieces remain depth-sorted with the card row if a shard drifts near an ally.
		material.render_priority = 0
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
		var shear: Vector2 = Vector2(0.85, -0.53) * (0.09 if centroid.x + centroid.y * 0.35 > 0.0 else -0.09)
		mesh_instance.global_position = card.to_global(Vector3(centroid.x + shear.x, centroid.y + shear.y, 0.06))
		mesh_instance.global_rotation = card.global_rotation
		var direction: Vector2 = Vector2(0.85, -0.53) * (1.0 if centroid.x + centroid.y * 0.35 > 0.0 else -1.0)
		_pieces.append({
			"node": mesh_instance,
			"velocity": Vector3(direction.x * rng.randf_range(0.7, 1.5), direction.y * rng.randf_range(0.7, 1.5) + 1.0, rng.randf_range(0.2, 0.8)),
			"spin": Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0), rng.randf_range(-5.0, 5.0)),
			"bounces": 0,
			"state": "air",
			"rest": 0.0,
			"floor": floor_y + rng.randf_range(0.0, 0.05),
		})


func _polygon_mesh(polygon: Array, centroid: Vector2) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for point: Vector2 in polygon:
		var local: Vector2 = (point - centroid) * 0.985
		vertices.append(Vector3(local.x, local.y, 0.0))
		uvs.append(Vector2(point.x / _card_size.x + 0.5, 0.5 - point.y / _card_size.y))
	var indices := PackedInt32Array()
	for index: int in range(1, polygon.size() - 1):
		indices.append_array([0, index, index + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
