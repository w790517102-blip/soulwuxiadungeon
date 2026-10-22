extends SceneTree

# 見聞頁（三本書）：開書、翻頁（含快速跳過未收錄）、末頁提示、目錄、收書。
# 執行：godot --headless --path . --script tests/test_lore_page.gd

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)

func _run() -> void:
	await process_frame
	var menu = load("res://scripts/system_menu.gd").new()
	root.add_child(menu)
	var page = load("res://scripts/inventory/LorePage.gd").new()
	page.menu = menu
	root.add_child(page)
	await process_frame
	await process_frame
	var Entries = load("res://scripts/inventory/LoreEntries.gd")
	for cat in Entries.CATEGORIES:
		var list: Array = Entries.entries(cat)
		_check(list.size() > 0, "%s has entries" % cat)
		for e in list:
			if not bool(e["unlocked"]):
				_check(String(e["name"]) == Entries.UNKNOWN, "%s locked entries are ？？？" % cat)
				break
	_check(page.mode == "shelf", "starts on the shelf")
	page.open_book("豪傑")
	await create_timer(2.6).timeout
	_check(page.mode == "book" and not page._busy, "the book opens")
	_check(page._spread == Entries.first_unlocked(page._list), "it opens at the first collected entry")
	var s0: int = page._spread
	page._turn(1)
	await create_timer(1.6).timeout
	_check(page._spread >= s0 and not page._busy, "a forward turn lands on a valid spread or stays")
	page._go(page._list.size())
	await create_timer(2.5).timeout
	_check(page._spread == page._list.size(), "jumping to the end works")
	page._turn(1)
	await create_timer(0.3).timeout
	_check(page._overlay.visible, "turning past the last page shows the notice")
	page._close_overlay()
	page.close_book()
	await create_timer(2.2).timeout
	_check(page.mode == "shelf" and not page._busy, "closing the book returns to the shelf")
	print("PASS test_lore_page" if _failures == 0 else "FAILED test_lore_page: %d" % _failures)
	quit(1 if _failures > 0 else 0)
