extends Node3D
## Minimal visual for a stage entity (echo, cover, tarot, token...): a small flat card
## with a name and, when it has HP, a HP line. It is only the DEFAULT; a game system
## registers its own factory per `card_kind` (CardStage3D.entity_card_factories) and may
## return any Node3D that follows the same small contract:
##   home_position, home_rotation, card_size, interaction_priority, refresh(entity).

const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")

var entity: Object
var card_size: Vector2 = Vector2(1.0, 1.4)
var home_position: Vector3 = Vector3.ZERO
var home_rotation: Vector3 = Vector3.ZERO
## Wins a picking tie against another card at the same distance.
var interaction_priority: int = 0
var body: MeshInstance3D
var label: Label3D


func configure(target_entity: Object) -> void:
	entity = target_entity
	var config: Dictionary = entity.get("card_config")
	card_size = config.get("card_size", card_size)
	interaction_priority = int(config.get("interaction_priority", entity.get("priority")))
	if body == null:
		body = MeshInstance3D.new()
		body.name = "Body"
		var quad := QuadMesh.new()
		quad.size = card_size
		body.mesh = quad
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.05, 0.07, 0.1, 0.92)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		body.material_override = material
		add_child(body)
		var border := MeshInstance3D.new()
		var border_mesh := QuadMesh.new()
		border_mesh.size = card_size + Vector2(0.08, 0.08)
		border.mesh = border_mesh
		var border_material := StandardMaterial3D.new()
		border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		border_material.albedo_color = Color("c9a565")
		border_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		border.material_override = border_material
		border.position.z = -0.01
		add_child(border)
		label = Label3D.new()
		label.font = FONT
		label.font_size = 48
		label.pixel_size = 0.0035
		label.outline_size = 8
		label.position.z = 0.01
		label.modulate = Color("eee4ca")
		add_child(label)
	refresh(entity)


func refresh(target_entity: Object) -> void:
	entity = target_entity
	var text: String = String(entity.get("display_name"))
	if text == "":
		text = String(entity.get("entity_type"))
	if int(entity.get("max_hp")) > 0:
		text += "\n%d/%d" % [int(entity.get("current_hp")), int(entity.get("max_hp"))]
	if label:
		label.text = text


func set_home(position_value: Vector3, yaw_degrees: float = 0.0) -> void:
	home_position = position_value
	home_rotation = Vector3(0.0, deg_to_rad(yaw_degrees), 0.0)
	position = home_position
	rotation = home_rotation
