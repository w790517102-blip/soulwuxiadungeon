extends SceneTree

# 裝備頁：載入、八個裝備欄顯示、換裝／卸下（含「前 → 後」變化量）、可選清單的過濾、鎖定欄、特殊效果區可捲動。
# 執行：godot --headless --path . --script tests/test_equipment_page.gd

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
	var page = load("res://scripts/inventory/EquipmentPage.gd").new()
	page.menu = menu
	root.add_child(page)
	await process_frame
	await process_frame
	page._refresh()

	_check(page.actor_id == "liuyu", "starts on 劉語塵")
	_check(page._slot_buttons.size() == 8, "eight slot buttons")
	var weapon_name := (page._slot_buttons["weapon_1"].get_node("ItemName") as Label).text
	_check(weapon_name == "青銅劍", "main weapon slot shows the bronze sword (got %s)" % weapon_name)
	_check((page._slot_buttons["armor_head"].get_node("ItemName") as Label).text == "布帽", "head slot shows the cloth cap")
	_check((page._slot_buttons["mechanism"].get_node("ItemName") as Label).text == "無", "empty mechanism slot shows 無")
	_check((page._slot_buttons["weapon_2"].get_node("ItemName") as Label).text == "空手", "empty sub weapon shows 空手")
	_check(page._info_vals[0].text == "劍類兵器" and page._info_vals[1].text == "主武器" and page._info_vals[2].text == "劉語塵", "detail shows category, slot, wearer")

	# 候選清單：主武器欄只列得到劉語塵能用的劍（鐵劍），不含琴、短刀
	page._on_slot_pressed("weapon_1")
	var candidates: Array = page._candidates()
	_check(candidates.has("iron_sword") and not candidates.has("yaoqin") and not candidates.has("wep_short_blade"), "weapon candidates follow the actor's weapon rules")

	# 換裝：鐵劍攻擊 -1、速度 -1，顯示前 → 後與變化量，換回來再還原
	page._apply_equip("iron_sword")
	_check(inv.get_equipped("liuyu").get("weapon_1") == "iron_sword", "iron sword is now equipped")
	_check(inv.has_item("bronze_sword"), "the bronze sword went back to the bag")
	var atk_row := {}
	for row: Dictionary in page._last_change.get("rows", []):
		if row["key"] == "atk":
			atk_row = row
	_check(not atk_row.is_empty() and int(atk_row["before"]) == 30 and int(atk_row["after"]) == 29 and int(atk_row["delta"]) == -1, "change rows record 30 → 29 (-1)")
	var shown := false
	for c in page._stat_holder.get_children():
		if c is Label and (c as Label).text == "-1":
			shown = true
	_check(shown, "the change amount is shown on the page")
	page._on_slot_pressed("armor_body")
	_check(page._last_change.is_empty(), "choosing another slot clears the change display")
	page._on_slot_pressed("weapon_1")
	page._apply_equip("bronze_sword")
	_check(inv.get_equipped("liuyu").get("weapon_1") == "bronze_sword", "swapped back")

	# 卸下
	page._on_slot_pressed("armor_head")
	page._on_unequip_pressed()
	_check(inv.get_equipped("liuyu").get("armor_head") == "", "cap taken off")
	_check(inv.has_item("arm_cloth_cap"), "cap returned to the bag")
	_check(page._btn_unequip.disabled, "nothing to take off now → 卸下 is disabled")
	page._apply_equip("arm_cloth_cap")

	# 鎖定欄、特殊效果區可捲動
	_check(menu.is_slot_locked_for("shumian", "weapon_2") and not menu.is_slot_locked_for("liuyu", "weapon_2"), "only 書眠's sub weapon is locked")
	_check(page._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "the description / special effect area scrolls (bar only when needed)")

	print("PASS test_equipment_page" if _failures == 0 else "FAILED test_equipment_page: %d" % _failures)
	quit(1 if _failures > 0 else 0)
