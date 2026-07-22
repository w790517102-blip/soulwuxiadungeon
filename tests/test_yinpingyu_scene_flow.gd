extends SceneTree

const ShumianScript = preload("res://scripts/yuheng/yuheng_marekt_west/Bai_Jian_Jue/baijianju_yinpingyu_story_shumian.gd")
const GuestScript = preload("res://scripts/yuheng/yuheng_marekt_west/Bai_Jian_Jue/baijianju_scene1_guest_dialog.gd")
const EntryFadeScript = preload("res://scripts/yuheng/yuheng_marekt_west/story_scene_entry_fade.gd")
const SceneMusicTagScript = preload("res://scripts/scene_music_tag.gd")
const ItemDBScript = preload("res://scripts/db/ItemDB.gd")

const MARKET_SCENE := "res://scenes/yuheng/yuheng_market_west/yuheng_market_west_scene1.tscn"
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
	var market_packed := load(MARKET_SCENE) as PackedScene
	_expect(market_packed != null, "劇情版西市集必須可載入")
	if market_packed:
		var market := market_packed.instantiate()
		_expect(market.get_script() == SceneMusicTagScript, "劇情版西市集必須向 GameRoot 宣告場景音樂")
		_expect(String(market.get("music_tag")) == "yuheng", "劇情版西市集 BGM 必須是 yuheng")
		market.free()

	var packed := load(BAIJIANJU_SCENE) as PackedScene
	_expect(packed != null, "白箋居事件場景必須可載入")
	if packed:
		var scene := packed.instantiate()
		_expect(scene.get_script() == EntryFadeScript, "白箋居根節點必須負責進場淡出")
		_expect(String(scene.get("music_tag")) == "yuheng_inner", "白箋居必須在淡出黑幕前切到 yuheng_inner")
		_expect(scene.has_node("SpawnPoints/from_yuheng_market_west_scene1"), "白箋居必須保留劇情版西市集入口 SpawnPoint")
		for path_text in ["Su_mienPath/Su_mien_leave1", "Su_mienPath/Su_mien_leave2", "Liu_yu_path/Liu_yu_leave1", "Liu_yu_path/Liu_yu_leave2"]:
			var path := scene.get_node_or_null(path_text) as Path2D
			_expect(path != null and path.curve != null and path.curve.get_baked_length() > 0.0, "離場 Path 必須有效：%s" % path_text)
		for furniture in scene.get_node("object").get_children():
			_expect(bool(furniture.get("sort_from_texture_bottom")), "白箋居家具必須以圖片底緣作為接地排序線：%s" % furniture.name)
		_expect(scene.get_node("NPC/Bookstore_guestA").get_script() == GuestScript, "客人一必須使用 scene-local 對話")
		_expect(scene.get_node("NPC/Bookstore_guestB").get_script() == GuestScript, "客人二必須使用 scene-local 對話")
		scene.free()

	var night_packed := load(NIGHT_SCENE) as PackedScene
	_expect(night_packed != null, "夜晚西市集必須可載入")
	if night_packed:
		var night := night_packed.instantiate()
		_expect(night.get_script() == EntryFadeScript, "夜晚西市集根節點必須負責全黑淡出")
		_expect(String(night.get("music_tag")) == "yuheng_night", "夜晚西市集必須在淡出黑幕前切到 yuheng_night")
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
	var reading := _join_dialogue(shumian._build_yinpingyu_event_lines())
	var after_yuxin := _join_dialogue(shumian._build_after_yuxin_music_lines())
	var resonance := _join_dialogue(shumian._build_resonance_lines())
	var before_leave_2 := _join_dialogue(shumian._build_before_shumian_leave2_lines())
	var after_leave := _join_dialogue(shumian._build_after_shumian_leave_lines())
	_expect(reading.ends_with("你沉默時，我想說的那一句。"), "讀詩 phase 必須停在 yuxin_moonlight_hint 切歌點")
	_expect(not reading.contains("BGM 切換為低聲版本"), "玩家對話不可包含舊製作備註")
	_expect(after_yuxin.begins_with("環境音靜默三秒"), "yuxin 切歌後才可進入環境靜默")
	_expect(resonance.begins_with("醉月茶坊方向傳來琴聲。"), "Hong_huei_yin_trueheart 切歌後才可顯示琴聲旁白")
	_expect(not resonance.contains("她起身，像是想再說什麼"), "第一次書眠走位旁白必須是獨立同步 phase")
	_expect(before_leave_2.ends_with("今晚的風太重了。"), "第二次走位前 phase 必須停在指定台詞之前")
	_expect(after_leave.contains("走到屏風旁"), "後續對話只能在書眠第二條 Path 完成後開始")
	_expect(after_leave.contains("……出去吧"), "後續對話必須包含劉語塵離開提示")
	_expect(ResourceLoader.exists("res://assets/BGM/Hong_huei_yin_trueheart.ogg"), "紅徽音共鳴事件曲必須存在")
	_expect(ResourceLoader.exists("res://assets/BGM/yuheng_night.ogg"), "夜晚西市集 BGM 必須存在")
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
