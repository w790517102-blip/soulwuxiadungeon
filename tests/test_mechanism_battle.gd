extends SceneTree

# 機關按鈕（卡牌舞台戰鬥 UI）：沒裝備機關就沒有按鈕；裝備諸葛連弩才出現；點機關 → 選目標 → 沿用原連射結算（敏捷決定發數、消耗箭矢、固定傷害）。
# 執行：godot --headless --path . --script tests/test_mechanism_battle.gd

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
	inv.party_inventory = [{"id": "tool_zhuge_crossbow", "count": 1}, {"id": "ammo_arrow", "count": 10}]
	inv.equipped_by_actor = {}
	root.get_node("GlobalState").remove_meta("pending_battle_context")
	var battle: Node = (load("res://scenes/battle_scene.tscn") as PackedScene).instantiate()
	battle.presentation_mode = 2
	root.add_child(battle)
	await process_frame
	await process_frame
	var controller: Node = battle.get_node("BattleController")
	var ui: Node = controller.battle_ui
	_check(ui != null, "battle ui exists")
	var liuyu := {"id": "liuyu", "name": "劉", "hp": 1000, "max_hp": 1000, "mp": 50, "max_mp": 50, "speed": 10, "atk": 20, "def": 5, "agi": 25, "accuracy": 100000}
	var foe := {"id": "foe", "name": "敵", "hp": 1000, "max_hp": 1000, "mp": 0, "speed": 7, "atk": 20, "def": 3, "is_enemy": true, "battle_uid": "foe#0", "accuracy": 100000}
	controller.player_party = [liuyu]
	controller.enemy_party = [foe]
	ui.current_actor = liuyu

	ui._command_buttons["mechanism"].visible = true
	ui._show_command_menu()
	_check(not ui._command_buttons["mechanism"].visible, "no mechanism equipped → no mechanism button")

	inv.equip_item_to_slot("tool_zhuge_crossbow", "mechanism", "liuyu")
	ui._show_command_menu()
	_check(ui._command_buttons["mechanism"].visible, "crossbow equipped → mechanism button shown")

	var hp_before := int(foe["hp"])
	ui._on_btn_mechanism_pressed()
	await process_frame
	var shots := 10 - int(inv.get_item_by_id("ammo_arrow").get("count", 0))
	_check(shots == 3, "agi 25 → 3 arrows spent (got %d)" % shots)
	_check(hp_before - int(foe["hp"]) >= 3 * 1 and int(foe["hp"]) < hp_before, "the enemy took damage")
	_check(not inv.get_equipped("liuyu").get("mechanism", "").is_empty(), "the mechanism stays equipped")

	print("PASS test_mechanism_battle" if _failures == 0 else "FAILED test_mechanism_battle: %d" % _failures)
	quit(1 if _failures > 0 else 0)
