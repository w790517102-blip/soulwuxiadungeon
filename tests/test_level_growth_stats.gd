extends SceneTree

const TeamDataManagerScript = preload("res://scripts/battlescripts/TeamDataManager.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_single_level_growth_for_story_party()
	_test_multi_level_growth_applies_each_step()
	_test_inactive_actor_is_not_modified()
	_test_level_growth_survives_export_import()

	if _failures.is_empty():
		print("PASS: level growth permanent stat regression")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_single_level_growth_for_story_party() -> void:
	var team = _make_team(["liuyu", "shumian", "lieshao"])
	var before := _snapshot_all(team, ["liuyu", "shumian", "lieshao"])
	var events := team.add_exp_to_active_party(50)
	_expect(events.size() == 3, "all three active actors level once")

	_expect_level_delta(team, before, "liuyu", 1, {"str": 3}, {"max_hp": 20, "max_mp": 8, "atk": 4, "def": 1, "accuracy": 3, "evasion": 3})
	_expect_level_delta(team, before, "shumian", 1, {"int": 3}, {"max_hp": 14, "max_mp": 12, "atk": 3, "def": 0, "accuracy": 3, "evasion": 3})
	_expect_level_delta(team, before, "lieshao", 1, {"agi": 3}, {"max_hp": 16, "max_mp": 10, "atk": 3, "def": 1, "accuracy": 3, "evasion": 3})

	team.free()


func _test_multi_level_growth_applies_each_step() -> void:
	var team = _make_team(["liuyu"])
	var before := _snapshot_actor(team.get_character_by_id("liuyu"))
	var events := team.add_exp_to_active_party(150)
	var actor := team.get_character_by_id("liuyu")

	_expect(events.size() == 3, "large exp applies three level-up events")
	_expect(int(actor.get("level", 0)) == int(before.get("level", 1)) + 3, "multi-level final level")
	_expect(int(actor.get("exp", -1)) == 0, "multi-level exp remainder")
	_expect(int(actor.get("base_str", 0)) == int(before.get("base_str", 0)) + 3, "multi-level str once")
	_expect(int(actor.get("base_agi", 0)) == int(before.get("base_agi", 0)) + 3, "multi-level agi once")
	_expect(int(actor.get("base_int", 0)) == int(before.get("base_int", 0)) + 3, "multi-level int once")
	_expect(int(actor.get("base_con", 0)) == int(before.get("base_con", 0)), "multi-level con not reached")
	_expect(int(actor.get("base_luck", 0)) == int(before.get("base_luck", 0)), "multi-level luck not reached")
	_expect(int(actor.get("base_atk", 0)) == int(before.get("base_atk", 0)) + 10, "multi-level atk includes job and stat_to_atk")

	team.free()


func _test_inactive_actor_is_not_modified() -> void:
	var team = _make_team(["liuyu"])
	var before_shumian := _snapshot_actor(team.get_character_by_id("shumian"))
	var before_lieshao := _snapshot_actor(team.get_character_by_id("lieshao"))

	team.add_exp_to_active_party(50)

	_expect_snapshot_same(before_shumian, _snapshot_actor(team.get_character_by_id("shumian")), "inactive shumian unchanged")
	_expect_snapshot_same(before_lieshao, _snapshot_actor(team.get_character_by_id("lieshao")), "inactive lieshao unchanged")
	team.free()


func _test_level_growth_survives_export_import() -> void:
	var team = _make_team(["liuyu", "shumian", "lieshao"])
	team.add_exp_to_active_party(50)
	var saved := team.export_team_state()

	var loaded = TeamDataManagerScript.new()
	loaded.import_team_state(saved)

	for actor_id in ["liuyu", "shumian", "lieshao"]:
		var before := _snapshot_actor(team.get_character_by_id(actor_id))
		var after := _snapshot_actor(loaded.get_character_by_id(actor_id))
		_expect_snapshot_same(before, after, "export/import keeps level growth for %s" % actor_id)

	team.free()
	loaded.free()


func _make_team(active_ids: Array):
	var team = TeamDataManagerScript.new()
	team._ready()
	team.current_team_ids = active_ids.duplicate()
	return team


func _snapshot_all(team, actor_ids: Array) -> Dictionary:
	var out := {}
	for actor_id in actor_ids:
		out[String(actor_id)] = _snapshot_actor(team.get_character_by_id(String(actor_id)))
	return out


func _snapshot_actor(actor: Dictionary) -> Dictionary:
	var keys := [
		"level",
		"exp",
		"stat_cycle_index",
		"base_str",
		"base_agi",
		"base_int",
		"base_con",
		"base_luck",
		"base_max_hp",
		"base_max_mp",
		"base_atk",
		"base_def",
		"base_accuracy",
		"base_evasion",
		"str",
		"agi",
		"int",
		"con",
		"luck",
		"max_hp",
		"max_mp",
		"atk",
		"def",
		"speed",
		"accuracy",
		"evasion",
	]
	var out := {}
	for key in keys:
		out[key] = actor.get(key, null)
	return out


func _expect_level_delta(team, before_all: Dictionary, actor_id: String, level_delta: int, main_deltas: Dictionary, derived_base_deltas: Dictionary) -> void:
	var actor := team.get_character_by_id(actor_id)
	var before: Dictionary = before_all.get(actor_id, {})
	_expect(int(actor.get("level", 0)) == int(before.get("level", 1)) + level_delta, "%s level delta" % actor_id)
	_expect(int(actor.get("exp", -1)) == 0, "%s exp remainder" % actor_id)

	for stat_key in ["str", "agi", "int", "con", "luck"]:
		var expected_delta := int(main_deltas.get(stat_key, 0))
		var base_key := "base_%s" % stat_key
		_expect(int(actor.get(base_key, 0)) == int(before.get(base_key, 0)) + expected_delta, "%s %s growth" % [actor_id, stat_key])

	for stat_key in ["max_hp", "max_mp", "atk", "def", "accuracy", "evasion"]:
		var expected_delta := int(derived_base_deltas.get(stat_key, 0))
		var base_key := "base_%s" % stat_key
		_expect(int(actor.get(base_key, 0)) == int(before.get(base_key, 0)) + expected_delta, "%s %s base growth" % [actor_id, stat_key])


func _expect_snapshot_same(before: Dictionary, after: Dictionary, label: String) -> void:
	for key in before.keys():
		if before.get(key) != after.get(key):
			_failures.append("%s changed %s before=%s after=%s" % [label, key, str(before.get(key)), str(after.get(key))])
			return


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
