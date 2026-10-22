extends Node

@onready var system_menu_scene := preload("res://scenes/system_menu.tscn")
var system_menu_instance: Control = null

const GAME_ROOT_PATH := "/root/GameRoot"
const UI_ROOT_NAME := "UIRoot"
const UI_ROOT_LAYER := 1000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)

func _unhandled_input(event):
	if GlobalState and bool(GlobalState.get_meta("menu_locked", false)):
		return
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
	system_menu_instance.set_process_unhandled_input(true)
	system_menu_instance.grab_focus()
	print(
		"[SystemMenuDebug]",
		" scene_file=", system_menu_instance.scene_file_path,
		" path=", system_menu_instance.get_path(),
		" parent=", parent.get_path(),
		" position=", system_menu_instance.position,
		" global_position=", system_menu_instance.global_position,
		" size=", system_menu_instance.size,
		" scale=", system_menu_instance.scale
	)

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
			(ui_root as CanvasLayer).layer = UI_ROOT_LAYER
			game_root.add_child(ui_root)
		elif ui_root is CanvasLayer:
			(ui_root as CanvasLayer).layer = UI_ROOT_LAYER
		return ui_root
	return get_tree().root

func close_menu_if_open() -> void:
	_close_system_menu()

func _can_open_menu_now() -> bool:
	if GlobalState and GlobalState.get("is_loading") == true:
		return false
	var liu_yu = get_node_or_null("/root/GameRoot/LiuYu")
	if liu_yu and liu_yu.get("can_move") != null and bool(liu_yu.get("can_move")) == false:
		return false
	return true

## 從遊戲內回到主選單：關掉選單、解除暫停、收掉 GameRoot，切到主選單場景。
## 全域狀態不在這裡重設：主選單「開始遊戲」會還原成新遊戲起始狀態（SaveManager.reset_to_new_game_state），讀檔則整份覆蓋。
func return_to_title() -> void:
	_close_system_menu()
	if GlobalState:
		GlobalState.set_meta("menu_locked", false)
		GlobalState.set_meta("menu_open", false)
	get_tree().paused = false
	var gr := get_node_or_null(GAME_ROOT_PATH)
	if gr != null and get_tree().current_scene != gr:
		gr.queue_free()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
