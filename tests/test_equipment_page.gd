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
	_check(page._slot_buttons["weapon_1"].get_node("Icon").texture != null and not page._slot_buttons["weapon_1"].get_node("EmptyIcon").visible, "main weapon slot shows the equipped item icon and hides the ghost")
	_check(page._slot_buttons["armor_head"].get_node("Icon").texture != null and not page._slot_buttons["armor_head"].get_node("EmptyIcon").visible, "head slot shows the cloth cap icon")
	_check(page._slot_buttons["mechanism"].get_node("Icon").texture == null and page._slot_buttons["mechanism"].get_node("EmptyIcon").visible, "empty mechanism slot shows the gray ghost only")
	_check(not page._slot_buttons["mechanism"].has_node("ItemName"), "slots do not print the item name (the right page shows it)")
	_check(page._slot_buttons["weapon_2"].get_node("EmptyIcon").visible, "empty sub weapon shows the gray ghost")
	# 八格的部位名稱統一字大小：每個字（邏輯 px）都相同
	var char_sizes: Array = []
	for slot_id in page._slot_buttons.keys():
		var pl: TextureRect = page._slot_buttons[slot_id].get_node("PartLabel")
		var chars: int = page.SLOT_LABEL_CHARS[page._empty_icon_name(slot_id)]
		char_sizes.append(snappedf(pl.size.x / chars, 0.1))
	_check(char_sizes.min() == char_sizes.max(), "all eight part names have the same character size (got %s)" % str(char_sizes))
	_check(page._info_vals[0].text == "劍類兵器" and page._info_vals[1].text == "主武器" and page._info_vals[2].text == "劉語塵", "detail shows category, slot, wearer")

	# 候選清單：主武器欄只列得到劉語塵能用的劍（鐵劍），不含琴、短刀
	page._on_slot_pressed("weapon_1")
	var candidates: Array = page._candidates()
	_check(candidates.has("iron_sword") and not candidates.has("yaoqin") and not candidates.has("wep_short_blade"), "weapon candidates follow the actor's weapon rules")

	# 詳情只顯示這件裝備自己的加成（青銅劍：攻擊 +4、速度 +1），不顯示換裝前後的總值
	var shown_texts: Array = []
	for c in page._stat_holder.get_children():
		if c is Label:
			shown_texts.append((c as Label).text)
	_check(shown_texts.has("攻擊") and shown_texts.has("+4") and shown_texts.has("速度") and shown_texts.has("+1"), "detail lists the item's own bonuses (+4 attack, +1 speed)")
	_check(not shown_texts.has("→"), "no before-after arrows on the main detail")

	# 更換裝備的視窗才顯示變化：鐵劍 攻擊 30 → 29（-1）、速度 14 → 13（-1）
	page._on_change_pressed()
	var popup_texts: Array = []
	for c in page._pick_compare.get_children():
		if c is Label:
			popup_texts.append((c as Label).text)
	_check(page._overlay.visible and popup_texts.has("29") and popup_texts.has("-1") and popup_texts.has("→"), "the swap window shows 30 → 29 (-1)")
	page._close_overlay()
	var rows: Array = page._candidates()
	_check(rows.has("iron_sword"), "iron sword is a candidate")
	page._apply_equip("iron_sword")
	_check(inv.get_equipped("liuyu").get("weapon_1") == "iron_sword", "iron sword is now equipped")
	_check(inv.has_item("bronze_sword"), "the bronze sword went back to the bag")
	var shown_after: Array = []
	for c in page._stat_holder.get_children():
		if c is Label:
			shown_after.append((c as Label).text)
	_check(shown_after.has("+3") and not shown_after.has("→"), "after the swap the detail shows the new item's own +3 only")
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

	# 紙面兩版：預設是共邊國原檔；備案是泛黃後製版（開關 use_aged_equipment_paper）
	var plain_tex: Texture2D = page._tex("equipment/equip_scroll_complete")
	page.use_aged_equipment_paper = true
	var aged_tex: Texture2D = page._tex("equipment/equip_scroll_complete")
	page.use_aged_equipment_paper = false
	_check(plain_tex != null and aged_tex != null and plain_tex.resource_path != aged_tex.resource_path, "the aged paper is a separate backup version of the scroll")
	_check(plain_tex.resource_path.contains("/equipment/") and aged_tex.resource_path.contains("equipment_aged"), "default is the original, the backup lives in equipment_aged")
	# 紙娃娃：身體護具依稀有度換圖，沒有該階的圖退回凡品；武器退回預設；機關沒裝備就不顯示
	_check(page._doll.has_figure() and page.doll_info.get("mode") == "master", "cloth clothes (common) show the whole master figure")
	_check(page.doll_info.get("weapon_art") == "default", "the sword uses the default weapon layers (no art of its own)")
	_check(page.doll_info.get("body_rarity") == 1, "cloth clothes are common (rarity 1)")
	page._on_slot_pressed("armor_body")
	page._apply_equip("arm_rare_clothes")
	_check(inv.get_equipped("liuyu").get("armor_body") == "arm_rare_clothes", "the rare clothes are worn")
	_check(page.doll_info.get("body_rarity") == 3 and page.doll_info.get("mode") == "whole" and page.doll_info.get("body_art") == "r3_whole", "the rare clothes (rarity 3) show the third-tier whole figure (bracer)")
	_check(page._doll.get_node("master").texture != null and page._doll.get_node("body").texture == null, "a whole figure uses the master layer only, no stale clothing layers")
	page._apply_equip("arm_fine_clothes")
	_check(page.doll_info.get("body_rarity") == 2 and page.doll_info.get("body_art") == "r2_whole", "the fine clothes (rarity 2) show the second-tier whole figure (no bracer)")
	_check(page._doll.get_node("master").offset_left != 0.0 and absf(page._doll.get_node("master").offset_left + 14.85) < 0.5, "tier 2/3 whole figures are shifted so the eyes line up with the master")
	page._apply_equip("arm_legend_clothes")
	_check(page._doll.get_node("master").offset_left == 0.0 or page.doll_info.get("mode") == "tiered", "the shift only applies to whole-figure tiers")
	_check(page.doll_info.get("body_rarity") == 4 and page.doll_info.get("mode") == "tiered" and page.doll_info.get("body_art") == "doll_liuyu_r4", "the legend clothes (rarity 4) show the layered fourth-tier set")
	_check(page._doll.get_node("body").texture != null and page._doll.get_node("front").texture != null and page._doll.get_node("master").texture == null, "the four clothing layers are shown together and the master is hidden")
	_check(page._doll.get_node("back").get_index() < page._doll.get_node("body").get_index() and page._doll.get_node("front").get_index() < page._doll.get_node("weapon_back").get_index() and page._doll.get_node("weapon_back").get_index() < page._doll.get_node("weapon_front").get_index(), "layered order: back at the bottom, the sword layers on top of all clothing")
	_check(page.doll_info.get("mech_art") == "", "no mechanism equipped → no mechanism layer")
	page._apply_equip("arm_cloth")
	_check(page.doll_info.get("body_rarity") == 1 and page.doll_info.get("mode") == "master" and page._doll.get_node("body").texture == null, "back to cloth clothes: the whole master figure again, no stale layers")
	# 機關：裝上諸葛連弩，三個機關層一起出現；卸下就消失
	page._on_slot_pressed("mechanism")
	inv.party_inventory.append({"id": "tool_zhuge_crossbow", "count": 1})
	page._apply_equip("tool_zhuge_crossbow")
	_check(page.doll_info.get("mech_art") == "tool_zhuge_crossbow" and page._doll.get_node("mech").texture != null and page._doll.get_node("strap").texture != null, "the crossbow and its strap are two full-canvas layers")
	_check(page._doll.get_node("master").get_index() < page._doll.get_node("strap").get_index() and page._doll.get_node("strap").get_index() < page._doll.get_node("mech").get_index() and page._doll.get_node("mech").get_index() < page._doll.get_node("weapon_back").get_index(), "order: clothing, then strap, then crossbow, then the sword on top")
	page._on_unequip_pressed()
	_check(page.doll_info.get("mech_art") == "" and page._doll.get_node("mech").texture == null and page._doll.get_node("strap").texture == null, "taking the crossbow off hides the crossbow and the strap")
	# 書眠：筆拿在手上，不畫紙娃娃的武器層（不能憑空背一把劍）；連弩有她自己的微調
	var shu: Dictionary = page._doll.show_actor("shumian")
	_check(shu.get("mode") == "master" and shu.get("art_rarity") == 1 and shu.get("weapon_art") == "", "書眠 in plain clothes shows her first-tier figure, and no sword layers for the brush")
	for pair in [["arm_fine_clothes", 2], ["arm_rare_clothes", 3], ["arm_legend_clothes", 4]]:
		inv.equip_item_to_slot(pair[0], "armor_body", "shumian")
		var tier: Dictionary = page._doll.show_actor("shumian")
		_check(tier.get("art_rarity") == pair[1], "書眠 wearing rarity %d shows her tier-%d figure" % [pair[1], pair[1]])
	inv.unequip("armor_body", "shumian")
	page._doll.show_actor("shumian")
	_check(page._doll.get_node("weapon_back").texture == null and page._doll.get_node("weapon_front").texture == null, "no weapon layers for a brush")
	page._doll.show_actor("liuyu")
	# 鎖定欄、特殊效果區可捲動
	_check(menu.is_slot_locked_for("shumian", "weapon_2") and not menu.is_slot_locked_for("liuyu", "weapon_2"), "only 書眠's sub weapon is locked")
	_check(page._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "the description / special effect area scrolls (bar only when needed)")

	print("PASS test_equipment_page" if _failures == 0 else "FAILED test_equipment_page: %d" % _failures)
	quit(1 if _failures > 0 else 0)
