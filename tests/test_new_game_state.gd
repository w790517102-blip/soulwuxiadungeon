extends SceneTree

# 新遊戲的起始狀態：氣血與內力是滿的（套用五維後最大值變大也要補滿）、預設裝備已經穿上、布帽在開局道具裡。
# 狀態頁顯示的目前值對「本來就是滿的」角色要顯示成滿（含裝備加成的最大值）。
# 執行：godot --headless --path . --script tests/test_new_game_state.gd

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
	var team = root.get_node("TeamData")
	for actor_id in ["liuyu", "shumian", "lieshao"]:
		var actor: Dictionary = team.all_characters[actor_id]
		_check(int(actor["hp"]) == int(actor["max_hp"]), "%s starts with full HP (%d/%d)" % [actor_id, int(actor["hp"]), int(actor["max_hp"])])
		_check(int(actor["mp"]) == int(actor["max_mp"]), "%s starts with full MP (%d/%d)" % [actor_id, int(actor["mp"]), int(actor["max_mp"])])
	var liuyu: Dictionary = team.all_characters["liuyu"]
	_check(int(liuyu["max_hp"]) > 150, "five stats raised the maximum above the literal 150 (got %d)" % int(liuyu["max_hp"]))

	var worn: Dictionary = inv.get_equipped("liuyu")
	_check(worn.get("weapon_1") == "wep_wood_sword", "劉語塵 starts with the wooden sword")
	_check(worn.get("armor_head") == "arm_cloth_cap", "劉語塵 wears the cloth cap (the opening item)")
	_check(worn.get("armor_body") == "arm_cloth", "劉語塵 wears the cloth clothes")
	_check(worn.get("accessory_1") == "jade_pendant", "劉語塵 wears the jade pendant")
	_check(inv.get_equipped("shumian").get("weapon_1") == "ink_brush", "書眠 holds the ink brush")
	_check(not inv.has_item("arm_cloth_cap"), "equipped items left the bag")
	_check(inv.has_item("iron_sword"), "the spare sword stays in the bag")

	var menu = load("res://scripts/system_menu.gd").new()
	var bonus: Dictionary = inv.get_equipment_stat_bonus("liuyu")
	var stats: Dictionary = menu.compute_overview_stats(liuyu, bonus)
	_check(int(stats["max_mp"]) == int(liuyu["max_mp"]) + int(bonus.get("max_mp", 0)), "total max MP = canonical max + the pendant's bonus")
	_check(int(bonus.get("max_mp", 0)) > 0, "the pendant raises max MP")
	_check(menu._displayed_resource(int(liuyu["mp"]), int(liuyu["max_mp"]), int(stats["max_mp"])) == int(stats["max_mp"]), "a canonically full actor shows full MP against the equipped maximum")
	_check(menu._displayed_resource(10, int(liuyu["max_mp"]), int(stats["max_mp"])) == 10, "an injured actor keeps the exact value")
	menu.free()
	print("PASS test_new_game_state" if _failures == 0 else "FAILED test_new_game_state: %d" % _failures)
	quit(1 if _failures > 0 else 0)
