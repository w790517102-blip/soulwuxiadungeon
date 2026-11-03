extends SceneTree
## The real round title is the scheduler barrier: neither camp receives a turn until it finishes.

const TurnManagerScript = preload("res://scripts/battlescripts/TurnManager.gd")
const PresenterScript = preload("res://scripts/presentation/BattleEventPresenter.gd")

class RoundHost extends Node:
	var battle_finished: bool = false
	var _ending: bool = false
	var manager: Node
	var presenter: Control
	var turns: Array[String] = []

	func _on_round_started(round_number: int) -> void:
		presenter.announce_round(round_number)
		var title: Node = presenter.current_round_title()
		if title != null:
			await title.finished
		manager.complete_round_intro(round_number)

	func _on_turn_started(actor: Dictionary) -> void:
		turns.append(String(actor.get("id", "")))


class InputSpy extends Node:
	var leaked_clicks: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			leaked_clicks += 1

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	var host := RoundHost.new()
	root.add_child(host)
	host.manager = TurnManagerScript.new()
	host.add_child(host.manager)
	host.presenter = PresenterScript.new()
	host.add_child(host.presenter)
	var input_spy := InputSpy.new()
	host.add_child(input_spy)
	host.manager.round_started.connect(host._on_round_started)
	host.manager.turn_started.connect(host._on_turn_started)
	host.manager.round_intro_barrier_enabled = true
	var hero: Dictionary = {"id": "hero", "name": "hero", "hp": 10, "speed": 10}
	var foe: Dictionary = {"id": "foe", "name": "foe", "hp": 10, "speed": 5, "is_enemy": true}
	host.manager.start_battle([hero], [foe])
	for frame: int in range(3):
		await process_frame
	_expect(host.manager.round_intro_pending and host.turns.is_empty(), "round 1 title holds both actors")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	_expect(input_spy.leaked_clicks == 0 and host.turns.is_empty(), "a title click is consumed before reaching cards or commands")
	host.manager.next_turn()
	_expect(host.turns.is_empty() and host.manager.active_actor.is_empty(), "an early next_turn cannot start commands or AI")
	var title: Node = host.presenter.current_round_title()
	_expect(title != null, "round title is present")
	if title != null:
		title.skip()
		await process_frame
		_expect(host.turns.is_empty(), "skipping to 開始 does not start the turn")
		title.skip()
	for frame: int in range(3):
		await process_frame
	_expect(host.turns == ["hero"] and host.manager.is_waiting_for_player, "the first actor starts once after the title finishes")
	host.manager.end_turn()
	for frame: int in range(3):
		await process_frame
	_expect(host.turns == ["hero", "foe"], "the enemy acts after the player")
	foe["speed"] = 20
	host.manager.end_turn()
	for frame: int in range(3):
		await process_frame
	_expect(host.manager.round_count == 2 and host.manager.round_intro_pending, "round 2 has a fresh title barrier")
	_expect(host.turns == ["hero", "foe"], "round 2 does not start while its title is visible")
	var second_title: Node = host.presenter.current_round_title()
	if second_title != null:
		second_title.dismiss()
	for frame: int in range(3):
		await process_frame
	_expect(host.turns == ["hero", "foe", "foe"], "an enemy that wins round 2 initiative starts only after its title completes")
	host.queue_free()
	await process_frame
	await _check_controller_and_card_ui()
	if _failures.is_empty():
		print("PASS: round intro blocks both camps and releases one turn per round")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check_controller_and_card_ui() -> void:
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	_expect(fixture.prepared, "production Card Stage preview prepares")
	if not fixture.prepared:
		fixture.queue_free()
		return
	var controller: Node = fixture.controller
	var ui: Node = fixture.ui
	var context: Dictionary = fixture.build_preview_context()
	var hero: Dictionary = context.player_party[0]
	var foe: Dictionary = context.enemy_party[0]
	hero["speed"] = 1000
	foe["speed"] = 1
	foe["is_enemy"] = true
	controller.player_party = [hero]
	controller.enemy_party = [foe]
	controller.encounter_mechanic = {}
	ui.set_teams([hero], [foe])
	var manager: Node = controller.turn_manager
	manager.start_battle([hero], [foe])
	for frame: int in range(3):
		await process_frame
	_expect(manager.round_intro_pending and manager.active_actor.is_empty(), "production controller holds the first actor during its title")
	_expect(not ui.on_action_selection, "Card Stage does not offer commands under the title")
	_expect(ui.stage.active_actor().is_empty() and not ui.stage.input_enabled, "Card Stage clears any old turn marker and card click target")
	ui.stage.active_card_clicked.emit(hero)
	_expect(not ui.command_menu.visible, "clicking an ally card during the title cannot open commands")
	var title: Node = ui.event_presenter.current_round_title()
	_expect(title != null, "production Card Stage shows the round title")
	if title != null:
		title.dismiss()
	for frame: int in range(3):
		await process_frame
	_expect(manager.round_intro_pending and manager.active_actor.is_empty(), "the completed title still has a short locked reading beat")
	await create_timer(0.2).timeout
	_expect(manager.round_intro_pending and not ui.on_action_selection, "commands remain locked during the reading beat")
	ui.stage.active_card_clicked.emit(hero)
	_expect(not ui.command_menu.visible, "clicking during the reading beat cannot open a command")
	await create_timer(0.35).timeout
	for frame: int in range(3):
		await process_frame
	_expect(not manager.round_intro_pending and manager.active_actor == hero, "production controller releases the hero after the title")
	_expect(ui.on_action_selection, "player commands become available after the title")
	fixture.queue_free()
	await process_frame
