extends SceneTree

const TurnManagerScript = preload("res://scripts/battlescripts/TurnManager.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager: Node = TurnManagerScript.new()
	var stub := GDScript.new()
	stub.source_code = "extends Node
var battle_finished: bool = false
var _ending: bool = false
"
	stub.reload()
	var host := Node.new()
	host.set_script(stub)
	root.add_child(host)
	host.add_child(manager)
	var hero := {"id": "hero", "name": "hero", "hp": 10, "speed": 10}
	var foe := {"id": "foe", "name": "foe", "hp": 10, "speed": 5, "is_enemy": true}
	var guest := {"id": "guest", "name": "guest", "hp": 1, "speed": 14, "is_scripted_guest": true}
	manager.start_battle([hero], [foe], guest)
	for step: int in range(4):
		await process_frame
	_expect(manager.get_all_actors().size() == 3, "the guest counts among the actors")
	_expect(manager.turn_queue.size() == 3, "the guest has a place in the turn queue")
	_expect(manager.turn_queue[0] == guest and manager.turn_queue[1] == hero and manager.turn_queue[2] == foe, "the guest is placed by speed")
	_expect(manager.active_actor == guest, "the guest gets the first turn")
	_expect(not manager.is_waiting_for_player, "the guest's turn does not wait for a player command")
	manager.end_turn()
	await process_frame
	_expect(manager.active_actor == hero, "the turn passes on after the guest")
	_expect(manager.round_roster.has("guest"), "the round waits for the guest's turn")
	host.free()
	if _failures.is_empty():
		print("PASS: guest turn")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
