extends Node

@onready var system_menu_scene := preload("res://scenes/system_menu.tscn")
var system_menu_instance: Control = null

const GAME_ROOT_PATH := "/root/GameRoot"
const UI_ROOT_NAME := "UIRoot"

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if system_menu_instance:
			_close_system_menu()
		else:
			_open_system_menu()

func _open_system_menu():
	if system_menu_instance:
		return
	system_menu_instance = system_menu_scene.instantiate()
	var parent := _resolve_ui_parent()
	parent.add_child(system_menu_instance)
	await get_tree().process_frame
	_center_menu_on_viewport(system_menu_instance)
	system_menu_instance.set_process_unhandled_input(true)
	system_menu_instance.grab_focus()

	# 🚫 不 pause 遊戲，而是透過旗標或全域鎖定角色輸入
	GlobalState.set_meta("menu_open", true)

func _close_system_menu():
	if system_menu_instance:
		system_menu_instance.queue_free()
		system_menu_instance = null
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
