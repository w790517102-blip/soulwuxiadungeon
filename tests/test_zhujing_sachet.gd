extends SceneTree

const ItemDBScript = preload("res://scripts/db/ItemDB.gd")
const EnemyDBScript = preload("res://scripts/db/EnemyDB.gd")
const SkillExecutorScript = preload("res://scripts/battlescripts/SkillExecutor.gd")
const LiuYuScript = preload("res://scripts/liu_yu.gd")
const GrandmaScript = preload("res://scripts/yuheng/Bamboo_Grove_Suburb/yuheng_grand_ma.gd")

const SACHET := "acc_zhujing_sachet"
const REGION := "yuheng_bamboo_outskirts"

var _failures: Array[String] = []
var _inventory_snapshot: Dictionary
var _team_ids_snapshot: Array
var _flags_snapshot: Dictionary
var _triggered_flags_snapshot: Dictionary
var _quest_snapshot: Dictionary


func _initialize() -> void:
	_inventory_snapshot = InventorySync.export_inventory_state()
	_team_ids_snapshot = TeamData.current_team_ids.duplicate()
	_flags_snapshot = GlobalState.flags.duplicate(true)
	_triggered_flags_snapshot = GlobalState.triggered_flags.duplicate(true)
	_quest_snapshot = QuestManager.get_main_quest_state().duplicate(true)

	_test_item_and_enemy_data()
	_test_inventory_equipment_and_round_trip()
	_test_party_region_effect()
	_test_damage_reduction()
	_test_grandma_reward_and_migration()

	_restore_runtime_state()
	if _failures.is_empty():
		print("PASS: 竹徑香包回歸測試全部通過")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_item_and_enemy_data() -> void:
	var item := ItemDBScript.get_def(SACHET)
	_expect(String(item.get("type", "")) == "equipment", "香包必須是 equipment")
	_expect(String(item.get("equip_slot", "")) == "accessory_1", "香包必須使用飾品欄")
	_expect(String(item.get("rarity", "")) == "common", "香包稀有度必須是 common")
	_expect(float((item.get("equip_effects", {}) as Dictionary).get("animal_damage_taken_multiplier", 1.0)) == 0.9, "香包動物減傷倍率必須是 0.9")
	_expect(((item.get("equip_effects", {}) as Dictionary).get("suppress_random_encounter_region_ids", []) as Array).has(REGION), "香包必須只以穩定 region ID 登記竹林避獸")
	_expect(String(EnemyDBScript.make_enemy("bamboo_macaque").get("family", "")) == "animal", "獼猴必須明確分類為 animal")
	_expect(String(EnemyDBScript.make_enemy("bamboo_poison_snake").get("family", "")) == "animal", "毒蛇必須明確分類為 animal")
	_expect(String(EnemyDBScript.make_enemy("sewer_drowned_wight").get("family", "")) != "animal", "非動物敵人不可分類為 animal")


func _test_inventory_equipment_and_round_trip() -> void:
	_reset_inventory_for_test()
	InventorySync.add_item_stack(SACHET, 1, false)
	_expect(InventorySync.has_item(SACHET), "取得後背包必須持有香包")

	InventorySync.equip_item_to_slot(SACHET, "accessory_1", "liuyu")
	_expect(InventorySync.is_equipped(SACHET, "liuyu"), "香包必須能裝到劉語塵飾品欄")
	_expect(not InventorySync.has_item(SACHET), "裝備中的香包不可同時留在背包")
	var equipped_save := InventorySync.export_inventory_state()

	_reset_inventory_for_test()
	InventorySync.import_inventory_state(equipped_save)
	_expect(InventorySync.is_equipped(SACHET, "liuyu"), "讀檔後必須仍裝備在原角色")
	_expect(float(InventorySync.get_equipment_effect("liuyu", "animal_damage_taken_multiplier", 1.0)) == 0.9, "讀檔後裝備效果必須由裝備狀態重建")

	InventorySync.unequip("accessory_1", "liuyu")
	var unequipped_save := InventorySync.export_inventory_state()
	InventorySync.equip_item_to_slot(SACHET, "accessory_1", "liuyu")
	InventorySync.import_inventory_state(unequipped_save)
	_expect(not InventorySync.is_equipped(SACHET, "liuyu"), "卸下後存讀檔不可自行重新裝備")
	_expect(InventorySync.has_item(SACHET), "卸下後存讀檔必須仍在背包")


func _test_party_region_effect() -> void:
	_reset_inventory_for_test()
	TeamData.current_team_ids = ["liuyu", "shumian"]
	InventorySync.add_item_stack(SACHET, 1, false)
	_expect(not InventorySync.active_party_has_equipment_region_effect("suppress_random_encounter_region_ids", REGION), "只放背包不可停止遭遇")
	InventorySync.equip_item_to_slot(SACHET, "accessory_1", "shumian")
	_expect(InventorySync.active_party_has_equipment_region_effect("suppress_random_encounter_region_ids", REGION), "任一 active member 裝備必須保護整隊")
	_expect(not InventorySync.active_party_has_equipment_region_effect("suppress_random_encounter_region_ids", "qingfeng_bamboo"), "其他地區不可停止遭遇")
	var liuyu := LiuYuScript.new()
	_expect(liuyu._is_random_encounter_suppressed(REGION), "劉語塵一般遭遇查詢必須即時讀取隊伍裝備")
	InventorySync.unequip("accessory_1", "shumian")
	_expect(not liuyu._is_random_encounter_suppressed(REGION), "卸下後一般遭遇抑制必須立即失效")
	liuyu.free()


func _test_damage_reduction() -> void:
	_reset_inventory_for_test()
	var executor := SkillExecutorScript.new()
	var animal := {"id": "test_animal", "name": "測試動物", "family": "animal", "atk": 100, "agi": 100, "luck": 0, "element": ""}
	var non_animal := animal.duplicate(true)
	non_animal["family"] = "phantom"
	var target := {"id": "liuyu", "name": "劉語塵", "hp": 500, "max_hp": 500, "def": 0, "agi": 0, "luck": 0, "element": ""}
	var skill := {"name": "測試攻擊", "kind": "武學", "weapon_type": "通用", "power": 1.0, "crit_rate_bonus": 0.0}

	seed(20260721)
	var base_result := executor.execute(animal.duplicate(true), target.duplicate(true), skill, {})
	InventorySync.add_item_stack(SACHET, 1, false)
	InventorySync.equip_item_to_slot(SACHET, "accessory_1", "liuyu")
	seed(20260721)
	var reduced_result := executor.execute(animal.duplicate(true), target.duplicate(true), skill, {})
	_expect(int(reduced_result.get("damage", 0)) == int(float(base_result.get("damage", 0)) * 0.9), "動物傷害必須在最終取整前降低 10%")

	seed(20260721)
	var non_animal_result := executor.execute(non_animal, target.duplicate(true), skill, {})
	_expect(int(non_animal_result.get("damage", 0)) == int(base_result.get("damage", 0)), "非動物傷害不可降低")

	var weak_animal := animal.duplicate(true)
	weak_animal["atk"] = 1
	var armored_target := target.duplicate(true)
	armored_target["def"] = 999
	seed(20260721)
	var minimum_result := executor.execute(weak_animal, armored_target, skill, {})
	_expect(int(minimum_result.get("damage", 0)) == 1, "香包不可讓最低 1 點傷害變成 0")
	executor.free()


func _test_grandma_reward_and_migration() -> void:
	_reset_inventory_for_test()
	GlobalState.flags = {
		"main_yh_gushi_request_report_grandma": true,
		"main_yh_grandma_reported": false,
		"main_yh_zhujing_sachet_received": false,
	}
	GlobalState.triggered_flags = GlobalState.flags.duplicate(true)
	var grandma := GrandmaScript.new()
	var reward_lines := grandma._build_lines_for_state()
	_expect(not InventorySync.has_item_anywhere(SACHET), "正式對話閱讀期間不可提前發放香包")
	_expect(reward_lines.any(func(line): return String((line as Dictionary).get("text", "")).contains("獲得飾品：竹徑香包")), "正式對話必須包含取得提示")
	grandma._apply_pending_actions()
	_expect(InventorySync.has_item_anywhere(SACHET), "完整對話結束後必須發放香包")
	_expect(GlobalState.get_flag("main_yh_grandma_reported"), "完整對話結束後必須設定回報旗標")
	_expect(GlobalState.get_flag("main_yh_zhujing_sachet_received"), "完整對話結束後必須設定香包一次性旗標")
	var count_after_reward := InventorySync.get_item_count(SACHET)
	grandma._build_lines_for_state()
	grandma._apply_pending_actions()
	_expect(InventorySync.get_item_count(SACHET) == count_after_reward, "重複互動不可再次發放香包")
	grandma.free()

	_reset_inventory_for_test()
	GlobalState.flags = {"main_yh_grandma_reported": true}
	GlobalState.triggered_flags = GlobalState.flags.duplicate(true)
	var migration_grandma := GrandmaScript.new()
	var migration_lines := migration_grandma._build_lines_for_state()
	_expect(migration_lines.any(func(line): return String((line as Dictionary).get("text", "")).contains("先前只顧著聽顧石的消息")), "漏領舊檔必須進入簡短補發對話")
	_expect(not InventorySync.has_item_anywhere(SACHET), "舊檔補發也必須等對話結束")
	migration_grandma._apply_pending_actions()
	_expect(InventorySync.has_item_anywhere(SACHET), "舊檔補發對話結束後必須取得香包")
	_expect(GlobalState.get_flag("main_yh_zhujing_sachet_received"), "舊檔補發後必須設定一次性旗標")
	migration_grandma.free()


func _reset_inventory_for_test() -> void:
	InventorySync.party_inventory = []
	InventorySync.equipped_by_actor = {}
	InventorySync.ever_owned_item_ids = {}


func _restore_runtime_state() -> void:
	InventorySync.party_inventory = []
	InventorySync.equipped_by_actor = {}
	InventorySync.ever_owned_item_ids = {}
	InventorySync.import_inventory_state(_inventory_snapshot)
	TeamData.current_team_ids = _team_ids_snapshot.duplicate()
	GlobalState.flags = _flags_snapshot.duplicate(true)
	GlobalState.triggered_flags = _triggered_flags_snapshot.duplicate(true)
	QuestManager.load_main_quest(_quest_snapshot)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
