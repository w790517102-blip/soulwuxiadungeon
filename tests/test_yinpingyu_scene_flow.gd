extends SceneTree

const ShumianScript = preload("res://scripts/yuheng/yuheng_marekt_west/Bai_Jian_Jue/baijianju_yinpingyu_story_shumian.gd")
const GuestScript = preload("res://scripts/yuheng/yuheng_marekt_west/Bai_Jian_Jue/baijianju_scene1_guest_dialog.gd")
const EntryFadeScript = preload("res://scripts/yuheng/yuheng_marekt_west/story_scene_entry_fade.gd")
const ItemDBScript = preload("res://scripts/db/ItemDB.gd")

const BAIJIANJU_SCENE := "res://scenes/yuheng/yuheng_market_west/Bai_Jian_Jue/bai_jian_jue_scene1.tscn"
const NIGHT_SCENE := "res://scenes/yuheng/yuheng_market_west/yuheng_market_west_night.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_scene_contracts()
	_test_dialogue_split()
	_test_item_definition()
	if _failures.is_empty():
		print("PASS: 白箋居銀屏語分段演出回歸測試全部通過")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_scene_contracts() -> void:
	var packed := load(BAIJIANJU_SCENE) as PackedScene
	_expect(packed != null, "白箋居事件場景必須可載入")
	if packed:
		var scene := packed.instantiate()
		_expect(scene.get_script() == EntryFadeScript, "白箋居根節點必須負責進場淡出")
		_expect(scene.has_node("SpawnPoints/from_yuheng_market_west_scene1"), "白箋居必須保留劇情版西市集入口 SpawnPoint")
		for path_text in ["Su_mienPath/Su_mien_leave1", "Liu_yu_path/Liu_yu_leave1", "Liu_yu_path/Liu_yu_leave2"]:
			var path := scene.get_node_or_null(path_text) as Path2D
			_expect(path != null and path.curve != null and path.curve.get_baked_length() > 0.0, "離場 Path 必須有效：%s" % path_text)
		_expect(scene.get_node("NPC/Bookstore_guestA").get_script() == GuestScript, "客人一必須使用 scene-local 對話")
		_expect(scene.get_node("NPC/Bookstore_guestB").get_script() == GuestScript, "客人二必須使用 scene-local 對話")
		scene.free()

	var night_packed := load(NIGHT_SCENE) as PackedScene
	_expect(night_packed != null, "夜晚西市集必須可載入")
	if night_packed:
		var night := night_packed.instantiate()
		_expect(night.get_script() == EntryFadeScript, "夜晚西市集根節點必須負責全黑淡出")
		_expect(night.has_node("SpawnPoints/Hong_huei_yin_recall_event_point"), "夜市必須保留紅徽音事件 SpawnPoint")
		_expect(night.has_node("Hong_huei_yin_recall_event_trigger"), "夜市必須保留紅徽音接手 Trigger")
		night.free()


func _test_dialogue_split() -> void:
	var shumian := ShumianScript.new()
	_expect(shumian.speaker_id == 1, "書眠必須使用上方 NPC 對話框 lane")
	_expect(shumian.liuyu_speaker_id == 2, "劉語塵必須使用下方玩家對話框 lane")
	_expect(shumian.huiyin_speaker_id == 1, "紅徽音必須使用上方 NPC 對話框 lane")
	_expect(ResourceLoader.exists(shumian.portrait_path), "書眠頭像資源必須存在")
	_expect(ResourceLoader.exists(shumian.huiyin_portrait_path), "紅徽音頭像資源必須存在")
	var phase_a := _join_dialogue(shumian._build_yinpingyu_event_lines())
	var phase_b := _join_dialogue(shumian._build_after_shumian_leave_lines())
	_expect(phase_a.contains("我怕再說下去，連窗也關不住"), "Phase A 必須停在書眠準備離開")
	_expect(not phase_a.contains("走到屏風旁"), "Phase A 不可提前描述書眠已到屏風旁")
	_expect(phase_b.contains("走到屏風旁"), "Phase B 必須從書眠抵達屏風旁後開始")
	_expect(phase_b.contains("……出去吧"), "Phase B 必須包含劉語塵離開提示")
	shumian.free()


func _test_item_definition() -> void:
	var item := ItemDBScript.get_def("item_yinpingyu_scroll")
	_expect(String(item.get("name", "")) == "《銀屏語》", "銀屏語道具必須有正式資料")
	_expect(String(item.get("type", "")) == "quest", "銀屏語必須是不可消耗的任務詩卷")


func _join_dialogue(lines: Array) -> String:
	var text := ""
	for line in lines:
		if line is Dictionary:
			text += String((line as Dictionary).get("text", ""))
	return text


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
