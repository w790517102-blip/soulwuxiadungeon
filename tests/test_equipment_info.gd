extends SceneTree

# 裝備頁資料：品類名稱、欄位名稱、布帽、裝備前後數值比較（與狀態頁同一套公式）、特殊效果說明。
# 執行：godot --headless --path . --script tests/test_equipment_info.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


func _delta_of(rows: Array, key: String) -> int:
	for row: Dictionary in rows:
		if row["key"] == key:
			return int(row["after"]) - int(row["before"])
	return 0


func _run() -> void:
	await process_frame
	var info: GDScript = load("res://scripts/inventory/EquipmentInfo.gd")
	var db: GDScript = load("res://scripts/db/ItemDB.gd")
	var inv = root.get_node("InventorySync")
	var menu_script: GDScript = load("res://scripts/system_menu.gd")
	_check(info.slot_label("armor_feet") == "足部" and info.slot_label("mechanism") == "機關" and info.slot_label("accessory_1") == "飾品", "slot labels")
	_check(info.LEFT_SLOTS.size() + info.RIGHT_SLOTS.size() == 8, "eight slots on the page")
	_check(info.category_label(db.get_def("bronze_sword")) == "劍類兵器", "sword is a 劍類兵器")
	_check(info.category_label(db.get_def("ink_brush")) == "筆類兵器", "brush is a 筆類兵器")
	_check(info.category_label(db.get_def("yaoqin")) == "琴類兵器", "qin is a 琴類兵器")
	_check(info.category_label(db.get_def("arm_cloth")) == "身體護具", "cloth is 身體護具")
	_check(info.category_label(db.get_def("acc_bracer")) == "手部護具", "bracer is 手部護具")
	_check(info.category_label(db.get_def("arm_straw_sandals")) == "足部護具", "sandals are 足部護具")
	_check(info.category_label(db.get_def("jade_pendant")) == "飾品", "pendant is 飾品")
	_check(info.category_label(db.get_def("tool_zhuge_crossbow")) == "機關", "crossbow is 機關")
	var cap: Dictionary = db.get_def("arm_cloth_cap")
	_check(cap.get("name") == "布帽" and cap.get("equip_slot") == "armor_head" and int(cap.get("stats", {}).get("def", 0)) == 1, "布帽 is a head item with def 1")
	_check(info.category_label(cap) == "頭部護具", "cap is 頭部護具")
	_check(info.special_effect_text(db.get_def("bronze_sword")) == "無特殊效果。", "no special effect text")
	_check(info.special_effect_text(db.get_def("tool_zhuge_crossbow")).contains("機關"), "crossbow effect text mentions the trigger")

	inv.party_inventory = [{"id": "bronze_sword", "count": 1}, {"id": "arm_cloth_cap", "count": 1}]
	inv.equipped_by_actor = {}
	var menu = menu_script.new()
	var actor := {"id": "liuyu", "atk": 20, "def": 5, "speed": 8, "max_hp": 150, "hp": 150, "max_mp": 60, "mp": 60, "agi": 5, "luck": 5, "str": 5, "int": 5, "con": 5, "accuracy": 100}
	var rows: Array = info.compare(menu, actor, "liuyu", "weapon_1", "bronze_sword")
	var keys: Array = []
	for row: Dictionary in rows:
		keys.append(row["key"])
	_check(_delta_of(rows, "atk") == 4, "bronze sword: attack +4")
	_check(_delta_of(rows, "speed") == 1 and keys.has("speed"), "bronze sword: speed +1 is listed")
	_check(keys.slice(0, 6) == ["atk", "hit", "def", "speed", "crit", "evade"], "the six rows are always listed in the agreed order")
	_check(not keys.has("max_hp"), "max HP row appears only when it changes")
	inv.party_inventory.append({"id": "jade_pendant", "count": 1})
	var jade_keys: Array = []
	for row: Dictionary in info.compare(menu, actor, "liuyu", "accessory_1", "jade_pendant"):
		jade_keys.append(row["key"])
	_check(jade_keys.has("max_mp"), "the pendant adds a max MP row")
	_check(info.format_delta("atk", 4.0) == "+4" and info.format_delta("def", 0.0) == "－" and info.format_delta("def", -2.0) == "-2", "delta formatting")
	_check(_delta_of(info.compare(menu, actor, "liuyu", "armor_head", "arm_cloth_cap"), "def") == 1, "cap: defence +1")
	inv.equip_item_to_slot("bronze_sword", "weapon_1", "liuyu")
	_check(_delta_of(info.compare(menu, actor, "liuyu", "weapon_1", ""), "atk") == -4, "taking the sword off: attack -4")
	menu.free()
	print("PASS test_equipment_info" if _failures == 0 else "FAILED test_equipment_info: %d" % _failures)
	quit(1 if _failures > 0 else 0)
