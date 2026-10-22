extends SceneTree

# 開系統選單時，先停在「狀態」分頁，且新狀態頁已顯示。
# 執行：godot --headless --path . --script tests/test_menu_initial_tab.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var menu = load("res://scenes/system_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var ok: bool = menu.tabs.current_tab == menu.get_node("VBoxContainer/狀態").get_index()
	var shown: bool = menu._status_page != null and menu._status_page.visible
	if not ok:
		print("FAIL initial tab is not 狀態: ", menu.tabs.current_tab)
	if not shown:
		print("FAIL the new status page is not visible at open")
	print("PASS test_menu_initial_tab" if ok and shown else "FAILED test_menu_initial_tab")
	quit(0 if ok and shown else 1)
