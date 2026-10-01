extends "res://scripts/presentation/StageBattleUI.gd"
## CARD_STAGE view. Everything (ItemLists, target picking, log, F8) is inherited
## from STAGE_25D. What differs: the 3D stage it builds, the "whose turn" marker,
## and the main commands (出招 / 內功 / 道具 / 防禦), which pop up from the active
## character card instead of sitting at the bottom of the screen.

const CardStageScene = preload("res://scenes/presentation/card_stage_3d.tscn")
const MAIN_COMMANDS: Array = [["skill", "出招"], ["inner_force", "內功"], ["item", "道具"], ["defend", "防禦"]]

var command_menu: PanelContainer
var command_hint: Label
var _command_buttons: Dictionary = {}


func _create_stage() -> Node3D:
	return CardStageScene.instantiate()


func _ready() -> void:
	super._ready()
	stage.active_card_clicked.connect(_on_active_card_clicked)
	_build_command_menu()


func _build_command_menu() -> void:
	command_menu = PanelContainer.new()
	command_menu.name = "CardCommandMenu"
	command_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	command_menu.add_theme_stylebox_override("panel", _plate_style())
	command_menu.hide()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	command_menu.add_child(column)
	for entry: Array in MAIN_COMMANDS:
		var button := Button.new()
		button.name = String(entry[0])
		button.text = String(entry[1])
		button.custom_minimum_size = Vector2(150, 50)
		button.add_theme_font_override("font", MenuUIFont)
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_on_card_command.bind(String(entry[0])))
		column.add_child(button)
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
		and not _archive_open and not _battle_opening_locked and not battle_result_overlay.visible


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
		_command_buttons["inner_force"].disabled = not combat_controller.can_switch_inner_force()
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
