extends Node2D
class_name GuqinInteractable

@export var interact_action := "interact"
@export var manager_path: NodePath

@onready var interact_area: Area2D = $Area2D

var player_inside := false
var interaction_locked := false
var manager: MusicRoomManager
var player_ref: Node = null


func _ready() -> void:
	manager = _resolve_manager()

	if interact_area:
		if not interact_area.body_entered.is_connected(_on_body_entered):
			interact_area.body_entered.connect(_on_body_entered)
		if not interact_area.body_exited.is_connected(_on_body_exited):
			interact_area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or interaction_locked or _is_world_interaction_blocked():
		return
	if not _is_interact_event(event):
		return

	get_viewport().set_input_as_handled()
	interact()


func interact() -> void:
	if manager == null:
		manager = _resolve_manager()

	if manager == null:
		push_warning("GuqinInteractable 找不到 MusicRoomManager")
		return

	interaction_locked = true
	var restore_movement := _is_player_movable()
	if restore_movement:
		_set_player_movable(false)

	await manager.inspect_qin(self)

	if restore_movement:
		_set_player_movable(true)
	interaction_locked = false


func _on_body_entered(body: Node) -> void:
	if _is_player(body):
		player_inside = true
		player_ref = body


func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		player_inside = false
		if player_ref == body:
			player_ref = null


func _is_player(body: Node) -> bool:
	return body.name == "Player" or body.name == "LiuYu" or body.is_in_group("player")


func _is_interact_event(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event and key_event.echo:
		return false
	if InputMap.has_action(interact_action) and event.is_action_pressed(interact_action):
		return true
	return key_event != null and key_event.pressed and key_event.keycode == KEY_SPACE


func _is_world_interaction_blocked() -> bool:
	var dialog_manager := _get_dialog_manager()
	if dialog_manager == null:
		return false
	if bool(dialog_manager.get("dialog_active")):
		return true
	var choice_box = dialog_manager.get("choice_box")
	if choice_box is CanvasItem:
		# 空的 ChoiceBox 不是 active choice；只有實際存在選項時才阻擋。
		return bool(choice_box.visible) and choice_box.get_child_count() > 0
	return false


func _get_dialog_manager() -> Node:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager:
		return dialog_manager
	return get_node_or_null("/root/DialogManager")


func _set_player_movable(value: bool) -> void:
	var target := _resolve_player()
	if target:
		target.set("can_move", value)


func _is_player_movable() -> bool:
	var target := _resolve_player()
	return target != null and bool(target.get("can_move"))


func _resolve_player() -> Node:
	var target := player_ref
	if target == null:
		target = get_node_or_null("/root/GameRoot/LiuYu")
	if target == null:
		target = get_node_or_null("/root/Player")
	return target


func _resolve_manager() -> MusicRoomManager:
	if manager_path != NodePath():
		var node := get_node_or_null(manager_path)
		if node is MusicRoomManager:
			return node

	var parent := get_parent()
	while parent:
		var found := parent.get_node_or_null("MusicRoomManager")
		if found is MusicRoomManager:
			return found

		parent = parent.get_parent()

	return null
