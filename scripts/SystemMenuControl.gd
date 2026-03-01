extends Node

@onready var system_menu_scene := preload("res://scenes/system_menu.tscn")
var system_menu_instance: Control = null

const GAME_ROOT_PATH := "/root/GameRoot"
const UI_ROOT_NAME := "UIRoot"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if system_menu_instance:
			_close_system_menu()
		else:
			_open_system_menu()

func _open_system_menu():
	if system_menu_instance:
		return
	if not _can_open_menu_now():
		return
	if SaveManager and SaveManager.has_method("cache_world_thumbnail"):
		await SaveManager.cache_world_thumbnail()
	system_menu_instance = system_menu_scene.instantiate()
	var parent := _resolve_ui_parent()
	parent.add_child(system_menu_instance)
	await get_tree().process_frame
	_center_menu_on_viewport(system_menu_instance)
	system_menu_instance.set_process_unhandled_input(true)
	system_menu_instance.grab_focus()

	system_menu_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true
	GlobalState.set_meta("menu_open", true)

func _close_system_menu():
	if system_menu_instance:
		system_menu_instance.queue_free()
		system_menu_instance = null
		get_tree().paused = false
		GlobalState.set_meta("menu_open", false)

func _resolve_ui_parent() -> Node:
	var game_root := get_node_or_null(GAME_ROOT_PATH)
	if game_root:
		var ui_root = game_root.get_node_or_null(UI_ROOT_NAME)
		if ui_root == null:
			ui_root = CanvasLayer.new()
			ui_root.name = UI_ROOT_NAME
			game_root.add_child(ui_root)
		return ui_root
	return get_tree().root

func _center_menu_on_viewport(menu: Control) -> void:
	if menu == null:
		return

	menu.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	if menu.size == Vector2.ZERO:
		menu.size = menu.get_combined_minimum_size()

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	menu.position = (vp_size - menu.size) * 0.5

func close_menu_if_open() -> void:
	_close_system_menu()

func _can_open_menu_now() -> bool:
	if GlobalState and GlobalState.get("is_loading") == true:
		return false
	var liu_yu = get_node_or_null("/root/GameRoot/LiuYu")
	if liu_yu and liu_yu.get("can_move") != null and bool(liu_yu.get("can_move")) == false:
		return false
	return true
