extends SceneTree

# 道具「整理」：先依種類；裝備再依部位、稀有度（高的在前）、名稱筆劃（少的在前）；其他依 id。
# 執行：godot --headless --path . --script tests/test_inventory_sort.gd

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
	var DB = load("res://scripts/db/ItemDB.gd")
	var backup: Array = inv.party_inventory.duplicate(true)

	# 1. 種類順序（沒有資料庫資料的假道具退回看列本身的 type）
	inv.party_inventory = [
		{"id": "z_other", "type": "tool"},
		{"id": "b_quest", "type": "quest"},
		{"id": "c_book", "type": "book"},
		{"id": "d_mat", "type": "material"},
		{"id": "e_drug_b", "type": "consumable"},
		{"id": "a_equip", "type": "equipment"},
		{"id": "e_drug_a", "type": "consumable"},
		{"id": "f_food", "type": "food"},
	]
	inv.sort_inventory()
	var ids: Array = []
	for it in inv.party_inventory:
		ids.append(String(it["id"]))
	_check(ids == ["e_drug_a", "e_drug_b", "f_food", "c_book", "a_equip", "d_mat", "b_quest", "z_other"], "category order, then id: %s" % str(ids))

	# 2. 裝備：部位 → 稀有度（高在前）→ 名稱筆劃（少在前）；用真實的道具資料
	var equip_ids: Array = []
	for id in DB.ITEM_DEFS.keys():
		if ItemCategory.category_of(DB.ITEM_DEFS[id]) == ItemCategory.EQUIPMENT:
			equip_ids.append(String(id))
	inv.party_inventory = []
	for id in equip_ids:
		inv.party_inventory.append({"id": id, "count": 1})
	inv.party_inventory.reverse()
	inv.sort_inventory()
	var order := ["weapon_1", "weapon_2", "armor_head", "armor_body", "armor_hands", "armor_feet", "accessory_1", "mechanism"]
	var last_slot := -1
	var last_rarity := 99
	var last_name := ""
	var strokes = load("res://scripts/items/StrokeTable.gd")
	for it in inv.party_inventory:
		var def: Dictionary = DB.get_def(String(it["id"]))
		var slot := order.find(String(def.get("equip_slot", "")))
		var rarity := int(def.get("rarity", 1))
		var nm := String(def.get("name", ""))
		if slot != last_slot:
			_check(slot > last_slot, "slots are in order at %s" % nm)
			last_slot = slot
			last_rarity = 99
			last_name = ""
		_check(rarity <= last_rarity, "rarity goes high to low inside a slot at %s" % nm)
		if rarity == last_rarity and last_name != "":
			_check(strokes.compare(last_name, nm) <= 0, "equal rarity goes by name strokes: %s then %s" % [last_name, nm])
		last_rarity = rarity
		last_name = nm

	# 2b. 反向：稀有度低的在前（整理第二下）；部位順序不變
	inv.sort_inventory(false)
	var prev_slot := -1
	var prev_rarity := 0
	for it in inv.party_inventory:
		var def: Dictionary = DB.get_def(String(it["id"]))
		var slot := order.find(String(def.get("equip_slot", "")))
		var rarity := int(def.get("rarity", 1))
		if slot != prev_slot:
			_check(slot > prev_slot, "reverse sort keeps the slot order")
			prev_slot = slot
			prev_rarity = 0
		_check(rarity >= prev_rarity, "reverse sort puts low rarity first inside a slot")
		prev_rarity = rarity

	# 2c. 道具頁：按「整理」輪流切換方向；頁面被隱藏就重置
	var menu = load("res://scripts/system_menu.gd").new()
	root.add_child(menu)
	var page = load("res://scripts/inventory/InventoryPage.gd").new()
	page.menu = menu
	root.add_child(page)
	await process_frame
	await process_frame
	_check(page._sort_rarity_high_first, "starts with high rarity first")
	page._on_sort_pressed()
	_check(not page._sort_rarity_high_first, "second press is low rarity first")
	page._on_sort_pressed()
	_check(page._sort_rarity_high_first, "third press is back to high first")
	page._on_sort_pressed()
	_check(not page._sort_rarity_high_first, "next press would be low first")
	page.visible = false
	_check(page._sort_rarity_high_first, "leaving the page (hidden) resets to high first")

	# 3. 筆劃比較
	var table = load("res://scripts/items/StrokeTable.gd")
	_check(table.compare("刀", "劍") < 0 and table.compare("劍", "刀") > 0 and table.compare("刀", "刀") == 0, "stroke compare: 刀 (2) < 劍 (15)")
	_check(table.of("劍") == 15 and table.of("刀") == 2, "stroke counts come from the table")

	inv.party_inventory = backup
	print("PASS: inventory sort" if _failures == 0 else "FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
