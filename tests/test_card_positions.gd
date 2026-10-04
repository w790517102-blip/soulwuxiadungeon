extends SceneTree
## Cards in the ADB obey POSITION, never speed: drawn at the far left, a newer card pushes the older one in,
## a card drawn beside its owner takes the place to his left, characters changing speed only trade places
## among themselves, and the cards keep their places across rounds.
## Run: --headless --path . --script tests/test_card_positions.gd

const TurnManagerScript = preload("res://scripts/battlescripts/TurnManager.gd")

var _failures: Array[String] = []
var manager: Node
var white := {"id": "shumian", "name": "白", "hp": 50, "speed": 15}
var liu := {"id": "liuyu", "name": "劉", "hp": 50, "speed": 10}
var third := {"id": "zuoyin", "name": "左", "hp": 50, "speed": 5}
var foe := {"id": "foe", "name": "敵", "hp": 50, "speed": 2, "is_enemy": true}


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


func _card(id: String, name: String) -> Dictionary:
	return {"id": id, "entity_id": id, "name": name, "faction": "player", "speed": 999}


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
	manager.start_battle([white, liu, third], [foe])
	for frame: int in range(4):
		await process_frame
	_expect(_names(manager.get_display_row(false)) == "左劉白", "start: [左][劉][白]: " + _names(manager.get_display_row(false)))

	# a card is drawn at the far left; a newer card goes further left, the older one is one place in
	var first := _card("a", "甲")
	manager.add_queue_actor(first)
	_expect(_names(manager.get_display_row(false)) == "甲左劉白", "first card at the far left: " + _names(manager.get_display_row(false)))
	var second := _card("b", "乙")
	manager.add_queue_actor(second)
	_expect(_names(manager.get_display_row(false)) == "乙甲左劉白", "a second card goes further left, the first is one place in: " + _names(manager.get_display_row(false)))

	# acting characters never move the cards out of their places
	await _step()
	_expect(_names(manager.get_display_row(false)).begins_with("乙甲"), "after 白 acts the cards still stand at the far left: " + _names(manager.get_display_row(false)))

	# speed: 白 becomes slower than 劉 - they only trade places, the cards do not move
	white["speed"] = 7
	for frame: int in range(1):
		await process_frame
	var round_before: int = manager.round_count
	var guard: int = 0
	while manager.round_count == round_before and guard < 12:
		await _step()
		guard += 1
	var row_names: String = _names(manager.get_display_row(false))
	_expect(row_names.begins_with("乙甲"), "in the next round the cards keep their places: " + row_names)
	var characters: String = row_names.replace("乙", "").replace("甲", "")
	_expect(characters == "左白劉", "白 became slower than 劉: they only traded places: " + characters)

	# a card drawn beside its owner takes the place to his left
	var beside := _card("c", "丙")
	var row_now: Array = manager.get_display_row(false)
	manager.add_queue_actor(beside, liu)
	var after: Array = manager.get_display_row(false)
	var liu_at: int = after.find(liu)
	_expect(liu_at >= 0 and String(after[liu_at + 1].get("name", "")) == "丙", "a card drawn beside 劉 stands directly to his left: " + _names(after))

	# removing a card closes the gap
	manager.remove_queue_actor(first)
	_expect(_names(manager.get_display_row(false)).find("甲") < 0, "a removed card is gone: " + _names(manager.get_display_row(false)))

	if _failures.is_empty():
		print("PASS: card positions")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)
