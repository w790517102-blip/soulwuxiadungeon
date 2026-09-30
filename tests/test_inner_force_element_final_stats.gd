extends SceneTree

const InnerForceDB = preload("res://scripts/battlescripts/InnerForceDB.gd")
const SkillExecutorScript = preload("res://scripts/battlescripts/SkillExecutor.gd")
const StatusEffectManagerScript = preload("res://scripts/battle/StatusEffectManager.gd")
const TurnManagerScript = preload("res://scripts/battlescripts/TurnManager.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_element_final_stats()
	_test_status_delta_is_weighted_after_addition()
	_test_element_advantage_cycle()
	_test_attack_and_defense_are_weighted_before_subtraction()
	_test_skill_executor_uses_weighted_attack_and_defense()
	_test_turn_manager_uses_final_speed()
	_test_repeated_resolution_does_not_accumulate()
	_test_unknown_element_is_unchanged()
	_test_ling_feng_jue_boosts_fist_only()
	_test_hit_resolution_consumes_accuracy_and_evasion_once()

	if _failures.is_empty():
		print("PASS: inner-force element final stat regression")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_element_final_stats() -> void:
	_expect(_resolve_int("快", "speed", 100) == 115, "fast speed x1.15")
	_expect(_resolve_int("快", "def", 100) == 90, "fast def x0.90")
	_expect(_resolve_int("柔", "evasion", 100) == 115, "soft evasion x1.15")
	_expect(is_equal_approx(_resolve_float("柔", "crit_rate", 0.20), 0.18), "soft final crit x0.90")
	_expect(_resolve_int("遲", "accuracy", 100) == 115, "slow accuracy x1.15")
	_expect(_resolve_int("遲", "evasion", 100) == 90, "slow evasion x0.90")
	_expect(_resolve_int("剛", "def", 100) == 115, "hard def x1.15")
	_expect(_resolve_int("剛", "speed", 100) == 90, "hard speed x0.90")


func _test_status_delta_is_weighted_after_addition() -> void:
	var status_manager = StatusEffectManagerScript.new()
	var actor := {
		"def": 50,
		"base_def": 50,
		"battle_base_def": 50,
		"element": "剛",
		"status_effects": {},
	}
	var applied := bool(status_manager.apply_effect(actor, "break_def", {"def_delta": -10}, 3))
	_expect(applied, "def down applies")
	_expect(int(actor.get("def", 0)) == 40, "status delta is applied to battle baseline first")
	_expect(_resolve_int("剛", "def", int(actor.get("def", 0))) == 46, "hard def weights base plus status delta")
	status_manager.remove_effect(actor, "break_def")
	_expect(int(actor.get("def", 0)) == 50, "status expiry restores battle baseline")
	_expect(_resolve_int("剛", "def", int(actor.get("def", 0))) == 58, "restored baseline is weighted once")
	status_manager.free()


func _test_element_advantage_cycle() -> void:
	for pair in [["快", "遲"], ["遲", "柔"], ["柔", "剛"], ["剛", "快"]]:
		_expect(is_equal_approx(
			InnerForceDB.resolve_element_advantage_multiplier(String(pair[0]), String(pair[1])),
			1.5
		), "%s over %s uses x1.5" % [pair[0], pair[1]])
	_expect(is_equal_approx(InnerForceDB.resolve_element_advantage_multiplier("快", "柔"), 1.0), "non-advantage uses x1.0")
	_expect(is_equal_approx(InnerForceDB.resolve_element_advantage_multiplier("", ""), 1.0), "empty elements use x1.0")


func _test_attack_and_defense_are_weighted_before_subtraction() -> void:
	var weighted_attack := int(round(100.0 * InnerForceDB.resolve_element_advantage_multiplier("柔", "剛")))
	var weighted_def := _resolve_int("剛", "def", 10)
	_expect(weighted_attack - weighted_def == 138, "100 x1.5 minus round(10 x1.15) equals 138")


func _test_skill_executor_uses_weighted_attack_and_defense() -> void:
	var executor = SkillExecutorScript.new()
	var user := _make_combat_actor("attacker", 100, 0, "柔")
	user["accuracy"] = 1000
	user["battle_base_accuracy"] = 1000
	var target := _make_combat_actor("defender", 1, 10, "剛")
	var skill := {
		"id": "element_weight_test",
		"name": "Element Weight Test",
		"kind": "",
		"weapon_type": "",
		"power": 1.0,
		"crit_rate_bonus": -1.0,
	}
	seed(20260806)
	var result: Dictionary = executor.execute(user, target, skill, {})
	_expect(bool(result.get("hit", false)), "weighted damage integration attack hits")
	_expect(int(result.get("damage", 0)) == 138, "SkillExecutor applies advantage before weighted defense")
	_expect(int(user.get("atk", 0)) == 100, "attack does not write final weighting into attacker")
	_expect(int(target.get("def", 0)) == 10, "attack does not write final weighting into defender")
	executor.free()


func _test_turn_manager_uses_final_speed() -> void:
	var turn_manager = TurnManagerScript.new()
	var fast_actor := {"element": "快", "speed": 100, "battle_order_index": 1}
	var neutral_actor := {"element": "柔", "speed": 110, "battle_order_index": 0}
	_expect(turn_manager._compare_speed(fast_actor, neutral_actor), "final fast speed 115 sorts before raw speed 110")
	turn_manager.free()


func _test_repeated_resolution_does_not_accumulate() -> void:
	var raw_speed := 100
	_expect(_resolve_int("快", "speed", raw_speed) == 115, "first fast resolution")
	_expect(_resolve_int("剛", "speed", raw_speed) == 90, "first hard resolution")
	_expect(_resolve_int("快", "speed", raw_speed) == 115, "second fast resolution")
	_expect(_resolve_int("剛", "speed", raw_speed) == 90, "second hard resolution")


func _test_unknown_element_is_unchanged() -> void:
	_expect(_resolve_int("", "speed", 100) == 100, "empty element unchanged")
	_expect(_resolve_int("未知", "def", 100) == 100, "unknown element unchanged")
	_expect(is_equal_approx(_resolve_float("快", "crit_rate", 0.20), 0.20), "unaffected stat unchanged")
	_expect(is_equal_approx(_resolve_float("柔", "crit_rate", 2.0), 0.95), "final crit keeps existing cap")


func _test_ling_feng_jue_boosts_fist_only() -> void:
	var force: Dictionary = InnerForceDB.INNER_FORCES["ling_feng_jue"]
	_expect(String(force.get("element", "")) == "快", "Ling Feng Jue retains the fast element")
	_expect(String(force.get("boost_weapon", "")) == "拳", "Ling Feng Jue targets fist skills")
	_expect(is_equal_approx(float(force.get("boost_damage_pct", 0.0)), 0.20), "Ling Feng Jue grants fist damage +20%")
	_expect(int(force.get("weapon_accuracy_flat_bonus", 0)) == 10, "Ling Feng Jue grants fist accuracy +10")

	var executor = SkillExecutorScript.new()
	var user := _make_combat_actor("shumian", 100, 0, "快")
	user["accuracy"] = 40
	user["battle_base_accuracy"] = 40
	var fist_skill := {"id": "fist_test", "name": "Fist", "weapon_type": "拳", "power": 1.0, "crit_rate_bonus": -1.0}
	var palm_skill := {"id": "palm_test", "name": "Palm", "weapon_type": "掌", "power": 1.0, "crit_rate_bonus": -1.0}
	var fist_result: Dictionary = executor.execute(user, _make_combat_actor("fist_target", 1, 0, "柔"), fist_skill, force)
	var palm_result: Dictionary = executor.execute(user, _make_combat_actor("palm_target", 1, 0, "柔"), palm_skill, force)
	_expect(bool(fist_result.get("boost_applied", false)), "fist damage uses Ling Feng Jue boost")
	_expect(not bool(palm_result.get("boost_applied", false)), "palm damage does not use Ling Feng Jue boost")
	_expect(int(fist_result.get("hit_chance", 0)) == int(palm_result.get("hit_chance", 0)) + 10, "only fist receives the +10 accuracy")
	executor.free()


func _test_hit_resolution_consumes_accuracy_and_evasion_once() -> void:
	var executor = SkillExecutorScript.new()
	var baseline_user := _make_combat_actor("baseline_user", 10, 0, "")
	var high_agi_luck_user := _make_combat_actor("high_agi_luck_user", 10, 0, "")
	var baseline_target := _make_combat_actor("baseline_target", 10, 0, "")
	var high_agi_luck_target := _make_combat_actor("high_agi_luck_target", 10, 0, "")
	high_agi_luck_user["agi"] = 99
	high_agi_luck_user["luck"] = 99
	high_agi_luck_target["agi"] = 99
	high_agi_luck_target["luck"] = 99

	var baseline: Dictionary = executor._roll_hit(baseline_user, baseline_target)
	var high_attacker_stats: Dictionary = executor._roll_hit(high_agi_luck_user, baseline_target)
	var high_defender_stats: Dictionary = executor._roll_hit(baseline_user, high_agi_luck_target)
	_expect(int(baseline.get("chance", 0)) == 75, "equal final Accuracy/Evasion use the base 75% hit chance")
	_expect(int(high_attacker_stats.get("chance", 0)) == 75, "attacker AGI/Luck are not added after final Accuracy")
	_expect(int(high_defender_stats.get("chance", 0)) == 75, "defender AGI/Luck are not added after final Evasion")

	var soft_target := _make_combat_actor("soft_target", 10, 0, "柔")
	soft_target["evasion"] = 20
	var soft_result: Dictionary = executor._roll_hit(baseline_user, soft_target)
	_expect(int(soft_result.get("chance", 0)) == 52, "soft final Evasion x1.15 remains in the hit contest")

	var debuffed_soft_target := soft_target.duplicate(true)
	debuffed_soft_target["evasion"] = 10
	var debuffed_result: Dictionary = executor._roll_hit(baseline_user, debuffed_soft_target)
	_expect(int(debuffed_result.get("chance", 0)) == 63, "an Evasion -10 debuff remains effective before soft weighting")

	var enemy_without_main_stats := {
		"id": "enemy_without_main_stats",
		"accuracy": 100,
		"evasion": 0,
		"element": "",
	}
	var enemy_result: Dictionary = executor._roll_hit(enemy_without_main_stats, baseline_target)
	_expect(int(enemy_result.get("chance", 0)) == 75, "enemy actors need only final Accuracy/Evasion")
	executor.free()


func _make_combat_actor(actor_id: String, atk: int, defense: int, element: String) -> Dictionary:
	return {
		"id": actor_id,
		"name": actor_id,
		"hp": 500,
		"max_hp": 500,
		"atk": atk,
		"base_atk": atk,
		"battle_base_atk": atk,
		"def": defense,
		"base_def": defense,
		"battle_base_def": defense,
		"accuracy": 100,
		"evasion": 0,
		"agi": 0,
		"luck": 0,
		"element": element,
		"status_effects": {},
	}


func _resolve_int(element: String, stat_name: String, raw_value: int) -> int:
	return int(InnerForceDB.resolve_element_final_stat(element, stat_name, float(raw_value)))


func _resolve_float(element: String, stat_name: String, raw_value: float) -> float:
	return InnerForceDB.resolve_element_final_stat(element, stat_name, raw_value)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
