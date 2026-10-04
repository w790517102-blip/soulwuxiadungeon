extends SceneTree
## 護脈符 through the real battle controller: the skill leaves a card in the ADB (not a buff), the
## covered characters follow the live order, the defense bonus really changes damage, and after
## three activations the card is gone. Run: --headless --path . --script tests/test_linfu_battle_flow.gd

var SkillDBScript: Script
const SKILL_ID := "skill_linfu_humai"
var _failures: Array[String] = []
var _assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	SkillDBScript = load("res://scripts/db/SkillDB.gd")
	var state: Node = root.get_node("GlobalState")
	state.remove_meta("pending_battle_context")
	var battle: Node = (load("res://scenes/battle_scene.tscn") as PackedScene).instantiate()
	battle.presentation_mode = 2
	root.add_child(battle)
	await process_frame
	await process_frame
	var controller: Node = battle.get_node("BattleController")
	controller.battle_ui = null
	controller.action_log_ui = null
	var skill: Dictionary = SkillDBScript.new().get_skill(SKILL_ID)
	_expect(skill.has("stage_entity") and skill.stage_entity.entity_type == "linfu_talisman", "護脈 is a stage-card skill, not a buff")
	_expect(skill.effects.is_empty() and not skill.has("positive_buff"), "it carries no actor buff effect")
	var party: Array = [
		{"id": "liuyu", "name": "劉語塵", "hp": 100, "max_hp": 100, "mp": 50, "max_mp": 50, "speed": 9, "atk": 20, "def": 20},
		{"id": "shumian", "name": "書眠", "hp": 80, "max_hp": 80, "mp": 40, "max_mp": 40, "speed": 14, "atk": 10, "def": 20},
	]
	var enemy: Dictionary = {"id": "foe", "name": "語魅", "hp": 300, "max_hp": 300, "mp": 0, "speed": 7, "atk": 40, "def": 3, "is_enemy": true, "battle_uid": "foe#0", "accuracy": 100000, "crit_rate": 0.0}
	controller.player_party = party
	controller.enemy_party = [enemy]
	var manager: Node = controller.turn_manager
	manager.player_party = party
	manager.enemy_party = [enemy]
	manager.round_in_progress = true
	manager.round_roster = ["liuyu", "shumian", "foe#0"]
	manager.turn_queue = (party + [enemy]).duplicate()
	manager.turn_queue.sort_custom(Callable(manager, "_compare_speed"))
	manager.current_index = 0
	var registry = controller.stage_entities
	var shumian: Dictionary = party[1]
	var liuyu: Dictionary = party[0]

	# --- the cast ---
	shumian["mp"] = 6
	await controller.execute_action(shumian, skill, shumian)
	_expect(registry.is_empty() and int(shumian.mp) == 6, "with 6 MP the skill cannot be cast")
	shumian["mp"] = 40
	await controller.execute_action(shumian, skill, shumian)
	_expect(int(shumian.mp) == 33, "casting spends the skill's own 7 MP (it is not free)")
	_expect(bool(shumian.get("acted_this_turn", false)), "casting uses the action")
	var entities: Array = registry.get_stage_entities()
	_expect(entities.size() == 1 and entities[0].entity_type == "linfu_talisman", "a 護脈符 card is on the stage")
	var card = entities[0]
	_expect(card.owner_id == "shumian" and card.faction == "player" and card.joins_turn_order and card.duration_turns == 3, "owned by 書眠, player side, in the turn order, three activations")
	_expect(card.has_tag("talisman") and card.has_tag("linfu") and card.has_tag("defense"), "tagged talisman / linfu / defense")
	_expect(manager.queue_entities.size() == 1, "it has its own place in the ADB")
	var row: Array = manager.get_display_row(false)
	_expect(row.size() == 3 and bool(row[row.size() - 1].get("is_stage_entity", false)), "it stands at the far left of the party row")
	_expect(liuyu.get("status_effects", {}).is_empty() and shumian.get("status_effects", {}).is_empty(), "nobody got a buff hung on them")

	# --- the live order decides who is covered ---
	# Party row while 書眠 is still acting: [書眠 (next)][劉語塵][card] - only 劉語塵 is beside the card.
	_expect(controller.get_adjacency_bonus(liuyu, "DEFENSE_UP") > 0.0, "劉語塵 stands beside it and is covered")
	_expect(controller.get_adjacency_bonus(shumian, "DEFENSE_UP") == 0.0, "書眠, two places away, is not (it was not decided when casting)")
	# 書眠 finishes: the order rotates by itself, the card ends up between 書眠 and ... the next one.
	manager.current_index = 1
	var row_after: Array = manager.get_display_row(false)
	_expect(String(row_after[0].get("id", "")) == "liuyu", "劉語塵 is next to act")
	_expect(controller.get_adjacency_bonus(shumian, "DEFENSE_UP") > 0.0 and controller.get_adjacency_bonus(liuyu, "DEFENSE_UP") == 0.0, "after the rotation the card (fixed at the far left) is beside 書眠 only")

	# --- the bonus changes damage, taken from the live order ---
	var attack: Dictionary = {"id": "basic_attack", "name": "普通攻擊", "power": 1.0, "target_scope": "enemy_single"}
	var covered_damage: int = _damage(controller, enemy, shumian, attack)
	manager.current_index = 1
	shumian["hp"] = 80
	# Take the card out of the order: 劉語塵 is no longer covered, same seed.
	var proxy: Dictionary = manager.queue_entities[0]
	manager.queue_entities.erase(proxy)
	var bare_damage: int = _damage(controller, enemy, shumian, attack)
	manager.queue_entities.append(proxy)
	_expect(covered_damage < bare_damage, "a covered character takes less damage (%d < %d)" % [covered_damage, bare_damage])

	# --- activations ---
	_expect(not await _activate(controller, proxy), "first activation: it stays")
	_expect(card.duration_turns == 2, "…two left")
	_expect(not await _activate(controller, proxy), "second activation: it stays")
	_expect(await _activate(controller, proxy), "third activation: it leaves")
	_expect(registry.is_empty() and manager.queue_entities.is_empty(), "gone from the stage and from the order")
	_expect(controller.get_adjacency_bonus(shumian, "DEFENSE_UP") == 0.0 and controller.get_adjacency_bonus(liuyu, "DEFENSE_UP") == 0.0, "its protection ends at once")

	battle.queue_free()
	if _failures.is_empty():
		print("PASS: ", _assertions, " assertions; linfu battle flow")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _damage(controller: Node, attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
	seed(77)
	var copy: Dictionary = target.duplicate(true)
	var result: Dictionary = controller.skill_executor.execute(attacker, copy, skill, {})
	return int(result.get("damage", 0))


## Runs the card's own turn once; true when it has left the stage.
func _activate(controller: Node, proxy: Dictionary) -> bool:
	await controller._run_stage_entity_turn(proxy)
	return controller.stage_entities.get_entity(String(proxy.get("entity_id", ""))) == null
