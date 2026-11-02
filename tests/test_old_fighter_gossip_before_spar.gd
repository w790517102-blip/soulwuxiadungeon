extends SceneTree

## Regression for PR #28: the old fighter is the third Zuo Yin gossip source,
## and the player chooses sparring on their first conversation.

class FakeChoiceBox extends Control:
	signal choice_selected
	var options: Array = []

	func hide_choices() -> void:
		visible = false


class FakeDialogManager extends Node:
	signal dialog_sequence_finished(npc_node)
	var choice_box: FakeChoiceBox
	var dialog_active: bool = false
	var sequences: Array = []
	var choice_count: int = 0
	var current_npc: Node2D = null

	func _init() -> void:
		choice_box = FakeChoiceBox.new()
		choice_box.name = "ChoiceBox"
		choice_box.visible = false
		add_child(choice_box)

	func show_dialog_sequence(lines: Array, npc_node: Node2D = null) -> void:
		dialog_active = true
		current_npc = npc_node
		sequences.append(lines.duplicate(true))

	func finish_sequence() -> void:
		dialog_active = false
		dialog_sequence_finished.emit(current_npc)

	func show_choice(options: Array) -> void:
		choice_count += 1
		choice_box.options = options
		choice_box.visible = true


var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	var global_state: Node = root.get_node("GlobalState")
	var side_quests: Node = root.get_node("SideQuestManager")
	var saved_flags: Dictionary = global_state.flags.duplicate(true)
	var saved_quests: Dictionary = side_quests.side_quests.duplicate(true)
	var watched_flags: Array[String] = [
		"heard_wanderoldman_zuoyin",
		"heard_waterwoman_zuoyin",
		"heard_oldman_zuoyin",
		"triggered_zuoyin_gossip_summary",
	]
	for flag_name: String in watched_flags:
		global_state.set_flag(flag_name, false)
	global_state.set_flag("heard_wanderoldman_zuoyin", true)
	global_state.set_flag("heard_waterwoman_zuoyin", true)
	side_quests.side_quests.erase("yh_side_oldfighter_01")

	var game_root: Node = Node.new()
	game_root.name = "GameRoot"
	root.add_child(game_root)
	var dialog: FakeDialogManager = FakeDialogManager.new()
	dialog.name = "DialogManager"
	game_root.add_child(dialog)
	var old_man: Node2D = load("res://scripts/yuheng/yuheng_outside/old_man_a.gd").new()
	old_man.name = "OldMan"
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	old_man.add_child(sprite)
	root.add_child(old_man)
	await process_frame

	old_man._begin_interaction_flow()
	old_man._run_oldfighter_interaction()
	_expect(dialog.sequences.size() == 1 and dialog.choice_count == 0, "intro plays before the choice")
	_expect(not global_state.get_flag("heard_oldman_zuoyin"), "gossip is not granted before the old man's story ends")

	dialog.finish_sequence()
	await process_frame
	await process_frame
	_expect(global_state.get_flag("heard_oldman_zuoyin"), "the finished intro grants the old man's gossip")
	_expect(global_state.get_flag("triggered_zuoyin_gossip_summary"), "the third source triggers the gossip summary")
	_expect(dialog.sequences.size() == 2, "the existing Liu Yu summary opens")
	_expect(dialog.choice_count == 0 and not dialog.choice_box.visible, "the sparring choice waits for the summary")

	dialog.finish_sequence()
	await process_frame
	_expect(dialog.choice_count == 1 and dialog.choice_box.visible, "the choice opens after the summary ends")
	_expect(dialog.choice_box.options.size() == 2, "both spar and decline choices remain")

	var spar_callback: Callable = dialog.choice_box.options[0]["callback"]
	spar_callback.call()
	dialog.choice_box.choice_selected.emit()
	await process_frame
	_expect(old_man._battle_pending and old_man._sparring_flow_active, "choosing spar keeps battle-flow guards")
	_expect(not dialog.choice_box.visible, "the choice is hidden during sparring")
	_expect(global_state.get_flag("heard_oldman_zuoyin") and global_state.get_flag("triggered_zuoyin_gossip_summary"),
		"choosing spar does not revoke gossip")

	if dialog.dialog_active:
		dialog.finish_sequence()
	await process_frame
	_expect(global_state.get_flag("heard_oldman_zuoyin"), "the pre-battle dialogue does not revoke gossip")
	global_state.set_meta("pending_battle_result", {"result": "defeat"})
	old_man._try_resolve_oldfighter_battle_return()
	await process_frame
	_expect(dialog.dialog_active, "a defeat continues into the existing loss dialogue")
	dialog.finish_sequence()
	await process_frame
	_expect(global_state.get_flag("heard_oldman_zuoyin") and global_state.get_flag("triggered_zuoyin_gossip_summary"),
		"losing the spar does not revoke gossip or its summary")

	# If this NPC is not the third source, the sparring choice follows the intro immediately.
	for flag_name: String in watched_flags:
		global_state.set_flag(flag_name, false)
	side_quests.side_quests.erase("yh_side_oldfighter_01")
	dialog.sequences.clear()
	dialog.choice_count = 0
	dialog.choice_box.hide_choices()
	old_man._begin_interaction_flow()
	old_man._run_oldfighter_interaction()
	dialog.finish_sequence()
	await process_frame
	_expect(global_state.get_flag("heard_oldman_zuoyin") and not global_state.get_flag("triggered_zuoyin_gossip_summary"),
		"the old man's gossip is granted even when the other two sources are missing")
	_expect(dialog.sequences.size() == 1 and dialog.choice_count == 1,
		"without all three sources, the choice follows the intro without a summary")
	var decline_callback: Callable = dialog.choice_box.options[1]["callback"]
	decline_callback.call()
	dialog.choice_box.choice_selected.emit()
	dialog.finish_sequence()
	await process_frame
	_expect(global_state.get_flag("heard_oldman_zuoyin"), "declining the spar does not revoke gossip")

	global_state.flags = saved_flags
	side_quests.side_quests = saved_quests
	for meta_name: String in ["pending_battle_result", "oldfighter_spar_pending", "oldfighter_spar_has_weapon", "oldfighter_spar_has_armor_or_acc", "oldfighter_sparring_flow_lock_active"]:
		if global_state.has_meta(meta_name):
			global_state.remove_meta(meta_name)
	old_man.queue_free()
	game_root.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: old fighter gossip before spar")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)
