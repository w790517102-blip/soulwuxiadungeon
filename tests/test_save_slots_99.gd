extends SceneTree
# 用法：Godot --headless --script tests/test_save_slots_99.gd
# 只使用隔離資料夾 user://test_save_99/；絕不碰 user://save/ 的正式存檔。
# 需要先把舊存檔樣本複製到 user://test_chronicle/（slot_02.save、slot_03.save 的副本）才會做「舊存檔相容」檢查，沒有就略過。

var fails := 0

func _expect(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)

func _init() -> void:
	await process_frame
	var sm = root.get_node("SaveManager")
	var folder := "user://test_save_99/"
	DirAccess.make_dir_recursive_absolute(folder)
	sm.save_folder = folder
	sm.invalidate_summary_cache()

	# --- 編號與分頁 ---
	_expect(sm.slot_count() == 99, "slot count is 99")
	_expect(sm._valid_slot(1) and sm._valid_slot(99), "01 and 99 valid")
	_expect(not sm._valid_slot(0) and not sm._valid_slot(100) and not sm._valid_slot(-1), "0, 100, -1 invalid")
	_expect(sm.page_count() == 10, "10 pages")
	for p in 10:
		var n := 0
		for i in sm.SLOTS_PER_PAGE:
			if p * sm.SLOTS_PER_PAGE + i + 1 <= sm.slot_count():
				n += 1
		_expect(n == (10 if p < 9 else 9), "page %d has %d slots" % [p + 1, n])
	_expect(sm._slot_path(5).ends_with("slot_05.save") and sm._slot_path(99).ends_with("slot_99.save"), "slot paths keep the slot_%02d rule")

	# --- 章節文字 ---
	_expect(sm.chapter_text(1) == "第一章" and sm.chapter_text(0) == "章節未記錄" and sm.chapter_text(10) == "第十章", "chapter text")

	# --- 空格 / 存檔 / 備份 / 邊界 ---
	for s in [1, 50, 99]:
		_expect(String(sm.get_slot_summary_cached(s).get("_status")) == "empty", "slot %d starts empty" % s)
	_expect(sm.save_to_slot(5) == true, "save slot 5 ok")
	var s5: Dictionary = sm.get_slot_summary_cached(5)
	_expect(String(s5.get("_status")) == "ok", "slot 5 reads back as ok")
	_expect(int(s5.get("chapter_number")) == 1 and String(s5.get("chapter_text")) == "第一章", "new save records chapter 1 from the formal quest data")
	_expect(not FileAccess.file_exists(sm._slot_backup_path(5)), "first save has no .bak")
	_expect(sm.save_to_slot(5) == true and FileAccess.file_exists(sm._slot_backup_path(5)), "second save creates .bak")
	_expect(sm.save_to_slot(99) == true, "save slot 99 ok")
	_expect(sm.save_to_slot(100) == false and sm.save_to_slot(0) == false, "slots 0 and 100 are refused")
	_expect(not FileAccess.file_exists(folder + "slot_100.save"), "no file written for slot 100")
	_expect(String(sm.get_slot_summary_cached(6).get("_status")) == "empty", "saving 5 does not touch 6")

	# --- 壞檔不可當空格 ---
	var bad := FileAccess.open(sm._slot_path(7), FileAccess.WRITE)
	bad.store_string("this is not a godot variant")
	bad.close()
	var zero := FileAccess.open(sm._slot_path(8), FileAccess.WRITE)
	zero.close()
	sm.invalidate_summary_cache()
	_expect(String(sm.get_slot_summary_cached(7).get("_status")) == "invalid", "garbage file is invalid, not empty")
	_expect(String(sm.get_slot_summary_cached(8).get("_status")) == "invalid", "zero-byte file is invalid, not empty")
	_expect(not bool(sm.check_slot_loadable(7).get("ok")) and not bool(sm.check_slot_loadable(6).get("ok")), "corrupt and empty slots are not loadable")
	_expect(await sm.load_from_slot(7) == false, "load_from_slot on a corrupt file fails safely")
	_expect(root.get_node("GlobalState").is_loading == false, "failed load leaves no loading lock")

	# --- 摘要快取 ---
	var a = sm.get_slot_summary_cached(5)
	var b = sm.get_slot_summary_cached(5)
	_expect(a == b, "cached summary is stable")

	# --- 舊存檔樣本 ---
	var old_dir := "user://test_chronicle/"
	for pair in [["slot_02.save", 2], ["slot_03.save", 3]]:
		var src: String = old_dir + pair[0]
		if FileAccess.file_exists(src):
			var bytes := FileAccess.get_file_as_bytes(src)
			var out := FileAccess.open(sm._slot_path(pair[1] + 10), FileAccess.WRITE)
			out.store_buffer(bytes)
			out.close()
			sm.invalidate_summary_cache()
			var sum: Dictionary = sm.get_slot_summary_cached(pair[1] + 10)
			_expect(String(sum.get("_status")) == "ok", "old save sample %s reads ok" % pair[0])
			_expect(int(sum.get("chapter_number")) == 1, "old save %s gets chapter 1 from its main quest id" % pair[0])
			_expect(bool(sm.check_slot_loadable(pair[1] + 10).get("ok")), "old save %s passes the load pre-check" % pair[0])

	# --- 清掉隔離資料夾 ---
	var d := DirAccess.open(folder)
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(folder)
	sm.save_folder = sm.SAVE_FOLDER
	sm.invalidate_summary_cache()
	print("PASS test_save_slots_99" if fails == 0 else "FAIL test_save_slots_99 failures=%d" % fails)
	quit(1 if fails else 0)
