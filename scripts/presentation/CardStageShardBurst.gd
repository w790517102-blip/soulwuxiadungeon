extends Node3D
## The purple shell shattering like a window hit by a baseball: a star of cracks (spokes and
## rings around the impact) breaks the card's shell into triangles that fly radially outward
## (nearer to the impact = faster), then fall under gravity. Some pieces bounce off the floor a
## couple of times, most simply land and lie still, and everything fades away after resting.
## Delta follows Engine.time_scale, so the slow motion applies by itself. Presentation only.

const GRAVITY := -9.5
const BOUNCY_SHARE := 0.30
const RESTITUTION := 0.42
const SECOND_RESTITUTION := 0.30
const REST_SECONDS := 1.4
const FADE_SECONDS := 0.9

var _pieces: Array[Dictionary] = []
var _floor_y: float = 0.0
var _done_after: float = 0.0
var rest_seconds: float = REST_SECONDS
var fade_seconds: float = FADE_SECONDS


## `card`: the card whose shell breaks; `impact` is in the card's own plane (x right, y up) around
## its centre; `floor_y` is the world height pieces land on.
func setup(card: Node3D, card_size: Vector2, impact: Vector2, floor_y: float, palette: Array[Color] = []) -> void:
	_floor_y = floor_y
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spokes: int = 16
	var radii: Array[float] = [0.0, 0.16, 0.38, 0.70, 1.10, 1.70, 2.6]
	# Jittered grid vertices around the impact, shared by neighbouring cells.
	var grid: Array = []
	for ring: int in range(radii.size()):
		var row: Array[Vector2] = []
		for spoke: int in range(spokes):
			var angle: float = TAU * float(spoke) / float(spokes) + rng.randf_range(-0.10, 0.10)
			var radius: float = radii[ring] * card_size.y * 0.5 * (1.0 + rng.randf_range(-0.10, 0.10)) if ring > 0 else 0.0
			row.append(impact + Vector2.from_angle(angle) * radius)
		grid.append(row)
	var colours: Array[Color] = [Color(0.58, 0.24, 0.88, 0.50), Color(0.36, 0.08, 0.55, 0.55), Color(0.74, 0.44, 0.96, 0.45)]
	if not palette.is_empty():
		colours = palette
	var triangles: Array = []
	for spoke: int in range(spokes):
		var next: int = (spoke + 1) % spokes
		triangles.append([impact, grid[1][spoke], grid[1][next]])
		for ring: int in range(1, radii.size() - 1):
			var a: Vector2 = grid[ring][spoke]
			var b: Vector2 = grid[ring][next]
			var c: Vector2 = grid[ring + 1][next]
			var d: Vector2 = grid[ring + 1][spoke]
			if rng.randf() < 0.5:
				triangles.append([a, b, c])
				triangles.append([a, c, d])
			else:
				triangles.append([a, b, d])
				triangles.append([b, c, d])
	var half: Vector2 = card_size * 0.5
	for triangle: Array in triangles:
		var centroid: Vector2 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
		if absf(centroid.x) > half.x * 1.02 or absf(centroid.y) > half.y * 1.02:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = _triangle_mesh(triangle, centroid)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = colours[rng.randi_range(0, colours.size() - 1)]
		material.render_priority = 27
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
		var world: Vector3 = card.to_global(Vector3(centroid.x, centroid.y, 0.06))
		mesh_instance.global_position = world
		mesh_instance.global_rotation = card.global_rotation
		# Radial blast: close to the impact is violent, far away is gentler.
		var offset: Vector2 = centroid - impact
		var distance: float = maxf(offset.length(), 0.05)
		var direction: Vector2 = offset / distance
		var speed: float = clampf(4.2 / (0.45 + distance * 1.7), 0.9, 7.0) * rng.randf_range(0.8, 1.25)
		var velocity := Vector3(direction.x * speed, direction.y * speed + rng.randf_range(0.8, 1.8), rng.randf_range(0.4, 2.6))
		_pieces.append({
			"node": mesh_instance,
			"velocity": velocity,
			"spin": Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0), rng.randf_range(-9.0, 9.0)),
			"bounces": 2 if rng.randf() < BOUNCY_SHARE else 0,
			"state": "air",
			"rest": 0.0,
			"floor": floor_y + rng.randf_range(0.0, 0.05),
		})


func _triangle_mesh(triangle: Array, centroid: Vector2) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for point: Vector2 in triangle:
		var local: Vector2 = (point - centroid) * 0.97
		vertices.append(Vector3(local.x, local.y, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func piece_count() -> int:
	return _pieces.size()


func bouncy_count() -> int:
	var count: int = 0
	for piece: Dictionary in _pieces:
		if int(piece.bounces) > 0 or piece.state == "bounced":
			count += 1
	return count


func _process(delta: float) -> void:
	var alive: int = 0
	for piece: Dictionary in _pieces:
		var node_ref: Variant = piece.node
		if not is_instance_valid(node_ref):
			continue
		var node: MeshInstance3D = node_ref
		alive += 1
		match String(piece.state):
			"air", "bounced":
				var velocity: Vector3 = piece.velocity
				velocity.y += GRAVITY * delta
				node.global_position += velocity * delta
				node.rotation += Vector3(piece.spin) * delta
				piece.velocity = velocity
				if node.global_position.y <= float(piece.floor) and velocity.y < 0.0:
					node.global_position.y = float(piece.floor)
					if int(piece.bounces) > 0:
						# A real bounce: loses most of its energy and spin, at most twice.
						var factor: float = RESTITUTION if int(piece.bounces) == 2 else SECOND_RESTITUTION
						piece.velocity = Vector3(velocity.x * 0.6, -velocity.y * factor, velocity.z * 0.6)
						piece.spin = Vector3(piece.spin) * 0.5
						piece.bounces = int(piece.bounces) - 1
						piece.state = "bounced"
					else:
						# Lands and stops, lying nearly flat; only a short slide.
						piece.state = "slide"
						piece.velocity = Vector3(velocity.x * 0.25, 0.0, velocity.z * 0.25)
			"slide":
				var slide: Vector3 = piece.velocity
				slide = slide.move_toward(Vector3.ZERO, 6.0 * delta)
				node.global_position += slide * delta
				node.rotation.x = lerp_angle(node.rotation.x, -PI * 0.5, minf(1.0, delta * 9.0))
				node.rotation.z = lerp_angle(node.rotation.z, 0.0, minf(1.0, delta * 5.0))
				piece.velocity = slide
				piece.rest = float(piece.rest) + delta
				if slide.length() < 0.02:
					piece.state = "rest"
			"rest":
				piece.rest = float(piece.rest) + delta
				if float(piece.rest) > rest_seconds:
					node.transparency = clampf((float(piece.rest) - rest_seconds) / fade_seconds, 0.0, 1.0)
					if node.transparency >= 1.0:
						node.queue_free()
	if alive == 0:
		queue_free()
