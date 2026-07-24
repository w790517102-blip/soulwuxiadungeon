extends SceneTree

const SkillExecutorScript = preload("res://scripts/battlescripts/SkillExecutor.gd")
const ItemDBScript = preload("res://scripts/db/ItemDB.gd")
const StatusEffectManagerScript = preload("res://scripts/battle/StatusEffectManager.gd")

const FIRE_TALISMAN_ID := "item_fire_talisman"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_item_data()
	_test_atk_up_status_affects_damage()
	_test_atk_up_does_not_touch_resources_or_primary_stats()
	_test_refresh_not_stack_and_duration()

	if _failures.is_empty():
		print("PASS: fire talisman atk buff damage regression")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_item_data() -> void:
	var item := ItemDBScript.get_def(FIRE_TALISMAN_ID)
	_expect(String(item.get("id", "")) == FIRE_TALISMAN_ID, "item id")
	_expect(String(item.get("effect", "")) == "fire_talisman", "effect key")
	_expect(int(item.get("amount", 0)) == 15, "ally atk flat amount")
	_expect(int(item.get("turns", 0)) == 3, "ally atk turns")
	_expect(int(item.get("enemy_damage", 0)) == 30, "enemy fixed damage")
	_expect(String(item.get("target_scope", "")) == "all_single", "target scope")


func _test_atk_up_status_affects_damage() -> void:
	var status_manager = StatusEffectManagerScript.new()
	var actor := _make_actor(20)
	var ok := bool(status_manager.apply_effect(actor, "atk_up", {"atk_delta": 15}, 3))
	_expect(ok, "atk_up applies")
	_expect(int(actor.get("base_atk", 0)) == 20, "base_atk remains unchanged")
	_expect(int(actor.get("atk", 0)) == 35, "runtime atk is recalculated")
	_expect(_has_status(actor, "atk_up"), "atk_up status exists")

	var stale_actor := actor.duplicate(true)
	stale_actor["atk"] = 20
	var skill := _make_attack_skill()
	seed(20260724)
	var before := SkillExecutorScript.new().execute(_make_actor(20), _make_enemy(), skill, {})
	seed(20260724)
	var after := SkillExecutorScript.new().execute(stale_actor, _make_enemy(), skill, {})
	_expect(int(before.get("damage", 0)) == 20, "damage before buff")
	_expect(int(after.get("base_atk", 0)) == 20, "resolver reports base atk")
	_expect(int(after.get("effective_atk", 0)) == 35, "resolver reports effective atk")
	_expect(int(after.get("atk_status_delta", 0)) == 15, "resolver reports atk status delta")
	_expect(int(after.get("damage", 0)) == 35, "damage after buff uses effective atk")
	status_manager.free()


func _test_atk_up_does_not_touch_resources_or_primary_stats() -> void:
	var status_manager = StatusEffectManagerScript.new()
	var actor := _make_actor(20)
	var watched_keys := [
		"hp",
		"max_hp",
		"mp",
		"max_mp",
		"def",
		"speed",
		"accuracy",
		"evasion",
		"str",
		"agi",
		"int",
		"con",
		"luck",
	]
	var before := _snapshot(actor, watched_keys)
	var ok := bool(status_manager.apply_effect(actor, "atk_up", {"atk_delta": 15}, 3))
	var after_apply := _snapshot(actor, watched_keys)
	_expect(ok, "atk_up applies for resource guard")
	_expect(_snapshots_equal(before, after_apply), "atk_up does not alter HP MP or primary stats")
	_expect(int(actor.get("atk", 0)) == 35, "atk_up still changes atk")

	status_manager.tick_end_of_turn([actor])
	status_manager.tick_end_of_turn([actor])
	status_manager.tick_end_of_turn([actor])
	var after_expire := _snapshot(actor, watched_keys)
	_expect(_snapshots_equal(before, after_expire), "atk_up expiry does not alter HP MP or primary stats")
	_expect(int(actor.get("atk", 0)) == 20, "atk_up expiry restores atk only")
	status_manager.free()


func _test_refresh_not_stack_and_duration() -> void:
	var status_manager = StatusEffectManagerScript.new()
	var actor := _make_actor(20)
	var ok1 := bool(status_manager.apply_effect(actor, "atk_up", {"atk_delta": 15}, 3))
	var ok2 := bool(status_manager.apply_effect(actor, "atk_up", {"atk_delta": 15}, 3))
	_expect(ok1 and ok2, "atk_up refresh applies")
	_expect(int(actor.get("atk", 0)) == 35, "atk_up refresh does not stack")
	_expect(int(actor.get("status_effects", {}).get("atk_up", {}).get("turns_left", 0)) == 3, "atk_up refreshes turns")
	status_manager.tick_end_of_turn([actor])
	_expect(int(actor.get("atk", 0)) == 35, "atk_up remains after first end-of-round tick")
	_expect(int(actor.get("status_effects", {}).get("atk_up", {}).get("turns_left", 0)) == 2, "atk_up decrements at end of round")
	status_manager.tick_end_of_turn([actor])
	status_manager.tick_end_of_turn([actor])
	_expect(not _has_status(actor, "atk_up"), "atk_up expires")
	_expect(int(actor.get("atk", 0)) == 20, "atk returns to base after expiry")
	status_manager.free()


func _make_actor(atk: int) -> Dictionary:
	return {
		"id": "liuyu",
		"name": "Liuyu",
		"hp": 176,
		"max_hp": 240,
		"mp": 41,
		"max_mp": 88,
		"atk": atk,
		"base_atk": atk,
		"battle_base_atk": atk,
		"def": 7,
		"base_def": 7,
		"battle_base_def": 7,
		"speed": 13,
		"base_speed": 13,
		"battle_base_speed": 13,
		"accuracy": 96,
		"base_accuracy": 96,
		"battle_base_accuracy": 96,
		"evasion": 4,
		"base_evasion": 4,
		"battle_base_evasion": 4,
		"str": 11,
		"agi": 12,
		"int": 13,
		"con": 14,
		"luck": 15,
		"base_str": 6,
		"base_agi": 7,
		"base_int": 8,
		"base_con": 9,
		"base_luck": 10,
		"battle_base_max_hp": 240,
		"battle_base_max_mp": 88,
		"base_max_hp": 240,
		"base_max_mp": 88,
		"element": "",
		"status_effects": {},
	}


func _make_enemy() -> Dictionary:
	return {
		"id": "training_dummy",
		"name": "Dummy",
		"hp": 200,
		"max_hp": 200,
		"atk": 1,
		"def": 0,
		"agi": 0,
		"luck": 0,
		"element": "",
		"status_effects": {},
	}


func _make_attack_skill() -> Dictionary:
	return {
		"id": "test_attack",
		"name": "Test Attack",
		"kind": "",
		"weapon_type": "",
		"power": 1.0,
		"crit_rate_bonus": -1.0,
	}


func _has_status(actor: Dictionary, effect_id: String) -> bool:
	var effects = actor.get("status_effects", {})
	return typeof(effects) == TYPE_DICTIONARY and (effects as Dictionary).has(effect_id)


func _snapshot(actor: Dictionary, keys: Array) -> Dictionary:
	var out := {}
	for key in keys:
		out[String(key)] = actor.get(String(key), null)
	return out


func _snapshots_equal(before: Dictionary, after: Dictionary) -> bool:
	for key in before.keys():
		if before.get(key) != after.get(key):
			push_error("Snapshot changed: %s before=%s after=%s" % [key, str(before.get(key)), str(after.get(key))])
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
