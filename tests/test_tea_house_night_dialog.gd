extends SceneTree
## 夜晚醉月茶坊掌櫃／店小二的八種對白（白天說過話 × 夜晚說過話 × 拿銅釦前後），以及白天茶坊不會被夜晚對白蓋掉。
## Run: --headless --path . --script tests/test_tea_house_night_dialog.gd

var _failures: Array[String] = []
var Dialog: Script


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _npc(night: bool) -> Node:
	var parent := Node.new()
	parent.scene_file_path = Dialog.NIGHT_TEASHOP_SCENE_PATH if night else "res://scenes/yuheng/zueyue_teashop/zue_yue_teashop.tscn"
	var npc := Node.new()
	parent.add_child(npc)
	return npc


func _set_state(day: bool, night: bool, window: bool, button: bool) -> void:
	var gs = root.get_node("GlobalState")
	for key: String in ["boss", "servant"]:
		gs.set_flag(String(Dialog.DAY_FLAGS[key]), day)
		gs.set_flag(String(Dialog.NIGHT_FLAGS[key]), night)
		gs.set_flag(String(Dialog.MET_FLAGS[key]), day or night)
	gs.set_flag(Dialog.F_GO_TO_ZUIYUE_HUIYIN, window or button)
	gs.set_flag(Dialog.F_HUIYIN_FIRST_TALK_DONE, button)
	gs.set_flag(Dialog.F_GOT_HALF_STRING_BUTTON, button)


func _flags(names: Array, value: bool) -> void:
	for name: String in names:
		root.get_node("GlobalState").set_flag(name, value)


func _texts(lines: Array) -> String:
	var out := ""
	for line: Dictionary in lines:
		out += String(line.get("text", "")) + "
"
	return out


## 白天 05／06：實際完成的事件決定；06 的台詞在新曲奏響以前絕不出現。
func _check_day_stages() -> void:
	var day := _npc(false)
	var gs = root.get_node("GlobalState")
	var all := [Dialog.F_NIGHT_MEETING_DONE, Dialog.F_BAIYUAN_PLAYED, "teahouse_boss_06_heard", "teahouse_servant_06_heard"]
	_set_state(false, false, false, true)
	_flags(all, false)
	for key: String in ["boss", "servant"]:
		_expect(Dialog.day_lines_for(key, day, 1, "p").is_empty(), "%s: before 05 the day script is left to the old logic" % key)
		# 只有銅釦、舊水道事件的其他旗標，都不能啟用 05／06
		_flags(["sewer_music_solved", "sewer_final_seal_opened", "main_chapter_liefeng_started"], true)
		_expect(Dialog.day_lines_for(key, day, 1, "p").is_empty(), "%s: sewer/liefeng flags alone do not enable 05" % key)
		_flags(["sewer_music_solved", "sewer_final_seal_opened", "main_chapter_liefeng_started"], false)
	# 05：四種（掌櫃 A/B、店小二 C/D），且不含 06 的台詞
	gs.set_flag(Dialog.F_NIGHT_MEETING_DONE, true)
	var seen := {}
	for key: String in ["boss", "servant"]:
		for talked: bool in [false, true]:
			_set_state(talked, false, false, true)
			var lines: Array = Dialog.day_lines_for(key, day, 1, "p")
			_expect(lines.size() == 3, "%s talked=%s has the 05 lines" % [key, talked])
			var t := _texts(lines)
			seen[t] = true
			_expect(t.contains("昨夜"), "%s 05 remembers last night" % key)
			for banned: String in ["嗓子也不啞", "曲調似乎有些不同", "願意嘗試不同茶品", "醉月青魁", "女伶近日奏了別的曲"]:
				_expect(not t.contains(banned), "%s 05 must not leak 06 line: %s" % [key, banned])
	_expect(seen.size() == 4, "05 has four distinct groups")
	# 夜晚場景不吃白天 05
	_expect(Dialog.day_lines_for("boss", _npc(true), 1, "p").is_empty(), "night scene never gets day 05/06 lines")
	# 06：旗標成立才出現；第一組之後換循環組
	gs.set_flag(Dialog.F_BAIYUAN_PLAYED, true)
	_set_state(true, false, false, true)
	_flags([Dialog.F_NIGHT_MEETING_DONE], true)
	for key: String in ["boss", "servant"]:
		_flags(["teahouse_%s_06_heard" % key], false)
		var first := _texts(Dialog.day_lines_for(key, day, 1, "p"))
		Dialog.mark_talked(key, day)
		var loop := _texts(Dialog.day_lines_for(key, day, 1, "p"))
		_expect(first != loop and loop != "", "%s 06 switches from first group to loop" % key)
		_expect(first.contains("曲") and not first.contains("昨夜"), "%s 06 outranks 05" % key)
	_flags(all, false)


## 04 的請託只屬於夜晚 04（銅釦剛到手）；05／06 不可倒退，白天通用 fallback 也不能有。
func _check_huiyin_revisit() -> void:
	var hong = load("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/zuiyue_huiyin_first_talk_story.gd").new()
	var all := [Dialog.F_NIGHT_MEETING_DONE, Dialog.F_BAIYUAN_PLAYED]
	_set_state(false, false, false, true)
	_flags(all, false)
	_expect(_texts(hong._build_revisit_lines()).contains("拜託你了，少俠。"), "04 revisit says the request")
	_flags([Dialog.F_NIGHT_MEETING_DONE], true)
	_expect(not _texts(hong._build_revisit_lines()).contains("拜託你了"), "abnormal night (meeting done) is a neutral line, not 04 and no new story")
	_flags([Dialog.F_BAIYUAN_PLAYED], true)
	_expect(not _texts(hong._build_revisit_lines()).contains("拜託你了"), "abnormal night (06) is a neutral line")
	_flags(all, false)
	hong.free()
	var day_src := FileAccess.get_file_as_string("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/Hong_huei_yin.gd")
	_expect(not day_src.contains("拜託你了"), "day Hong script has no 04 request line")


## 銅釦之後、尚未夜間交談的第 4、5 格：要認得「方才進門直奔琴案」，不能再說頭一回來。
func _check_after_button_witness() -> void:
	var night := _npc(true)
	for key: String in ["boss", "servant"]:
		for day: bool in [false, true]:
			_set_state(day, false, false, true)
			var t := _texts(Dialog.lines_for(key, night, 1, "p", []))
			_expect(t.contains("琴案") or t.contains("那位姑娘"), "%s day=%s after button recalls the handover" % [key, day])
			for banned: String in ["頭一回", "頭回", "銅釦", "廢井", "水道"]:
				_expect(not t.contains(banned), "%s day=%s after button must not say %s" % [key, day, banned])


## 調查琴音後第一次跟掌櫃說話：要走「劉語塵問女伶來歷」的初見台詞，不能被別人設的旗標吃掉變成循環台詞。
func _check_keeper_first_meeting() -> void:
	var gs = root.get_node("GlobalState")
	_set_state(false, false, false, false)
	for f in ["event_market_choice_observe", "event_yuheng_market_melody", "met_yuheng_inn_boss"]:
		gs.set_flag(f, true)
	var keeper = load("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/tea_shop_keeper.gd").new()
	var parent := Node.new()
	parent.scene_file_path = "res://scenes/yuheng/zueyue_teashop/zue_yue_teashop.tscn"
	parent.add_child(keeper)
	var t := _texts(keeper._build_lines_for_quest({"id": "main_001", "stage": 1}))
	_expect(t.contains("紅衣女伶的來歷"), "first chat after investigating the qin has Liu Yu asking about the singer")
	_expect(not t.begins_with("掌櫃：「這世道"), "first chat is not the repeat loop")
	var inn_src := FileAccess.get_file_as_string("res://scripts/yuheng/yuheng_inn/inn_boss.gd")
	_expect(not inn_src.contains('set_flag("met_yuheng_teahouse_boss"'), "talking to the inn keeper must not mark the tea house keeper as met")
	for f in ["event_market_choice_observe", "event_yuheng_market_melody", "met_yuheng_inn_boss"]:
		gs.set_flag(f, false)


func _run() -> void:
	Dialog = load("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/tea_house_night_dialog.gd")
	var reunion := [{"text": "REUNION"}]
	var seen := {}
	for key: String in ["boss", "servant"]:
		for button: bool in [false, true]:
			for day: bool in [false, true]:
				for night: bool in [false, true]:
					_set_state(day, night, not button, button)
					var lines: Array = Dialog.lines_for(key, _npc(true), 1, "p", reunion)
					var label := "%s button=%s day=%s night=%s" % [key, button, day, night]
					_expect(not lines.is_empty(), "%s has lines" % label)
					if lines.is_empty():
						continue
					var first := String(lines[0].get("text", ""))
					if not button and day and not night:
						_expect(first == "REUNION", "%s keeps the original reunion lines" % label)
					else:
						_expect(first != "REUNION", "%s has its own lines" % label)
					# 拿銅釦以前、夜晚已經說過一次：不分白天有沒有說過，共用同一組循環對白
					var sig := key + "|" + JSON.stringify(lines)
					if not (not button and night and day):
						_expect(not seen.has(sig), "%s is different from every other case" % label)
					seen[sig] = true
	_set_state(true, true, true, false)
	_expect(Dialog.lines_for("boss", _npc(false), 1, "p", reunion).is_empty(), "day scene never gets night lines")
	_set_state(false, false, false, true)
	_expect(Dialog.lines_for("boss", _npc(false), 1, "p", reunion).is_empty(), "day scene after the button is left to the day script")
	_set_state(false, false, false, false)
	_expect(Dialog.lines_for("boss", _npc(true), 1, "p", reunion).is_empty(), "night scene before the story window is left to the old logic")
	_check_after_button_witness()
	_check_keeper_first_meeting()
	_check_day_stages()
	_check_huiyin_revisit()
	_set_state(false, false, false, false)
	Dialog.mark_talked("boss", _npc(true))
	_expect(root.get_node("GlobalState").get_flag("met_teahouse_boss_night"), "talking at night marks the night flag")
	Dialog.mark_talked("servant", _npc(false))
	_expect(root.get_node("GlobalState").get_flag("met_teahouse_servant_day"), "talking by day marks the day flag")
	if _failures.is_empty():
		print("PASS: tea house night dialog (%d distinct cases)" % seen.size())
		quit(0)
	else:
		for message: String in _failures:
			push_error("FAIL: " + message)
		quit(1)
