extends Node

@onready var system_menu_scene := preload("res://scenes/system_menu.tscn")
var system_menu_instance: Control = null

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
	get_tree().root.add_child(system_menu_instance)
	system_menu_instance.set_process_unhandled_input(true)
	system_menu_instance.grab_focus()

	# 🚫 不 pause 遊戲，而是透過旗標或全域鎖定角色輸入
	GlobalState.set_meta("menu_open", true)

func _close_system_menu():
	if system_menu_instance:
		system_menu_instance.queue_free()
		system_menu_instance = null
		GlobalState.set_meta("menu_open", false)
