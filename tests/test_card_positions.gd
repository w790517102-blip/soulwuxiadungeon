extends SceneTree
## Cards in the ADB have no speed. Characters order themselves by speed; a card is moved only by the line's own
## rules: the character at its right takes it along when he ends his turn (follow_topology), a speed change
## never moves it, a death hands it to nobody, and a card that reaches the frontier takes its own turn.
## Run: --headless --path . --script tests/test_card_positions.gd

const TurnManagerScript = preload("res://scripts/battlescripts/TurnManager.gd")
const Adjacency = preload("res://scripts/battlescripts/StageAdjacency.gd")

var _failures: Array[String] = []
var manager: Node
var host: Node


func _initialize() -> void:
	_run.call_deferred()


func _names(row: Array) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in row:
		parts.append(String(entry.get("name", "?")))
	parts.reverse()
	return "".join(parts)   # drawn left to right


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _card(id: String, name: String, follow: bool = true) -> Dictionary:
	return {"id": id, "entity_id": id, "name": name, "faction": "player", "follow_topology": follow}


func _start(party: Array) -> void:
	if host != null:
		host.queue_free()
		await process_frame
	var stub := GDScript.new()
	stub.source_code = "extends Node\nvar battle_finished: bool = false\nvar _ending: bool = false\n"
	stub.reload()
	host = Node.new()
	host.set_script(stub)
	root.add_child(host)
	manager = TurnManagerScript.new()
	host.add_child(manager)
	var foe := {"id": "foe", "name": "敵", "hp": 50, "speed": 2, "is_enemy": true}
	manager.start_battle(party, [foe])
	for frame: int in range(4):
		await process_frame


func _step() -> void:
	manager.end_turn()
	for frame: int in range(3):
		await process_frame


func _run() -> void:
	await _test_hen_takes_chicks()
	await _test_speed_reorder()
	await _test_death_and_frontier()
	if _failures.is_empty():
		print("PASS: card positions")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


## Test A: [A][B][劉][白] - when 劉 ends his turn A and B go to the far left with him, in the same order.
func _test_hen_takes_chicks() -> void:
	var white := {"id": "shumian", "name": "白", "hp": 50, "speed": 15}
	var liu := {"id": "liuyu", "name": "劉", "hp": 50, "speed": 10}
	await _start([white, liu])
	var a := _card("a", "甲")
	var b := _card("b", "乙")
	manager.add_queue_actor(a, liu)
	manager.add_queue_actor(b, liu)
	_expect(_names(manager.get_display_row(false)) == "甲乙劉白", "A: the cards stand at 劉's left, the later one next to him: " + _names(manager.get_display_row(false)))
	await _step()   # 白 ends his turn; nothing stands at his left
	_expect(_names(manager.get_display_row(false)) == "白甲乙劉", "A: 白 goes to the far left alone: " + _names(manager.get_display_row(false)))
	await _step()   # 劉 ends: he takes 甲 and 乙 with him
	_expect(_names(manager.get_display_row(false)) == "甲乙劉白", "A: 劉 takes both cards, order kept: " + _names(manager.get_display_row(false)))


## Tests B / C / L: a speed change only trades characters; the card stays and meets the other character.
func _test_speed_reorder() -> void:
	var white := {"id": "shumian", "name": "白", "hp": 50, "speed": 15}
	var liu := {"id": "liuyu", "name": "劉", "hp": 50, "speed": 10}
	var third := {"id": "zuoyin", "name": "左", "hp": 50, "speed": 5}
	await _start([white, liu, third])
	var sheath := _card("s", "鞘")
	manager.add_queue_actor(sheath, liu)   # directly at 劉's left
	_expect(_names(manager.get_display_row(false)) == "左鞘劉白", "B: [左][鞘][劉][白]: " + _names(manager.get_display_row(false)))
	var row: Array = manager.get_display_row(false)
	_expect(Adjacency.recipients(row, row.find(sheath)).size() == 2, "B: the card touches 左 and 劉")
	third["speed"] = 12   # 左 becomes faster than 劉, during 白's turn
	manager.resort_remaining_characters()
	row = manager.get_display_row(false)
	_expect(_names(row) == "劉鞘左白", "B: only the characters traded places, the card stayed: " + _names(row))
	# C: it now stands beside 左 and 劉 the other way round; L: a new round only re-sorts characters
	var round_before: int = manager.round_count
	var guard: int = 0
	while manager.round_count == round_before and guard < 14:
		await _step()
		guard += 1
	_expect(manager.round_count > round_before, "L: a new round started")
	var new_row: Array = manager.get_display_row(false)
	_expect(new_row.has(sheath) and _names(new_row).length() == 4, "L: the card is still on the line: " + _names(new_row))


## Tests D / E: the character at the right dies; nobody inherits the cards, and they walk to the frontier.
func _test_death_and_frontier() -> void:
	var white := {"id": "shumian", "name": "白", "hp": 50, "speed": 15}
	var liu := {"id": "liuyu", "name": "劉", "hp": 50, "speed": 10}
	await _start([white, liu])
	var a := _card("a", "甲")
	var b := _card("b", "乙")
	manager.add_queue_actor(a, white)
	manager.add_queue_actor(b, white)
	_expect(_names(manager.get_display_row(false)) == "劉甲乙白", "D: [劉][甲][乙][白]: " + _names(manager.get_display_row(false)))
	white["hp"] = 0
	manager.acted_this_round.clear()   # as at the start of a round
	var row: Array = manager.get_display_row(false)
	_expect(_names(row) == "劉甲乙", "D: 白 is gone, the cards keep their relative places and 劉 does not get them: " + _names(row))
	_expect(row[0] == b, "E: 乙 is now at the frontier")
	_expect(manager.pending_frontier_card() == b, "E: the frontier card is waiting for its own turn")
	var turns: int = 0
	while not manager.pending_frontier_card().is_empty() and turns < 6:
		manager.active_actor = manager.pending_frontier_card()
		await _step()
		turns += 1
	_expect(turns == 2, "E: both cards took their turns, then nothing is pending (%d)" % turns)
	_expect(manager.has_acted(a) and manager.has_acted(b), "E: both are marked as having acted this round")
