extends SceneTree
## All six 臨符 are cards in the ADB now: each skill's data, and what each effect family really does
## to damage / hit chance when a card is beside the character. Run:
## --headless --path . --script tests/test_linfu_families.gd

var _failures: Array[String] = []
var _assertions: int = 0
const CARDS := {
	"skill_linfu_humai": ["DEFENSE_UP", "護脈符"],
	"skill_qihui_talisman": ["INTELLECT_UP", "啟慧符"],
	"skill_jufu_talisman": ["LUCK_UP", "聚福符"],
	"skill_linfu_ranfeng": ["ATTACK_UP", "燃鋒符"],
	"skill_linfu_guyuan": ["CONSTITUTION_UP", "固元符"],
	"skill_linfu_jiying": ["AGILITY_UP", "疾影符"],
	"skill_linfu_zhuangli": ["STRENGTH_UP", "壯力符"],
}


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	var db = load("res://scripts/db/SkillDB.gd").new()
	for skill_id: String in CARDS.keys():
		var skill: Dictionary = db.get_skill(skill_id)
		var config: Dictionary = skill.get("stage_entity", {})
		_expect(not config.is_empty() and config.entity_type == "linfu_talisman" and bool(config.joins_turn_order), "%s is a card in the ADB" % skill_id)
		_expect(skill.effects.is_empty() and int(skill.mp_cost) == 7, "%s has no actor buff and still costs its 7 MP" % skill_id)
		var effects: Array = config.get("adjacency_effects", [])
		_expect(effects.size() == 1 and String(effects[0].family) == String(CARDS[skill_id][0]), "%s gives %s" % [skill_id, CARDS[skill_id][0]])
		_expect(String(config.display_name) == String(CARDS[skill_id][1]) and int(config.duration_turns) == 3, "%s: named %s, three activations" % [skill_id, CARDS[skill_id][1]])
		_expect(ResourceLoader.exists(String(config.card_config.art)), "%s has its card art" % skill_id)

	var state: Node = root.get_node("GlobalState")
	state.remove_meta("pending_battle_context")
	var battle: Node = (load("res://scenes/battle_scene.tscn") as PackedScene).instantiate()
	battle.presentation_mode = 2
	root.add_child(battle)
	await process_frame
	await process_frame
	var executor: Node = battle.get_node("BattleController").skill_executor
	var user := {"id": "u", "name": "甲", "hp": 100, "max_hp": 100, "atk": 30, "def": 10, "str": 10, "agi": 10, "int": 10, "con": 10, "luck": 10, "accuracy": 100, "evasion": 0, "crit_rate_bonus": -1.0}
	var target := {"id": "t", "name": "乙", "hp": 5000, "max_hp": 5000, "atk": 10, "def": 20, "str": 10, "agi": 10, "int": 10, "con": 10, "luck": 10, "accuracy": 100, "evasion": 0, "is_enemy": true}
	var plain: Dictionary = {"id": "basic_attack", "name": "普通攻擊", "power": 1.0, "target_scope": "enemy_single"}
	var scaled: Dictionary = {"id": "int_skill", "name": "智", "power": 1.0, "target_scope": "enemy_single", "effects": [{"type": "damage", "power": 1.0}], "stat_scaling": {"int": 1.0}}
	var base: Dictionary = _run_once(executor, user, target, plain, {})
	var base_int: Dictionary = _run_once(executor, user, target, scaled, {})
	_expect(int(base.damage) > 0, "baseline damage")
	_expect(int(_run_once(executor, user, target, plain, {"ATTACK_UP": 0.15}).damage) > int(base.damage), "ATTACK_UP: the attacker hits harder")
	_expect(int(_run_once(executor, user, target, plain, {"STRENGTH_UP": 10.0}).damage) > int(base.damage), "STRENGTH_UP: the attacker hits harder")
	_expect(int(_run_once(executor, user, target, plain, {"CONSTITUTION_UP": 10.0}, true).damage) < int(_run_once(executor, user, target, plain, {}, true).damage), "CONSTITUTION_UP: the defender takes less")
	_expect(int(_run_once(executor, user, target, plain, {"DEFENSE_UP": 0.15}, true).damage) < int(_run_once(executor, user, target, plain, {}, true).damage), "DEFENSE_UP: the defender takes less")
	_expect(int(_run_once(executor, user, target, scaled, {"INTELLECT_UP": 10.0}).damage) > int(base_int.damage), "INTELLECT_UP: an intellect-scaled skill hits harder")
	_expect(int(_run_once(executor, user, target, plain, {"AGILITY_UP": 10.0}, true).hit_chance) < int(_run_once(executor, user, target, plain, {}, true).hit_chance), "AGILITY_UP: the defender is harder to hit")
	_expect(int(_run_once(executor, user, target, plain, {"LUCK_UP": 10.0}, true).hit_chance) < int(_run_once(executor, user, target, plain, {}, true).hit_chance), "LUCK_UP: the defender is harder to hit")

	battle.queue_free()
	if _failures.is_empty():
		print("PASS: ", _assertions, " assertions; linfu families")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


## One resolved strike with the cards' effects forced to `effects` (family -> value) for whoever is hit
## (`on_target`) or for the attacker. Same random seed every time.
func _run_once(executor: Node, attacker: Dictionary, target: Dictionary, skill: Dictionary, effects: Dictionary, on_target: bool = false) -> Dictionary:
	executor.adjacency_provider = func(actor: Dictionary, family: String) -> float:
		var wanted: String = String(target.get("id", "")) if on_target else String(attacker.get("id", ""))
		return float(effects.get(family, 0.0)) if String(actor.get("id", "")) == wanted else 0.0
	seed(99)
	var copy: Dictionary = target.duplicate(true)
	var result: Dictionary = executor.execute(attacker, copy, skill, {})
	executor.adjacency_provider = Callable()
	return result
