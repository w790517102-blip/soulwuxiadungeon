extends "res://scripts/presentation/StageBattleUI.gd"
## CARD_STAGE view. Everything (ItemLists, target picking, log, F8) is inherited
## from STAGE_25D. What differs: the 3D stage it builds, the "whose turn" marker,
## and the main commands (出招 / 內功 / 道具 / 防禦), which pop up from the active
## character card instead of sitting at the bottom of the screen.

const CardStageScene = preload("res://scenes/presentation/card_stage_3d.tscn")
## [id, label, art name, implemented]. 逃跑 and 機關 are placeholders: they do nothing yet.
const MAIN_COMMANDS: Array = [["skill", "出招", "btn_skill", true], ["inner_force", "內功", "btn_inner_force", true], ["item", "道具", "btn_item", true], ["defend", "防禦", "btn_defend", true], ["flee", "逃跑", "btn_flee", false], ["mechanism", "機關", "btn_mechanism", false]]
const BUTTON_DIR := "res://assets/UI/card_stage/"
const BUTTON_SIZE := Vector2(150, 108)
const LOG_BAR_TEXTURE := "res://assets/UI/card_stage/log_bar.webp"

var command_menu: PanelContainer
var command_hint: Label
var _command_buttons: Dictionary = {}


func _create_stage() -> Node3D:
	return CardStageScene.instantiate()


func _ready() -> void:
	super._ready()
	stage.active_card_clicked.connect(_on_active_card_clicked)
	_build_command_menu()
	_install_log_bar()


func _build_command_menu() -> void:
	command_menu = PanelContainer.new()
	command_menu.name = "CardCommandMenu"
	command_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	# The button art is the plate; the container itself draws nothing.
	command_menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	command_menu.hide()
	var grid := GridContainer.new()
	grid.name = "Buttons"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	command_menu.add_child(grid)
	for entry: Array in MAIN_COMMANDS:
		var button := TextureButton.new()
		button.name = String(entry[0])
		button.tooltip_text = String(entry[1])
		button.texture_normal = load(BUTTON_DIR + String(entry[2]) + ".webp") as Texture2D
		var glow: Texture2D = load(BUTTON_DIR + String(entry[2]) + "_glow.webp") as Texture2D
		button.texture_hover = glow
		button.texture_pressed = glow
		button.texture_focused = glow
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = BUTTON_SIZE
		if bool(entry[3]):
			button.pressed.connect(_on_card_command.bind(String(entry[0])))
		else:
			# Not implemented yet (逃跑 / 機關): clickable, but nothing happens.
			button.pressed.connect(_on_unimplemented_command.bind(String(entry[0])))
		grid.add_child(button)
		_command_buttons[String(entry[0])] = button
	_stage_hud.add_child(command_menu)
	command_hint = Label.new()
	command_hint.name = "CommandHint"
	command_hint.text = "點選閃爍的角色卡，下達指令"
	command_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	command_hint.add_theme_font_override("font", MenuUIFont)
	command_hint.add_theme_font_size_override("font_size", 22)
	command_hint.add_theme_color_override("font_color", Color("fff0a0"))
	command_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	command_hint.add_theme_constant_override("outline_size", 6)
	command_hint.hide()
	_stage_hud.add_child(command_hint)
	preload("res://scripts/presentation/BattleTypography.gd").apply(command_menu)


# --- Turn marker -----------------------------------------------------------------

func begin_turn(actor: Dictionary) -> void:
	super.begin_turn(actor)
	if _battle_opening_locked or stage == null:
		return
	if combat_controller and (bool(combat_controller.get("battle_finished")) or bool(combat_controller.get("_ending"))):
		return
	stage.set_active_actor(actor)


## Called by the preview/stage controller when an enemy starts acting.
func present_turn_marker(actor: Dictionary) -> void:
	if stage and stage_enabled:
		_hide_command_menu()
		stage.set_active_actor(actor)


func _enter_battle_end_ui_cleanup() -> void:
	if stage:
		stage.clear_active_actor()
	_hide_command_menu()
	super._enter_battle_end_ui_cleanup()


func set_teams(allies_data: Array, enemies_data: Array) -> void:
	super.set_teams(allies_data, enemies_data)
	_hide_command_menu()


func set_stage_enabled(value: bool) -> void:
	super.set_stage_enabled(value)
	# The base loop shows every HUD child with the stage; these two are on demand.
	if command_menu:
		command_menu.hide()
	if command_hint:
		command_hint.hide()


# --- Command pop-up --------------------------------------------------------------

func _command_menu_allowed() -> bool:
	return stage_enabled and on_action_selection and _menu.is_empty() \
		and not (target_picker and target_picker.active) and not stage.busy \
		and not _archive_open and not _battle_opening_locked and not battle_result_overlay.visible \
		and not stage.is_lineup_moving()


func _same_actor(first: Dictionary, second: Dictionary) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	var first_uid: String = String(first.get("battle_uid", ""))
	if not first_uid.is_empty():
		return first_uid == String(second.get("battle_uid", ""))
	return String(first.get("id", "")) == String(second.get("id", ""))


func _on_active_card_clicked(actor: Dictionary) -> void:
	if not _command_menu_allowed() or not _same_actor(actor, current_actor):
		return
	if command_menu.visible:
		_hide_command_menu()
		return
	_show_command_menu()


func _show_command_menu() -> void:
	if combat_controller:
		_command_buttons["item"].disabled = not combat_controller.can_use_items()
		_command_buttons["item"].modulate = Color.WHITE if combat_controller.can_use_items() else Color(0.45, 0.45, 0.45)
		_command_buttons["inner_force"].disabled = not combat_controller.can_switch_inner_force()
		_command_buttons["inner_force"].modulate = Color.WHITE if combat_controller.can_switch_inner_force() else Color(0.45, 0.45, 0.45)
	command_menu.show()
	command_menu.reset_size()
	var rect: Rect2 = stage.card_screen_rect(current_actor)
	var screen: Vector2 = get_viewport_rect().size
	var point := Vector2(rect.end.x + 12.0, rect.position.y + rect.size.y * 0.22)
	command_menu.global_position = point.clamp(Vector2(12, 60), screen - command_menu.size - Vector2(12, 160))
	command_hint.hide()


func _hide_command_menu() -> void:
	if command_menu:
		command_menu.hide()


func _on_card_command(command: String) -> void:
	_hide_command_menu()
	dispatch_stage_command(command)


func _process(delta: float) -> void:
	super._process(delta)
	if not _view_ready or command_menu == null:
		return
	var allowed: bool = _command_menu_allowed()
	if command_menu.visible and not allowed:
		_hide_command_menu()
	command_hint.visible = allowed and not command_menu.visible
	if command_hint.visible:
		var screen: Vector2 = get_viewport_rect().size
		command_hint.global_position = Vector2(24.0, screen.y - 96.0)


func _unhandled_input(event: InputEvent) -> void:
	if command_menu and command_menu.visible:
		var cancel: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
		if cancel:
			_hide_command_menu()
			get_viewport().set_input_as_handled()
			return
	# Dev aid for yaw comparison (45 / 50 / 55 degrees). Debug builds only.
	if OS.is_debug_build() and stage_enabled and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9 and stage.has_method("cycle_yaw_preset"):
		var yaw: float = stage.cycle_yaw_preset()
		print("Card Stage yaw: %d°" % int(yaw))
		var scene: Node = get_parent().get_parent() if get_parent() else null
		if scene and scene.has_method("_show_presentation_badge") and scene.get("_presentation_badge") != null:
			scene._show_presentation_badge("CARD_STAGE  yaw %d°" % int(yaw))
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


## 逃跑 / 機關: placeholders for features that are not implemented yet.
func _on_unimplemented_command(_command: String) -> void:
	pass


# --- Log bar ---------------------------------------------------------------------

var _log_bar_art: TextureRect


## The supplied long bar replaces the plain recent-log plate. 「紀錄」sits in the bar's
## small slot; text goes in its dark panel.
func _install_log_bar() -> void:
	var plate: Control = _stage_hud.get_node_or_null("RecentLogPlate")
	var texture: Texture2D = load(LOG_BAR_TEXTURE) as Texture2D
	if plate == null or texture == null:
		return
	if plate is Panel:
		(plate as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_log_bar_art = TextureRect.new()
	_log_bar_art.name = "LogBarArt"
	_log_bar_art.texture = texture
	_log_bar_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_log_bar_art.stretch_mode = TextureRect.STRETCH_SCALE
	_log_bar_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_log_bar_art)
	var archive: Button = _stage_hud.get_node_or_null("Archive")
	if archive:
		archive.text = "紀錄"
		for state: String in ["normal", "pressed", "focus", "disabled"]:
			archive.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1.0, 0.85, 0.45, 0.16)
		hover.set_corner_radius_all(6)
		archive.add_theme_stylebox_override("hover", hover)
		archive.add_theme_color_override("font_color", Color("e8d6a8"))
		archive.add_theme_font_size_override("font_size", 17)
	_recent_log.add_theme_font_size_override("normal_font_size", 16)
	_layout_stage_hud()


func _layout_stage_hud() -> void:
	super._layout_stage_hud()
	if _log_bar_art == null or not is_instance_valid(_stage_hud):
		return
	var plate: Control = _stage_hud.get_node("RecentLogPlate")
	var screen: Vector2 = get_viewport_rect().size
	var texture_size: Vector2 = _log_bar_art.texture.get_size()
	var width: float = screen.x * 0.56
	var height: float = width * texture_size.y / texture_size.x
	plate.position = Vector2(screen.x - width - 10.0, screen.y - height - 8.0)
	plate.size = Vector2(width, height)
	_log_bar_art.position = Vector2.ZERO
	_log_bar_art.size = plate.size
	# Fractions measured on the supplied bar: dark text panel and the small slot.
	_recent_log.position = plate.position + Vector2(width * 0.066, height * 0.33)
	_recent_log.size = Vector2(width * 0.73, height * 0.52)
	var archive: Control = _stage_hud.get_node("Archive")
	archive.position = plate.position + Vector2(width * 0.822, height * 0.60)
	archive.size = Vector2(width * 0.113, height * 0.26)
	_continue.position = Vector2(plate.position.x + width - 176.0, plate.position.y - 42.0)
	_continue.size = Vector2(160, 35)


# --- Stage entity presentation entry points (called by BattleController) ------------------

## Casting a skill that leaves a card on the stage. phase: "windup" / "finish".
func play_stage_entity_cast(actor: Dictionary, _skill_data: Dictionary, phase: String) -> void:
	if stage_enabled and stage:
		await stage.present_stage_entity_cast(actor, phase)


## An enemy blow (or the shared part of an area blow) lands on a stage entity.
func play_stage_entity_hit(attacker: Dictionary, entity: Object, destroyed: bool, attacker_motion: bool, landed: bool = true) -> void:
	if stage_enabled and stage:
		await stage.present_entity_attack(attacker, entity, destroyed, attacker_motion, landed)


## Support action on teammates: step forward, hold, return slowly.
func play_support_motion(actor: Dictionary) -> void:
	if stage_enabled and stage:
		stage.support_motion(actor)
	else:
		play_attack_motion(actor)


## Boss story actions (called by BattleController).
func play_stage_status_event(kind: String, actor: Dictionary) -> void:
	if not (stage_enabled and stage):
		return
	match kind:
		"entangle": await stage.present_entangle(actor)
		"entangle_break": stage.present_entangle_break(actor)


func play_guest_action(guest: Dictionary, action_id: String, boss: Dictionary, removes: bool) -> void:
	if stage_enabled and stage:
		await stage.present_guest_action(guest, action_id, boss, removes)
