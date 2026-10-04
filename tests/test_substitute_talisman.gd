extends SceneTree
## 替身符: a card in the ADB row that blocks the Hits meant for the characters standing directly at its two
## ends (like the 持鞘 card), takes no aggro, and breaks after the enemy action in which it blocked.
## Real battle controller. Run: --headless --path . --script tests/test_substitute_talisman.gd

const Adjacency = preload("res://scripts/battlescripts/StageAdjacency.gd")
const SKILL_ID := "skill_substitute_talisman"

var SkillDBScript: Script
var rules
var _failures: Array[String] = []
var _assertions: int = 0
var battle: Node
var controller: Node
var manager: Node
var real_executor: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _names(row: Array) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in row:
		parts.append(String(entry.get("name", "?")))
	parts.reverse()
	return "".join(parts)   # drawn left to right


func _liuyu() -> Dictionary:
	return {"id": "liuyu", "name": "劉", "hp": 100000, "max_hp": 100000, "mp": 50, "max_mp": 50, "speed": 10, "atk": 20, "def": 5, "weapon_1": "劍", "weapon_2": ""}


func _shumian() -> Dictionary:
	return {"id": "shumian", "name": "白", "hp": 100000, "max_hp": 100000, "mp": 60, "max_mp": 60, "speed": 15, "atk": 10, "def": 4}


func _enemy() -> Dictionary:
	return {"id": "foe", "name": "敵", "hp": 100000, "max_hp": 100000, "mp": 0, "speed": 7, "atk": 20, "def": 3, "is_enemy": true, "battle_uid": "foe#0", "accuracy": 100000, "crit_rate": 0.0}


## A fresh battle with `party` and one enemy; everybody in the party has already acted this round.
func _setup(party: Array) -> void:
	if battle != null:
		battle.queue_free()
		await process_frame
	var state: Node = root.get_node("GlobalState")
	state.remove_meta("pending_battle_context")
	battle = (load("res://scenes/battle_scene.tscn") as PackedScene).instantiate()
	battle.presentation_mode = 2
	root.add_child(battle)
	await process_frame
	await process_frame
	controller = battle.get_node("BattleController")
	controller.battle_ui = null
	controller.action_log_ui = null
	real_executor = controller.skill_executor
	var enemy: Dictionary = _enemy()
	controller.player_party = party
	controller.enemy_party = [enemy]
	manager = controller.turn_manager
	manager.player_party = party
	manager.enemy_party = [enemy]
	manager.queue_entities.clear()
	manager.round_in_progress = true
	manager.round_roster = []
	for actor: Dictionary in party + [enemy]:
		manager.round_roster.append(manager._actor_key(actor))
	manager.acted_this_round = {}
	manager.turn_queue = (party + [enemy]).duplicate()
	manager.turn_queue.sort_custom(Callable(manager, "_compare_speed"))
	manager.current_index = 0


func _run() -> void:
	SkillDBScript = load("res://scripts/db/SkillDB.gd")
	rules = SkillDBScript.new()
	_check_data()
	await _check_cast()
	await _check_cast_placement()
	await _check_no_lifetime()
	await _check_layouts()
	await _check_sheath_combinations()
	await _check_spent()
	if battle != null:
		battle.queue_free()
	if _failures.is_empty():
		print("PASS: ", _assertions, " assertions; substitute talisman")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check_data() -> void:
	var skill: Dictionary = rules.get_skill(SKILL_ID)
	_expect(not skill.is_empty() and skill.name == "替身符", "the skill exists in the skill database")
	_expect(skill.weapon_type == "筆" and int(skill.mp_cost) == 20 and int(skill.required_level) == 1, "a pen skill, 20 MP, learned at level 1")
	_expect(skill.available.actor_ids == ["shumian"], "only Shumian can use it")
	var config: Dictionary = skill.stage_entity
	_expect(config.entity_type == "substitute_talisman" and bool(config.joins_turn_order), "it is a card in the turn order")
	_expect(not bool(config.targetable) and not bool(config.damageable) and not bool(config.healable) and int(config.guard_charges) == 1, "not targetable (no aggro), not damageable, not healable, one charge")
	_expect(not config.has("advance_policy") and not config.has("expire_at_edge"), "it no longer advances or expires at the edge")


func _cast_substitute(shumian: Dictionary) -> Object:
	shumian["mp"] = 60
	await controller.execute_action(shumian, rules.get_skill(SKILL_ID), shumian)
	for entity: Object in controller.stage_entities.get_stage_entities():
		if String(entity.entity_type) == "substitute_talisman":
			return entity
	return null


func _check_cast() -> void:
	var liuyu: Dictionary = _liuyu()
	var shumian: Dictionary = _shumian()
	await _setup([liuyu, shumian])
	manager.current_index = 0
	var entity: Object = await _cast_substitute(shumian)
	_expect(entity != null and int(shumian.mp) == 40, "casting makes the card and spends 20 MP")
	if entity == null:
		return
	_expect(controller.stage_entities.get_targetable_entities().is_empty(), "nothing can target it: no aggro, no area-attack share")
	_expect(not manager.find_queue_actor(String(entity.entity_id)).is_empty(), "it stands in the turn order")
	_expect(entity.is_alive() and entity.heal(50).healed == 0, "alive, cannot be healed")
	# a plain attack never goes for the card: the enemy AI only ever picks characters
	var picked: Dictionary = {}
	for trial: int in range(60):
		var target: Dictionary = controller._pick_enemy_target(controller.enemy_party[0]) if controller.has_method("_pick_enemy_target") else liuyu
		picked[String(target.get("name", "?"))] = true
	_expect(not picked.has("替身符"), "the enemy never chooses the card as a target")


## Row layout helper: put the cards in the order given (left to right) by stamping them far left one by one.
func _arrange(order: Array) -> void:
	manager.current_index = manager.turn_queue.size()   # everyone has acted: the whole row is the acted list
	var right_to_left: Array = order.duplicate()
	right_to_left.reverse()
	for entry: Dictionary in right_to_left:
		manager.send_to_far_left(entry)


func _proxy_of(entity: Object) -> Dictionary:
	return manager.find_queue_actor(String(entity.entity_id))


func _hits(target: Dictionary, count: int = 1) -> int:
	var blocked: int = 0
	for index: int in range(count):
		var answer: Dictionary = controller._hit_block_info(target, controller.enemy_party[0])
		if bool(answer.get("blocked", false)):
			blocked += 1
	return blocked


func _check_layouts() -> void:
	var liuyu: Dictionary = _liuyu()
	var shumian: Dictionary = _shumian()
	await _setup([liuyu, shumian])
	var entity: Object = await _cast_substitute(shumian)
	var proxy: Dictionary = _proxy_of(entity)
	# [白][替身][劉]: both are beside it
	_arrange([shumian, proxy, liuyu])
	
	var row: Array = manager.get_display_row(false)
	var order: String = _names(row)
	_expect(order.begins_with("白") and order.ends_with("劉") and order.contains(String(proxy.name)), "[白][替身][劉] is the row: " + order)
	controller._substitute_actions.clear()
	_expect(_hits(shumian) == 1, "[白][替身][劉]: a blow at 白 is blocked")
	controller._substitute_actions.clear()
	_expect(_hits(liuyu) == 1, "[白][替身][劉]: a blow at 劉 is blocked")
	# one charge: the first Hit meant for each character only
	controller._substitute_actions.clear()
	_expect(_hits(shumian, 3) == 1, "only the first Hit at one character is blocked, the rest land")
	_expect(_hits(liuyu, 3) == 1, "...and the other neighbour gets its own first Hit blocked (one area attack covers both)")
	# [替身][白][劉]: only 白 is beside it
	_arrange([proxy, shumian, liuyu])
	order = _names(manager.get_display_row(false))
	_expect(order.begins_with(String(proxy.name)), "[替身][白][劉] is the row: " + order)
	controller._substitute_actions.clear()
	_expect(_hits(shumian) == 1, "[替身][白][劉]: 白 is protected")
	controller._substitute_actions.clear()
	_expect(_hits(liuyu) == 0, "[替身][白][劉]: 劉 is not")
	# an enemy's own side and the party's own cards are untouched
	controller._substitute_actions.clear()
	_expect(controller._hit_block_info(shumian, shumian).is_empty(), "only enemy blows are blocked")


func _check_sheath_combinations() -> void:
	var liuyu: Dictionary = _liuyu()
	var shumian: Dictionary = _shumian()
	await _setup([liuyu, shumian])
	manager.current_index = 1
	await controller.execute_action(liuyu, rules.get_skill("skill_bajian_chishao"), liuyu)
	var sheath: Object = controller.find_stance_entity(liuyu)
	var entity: Object = await _cast_substitute(shumian)
	var sheath_proxy: Dictionary = _proxy_of(sheath)
	var proxy: Dictionary = _proxy_of(entity)
	_expect(sheath != null and entity != null, "both cards stand")
	# [白][持鞘][替身][劉]: 替身 protects only 劉 (it never protects an entity, 白 is not beside it)
	_arrange([shumian, sheath_proxy, proxy, liuyu])
	controller._substitute_actions.clear()
	_expect(_hits(liuyu) == 1, "[白][持鞘][替身][劉]: 劉 is protected by the 替身符")
	controller._substitute_actions.clear()
	_expect(_hits(shumian) == 0, "[白][持鞘][替身][劉]: 白 is not (the sheath card is between)")
	# [白][持鞘][替身][護脈符][劉]: nobody beside the 替身符 is a character
	var ward: Dictionary = {"id": "ward", "name": "符", "ent": true, "entity_id": "ward_entity", "speed": 0, "is_entity_proxy": true, "joins_turn_order": true}
	manager.add_queue_actor(ward)
	_arrange([shumian, sheath_proxy, proxy, ward, liuyu])
	controller._substitute_actions.clear()
	_expect(_hits(liuyu) == 0 and _hits(shumian) == 0, "[白][持鞘][替身][護脈][劉]: the 替身符 protects nobody")
	manager.remove_queue_actor(ward)
	# [持鞘][替身][劉]: the 替身符 blocks, and the sheath card is then not asked at all
	_arrange([sheath_proxy, proxy, liuyu, shumian])
	controller._substitute_actions.clear()
	var answer: Dictionary = controller._hit_block_info(liuyu, controller.enemy_party[0])
	_expect(bool(answer.get("blocked", false)) and controller._last_blocker == entity, "[持鞘][替身][劉]: the 替身符 blocks for 劉, not the sheath card")
	# after the 替身符 has taken the first Hit, the sheath card (which is not at the right end here) stays out
	var second: Dictionary = controller._hit_block_info(liuyu, controller.enemy_party[0])
	_expect(not bool(second.get("blocked", false)) and controller._last_blocker == null, "the next Hit is not blocked by anyone")


func _check_spent() -> void:
	var liuyu: Dictionary = _liuyu()
	var shumian: Dictionary = _shumian()
	await _setup([liuyu, shumian])
	var entity: Object = await _cast_substitute(shumian)
	var proxy: Dictionary = _proxy_of(entity)
	_arrange([shumian, proxy, liuyu])
	var enemy: Dictionary = controller.enemy_party[0]
	# through the real executor: the Hit is reported blocked
	var attack: Dictionary = {"id": "basic_attack", "name": "普通攻擊", "power": 1.0, "target_scope": "enemy_single"}
	controller._substitute_actions.clear()
	var hp_before: int = int(liuyu.hp)
	var result: Dictionary = real_executor.execute(enemy, liuyu, attack, {})
	_expect(bool(result.get("blocked", false)) and int(liuyu.hp) == hp_before, "the executor reports the blocked Hit and nobody loses HP")
	_expect(String(result.log[0]).contains("替身符"), "the log names the 替身符")
	# it breaks when the action is over
	await controller._spend_substitutes()
	_expect(controller.stage_entities.get_stage_entities().filter(func(e: Object) -> bool: return String(e.entity_type) == "substitute_talisman").is_empty(), "the card breaks after the action")
	_expect(manager.find_queue_actor(String(entity.entity_id)).is_empty(), "...and leaves the row")
	# an action that blocked nothing leaves a fresh card alone
	var second: Object = await _cast_substitute(shumian)
	controller._substitute_actions.clear()
	await controller._spend_substitutes()
	_expect(second != null and controller.stage_entities.get_stage_entities().has(second), "a card that took no blow stays")


## 書眠 acts after 劉語塵 (slower): the new card still stands at the far left and has no turn in the round it was drawn.
func _check_cast_placement() -> void:
	var liuyu: Dictionary = _liuyu()
	var shumian: Dictionary = _shumian()
	shumian["speed"] = 5
	await _setup([liuyu, shumian])
	manager.current_index = 1   # 劉 acted; 書眠 is acting
	var entity: Object = await _cast_substitute(shumian)
	var row: Array = manager.get_display_row(false)
	_expect(Adjacency.key_of(row[row.size() - 1]) == "ent:%s" % String(entity.entity_id), "the new card is at the far left even though 劉語塵 had already acted: " + _names(row))
	var proxy: Dictionary = _proxy_of(entity)
	_expect(manager.turn_queue.find(proxy) < 0 or manager.turn_queue.find(proxy) < manager.current_index, "it has no turn left in the round it was drawn")


## A card without a turn-based lifetime goes through its own turn without being counted down (NO_LIFETIME).
func _check_no_lifetime() -> void:
	var liuyu: Dictionary = _liuyu()
	var shumian: Dictionary = _shumian()
	await _setup([liuyu, shumian])
	var entity: Object = await _cast_substitute(shumian)
	var proxy: Dictionary = _proxy_of(entity)
	await controller._run_stage_entity_turn(proxy)
	_expect(int(entity.duration_turns) == -1 and entity.is_alive() and controller.stage_entities.get_stage_entities().has(entity), "its own turn costs it nothing: no lifetime, no countdown")
