extends Node3D
## "Whose turn" marker: a red lacquered, brass-trimmed arrow that hangs above the
## active card, bobbing and slowly turning. A real lit 3D object (not an overlay),
## built from primitives so it needs no art assets. Presentation only.

const RED := Color(0.80, 0.07, 0.05)
const BRASS := Color(0.88, 0.67, 0.26)
const BOB_HEIGHT := 0.10
const BOB_SPEED := 2.4
const TURN_SPEED := 0.9

var body: Node3D
var _time: float = 0.0


func _ready() -> void:
	build()


func build() -> void:
	if body:
		return
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var red: StandardMaterial3D = _material(RED, 0.15, 0.30)
	var brass: StandardMaterial3D = _material(BRASS, 0.85, 0.28)
	brass.emission_enabled = true
	brass.emission = Color(0.30, 0.20, 0.05)
	# Four-sided lacquered head pointing down; its apex sits at the node origin.
	var head := CylinderMesh.new()
	head.top_radius = 0.30
	head.bottom_radius = 0.0
	head.height = 0.62
	head.radial_segments = 4
	head.rings = 1
	_add(head, red, Vector3(0.0, 0.31, 0.0), 45.0, "Head")
	# Brass trim plate under the lacquer, slightly wider than the head.
	var plate := CylinderMesh.new()
	plate.top_radius = 0.36
	plate.bottom_radius = 0.36
	plate.height = 0.07
	plate.radial_segments = 4
	_add(plate, brass, Vector3(0.0, 0.645, 0.0), 45.0, "TrimPlate")
	# Neck collar, ring and finial: the brass ornament on top.
	var collar := CylinderMesh.new()
	collar.top_radius = 0.09
	collar.bottom_radius = 0.12
	collar.height = 0.24
	collar.radial_segments = 10
	_add(collar, brass, Vector3(0.0, 0.80, 0.0), 0.0, "Collar")
	var ring := TorusMesh.new()
	ring.inner_radius = 0.10
	ring.outer_radius = 0.17
	ring.rings = 14
	ring.ring_segments = 8
	_add(ring, brass, Vector3(0.0, 0.84, 0.0), 0.0, "Ring")
	var finial := SphereMesh.new()
	finial.radius = 0.13
	finial.height = 0.26
	finial.radial_segments = 14
	finial.rings = 8
	_add(finial, brass, Vector3(0.0, 1.02, 0.0), 0.0, "Finial")


func _process(delta: float) -> void:
	_time += delta
	if body:
		body.position.y = sin(_time * BOB_SPEED) * BOB_HEIGHT
		body.rotation.y += delta * TURN_SPEED


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _add(mesh: Mesh, material: Material, offset: Vector3, yaw_degrees: float, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	instance.rotation_degrees.y = yaw_degrees
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(instance)
