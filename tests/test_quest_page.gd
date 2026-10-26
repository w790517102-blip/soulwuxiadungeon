extends SceneTree

# 任務頁：分類（主線／支線／已完成）、清單、詳情、已錯過歸在已完成。
# 執行：godot --headless --path . --script tests/test_quest_page.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


func _run() -> void:
	await process_frame
	var sq = root.get_node("SideQuestManager")
	sq.side_quests.clear()
	sq.register_quest("tq_active", {"title": "進行中的支線", "description": "描述甲", "current_objective": "目標甲", "notes": ["筆記一"]})
	sq.register_quest("tq_done", {"title": "完成的支線", "description": "描述乙", "current_objective": "目標乙"})
	sq.complete_quest("tq_done")
	sq.register_quest("tq_missed", {"title": "錯過的支線", "description": "描述丙", "current_objective": "目標丙"})
	sq.mark_quest_missed("tq_missed")
	var menu = load("res://scripts/system_menu.gd").new()
	root.add_child(menu)
	var page = load("res://scripts/inventory/QuestPage.gd").new()
	page.menu = menu
	root.add_child(page)
	await process_frame
	await process_frame
	page._refresh()

	_check(page.category == "主線", "starts on the main-quest category")
	page._on_category_pressed("支線")
	_check(page._shown.size() == 1 and page.selected_id == "tq_active", "side category lists only the active side quest")
	_check(page._title_label.text == "進行中的支線" and page._goal_text.text == "目標甲", "detail shows title and objective")
	_check(page._note_text.text.contains("筆記一"), "detail shows the notes")
	_check(page._status_label.text == "進行中", "status stamp says in progress")
	page._on_category_pressed("已完成")
	_check(page._shown.size() == 2, "finished category holds the finished and the missed quest")
	page._on_row_pressed("tq_missed")
	_check(page._status_label.text == "已錯過" and page._seal_label.text == "支線", "missed quest shows its status and type")
	page._on_category_pressed("支線")
	_check(page._shown.size() == 1, "missed quests are not listed under side quests")
	sq.side_quests.clear()
	page._refresh()
	page._on_category_pressed("支線")
	_check(page._shown.is_empty() and page._empty_label.visible, "an empty category shows the empty state")

	print("PASS: quest page" if _failures == 0 else "FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
