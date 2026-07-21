extends SceneTree

const RichmanTriggerScript = preload("res://scripts/yuheng/yuheng_marekt_west/baijianju_richman_trigger.gd")
const WitnessScript = preload("res://scripts/yuheng/yuheng_marekt_west/scene1_witness_dialog.gd")
const EVENT_SCENE := "res://scenes/yuheng/yuheng_market_west/yuheng_market_west_scene1.tscn"
const EVENT_OBJECTIVE := "進入白箋居，確認書眠是否無恙。"

var _failures: Array[String] = []
var _flags_snapshot: Dictionary
var _triggered_flags_snapshot: Dictionary
var _quest_snapshot: Dictionary


func _initialize() -> void:
	_flags_snapshot = GlobalState.flags.duplicate(true)
	_triggered_flags_snapshot = GlobalState.triggered_flags.duplicate(true)
	_quest_snapshot = QuestManager.get_main_quest_state().duplicate(true)

	_test_scene_contract()
	_test_dialogue_contract()
	_test_stage_and_flag_round_trip()

	_restore_runtime_state()
	if _failures.is_empty():
		print("PASS: 玉衡鎮西市暴發戶事件回歸測試全部通過")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_scene_contract() -> void:
	var packed := load(EVENT_SCENE) as PackedScene
	_expect(packed != null, "事件專用場景必須可載入")
	if packed == null:
		return
	var scene := packed.instantiate()
	var trigger := scene.get_node_or_null("yuheng_market_west_scene1_trigger")
	_expect(trigger != null and trigger.get_script() == RichmanTriggerScript, "scene1 必須掛接暴發戶事件控制器")
	_expect(scene.has_node("yuheng_market_west_scene1_trigger/to_bai_jian_ju_front/PathFollow2D"), "必須保留玩家進場 Path")
	_expect(scene.has_node("NPC/yuheng_Parvenu/Path_OutFromBookstore/PathFollow2D"), "必須保留暴發戶出場 Path")
	_expect(scene.has_node("NPC/yuheng_Parvenu/Path_LeaveTown/PathFollow2D"), "必須保留暴發戶離場 Path")
	_expect(scene.has_node("NPC/yuheng_Parvenu/Bookstore_guestC"), "必須保留暴發戶演員")
	for path in [
		"yuheng_market_east_forbidden",
		"yuheng_weapon_shop_forbidden",
		"pharmacy_forbidden",
		"Bamboo_Grove_Suburb_forbidden",
		"to_Bai_Jian_Jue",
	]:
		_expect(scene.has_node(path), "scene1 缺少區域節點：%s" % path)
	for witness in ["yuheng_black_smith", "sugar_kid", "scholar", "outlander"]:
		var npc := scene.get_node_or_null("NPC/%s" % witness)
		_expect(npc != null and npc.get_script() == WitnessScript, "圍觀者必須使用 scene1 限定對話：%s" % witness)
	scene.free()


func _test_dialogue_contract() -> void:
	var trigger := RichmanTriggerScript.new()
	var confrontation: Array = trigger._build_confrontation_lines()
	var all_text := _join_dialogue(confrontation)
	_expect(all_text.contains("因為那是她的詩"), "對峙必須說明書眠擁有決定權")
	_expect(all_text.contains("你買不到別人願意"), "對峙定稿關鍵句不可遺失")
	_expect(all_text.contains("等到書懂得嫌人"), "對峙收束句不可遺失")
	trigger.free()

	var expected := {
		"sugar_kid": "比糖畫還精彩",
		"scholar": "將詩書當作炫耀門面的擺設",
		"outlander": "尊重人家規矩",
		"blacksmith": "好鋒口",
	}
	for witness_id in expected:
		var witness := WitnessScript.new()
		witness.witness_id = witness_id
		_expect(_join_dialogue(witness._build_lines()).contains(expected[witness_id]), "圍觀者定稿對話缺漏：%s" % witness_id)
		witness.free()


func _test_stage_and_flag_round_trip() -> void:
	GlobalState.flags = {
		"main_yh_manor_closed": true,
		"event_baijianju_richman_done": true,
		"main_yh_baijianju_open": true,
	}
	GlobalState.triggered_flags = GlobalState.flags.duplicate(true)
	QuestManager.load_main_quest({
		"id": "main_001",
		"stage": 4,
		"objective_override": EVENT_OBJECTIVE,
		"current_objective": EVENT_OBJECTIVE,
	})

	var saved_flags := GlobalState.flags.duplicate(true)
	var saved_quest := QuestManager.get_main_quest_state().duplicate(true)
	GlobalState.flags.clear()
	GlobalState.triggered_flags.clear()
	QuestManager.reset_main_quest()
	GlobalState.flags = saved_flags.duplicate(true)
	GlobalState.triggered_flags = saved_flags.duplicate(true)
	QuestManager.load_main_quest(saved_quest)

	_expect(GlobalState.get_flag("event_baijianju_richman_done"), "讀檔後事件完成旗標必須保留")
	_expect(GlobalState.get_flag("main_yh_baijianju_open"), "讀檔後白箋居開放旗標必須保留")
	var loaded_quest := QuestManager.get_main_quest_state()
	_expect(int(loaded_quest.get("stage", 0)) == 4, "讀檔後 main_001 必須維持 stage 4")
	_expect(String(loaded_quest.get("current_objective", "")) == EVENT_OBJECTIVE, "讀檔後 stage 4 objective 必須維持")


func _join_dialogue(lines: Array) -> String:
	var text := ""
	for line in lines:
		if line is Dictionary:
			text += String((line as Dictionary).get("text", ""))
	return text


func _restore_runtime_state() -> void:
	GlobalState.flags = _flags_snapshot.duplicate(true)
	GlobalState.triggered_flags = _triggered_flags_snapshot.duplicate(true)
	QuestManager.load_main_quest(_quest_snapshot)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
