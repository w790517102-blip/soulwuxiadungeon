extends SceneTree

const ShumianScript = preload("res://scripts/yuheng/yuheng_marekt_west/Bai_Jian_Jue/baijianju_yinpingyu_story_shumian.gd")
const GuestScript = preload("res://scripts/yuheng/yuheng_marekt_west/Bai_Jian_Jue/baijianju_scene1_guest_dialog.gd")
const EntryFadeScript = preload("res://scripts/yuheng/yuheng_marekt_west/story_scene_entry_fade.gd")
const SceneMusicTagScript = preload("res://scripts/scene_music_tag.gd")
const ItemDBScript = preload("res://scripts/db/ItemDB.gd")

const MARKET_SCENE := "res://scenes/yuheng/yuheng_market_west/yuheng_market_west_scene1.tscn"
const NORMAL_BAIJIANJU_SCENE := "res://scenes/yuheng/yuheng_market_west/Bai_Jian_Jue/bai_jian_jue.tscn"
const BAIJIANJU_SCENE := "res://scenes/yuheng/yuheng_market_west/Bai_Jian_Jue/bai_jian_jue_scene1.tscn"
const NIGHT_SCENE := "res://scenes/yuheng/yuheng_market_west/yuheng_market_west_night.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_scene_contracts()
	_test_dynamic_y_sort_contract()
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


func _test_dynamic_y_sort_contract() -> void:
	var normal_packed := load(NORMAL_BAIJIANJU_SCENE) as PackedScene
	var story_packed := load(BAIJIANJU_SCENE) as PackedScene
	_expect(normal_packed != null and story_packed != null, "普通與劇情白箋居都必須可載入以比較排序")
	if normal_packed == null or story_packed == null:
		return

	var normal := normal_packed.instantiate()
	var story := story_packed.instantiate()
	_expect(story.get_node("NPC").z_index == 0 and story.get_node("object").z_index == 0, "角色與家具父節點不可帶固定高 Z")
	_expect(not story.get_node("NPC").y_sort_enabled and not story.get_node("object").y_sort_enabled, "白箋居必須完整沿用動態 z_index，不混用 Y-sort")
	var story_shumian := story.get_node("NPC/Su_mien") as CharacterBody2D
	var shumian_sprite := story_shumian.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_expect(story_shumian.get_parent() == story.get_node("NPC"), "劇情書眠必須留在共同 NPC 排序分支")
	_expect(shumian_sprite.z_index == 0 and shumian_sprite.z_as_relative and not shumian_sprite.show_behind_parent and not shumian_sprite.top_level, "書眠可見 Sprite 不可覆寫根節點排序")
	_expect(float(story_shumian.get("z_index_offset")) == 0.0, "劇情書眠 Inspector 不可殘留異常 z_index_offset")
	var leave1 := story.get_node("Su_mienPath/Su_mien_leave1") as Path2D
	var leave1_end := leave1.to_global(leave1.curve.get_point_position(leave1.curve.point_count - 1))
	story_shumian.global_position = leave1_end
	story_shumian._process(0.0)
	var counter_at_handoff := story.get_node("object/counter1") as Sprite2D
	counter_at_handoff.call("_process", 0.0)
	_expect(story_shumian.z_index == int(story_shumian.global_position.y), "書眠必須沿用 authored root Y 作為 sorting pivot")
	_expect(story_shumian.z_index < counter_at_handoff.z_index, "第一段終點的站立書眠必須位於較低 Y 的櫃台後方")
	var handoff_z := story_shumian.z_index
	story_shumian.call("_play_directional_animation", story_shumian, Vector2.ZERO, "idle")
	story_shumian._process(0.0)
	_expect(story_shumian.z_index == handoff_z, "切換 idle 並經過下一個 process frame 後必須維持 authored Z")

	for name in ["table1", "table2", "bookshelf1", "bookshelf2", "bookshelf3", "bookshelf4", "counter1", "counter2", "bookshelf5"]:
		var normal_furniture := normal.get_node("object/" + name) as Sprite2D
		var story_furniture := story.get_node("object/" + name) as Sprite2D
		_expect(story_furniture.get_script() == normal_furniture.get_script(), "劇情家具必須沿用普通白箋居的排序腳本：%s" % name)
		_expect(story_furniture.position.is_equal_approx(normal_furniture.position), "劇情家具排序 pivot 必須與普通白箋居一致：%s" % name)
		story_furniture.call("_process", 0.0)
		_expect(story_furniture.z_index == int(story_furniture.global_position.y), "家具 Z 必須等於 authored sorting pivot Y：%s" % name)

	var guest := GuestScript.new()
	guest.position = Vector2(0.0, 345.0)
	guest._process(0.0)
	var furniture_z := 346
	_expect(guest.z_index < furniture_z, "角色在家具排序線上方時必須位於家具後方")
	guest.position.y = 347.0
	guest._process(0.0)
	_expect(guest.z_index > furniture_z, "角色在家具排序線下方時必須位於家具前方")
	guest.free()

	var scripted_actor := ShumianScript.new()
	scripted_actor.global_position.y = 512.75
	scripted_actor.call("_sync_dynamic_z", scripted_actor)
	_expect(scripted_actor.z_index == 512, "Path 同幀改變角色座標後必須立即同步動態 Z")
	scripted_actor.free()
	normal.free()
	story.free()


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
