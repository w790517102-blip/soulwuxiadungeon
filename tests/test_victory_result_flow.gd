extends SceneTree

const BattleUIScript = preload("res://scripts/battlescripts/BattleUI.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var ui = BattleUIScript.new()
	_test_no_growth_finishes_after_rewards(ui)
	_test_skill_only_opens_growth(ui)
	_test_level_up_opens_one_growth_phase(ui)
	_test_level_and_skill_open_one_growth_phase(ui)
	_test_multi_actor_growth_uses_one_combined_body(ui)
	_test_growth_rearm_waits_for_key_release(ui)
	ui.free()

	if _failures.is_empty():
		print("PASS: victory result phase regression")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_no_growth_finishes_after_rewards(ui) -> void:
	var result := _result([], [])
	_expect(
		ui._next_battle_result_phase(BattleUIScript.BattleResultPhase.REWARDS, result) == BattleUIScript.BattleResultPhase.NONE,
		"reward confirmation finishes immediately without level or skill growth"
	)


func _test_skill_only_opens_growth(ui) -> void:
	var result := _result([], [{
		"actor_id": "liuyu",
		"actor_name": "劉語塵",
		"skill_id": "test_skill",
		"skill_name": "測試武學",
	}])
	_expect(
		ui._next_battle_result_phase(BattleUIScript.BattleResultPhase.REWARDS, result) == BattleUIScript.BattleResultPhase.GROWTH,
		"skill-only result opens Growth"
	)


func _test_level_up_opens_one_growth_phase(ui) -> void:
	var result := _result([{
		"actor_id": "liuyu",
		"actor_name": "劉語塵",
		"old_level": 8,
		"new_level": 9,
	}], [])
	_expect(
		ui._next_battle_result_phase(BattleUIScript.BattleResultPhase.REWARDS, result) == BattleUIScript.BattleResultPhase.GROWTH,
		"level-only result opens Growth"
	)


func _test_level_and_skill_open_one_growth_phase(ui) -> void:
	var result := _result([{
		"actor_id": "liuyu",
		"actor_name": "劉語塵",
		"old_level": 8,
		"new_level": 9,
	}], [{
		"actor_id": "liuyu",
		"actor_name": "劉語塵",
		"skill_id": "skill_liedaoposhi",
		"skill_name": "烈刀破勢",
	}])
	_expect(
		ui._next_battle_result_phase(BattleUIScript.BattleResultPhase.REWARDS, result) == BattleUIScript.BattleResultPhase.GROWTH,
		"combined level and skill result opens Growth"
	)
	_expect(
		ui._next_battle_result_phase(BattleUIScript.BattleResultPhase.GROWTH, result) == BattleUIScript.BattleResultPhase.NONE,
		"Growth confirmation finishes instead of opening another actor window"
	)
	var body: String = ui._build_growth_result_block(result)
	_expect(body.contains("劉語塵　Lv.8 → Lv.9"), "Growth body displays the collapsed level range")
	_expect(body.contains("悟得「烈刀破勢」"), "Growth body displays the structured skill event")


func _test_multi_actor_growth_uses_one_combined_body(ui) -> void:
	var result := _result([
		{"actor_id": "liuyu", "actor_name": "劉語塵", "old_level": 10, "new_level": 11},
		{"actor_id": "shumian", "actor_name": "白書眠", "old_level": 6, "new_level": 7},
	], [{
		"actor_id": "liuyu",
		"actor_name": "劉語塵",
		"skill_id": "skill_luanyinsuiqin",
		"skill_name": "亂音碎琴",
	}])
	var body: String = ui._build_growth_result_block(result)
	_expect(body.contains("劉語塵　Lv.10 → Lv.11"), "combined Growth contains LiuYu")
	_expect(body.contains("白書眠　Lv.6 → Lv.7"), "combined Growth contains Shumian")
	_expect(body.contains("悟得「亂音碎琴」"), "combined Growth includes all battle skill events")


func _test_growth_rearm_waits_for_key_release(ui) -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	var release := InputEventKey.new()
	release.keycode = KEY_SPACE
	release.pressed = false
	_expect(not ui._is_battle_result_confirm_release(press), "held Space cannot rearm the Growth confirm")
	_expect(ui._is_battle_result_confirm_release(release), "released Space rearms Growth for a fresh press")


func _result(level_ups: Array, skills_learned: Array) -> Dictionary:
	return {
		"growth_result": {
			"level_ups": level_ups,
			"skills_learned": skills_learned,
		},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
