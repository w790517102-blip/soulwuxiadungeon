extends SceneTree

# 狀態頁：載入、與裝備頁同一套數值、經驗、直排姓名、八格裝備摘要、切換角色。
# 執行：godot --headless --path . --script tests/test_status_page.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


func _run() -> void:
	await process_frame
	var inv = root.get_node("InventorySync")
	var menu = load("res://scripts/system_menu.gd").new()
	root.add_child(menu)
	var page = load("res://scripts/inventory/StatusPage.gd").new()
	page.menu = menu
	root.add_child(page)
	await process_frame
	await process_frame
	page._refresh()

	_check(page.actor_id == "liuyu", "starts on 劉語塵")
	var team = root.get_node("TeamData")
	var actor: Dictionary = team.get_character_by_id("liuyu")
	var stats: Dictionary = menu.compute_overview_stats(actor, inv.get_equipment_stat_bonus("liuyu"))
	_check(page._stat_labels["atk"].text == str(int(stats["atk"])) and page._stat_labels["def"].text == str(int(stats["def"])), "attack and defence use the shared formula")
	_check(page._stat_labels["crit"].text.ends_with("%"), "crit is a percentage")
	for key in ["str", "agi", "int", "con", "luck"]:
		_check(page._stat_labels[key].text == str(int(stats[key])), "trait %s uses the shared formula" % key)
	_check(page._level_label.text == str(int(actor.get("level", 1))), "level shown")
	_check(page._exp_label.text == "%d / %d" % [int(actor.get("exp", 0)), int(team.exp_required(int(actor.get("level", 1))))], "experience shown as now / needed")
	_check(not page._stat_labels.has("hp") and not page._stat_labels.has("mp"), "no HP / MP rows on the right (they are on the left cards)")
	# 八格裝備摘要
	_check(page._tiles.size() == 8, "eight summary tiles")
	_check(page._tiles["weapon_1"].get_node("Icon").texture != null and not page._tiles["weapon_1"].get_node("EmptyIcon").visible, "the worn sword fills the main weapon tile")
	_check(page._tiles["armor_feet"].get_node("EmptyIcon").visible, "an empty slot shows the ghost icon")
	_check(page._tiles["weapon_1"].mouse_filter == Control.MOUSE_FILTER_IGNORE, "the summary tiles are display only")
	# 直排姓名：一個字一個 Label
	var chars := []
	for c in page._name_box.get_children():
		if (c as Label).text.length() == 1:
			chars.append((c as Label).text)
	_check("".join(chars).begins_with("劉語塵"), "the name is written vertically, one character per line")
	# 切換角色（書眠有立繪）
	team.unlock_roster("shumian")
	page._refresh()
	page._on_actor_pressed("shumian")
	_check(page.actor_id == "shumian" and page._stat_labels["atk"].text != "", "switching to 書眠 refreshes the page")
	var names := []
	for c in page._name_box.get_children():
		if (c as Label).text.length() == 1:
			names.append((c as Label).text)
	_check("".join(names).begins_with("書眠"), "書眠's name is shown vertically")
	# 穿上東西，摘要跟著變
	page._on_actor_pressed("liuyu")
	inv.equip_item_to_slot("arm_cloth_cap", "armor_head", "liuyu") if inv.has_item("arm_cloth_cap") else null
	inv.equipment_changed.emit()
	_check(page._tiles["armor_head"].get_node("Icon").texture != null, "the summary follows equipment changes")
	print("PASS test_status_page" if _failures == 0 else "FAILED test_status_page: %d" % _failures)
	quit(1 if _failures > 0 else 0)
