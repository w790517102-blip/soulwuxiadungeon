extends Node
## Standalone presentation fixture. It uses production combat and copied actors,
## but its controller can never enter rewards, persistence, or story return.

signal prototype_prepared

const BATTLE_SCENE := preload("res://scenes/battle_scene.tscn")
const EnemyDBScript := preload("res://scripts/db/EnemyDB.gd")

@export var auto_start: bool = true
@export var stage_enabled: bool = true
## View script for the preview battle; CardStagePrototype swaps in CARD_STAGE.
@export var ui_script_path: String = "res://scripts/presentation/StageBattleUI.gd"

var battle: Node
var controller: Node
var ui: Node
var preview_team: Node
var prepared: bool = false
var _status: Label
var _toggle: Button
var _restarting: bool = false
var _capture_path: String = ""
var _capture_menu: String = ""


class PreviewTeam extends "res://scripts/battlescripts/TeamDataManager.gd":
	func _sync_inner_force_to_global_state(_actor_id: String, _force_id: String) -> void:
		# A preview switch must not replace the active campaign's inner-force map.
		pass


class PreviewBattleRoot extends "res://scripts/battlescripts/BattleScene.gd":
	func _enter_tree() -> void:
		# Do not inspect or consume a campaign's pending battle context.
		get_node("BattleUILayer/BattleUI/LogPanel").set_script(load("res://scripts/presentation/StageLogPanel.gd"))
		var ui_script: String = String(get_meta("presentation_ui_script", "res://scripts/presentation/StageBattleUI.gd"))
		_replace_view_script(get_node("BattleUILayer/BattleUI"), load(ui_script), ["tone"])

	func _try_start_from_pending_context() -> void:
		pass


class PreviewController extends "res://scripts/presentation/StageBattleController.gd":
	signal preview_finished(result: String)

	func _mark_enemy_lore_encounter(_enemy: Dictionary) -> void:
		pass

	func _begin_end_battle(result: String) -> void:
		if _ending:
			return
		_ending = true
		battle_finished = true
		if battle_ui:
			battle_ui.on_action_selection = false
			battle_ui.action_panel.hide()
			if battle_ui.get("stage"):
				battle_ui.stage.input_enabled = false
				battle_ui.stage.command_tray.set_enabled(false)
		preview_finished.emit(result)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage-capture="):
			_capture_path = argument.trim_prefix("--stage-capture=")
			auto_start = false
		elif argument.begins_with("--stage-capture-menu="):
			_capture_menu = argument.trim_prefix("--stage-capture-menu=")
	_build_preview_controls()
	await _prepare_battle()
	if not _capture_path.is_empty():
		await _capture_snapshot()


func _prepare_battle() -> void:
	prepared = false
	preview_team = PreviewTeam.new()
	preview_team.name = "PreviewTeam"
	add_child(preview_team)
	battle = BATTLE_SCENE.instantiate()
	battle.set_script(PreviewBattleRoot)
	battle.set_meta("presentation_preview_controller", true)
	battle.set_meta("presentation_ui_script", ui_script_path)
	controller = battle.get_node("BattleController")
	PreviewBattleRoot._replace_view_script(controller, PreviewController, ["tone_map", "status_manager"])
	add_child(battle)
	# The production controller wires its scene references with call_deferred.
	await get_tree().process_frame
	await get_tree().process_frame
	controller.team_data_manager = preview_team
	controller.skill_db.knowledge_provider = preview_team
	controller.preview_finished.connect(_on_preview_finished)
	ui = battle.get_node("BattleUILayer/BattleUI")
	ui.set_stage_enabled(stage_enabled)
	prepared = true
	prototype_prepared.emit()
	if auto_start:
		controller.start_battle(build_preview_context())


func build_preview_context() -> Dictionary:
	var actor: Dictionary = preview_team.get_character_by_id("liuyu").duplicate(true)
	actor["hp"] = actor.get("max_hp", 150)
	actor["mp"] = actor.get("max_mp", 60)
	# Existing authored enemies/skills are copied, never added to their databases.
	var enemy: Dictionary = EnemyDBScript.make_enemy("fidgety_sewer_fish")
	enemy["name"] = "燥尾魚蝦魅・演示"
	enemy["display_name"] = enemy["name"]
	enemy["hp"] = 180
	enemy["max_hp"] = 180
	enemy["atk"] = 8
	enemy["exp"] = 0
	enemy["gold"] = {"chance": 0.0, "min": 0, "max": 0}
	enemy["drops"] = []
	return {
		"battle_id": "presentation_stage_preview",
		"player_party": [actor],
		"enemy_party": [enemy],
		"use_exact_enemy_rewards": true,
		"ruleset": {"allow_items": false, "allow_inner_force_switch": true, "allow_escape": false},
		"battle_tag": "yuheng_sewer_random",
		"zone_id": "yuheng_sewer",
		"stage_background": "res://assets/presentation/stalactite_stage.png",
	}


func _capture_snapshot() -> void:
	# Opt-in rendering check. It writes only the explicitly supplied PNG path.
	# No combat starts, so a capture does not need simulated progression inputs.
	var context := build_preview_context()
	if _capture_menu == "multi":
		for index in range(1, 3):
			var ally: Dictionary = context.player_party[0].duplicate(true)
			ally["id"] = "preview_ally_%d" % index
			ally["name"] = "演武同伴 %d" % index
			var enemy: Dictionary = context.enemy_party[0].duplicate(true)
			context.player_party.append(ally)
			context.enemy_party.append(enemy)
	controller.player_party = context.player_party
	controller.enemy_party = context.enemy_party
	controller.battle_context = context
	controller.ruleset = context.ruleset
	for index: int in range(controller.enemy_party.size()):
		controller.enemy_party[index]["is_enemy"] = true
		controller.enemy_party[index]["battle_uid"] = "preview_capture#%d" % index
	ui.set_teams(controller.player_party, controller.enemy_party)
	ui.apply_ruleset(context.ruleset)
	ui.stage.set_background(context.stage_background)
	ui._opening_overlay.hide()
	ui._battle_black_overlay.hide()
	ui.log_panel._chars_per_sec = 1000000
	ui.begin_turn(controller.player_party[0])
	while ui.log_panel._typing or not ui.log_panel._queue.is_empty():
		if ui.log_panel.waiting_for_message_advance(): ui.log_panel.handle_message_input()
		await get_tree().process_frame
	if not _capture_menu.is_empty():
		if _capture_menu == "item":
			# Capture-only copied entries; never grant/consume campaign inventory.
			var popup: Window = ui.item_list_popup
			popup.user_actor = controller.player_party[0]
			popup.item_list.clear()
			popup.current_items.clear()
			for id: String in ["med_bandage", "med_bandage", "med_bandage"]:
				var item: Dictionary = load("res://scripts/db/ItemDB.gd").get_def(id).duplicate(true)
				item["quantity"] = 3
				popup.current_items.append(item)
				popup.item_list.add_item("%s ×3" % item.name)
			popup.popup_centered()
		elif _capture_menu == "archive":
			for index in range(60): ui.log_panel.log("歷史戰報 %02d：演武紀錄，保留從開戰起的全部訊息。" % index)
			while ui.log_panel._typing or not ui.log_panel._queue.is_empty(): await get_tree().process_frame
			ui._toggle_archive()
		else:
			ui.dispatch_stage_command("skill" if _capture_menu in ["target", "confirm"] else _capture_menu)
		if ui._menu_list() and ui._menu_list().item_count > 0:
			ui.select_stage_option(0)
		if _capture_menu in ["target", "confirm"]:
			ui.select_stage_option(ui._option_actions.find("confirm"))
			var point: Vector2 = ui.stage.card_screen_rect(controller.enemy_party[0]).get_center()
			ui.target_picker._update_pointer(point)
			if _capture_menu == "confirm": ui.target_picker.select_at(point)
		elif _capture_menu == "os":
			ui.show_actor_line_for_actor(controller.enemy_party[0], "休想從這裡過去！")
		elif _capture_menu == "legacy": ui.set_stage_enabled(false)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var error: Error = screenshot.save_png(_capture_path)
	if error != OK:
		push_error("Unable to save stage preview: %s (%d)" % [_capture_path, error])
	get_tree().quit(0 if error == OK else 1)


func _build_preview_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PreviewTools"
	layer.layer = 100
	add_child(layer)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 8)
	row.add_theme_constant_override("separation", 14)
	layer.add_child(row)
	_status = Label.new()
	_status.text = "舞台演示｜獨立演武，不發獎勵"
	_status.add_theme_font_size_override("font_size", 16)
	row.add_child(_status)
	_toggle = Button.new()
	_toggle.text = "切換舊版戰報"
	_toggle.pressed.connect(_toggle_presentation)
	row.add_child(_toggle)
	var restart := Button.new()
	restart.text = "重新演武"
	restart.pressed.connect(_restart_preview)
	row.add_child(restart)
	preload("res://scripts/presentation/BattleTypography.gd").apply(row)


func _toggle_presentation() -> void:
	if not prepared:
		return
	if ui.stage.busy:
		return
	stage_enabled = not stage_enabled
	ui.set_stage_enabled(stage_enabled)
	_toggle.text = "切換舊版戰報" if stage_enabled else "切換 2.5D 舞台"


func _restart_preview() -> void:
	if _restarting or not prepared:
		return
	_restarting = true
	prepared = false
	battle.queue_free()
	_free_preview_team()
	await get_tree().process_frame
	_status.text = "舞台演示｜獨立演武，不發獎勵"
	await _prepare_battle()
	_restarting = false


func _on_preview_finished(result: String) -> void:
	_status.text = "演武結束：%s｜可按「重新演武」" % ("勝利" if result == "victory" else "落敗")


func _free_preview_team() -> void:
	if not is_instance_valid(preview_team):
		return
	# TeamData owns these unattached database Nodes; release the isolated copies.
	for key: String in ["_inner_force_db", "_skill_db", "_character_db", "_job_db"]:
		var database: Node = preview_team.get(key)
		if is_instance_valid(database):
			database.free()
	preview_team.queue_free()
	preview_team = null


func _exit_tree() -> void:
	_free_preview_team()
