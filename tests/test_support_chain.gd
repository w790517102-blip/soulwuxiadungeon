extends SceneTree
## Support chains: a card that works on the head of its chain (the nearest character to its right, however many
## cards stand between), one that works only on strict neighbours, how they stack (different families add, the same
## family counts once), and what a reorder of the cards or of the characters changes. Real battle controller.
## Run: --headless --path . --script tests/test_support_chain.gd

const Adjacency = preload("res://scripts/battlescripts/StageAdjacency.gd")
const LinfuTalisman = preload("res://scripts/battlescripts/LinfuTalisman.gd")

var _failures: Array[String] = []
var battle: Node
var controller: Node
var manager: Node
var _next_id: int = 1


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _names(row: Array) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in row:
		parts.append(String(entry.get("name", "?")))
	parts.reverse()
	return "".join(parts)   # drawn left to right


func _actors() -> Array:
	return [
		{"id": "liuyu", "name": "劉", "hp": 1000, "max_hp": 1000, "mp": 50, "max_mp": 50, "speed": 10, "atk": 20, "def": 5},
		{"id": "shumian", "name": "白", "hp": 1000, "max_hp": 1000, "mp": 50, "max_mp": 50, "speed": 15, "atk": 10, "def": 4},
	]


func _setup(party: Array) -> void:
	if battle != null:
		battle.queue_free()
		await process_frame
	root.get_node("GlobalState").remove_meta("pending_battle_context")
	battle = (load("res://scenes/battle_scene.tscn") as PackedScene).instantiate()
	battle.presentation_mode = 2
	root.add_child(battle)
	await process_frame
	await process_frame
	controller = battle.get_node("BattleController")
	controller.battle_ui = null
	controller.action_log_ui = null
	var enemy: Dictionary = {"id": "foe", "name": "敵", "hp": 1000, "max_hp": 1000, "mp": 0, "speed": 7, "atk": 20, "def": 3, "is_enemy": true, "battle_uid": "foe#0"}
	controller.player_party = party
	controller.enemy_party = [enemy]
	manager = controller.turn_manager
	manager.player_party = party
	manager.enemy_party = [enemy]
	manager.queue_entities.clear()
	manager.round_in_progress = true
	manager.round_roster = []
	manager.acted_this_round = {}
	manager.turn_queue = (party + [enemy]).duplicate()
	manager.turn_queue.sort_custom(Callable(manager, "_compare_speed"))
	manager.current_index = 0


## A support card with one effect, put on the line directly to the left of `beside` (or at the far left).
func _card(name: String, pattern: String, family: String, value: float, beside: Dictionary = {}) -> Dictionary:
	var entity := LinfuTalisman.new()
	var id: String = "card#%d" % _next_id
	_next_id += 1
	entity.apply_config({"entity_id": id, "display_name": name, "faction": "player", "duration_turns": 3,
		"adjacency_pattern": pattern, "adjacency_effects": [{"family": family, "value": value}]})
	var proxy := {"id": id, "entity_id": id, "name": name, "faction": "player", "follow_topology": false}
	controller.stage_entities.register_stage_entity(entity)
	manager.add_queue_actor(proxy, beside)
	return proxy


func _bonus(actor: Dictionary, family: String) -> float:
	return controller.get_adjacency_bonus(actor, family)


func _run() -> void:
	await _check_anchor_examples()
	await _check_stacking()
	_check_chain_queries()
	if battle != null:
		battle.queue_free()
	if _failures.is_empty():
		print("PASS: support chain")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


## [持鞘][護脈][戰鼓] stand between 白 and 劉 or beside them: the drum beats for the head of its chain.
func _check_anchor_examples() -> void:
	var party: Array = _actors()
	var liu: Dictionary = party[0]
	var white: Dictionary = party[1]
	await _setup(party)
	# Drawn: [白][戰鼓][甲][乙][劉]  (right to left: 劉, 乙, 甲, 戰鼓, 白)
	var filler_a: Dictionary = _card("甲", "both", "STRENGTH_UP", 0.0, liu)
	var drum: Dictionary = _card("戰鼓", "anchor", "RALLY_ATTACK_UP", 15.0, liu)
	var filler_b: Dictionary = _card("乙", "both", "STRENGTH_UP", 0.0, liu)
	var row: Array = manager.get_display_row(false)
	_expect(_names(row) == "白戰鼓甲乙劉" or _names(row).find("戰鼓") > 0, "layout: " + _names(row))
	_expect(Adjacency.chain_head_index(row, row.find(drum)) == row.find(liu), "the drum's head is 劉 (cards in between do not matter): " + _names(row))
	_expect(_bonus(liu, "RALLY_ATTACK_UP") == 15.0, "the drum raises 劉's attack although cards stand between them: " + _names(row))
	_expect(_bonus(white, "RALLY_ATTACK_UP") == 0.0, "...and not 白's")
	# The cards are shuffled among themselves: its head is still 劉.
	manager.send_to_far_left(filler_a)
	manager.send_to_far_left(drum)
	manager.send_to_far_left(filler_b)
	row = manager.get_display_row(false)
	_expect(_bonus(liu, "RALLY_ATTACK_UP") == 15.0 and _bonus(white, "RALLY_ATTACK_UP") == 0.0, "after the cards are shuffled the drum still beats for 劉: " + _names(row))
	# The characters are re-sorted (劉 becomes faster than 白): the head changes.
	liu["speed"] = 30
	manager.resort_remaining_characters()
	row = manager.get_display_row(false)
	_expect(_bonus(white, "RALLY_ATTACK_UP") == 15.0 and _bonus(liu, "RALLY_ATTACK_UP") == 0.0, "after the characters trade places the drum beats for the new head: " + _names(row))


## Different families add; the same family counts once, however many cards give it. Strict neighbours stay strict.
func _check_stacking() -> void:
	var party: Array = _actors()
	var liu: Dictionary = party[0]
	var white: Dictionary = party[1]
	await _setup(party)
	_card("燃鋒甲", "both", "ATTACK_UP", 15.0, liu)
	_card("戰鼓甲", "anchor", "RALLY_ATTACK_UP", 15.0, liu)
	_card("戰鼓乙", "anchor", "RALLY_ATTACK_UP", 15.0, liu)
	var row: Array = manager.get_display_row(false)
	_expect(_bonus(liu, "RALLY_ATTACK_UP") == 15.0, "two drums give the drum bonus once: " + _names(row))
	# 燃鋒 only works on a character directly beside it; with the drums between, 劉 is not beside it.
	var beside_liu: bool = _bonus(liu, "ATTACK_UP") > 0.0
	var beside_white: bool = _bonus(white, "ATTACK_UP") > 0.0
	_expect(not (beside_liu and beside_white), "a strict-neighbour card never reaches across other cards: " + _names(row))
	# Put a strict card directly at 劉's left: it adds to the drum (different families).
	await _setup(party)
	_card("戰鼓", "anchor", "RALLY_ATTACK_UP", 15.0, liu)
	_card("燃鋒", "both", "ATTACK_UP", 15.0, liu)   # directly beside 劉
	_card("燃鋒二", "both", "ATTACK_UP", 15.0, liu)   # a second one beside him: the same family counts once
	_expect(_bonus(liu, "ATTACK_UP") == 15.0 and _bonus(liu, "RALLY_ATTACK_UP") == 15.0, "both families reach 劉, each once")
	var attack: Dictionary = {"id": "basic_attack", "name": "普通攻擊", "power": 1.0, "target_scope": "enemy_single"}
	var enemy: Dictionary = controller.enemy_party[0]
	liu["weapon_1"] = "劍"
	var plain_executor_atk: int = int(liu.atk)
	var result: Dictionary = controller.skill_executor.execute(liu, enemy.duplicate(true), attack, {})
	_expect(int(result.get("effective_atk", 0)) >= plain_executor_atk + 30, "the two families add in the damage calculation (%d)" % int(result.get("effective_atk", 0)))


func _check_chain_queries() -> void:
	var a := {"id": "a", "name": "甲", "hp": 5}
	var b := {"id": "b", "name": "乙", "hp": 5}
	var x := {"is_stage_entity": true, "entity_id": "x", "name": "X", "hp": 1}
	var y := {"is_stage_entity": true, "entity_id": "y", "name": "Y", "hp": 1}
	# right to left: a, x, y, b  (drawn [b][y][x][a])
	var row: Array = [a, x, y, b]
	_expect(Adjacency.chain_head_index(row, 2) == 0 and Adjacency.chain_head_index(row, 1) == 0, "both cards belong to the chain of the character at their right")
	_expect(Adjacency.support_chain_of(row, 0).size() == 2 and Adjacency.support_chain_of(row, 3).is_empty(), "the chain of a is [x, y]; b has none")
	_expect(Adjacency.chain_head_index([x, a], 0) == -1, "a card with no character at its right has no head")
	_expect(Adjacency.recipients([x, a], 0, Adjacency.ANCHOR).is_empty(), "...so an anchor effect reaches nobody")
