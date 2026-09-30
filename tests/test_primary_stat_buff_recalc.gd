extends SceneTree

const StatusEffectManagerScript = preload("res://scripts/battle/StatusEffectManager.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_str_buff_updates_atk_without_repairing_drifted_hp()
	_test_agi_buff_updates_only_agi_dependents()
	_test_int_buff_updates_max_mp_without_restoring_mp()
	_test_con_buff_updates_hp_and_def_without_healing()
	_test_luck_buff_updates_luck_dependents_only()

	if _failures.is_empty():
		print("PASS: primary stat buff dependency recalculation")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_str_buff_updates_atk_without_repairing_drifted_hp() -> void:
	var manager = StatusEffectManagerScript.new()
	var actor := _make_actor()
	actor["max_hp"] = 192
	var applied := bool(manager.apply_effect(actor, "stat_buff", {"stat_key": "str", "stat_delta": 10}, 3))
	_expect(applied, "STR buff applies")
	_expect(int(actor.get("str", 0)) == 20, "STR buff updates STR before derived stats")
	_expect(int(actor.get("atk", 0)) == 44, "STR buff recalculates ATK from the new STR")
	_expect(int(actor.get("con", 0)) == 10, "STR buff does not alter CON")
	_expect(int(actor.get("max_hp", 0)) == 192, "STR buff does not repair unrelated drifted max HP")
	_expect(int(actor.get("hp", 0)) == 150, "STR buff does not alter current HP")

	manager.apply_effect(actor, "stat_buff", {"stat_key": "str", "stat_delta": 6}, 4)
	_expect(int(actor.get("str", 0)) == 16, "same STR status replaces strength instead of stacking")
	_expect(int(actor.get("atk", 0)) == 39, "refreshed STR status recalculates ATK from replacement strength")
	_expect(int(actor.get("status_effects", {}).get("stat_buff_str", {}).get("turns_left", 0)) == 4, "same STR status refreshes duration")
	_expect(int(actor.get("max_hp", 0)) == 192, "STR status refresh does not touch max HP")

	manager.remove_effect(actor, "stat_buff_str")
	_expect(int(actor.get("str", 0)) == 10, "STR returns to battle baseline on removal")
	_expect(int(actor.get("atk", 0)) == 32, "ATK returns after STR buff removal")
	_expect(int(actor.get("max_hp", 0)) == 192, "STR buff removal still does not touch max HP")
	manager.free()


func _test_agi_buff_updates_only_agi_dependents() -> void:
	var manager = StatusEffectManagerScript.new()
	var actor := _make_actor()
	manager.apply_effect(actor, "stat_buff", {"stat_key": "agi", "stat_delta": 10}, 3)
	_expect(int(actor.get("agi", 0)) == 20, "AGI buff updates AGI")
	_expect(int(actor.get("speed", 0)) == 27, "AGI buff recalculates speed")
	_expect(int(actor.get("accuracy", 0)) == 130, "AGI buff recalculates accuracy")
	_expect(int(actor.get("evasion", 0)) == 30, "AGI buff recalculates evasion")
	_expect(int(actor.get("max_hp", 0)) == 202, "AGI buff does not alter max HP")
	manager.free()


func _test_int_buff_updates_max_mp_without_restoring_mp() -> void:
	var manager = StatusEffectManagerScript.new()
	var actor := _make_actor()
	manager.apply_effect(actor, "stat_buff", {"stat_key": "int", "stat_delta": 10}, 3)
	_expect(int(actor.get("int", 0)) == 20, "INT buff updates INT")
	_expect(int(actor.get("max_mp", 0)) == 175, "INT buff recalculates max MP")
	_expect(int(actor.get("mp", 0)) == 80, "INT buff does not restore current MP")
	_expect(int(actor.get("max_hp", 0)) == 202, "INT buff does not alter max HP")
	manager.free()


func _test_con_buff_updates_hp_and_def_without_healing() -> void:
	var manager = StatusEffectManagerScript.new()
	var actor := _make_actor()
	manager.apply_effect(actor, "stat_buff", {"stat_key": "con", "stat_delta": 10}, 3)
	_expect(int(actor.get("con", 0)) == 20, "CON buff updates CON")
	_expect(int(actor.get("max_hp", 0)) == 220, "CON buff recalculates max HP")
	_expect(int(actor.get("def", 0)) == 22, "CON buff recalculates DEF")
	_expect(int(actor.get("hp", 0)) == 150, "CON buff does not restore current HP")

	actor["hp"] = 220
	manager.remove_effect(actor, "stat_buff_con")
	_expect(int(actor.get("max_hp", 0)) == 202, "max HP returns after CON buff removal")
	_expect(int(actor.get("hp", 0)) == 202, "current HP clamps only when restored max HP is lower")
	manager.free()


func _test_luck_buff_updates_luck_dependents_only() -> void:
	var manager = StatusEffectManagerScript.new()
	var actor := _make_actor()
	manager.apply_effect(actor, "stat_buff", {"stat_key": "luck", "stat_delta": 10}, 3)
	_expect(int(actor.get("luck", 0)) == 20, "LUCK buff updates luck")
	_expect(int(actor.get("accuracy", 0)) == 126, "LUCK buff recalculates accuracy")
	_expect(int(actor.get("evasion", 0)) == 26, "LUCK buff recalculates evasion")
	_expect(is_equal_approx(float(actor.get("crit_rate", 0.0)), 0.09), "LUCK buff recalculates crit rate")
	_expect(int(actor.get("max_hp", 0)) == 202, "LUCK buff does not alter max HP")
	_expect(int(actor.get("max_mp", 0)) == 160, "LUCK buff does not alter max MP")
	manager.free()


func _make_actor() -> Dictionary:
	return {
		"id": "liuyu",
		"hp": 150,
		"max_hp": 202,
		"mp": 80,
		"max_mp": 160,
		"atk": 32,
		"def": 14,
		"speed": 17,
		"accuracy": 123,
		"evasion": 23,
		"crit_rate": 0.07,
		"str": 10,
		"agi": 10,
		"int": 10,
		"con": 10,
		"luck": 10,
		"battle_base_max_hp": 202,
		"battle_base_max_mp": 160,
		"battle_base_atk": 32,
		"battle_base_def": 14,
		"battle_base_speed": 17,
		"battle_base_accuracy": 123,
		"battle_base_evasion": 23,
		"battle_base_crit_rate": 0.07,
		"battle_base_str": 10,
		"battle_base_agi": 10,
		"battle_base_int": 10,
		"battle_base_con": 10,
		"battle_base_luck": 10,
		"base_max_hp": 202,
		"base_max_mp": 160,
		"base_atk": 32,
		"base_def": 14,
		"base_speed": 17,
		"base_accuracy": 123,
		"base_evasion": 23,
		"base_str": 10,
		"base_agi": 10,
		"base_int": 10,
		"base_con": 10,
		"base_luck": 10,
		"status_effects": {},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
