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
