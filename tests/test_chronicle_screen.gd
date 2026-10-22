extends SceneTree

# 《江湖行跡錄》畫面：開啟、選格、翻頁、確認視窗開關；不寫入任何存檔。
# 執行：godot --headless --path . --script tests/test_chronicle_screen.gd

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)

func _run() -> void:
	await process_frame
	var CS = load("res://scripts/chronicle/ChronicleScreen.gd")
	var s = CS.open(root, CS.Mode.SAVE)
	await process_frame
	await process_frame
	_check(s._items.size() == root.get_node("SaveManager").SLOTS_PER_PAGE, "ten slots per page")
	_check(s.selected_slot == 1 and s.page == 0, "starts on slot 1, page 1")
	s._on_item_pressed(s._items[2])
	_check(s.selected_slot == 3, "clicking a slot selects it")
	s._change_page(1)
	_check(s.page == 1 and s.selected_slot == 11, "next page selects the first slot of that page")
	s._change_page(-1)
	_check(s.page == 0, "previous page")
	s._show_confirm("測試", "內容", "確認", func(): pass)
	_check(s._overlay.visible, "the confirm window opens")
	s._hide_confirm()
	_check(not s._overlay.visible, "the confirm window closes")
	var closed := [false]
	s.closed.connect(func(): closed[0] = true)
	s.close()
	_check(closed[0], "close() emits closed")
	print("PASS test_chronicle_screen" if _failures == 0 else "FAILED test_chronicle_screen: %d" % _failures)
	quit(1 if _failures > 0 else 0)
