extends SceneTree
## 臨符 (護脈符) as a card in the ADB: where it stands in the row, who it covers and when, how its
## effects combine, and how it leaves. Logic only (TurnManager + StageAdjacency + LinfuTalisman).

const TurnManagerScript = preload("res://scripts/battlescripts/TurnManager.gd")
const StageAdjacency = preload("res://scripts/battlescripts/StageAdjacency.gd")
const LinfuTalisman = preload("res://scripts/battlescripts/LinfuTalisman.gd")

var _failures: Array[String] = []
var manager: Node
var shumian := {"id": "shumian", "name": "書眠", "hp": 50, "speed": 15}
var liuyu := {"id": "liuyu", "name": "語塵", "hp": 50, "speed": 10}
var zuoyin := {"id": "zuoyin", "name": "左飲", "hp": 1, "speed": 5, "is_scripted_guest": true}
var foe := {"id": "foe", "name": "敵", "hp": 50, "speed": 2, "is_enemy": true}


func _initialize() -> void:
	_run.call_deferred()


func _names(row: Array) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in row:
		parts.append(String(entry.get("name", "?")))
	# Drawn left to right: the last of the row stands at the far left.
	parts.reverse()
	return "".join(parts)


func _step() -> void:
	manager.end_turn()
	for frame: int in range(3):
		await process_frame


func _run() -> void:
	var stub := GDScript.new()
	stub.source_code = "extends Node\nvar battle_finished: bool = false\nvar _ending: bool = false\n"
	stub.reload()
	var host := Node.new()
	host.set_script(stub)
	root.add_child(host)
	manager = TurnManagerScript.new()
	host.add_child(manager)
	manager.start_battle([shumian, liuyu], [foe], zuoyin)
	for frame: int in range(4):
		await process_frame
	_expect(_names(manager.get_display_row(false)) == "左飲語塵書眠", "before the cast the row is [左飲][語塵][書眠]: " + _names(manager.get_display_row(false)))
	_expect(manager.active_actor == shumian, "書眠 acts first")

	# --- the cast: the card takes the last place of the round, the far left ---
	var talisman := LinfuTalisman.new()
	talisman.apply_config({"entity_id": "linfu#1", "display_name": "護脈符", "faction": "player", "duration_turns": 3, "turn_speed": 999,
		"adjacency_effects": [{"family": "DEFENSE_UP", "value": 0.15}]})
	var proxy := {"id": "linfu#1", "entity_id": "linfu#1", "name": "符", "faction": "player", "speed": 999}
	manager.add_queue_actor(proxy)
	_expect(_names(manager.get_display_row(false)) == "符左飲語塵書眠", "the card is inserted at the far left: " + _names(manager.get_display_row(false)))
	_expect(not manager.is_enemy_side(proxy), "the card stands in the party's row")

	# --- 書眠 finishes: the order rotates ---
	await _step()
	_expect(_names(manager.get_display_row(false)) == "符書眠左飲語塵", "after 書眠 acts the card still stands at the far left: " + _names(manager.get_display_row(false)))
	var row: Array = manager.get_display_row(false)
	var at: int = StageAdjacency.index_of(row, "ent:linfu#1")
	var names_hit: Array[String] = []
	for recipient: Dictionary in StageAdjacency.recipients(row, at):
		names_hit.append(String(recipient.name))
	names_hit.sort()
	_expect(names_hit == ["書眠"], "a card obeys position, not speed: it covers only the character beside it: " + str(names_hit))
	_expect(not names_hit.has("語塵"), "a character that is not next to it is not covered")

	# --- 語塵 acts: the card still stands between 書眠 and 左飲 ---
	await _step()
	row = manager.get_display_row(false)
	_expect(_names(row) == "符語塵書眠左飲", "after 語塵 acts the card still stands at the far left: " + _names(row))
	at = StageAdjacency.index_of(row, "ent:linfu#1")
	names_hit.clear()
	for recipient: Dictionary in StageAdjacency.recipients(row, at):
		names_hit.append(String(recipient.name))
	_expect(names_hit == ["語塵"], "now the one beside it is 語塵: " + str(names_hit))

	# --- 左飲 acts: the card reaches the end of the row, one neighbour only ---
	await _step()
	row = manager.get_display_row(false)
	_expect(_names(row) == "符左飲語塵書眠", "after 左飲 acts the card still stands at the far left: " + _names(row))
	at = StageAdjacency.index_of(row, "ent:linfu#1")
	var last_hits: Array = StageAdjacency.recipients(row, at)
	_expect(last_hits.size() == 1 and String(last_hits[0].name) == "左飲", "at the far left only the character beside it is covered")

	# --- ends are not neighbours ---
	var ends: Array = [{"name": "A", "hp": 5, "id": "a"}, {"name": "B", "hp": 5, "id": "b"}, {"name": "C", "hp": 5, "id": "c"}, {"is_stage_entity": true, "entity_id": "t", "name": "符", "hp": 1}]
	# index 0 is the right end; the card is at the far left (last index)
	var end_hits: Array = StageAdjacency.recipients(ends, 3)
	_expect(end_hits.size() == 1 and String(end_hits[0].name) == "C", "at the end of the row only the one neighbour is covered (no wrap-around)")

	# --- no reaching across another entity ---
	var blocked: Array = [{"name": "B", "hp": 5, "id": "b"}, {"is_stage_entity": true, "entity_id": "t", "name": "符", "hp": 1}, {"is_stage_entity": true, "entity_id": "x", "name": "他", "hp": 1}, {"name": "A", "hp": 5, "id": "a"}]
	var blocked_hits: Array = StageAdjacency.recipients(blocked, 1)
	_expect(blocked_hits.size() == 1 and String(blocked_hits[0].name) == "B", "an entity in between blocks: A is not covered through it")

	# --- patterns ---
	var trio: Array = [{"name": "R", "hp": 5, "id": "r"}, {"is_stage_entity": true, "entity_id": "t", "name": "符", "hp": 1}, {"name": "L", "hp": 5, "id": "l"}]
	_expect(StageAdjacency.recipients(trio, 1, "left").size() == 1 and String(StageAdjacency.recipients(trio, 1, "left")[0].name) == "L", "pattern left touches the card on the left")
	_expect(String(StageAdjacency.recipients(trio, 1, "right")[0].name) == "R", "pattern right touches the card on the right")

	# --- the same family never stacks ---
	var two: Dictionary = StageAdjacency.resolve_effects([{"family": "DEFENSE_UP", "value": 0.15}, {"family": "DEFENSE_UP", "value": 0.15}])
	_expect(is_equal_approx(float(two["DEFENSE_UP"]), 0.15), "two cards of equal strength do not stack")
	var mixed: Dictionary = StageAdjacency.resolve_effects([{"family": "DEFENSE_UP", "value": 0.15}, {"family": "DEFENSE_UP", "value": 0.25}, {"family": "DEFENSE_UP", "value": 0.10}])
	_expect(is_equal_approx(float(mixed["DEFENSE_UP"]), 0.25), "different strengths of one family: only the highest counts")
	var modes: Dictionary = StageAdjacency.resolve_effects([{"family": "DEFENSE_UP", "value": 15, "mode": "flat"}, {"family": "DEFENSE_UP", "value": 0.15, "mode": "percent"}])
	_expect(is_equal_approx(float(modes["DEFENSE_UP"]), 15.0) and is_equal_approx(float(modes["DEFENSE_UP_PCT"]), 0.15), "flat and percent versions of one effect are kept apart (an inner force can switch a card between them)")
	var apart: Dictionary = StageAdjacency.resolve_effects([{"family": "DEFENSE_UP", "value": 0.15}, {"family": "PARRY_UP", "value": 0.2}])
	_expect(apart.size() == 2, "different families coexist")

	# --- three activations, then it leaves ---
	_expect(not talisman.activate(), "first activation: it stays")
	_expect(not talisman.activate(), "second activation: it stays")
	_expect(talisman.activate(), "third activation: its duration is spent")
	_expect(talisman.duration_turns == 0, "duration counts its own activations")
	manager.remove_queue_actor(proxy)
	row = manager.get_display_row(false)
	_expect(StageAdjacency.index_of(row, "ent:linfu#1") == -1, "once it has left, the row no longer contains it")
	_expect(manager.find_queue_actor("linfu#1").is_empty(), "and it is out of the turn order")

	host.free()
	if _failures.is_empty():
		print("PASS: linfu adjacency")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
