extends Node
## Card Inspect: the pointed card is taken in front of the camera on the left of the screen (nearer, a little larger,
## turned to face the player), the rest of the stage is dimmed and the panel with the details slides in on the right.
## Closing puts the card back in its place. Presentation only: it changes no battle rule and no card position
## (`home_position` is never touched, so the line-up is exactly as it was).

const Formation = preload("res://scripts/presentation/CardStageFormation.gd")
const InspectData = preload("res://scripts/presentation/CardInspectData.gd")
const InspectPanel = preload("res://scripts/presentation/CardInspectPanel.gd")

signal opened(key: String)
signal closed

const FOCUS_FRACTION: float = 0.70       # the card's height as a share of the screen's
const FOCUS_SCREEN_X: float = 0.27       # where on the screen it hangs
const FOCUS_SCREEN_Y: float = 0.47
const DIM_ALPHA: float = 0.62
const MOVE_SECONDS: float = 0.38

var ui: Object = null
var stage: Node3D = null
var panel: PanelContainer = null
var _key: String = ""
var _card: Node3D = null
var _dim: MeshInstance3D = null
var _tween: Tween = null
var _closing: bool = false


func setup(ui_ref: Object, stage_ref: Node3D, hud: Control, font: Font) -> void:
	ui = ui_ref
	stage = stage_ref
	var layer := CanvasLayer.new()
	layer.name = "InspectLayer"
	layer.layer = 60
	add_child(layer)
	panel = InspectPanel.new(font)
	panel.hide()
	layer.add_child(panel)
	panel.close_requested.connect(close)


func is_open() -> bool:
	return _card != null


func current_key() -> String:
	return _key


## Opens the card with this key ("ent:<id>" for a support card, otherwise the actor key). False when there is no
## such card.
func open_key(key: String) -> bool:
	if is_open() or stage == null or panel == null:
		return false
	var data: Dictionary = {}
	var node: Node3D = null
	if key.begins_with("ent:"):
		var entity: Object = _entity_for(key.trim_prefix("ent:"))
		node = stage.entity_cards.get(key.trim_prefix("ent:")) as Node3D
		if entity == null or node == null:
			return false
		data = InspectData.for_entity(ui, entity)
	else:
		var actor: Dictionary = _actor_for(key)
		node = stage.cards.get(key) as Node3D
		if actor.is_empty() or node == null:
			return false
		data = InspectData.for_actor(ui, actor, bool(node.get("is_enemy")))
	_key = key
	_card = node
	_closing = false
	stage.busy = true
	stage._apply_hover("")
	_stop_card_motion(node)
	_make_dim()
	_pull_forward(node)
	panel.show_data(data)
	panel.slide_in(_panel_rect())
	opened.emit(key)
	return true


func close() -> void:
	if not is_open() or _closing:
		return
	_closing = true
	var card: Node3D = _card
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if is_instance_valid(card):
		_tween.tween_property(card, "position", card.home_position, MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(card, "rotation", card.home_rotation, MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if _dim != null:
		var material: StandardMaterial3D = _dim.material_override as StandardMaterial3D
		_tween.tween_property(material, "albedo_color:a", 0.0, MOVE_SECONDS)
	panel.slide_out()
	_tween.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	if is_instance_valid(_card):
		_card.position = _card.home_position
		_card.rotation = _card.home_rotation
	if _dim != null:
		_dim.queue_free()
		_dim = null
	_card = null
	_key = ""
	_closing = false
	if stage != null:
		stage.busy = false
		stage.hover_key = ""
	closed.emit()


## Opening and closing take the card out of whatever it was doing and put it exactly back on its slot.
func _stop_card_motion(card: Node3D) -> void:
	if card.has_method("_kill_motion"):
		card._kill_motion()
	if card.has_method("fan_to"):
		card.fan_to(Vector3.ZERO, 0.0)
	card.position = card.home_position
	card.rotation = card.home_rotation


func _pull_forward(card: Node3D) -> void:
	var camera: Camera3D = stage.camera
	var screen: Vector2 = stage.get_viewport().get_visible_rect().size
	var card_height: float = float(card.card_size.y)
	var distance: float = Formation.distance_for_fraction(card_height, FOCUS_FRACTION, camera.fov)
	var world: Vector3 = camera.project_position(Vector2(screen.x * FOCUS_SCREEN_X, screen.y * FOCUS_SCREEN_Y), distance)
	var local: Vector3 = stage.actor_root.to_local(world)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(card, "position", local, MOVE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "rotation", Vector3.ZERO, MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _dim != null:
		_tween.tween_property((_dim.material_override as StandardMaterial3D), "albedo_color:a", DIM_ALPHA, MOVE_SECONDS)


## A dark sheet across the whole view, behind the pulled card and in front of everything else on the stage.
func _make_dim() -> void:
	var camera: Camera3D = stage.camera
	var screen: Vector2 = stage.get_viewport().get_visible_rect().size
	var card_height: float = float(_card.card_size.y)
	var focus_distance: float = Formation.distance_for_fraction(card_height, FOCUS_FRACTION, camera.fov)
	var dim_distance: float = focus_distance + 0.9
	var visible_height: float = 2.0 * dim_distance * tan(deg_to_rad(camera.fov) / 2.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(visible_height * (screen.x / maxf(screen.y, 1.0)) * 1.4, visible_height * 1.4)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.0, 0.0, 0.02, 0.0)
	_dim = MeshInstance3D.new()
	_dim.name = "InspectDim"
	_dim.mesh = quad
	_dim.material_override = material
	_dim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(_dim)
	var basis: Basis = camera.global_transform.basis
	_dim.global_transform = Transform3D(basis, camera.global_position - basis.z * dim_distance)


func _panel_rect() -> Rect2:
	var screen: Vector2 = stage.get_viewport().get_visible_rect().size
	var left: float = screen.x * 0.50
	return Rect2(left, 36.0, screen.x - left - 28.0, screen.y - 36.0 - 150.0)


func _entity_for(entity_id: String) -> Object:
	var controller: Object = ui.get("combat_controller") as Object
	if controller == null or controller.get("stage_entities") == null:
		return null
	return controller.stage_entities.get_entity(entity_id)


func _actor_for(key: String) -> Dictionary:
	var pool: Array = []
	pool.append_array(ui.get("allies"))
	pool.append_array(ui.get("enemies"))
	var controller: Object = ui.get("combat_controller") as Object
	if controller != null and controller.get("turn_manager") != null and not (controller.turn_manager.guest_actor as Dictionary).is_empty():
		pool.append(controller.turn_manager.guest_actor)
	for actor: Variant in pool:
		if typeof(actor) == TYPE_DICTIONARY and stage.actor_key(actor) == key:
			return actor
	return {}
