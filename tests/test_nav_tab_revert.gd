extends SceneTree

# 導航標籤：按下別的標籤的瞬間，這一頁原本選中的（紅）標籤立刻變回一般。
# 執行：godot --headless --path . --script tests/test_nav_tab_revert.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var page = load("res://scripts/inventory/StatusPage.gd").new()
	root.add_child(page)
	await process_frame
	var btns: Array = []
	for c in page.get_children():
		if c is Button and c.text in ["狀態", "道具", "裝備"]:
			btns.append(c)
	var status_btn: Button
	var equip_btn: Button
	for b in btns:
		if b.text == "狀態": status_btn = b
		if b.text == "裝備": equip_btn = b
	var ok := status_btn != null and equip_btn != null
	if ok:
		var before: StyleBox = status_btn.get_theme_stylebox("normal")
		equip_btn.button_down.emit()
		var after: StyleBox = status_btn.get_theme_stylebox("normal")
		ok = before != after
		if not ok:
			print("FAIL the selected tab did not revert on mouse down")
	print("PASS test_nav_tab_revert" if ok else "FAILED test_nav_tab_revert")
	quit(0 if ok else 1)
