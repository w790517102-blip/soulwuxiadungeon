# 掛在 system_menu.tscn 的 Panel 根節點上的腳本
extends Panel

func _ready():
	# ✅ Godot 4 正確用法，Control 沒有 pause_mode，這裡不能設！
	# 所以這行我們移除：pause_mode = Node.PAUSE_MODE_PROCESS ❌

	# ✅ 抓焦點與接收輸入
	focus_mode = Control.FOCUS_ALL
	grab_focus()

	# ✅ 這邊開啟輸入處理
	set_process_unhandled_input(true)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		# 嘗試關閉選單（呼叫 Global 單例）
		if has_node("/root/GlobalSystemMenu"):
			var controller = get_node("/root/GlobalSystemMenu")
			if controller.has_method("_close_system_menu"):
				controller._close_system_menu()
