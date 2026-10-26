extends SceneTree

# 道具「整理」：先依種類（藥物、書籍、裝備、材料、任務、其他），同種類再依 id。
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
	var backup: Array = inv.party_inventory.duplicate(true)
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
	_check(ids == ["e_drug_a", "e_drug_b", "f_food", "c_book", "a_equip", "d_mat", "b_quest", "z_other"], "sorted by category (drugs, books, equipment, materials, quests, other), then by id: %s" % str(ids))
	inv.party_inventory = backup
	print("PASS: inventory sort" if _failures == 0 else "FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
