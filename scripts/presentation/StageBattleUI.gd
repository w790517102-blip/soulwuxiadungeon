extends "res://scripts/battlescripts/BattleUI.gd"
## Inherits the production command/result workflow. Only its presentation changes.

const StageScene = preload("res://scenes/presentation/combat_stage_25d.tscn")
var stage: Node3D
var stage_enabled: bool = true
var _stage_hud: Control
var _recent_log: RichTextLabel
var _continue: Button
var _archive_panel: Panel
var _archive_open: bool = false
var _menu_description: RichTextLabel
var _mode_button: Button
var _old_log_rect: Rect2
var _old_log_z: int
var _old_mouse_filter: int
var _menu: String = ""
var _menu_selected: int = -1
var _option_actions: Array = []
var _view_ready: bool = false
var _status_clock: float = 0.0
## true: the battlefield cards show status ICONS (CardStageStatusRow); false: the old single words.
const BATTLEFIELD_STATUS_ICONS := false
var _last_input_enabled: bool = false
var target_picker: Control
var _target_return_menu: String = "skill"
var _old_log_mouse_filter: int


func _ready() -> void:
	super._ready()
	_old_log_rect = Rect2(log_panel.position, log_panel.size)
	_old_log_z = log_panel.z_index
	_old_log_mouse_filter = log_panel.mouse_filter
	_old_mouse_filter = mouse_filter
	stage = _create_stage()
	add_child(stage)
	stage.bind_ui(self)
	_build_stage_hud()
	get_viewport().gui_embed_subwindows = true
	_prepare_action_list_layouts()
	target_picker = preload("res://scripts/presentation/StageTargetPicker.gd").new()
	add_child(target_picker)
	target_picker.stage = stage
	target_picker.target_confirmed.connect(_confirm_stage_target)
	target_picker.selection_cancelled.connect(_return_to_skill_list)
	for popup in [skill_list_popup, inner_force_popup, item_list_popup, defense_confirm_popup, target_select_popup]:
		popup.visibility_changed.connect(_capture_popup.bind(popup))
		popup.window_input.connect(_popup_shortcuts.bind(popup))
	for popup in [skill_list_popup, inner_force_popup, item_list_popup]:
		popup.popup_hide.connect(_action_popup_closed.bind(popup))
	_view_ready = true
	set_stage_enabled(true)
	get_viewport().size_changed.connect(_layout_stage_hud)
	preload("res://scripts/presentation/BattleTypography.gd").apply(self)
	move_child(_message_input_router, get_child_count() - 1)


func _create_stage() -> Node3D:
	# Extension point for other stage presentations (CARD_STAGE overrides this).
	return StageScene.instantiate()


func _build_stage_hud() -> void:
	_stage_hud = Control.new()
	_stage_hud.name = "StageReadout"
	_stage_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_hud.z_index = 100
	add_child(_stage_hud)
	var plate := Panel.new()
	plate.name = "RecentLogPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _plate_style())
	_stage_hud.add_child(plate)
	_recent_log = RichTextLabel.new()
	_recent_log.bbcode_enabled = true
	_recent_log.name = "RecentThreeLines"
	_recent_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recent_log.scroll_active = false
	_recent_log.add_theme_font_override("normal_font", MenuUIFont)
	_recent_log.add_theme_font_size_override("normal_font_size", 18)
	_stage_hud.add_child(_recent_log)
	_menu_description = RichTextLabel.new()
	_menu_description.name = "SelectionDescription"
	_menu_description.bbcode_enabled = true
	_menu_description.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_description.add_theme_font_override("normal_font", MenuUIFont)
	_menu_description.add_theme_font_size_override("normal_font_size", 18)
	_menu_description.add_theme_stylebox_override("normal", _plate_style())
	_stage_hud.add_child(_menu_description)
	_continue = _button("Continue", "繼續 [Space]", _accept_checkpoint)
	_button("Archive", "紀錄 [L]", _toggle_archive)
	_mode_button = _button("Mode", "切回文字版 [F8]", _toggle_mode)
	_archive_panel = Panel.new()
	_archive_panel.name = "LogDrawerPlate"
	# GUI hit order follows the tree, not z_index. Let the earlier LogPanel's
	# native scrollbar receive clicks; child close/latest buttons remain active.
	_archive_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_archive_panel.z_index = 110
	_archive_panel.add_theme_stylebox_override("panel", _plate_style())
	_archive_panel.hide()
	add_child(_archive_panel)
	var latest := Button.new()
	latest.name = "Latest"
	latest.text = "回到最新"
	latest.pressed.connect(log_panel.scroll_archive_to_latest)
	_archive_panel.add_child(latest)
	var close := Button.new()
	close.name = "Close"
	close.text = "關閉 [L]"
	close.pressed.connect(_toggle_archive)
	_archive_panel.add_child(close)
	_layout_stage_hud()


func _plate_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.037, 0.05, 0.94)
	style.border_color = Color("96784d")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	return style


func _button(node_name: String, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.add_theme_font_override("font", MenuUIFont)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	_stage_hud.add_child(button)
	return button


func _layout_stage_hud() -> void:
	if not is_instance_valid(_stage_hud):
		return
	var screen: Vector2 = get_viewport_rect().size
	_stage_hud.position = -global_position
	_stage_hud.size = screen
	var plate: Control = _stage_hud.get_node("RecentLogPlate")
	plate.position = Vector2(screen.x * 0.54, screen.y - 145)
	plate.size = Vector2(screen.x * 0.46 - 16, 129)
	_recent_log.position = plate.position + Vector2(12, 8)
	_recent_log.size = plate.size - Vector2(24, 45)
	_continue.position = Vector2(screen.x - 354, screen.y - 55)
	_continue.size = Vector2(160, 35)
	var archive: Control = _stage_hud.get_node("Archive")
	archive.position = Vector2(screen.x - 184, screen.y - 59)
	archive.size = Vector2(160, 35)
	_mode_button.position = Vector2(screen.x - 242, 12)
	_mode_button.size = Vector2(225, 36)
	_menu_description.position = Vector2(screen.x * 0.30, screen.y * 0.10)
	_menu_description.size = Vector2(screen.x * 0.40, screen.y * 0.27)
	if _archive_panel:
		_archive_panel.position = Vector2(screen.x * 0.17, 64) - global_position
		_archive_panel.size = Vector2(screen.x * 0.66, screen.y - 190)
		_archive_panel.get_node("Latest").position = Vector2(_archive_panel.size.x - 240, 8)
		_archive_panel.get_node("Close").position = Vector2(_archive_panel.size.x - 120, 8)
	if _archive_open:
		log_panel.position = Vector2(14, 52)
		log_panel.size = _archive_panel.size - Vector2(28, 66)


func set_stage_enabled(value: bool) -> void:
	if not _view_ready:
		stage_enabled = value
		return
	if not _menu.is_empty():
		_cancel_menu()
	if target_picker:
		if target_picker.active:
			pending_skill = {}
			pending_skill_user = {}
			pending_item = {}
			pending_item_user = {}
			on_action_selection = true
			action_panel.show()
		target_picker.close()
	if skill_list_popup: skill_list_popup.hide()
	_close_menu()
	_restore_log_parent()
	_archive_open = false
	stage_enabled = value
	stage.visible = value
	stage.enabled = value
	_stage_hud.visible = true # Mode switch also remains available in Legacy.
	for child in _stage_hud.get_children():
		child.visible = value or child == _mode_button
	_menu_description.hide()
	_archive_panel.hide()
	ally_panel.visible = not value
	enemy_panel.visible = not value
	get_node("background").visible = not value
	get_node("logpanel").visible = not value
	if _status_abbrev_overlay:
		_status_abbrev_overlay.visible = not value
	for child in action_panel.get_children():
		if child is Button:
			child.visible = not value
	# Hidden legacy Controls must not intercept clicks aimed at the 3D tray.
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else _old_mouse_filter
	action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	log_panel.visible = not value
	log_panel.position = _old_log_rect.position
	log_panel.size = _old_log_rect.size
	log_panel.z_index = _old_log_z
	log_panel.set("stage_active", value)
	log_panel.set("drawer_open", false)
	log_panel.mouse_filter = _old_log_mouse_filter
	_mode_button.text = "切回文字版 [F8]" if value else "切回舞台版 [F8]"
	if value:
		stage.camera.make_current()
		stage.refresh_statuses(allies, enemies)
	else:
		stage.camera.clear_current()
		for card in stage.cards.values():
			card.reset_pose()
	_sync_input_state()


func _toggle_mode() -> void:
	if _battle_opening_locked or stage.busy or battle_result_overlay.visible:
		return
	set_stage_enabled(not stage_enabled)


func _toggle_archive() -> void:
	if not stage_enabled or _battle_opening_locked or battle_result_overlay.visible or not _menu.is_empty():
		return
	_archive_open = not _archive_open
	if _archive_open:
		log_panel.reparent(_archive_panel, false)
	else:
		_restore_log_parent()
	_archive_panel.visible = _archive_open
	log_panel.visible = _archive_open
	log_panel.z_index = 1 if _archive_open else _old_log_z
	log_panel.set("drawer_open", _archive_open)
	log_panel.mouse_filter = Control.MOUSE_FILTER_STOP if _archive_open else _old_log_mouse_filter
	log_panel.scroll_active = true
	log_panel.scroll_following = false
	log_panel.get_v_scroll_bar().custom_minimum_size.x = 18
	_layout_stage_hud()
	if _archive_open: log_panel.call_deferred("scroll_archive_to_latest")
	_sync_input_state()

func _restore_log_parent() -> void:
	if log_panel.get_parent() != self:
		log_panel.reparent(self, false)
		move_child(_message_input_router, get_child_count() - 1)
	log_panel.position = _old_log_rect.position
	log_panel.size = _old_log_rect.size


func _accept_checkpoint() -> void:
	if not _archive_open and _menu.is_empty():
		log_panel.accept_checkpoint()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			_toggle_mode()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_L:
			_toggle_archive()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and not _menu.is_empty():
			_cancel_menu()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func _process(delta: float) -> void:
	super._process(delta)
	if not _view_ready or not stage_enabled:
		return
	_sync_input_state()
	for slot in ally_slots + enemy_slots:
		var key: String = _get_bubble_key_for_slot(slot)
		var box: PanelContainer = _actor_bubble_boxes.get(key)
		if box and box.visible: _position_bubble_on_portrait(slot, box)
	var shown_text: String = log_panel.get_parsed_text()
	if log_panel.visible_characters >= 0: shown_text = shown_text.left(log_panel.visible_characters)
	if log_panel.has_method("recent_bbcode"):
		# Same colours as the log itself (the box used to copy plain text only).
		_recent_log.text = log_panel.recent_bbcode(shown_text, 3)
	else:
		var lines: PackedStringArray = shown_text.strip_edges().split("\n", false)
		_recent_log.text = "\n".join(lines.slice(maxi(0, lines.size() - 3)))
	_continue.visible = (log_panel._waiting_for_continue or log_panel.waiting_for_message_advance()) and not _archive_open and _menu.is_empty()
	if log_panel.get("_continue_hint_label"):
		log_panel.get("_continue_hint_label").hide()
	# Only status glyphs (including their existing last-turn blink) refresh here;
	# HP/MP changes remain tied to the original explicit refresh hooks.
	_status_clock += delta
	if _status_clock > 0.15:
		_status_clock = 0.0
		for actor in allies + enemies:
			var card: Node = stage.card_for(actor)
			if card:
				var packed: Dictionary = _build_status_abbrev_text(actor)
				if BATTLEFIELD_STATUS_ICONS and card.has_method("set_status_entries"):
					# Optional: icons on the battlefield card (a word where there is no art). Off by default: the field is for
					# a quick read (single words) and the details, icons included, are in Card Inspect.
					card.set_status_entries(packed.get("entries", []) if int(actor.get("hp", 0)) > 0 else [])
				else:
					card.status_label.text = String(packed.get("text", ""))


func _sync_input_state() -> void:
	if not stage:
		return
	var ending: bool = combat_controller != null and bool(combat_controller.get("_ending"))
	var can_select: bool = stage_enabled and not ending and not _battle_opening_locked and not battle_result_overlay.visible and not _archive_open and not stage.busy and (on_action_selection or not _menu.is_empty())
	stage.input_enabled = can_select
	if can_select != _last_input_enabled:
		stage.command_tray.set_enabled(can_select and _menu not in ["skill", "inner_force", "item", "target"])
		_last_input_enabled = can_select
	if combat_controller:
		stage.command_tray.set_allowed("item", combat_controller.can_use_items())
		stage.command_tray.set_allowed("inner_force", combat_controller.can_switch_inner_force())


func _set_button_allowed(button: Node, allowed: bool) -> void:
	super._set_button_allowed(button, allowed)
	if button and stage_enabled:
		button.hide()


func _set_battle_input_locked(locked: bool) -> void:
	super._set_battle_input_locked(locked)
	if stage_enabled and action_panel:
		action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func dispatch_stage_command(command: String) -> void:
	if not stage.input_enabled or not _menu.is_empty():
		return
	match command:
		"skill": _on_btn_skill_pressed()
		"inner_force": _on_btn_inner_force_pressed()
		"item": _on_btn_item_pressed()
		"defend": _on_btn_defend_pressed()
	_sync_input_state()


func _capture_popup(popup: Window) -> void:
	if not _view_ready or not stage_enabled or not popup.visible:
		return
	if popup in [skill_list_popup, inner_force_popup, item_list_popup]:
		_menu = "skill" if popup == skill_list_popup else ("inner_force" if popup == inner_force_popup else "item")
		var list: ItemList = _menu_list()
		var selected: PackedInt32Array = list.get_selected_items()
		_menu_selected = selected[0] if not selected.is_empty() else -1
		_option_actions.clear()
		for i in range(list.item_count): _option_actions.append(i)
		_option_actions.append("confirm")
		_option_actions.append("cancel")
		stage.command_tray.set_expanded(false)
		stage.command_tray.set_enabled(false)
		_menu_description.hide()
		_menu_description.text = "選擇項目查看說明，再按確認。"
		return
	# The original popup builds its real eligible entries first. Re-present those
	# entries in depth; its selection/confirm callbacks remain the sole authority.
	popup.hide()
	if popup == skill_list_popup: _menu = "skill"
	elif popup == inner_force_popup: _menu = "inner_force"
	elif popup == item_list_popup: _menu = "item"
	elif popup == target_select_popup: _menu = "target"
	elif popup == defense_confirm_popup: _menu = "defend"
	_menu_selected = -1
	_menu_description.text = "選擇項目查看說明，再按確認。"
	if _menu == "defend":
		_menu_description.text = "採取防禦姿態，結束本回合？"
	_render_menu()
	_sync_input_state()


func _menu_list() -> ItemList:
	match _menu:
		"skill": return skill_list_popup.skill_list
		"inner_force": return inner_force_popup.force_list
		"item": return item_list_popup.item_list
		"target": return target_select_popup.target_list
	return null


func _render_menu() -> void:
	var list: ItemList = _menu_list()
	var labels: Array = []
	_option_actions.clear()
	if list:
		for i in range(list.item_count):
			labels.append(("✓ " if i == _menu_selected else "") + list.get_item_text(i))
			_option_actions.append(i)
	var footer: Array = ["確認" if _menu_selected >= 0 or _menu == "defend" else "先選擇項目", "取消"]
	_option_actions.append("confirm")
	_option_actions.append("cancel")
	stage.command_tray.set_options(labels, footer)
	stage.command_tray.set_expanded(true)
	_menu_description.show()


func select_stage_option(index: int) -> void:
	if index < 0 or index >= _option_actions.size() or not stage.input_enabled:
		return
	var action: Variant = _option_actions[index]
	var list: ItemList = _menu_list()
	if action is int:
		if not list or list.is_item_disabled(action):
			return
		_menu_selected = action
		list.select(action)
		list.item_selected.emit(action)
		match _menu:
			"skill": _menu_description.text = skill_list_popup.description_label.text
			"inner_force": _menu_description.text = inner_force_popup.description.text
			"item": _menu_description.text = item_list_popup.description.text + "\n" + item_list_popup.quantity_label.text
			"target": _menu_description.text = target_select_popup.description.text
		if _menu not in ["skill", "inner_force", "item"]: _render_menu()
	elif action == "cancel":
		_cancel_menu()
	elif action == "confirm" and (_menu_selected >= 0 or _menu == "defend"):
		var selected_menu: String = _menu
		_close_menu()
		match selected_menu:
			"skill": skill_list_popup._on_Confirm_pressed()
			"inner_force": inner_force_popup._on_confirm_pressed()
			"item": item_list_popup._on_confirm_pressed()
			"target": target_select_popup._on_confirm_pressed()
			"defend": defense_confirm_popup._on_confirm_pressed()
		_sync_input_state()


func _cancel_menu() -> void:
	if target_picker and target_picker.active:
		target_picker.cancel_layer()
		return
	var selected_menu: String = _menu
	_close_menu()
	match selected_menu:
		"skill": skill_list_popup._on_Cancel_pressed()
		"inner_force": inner_force_popup._on_cancel_pressed()
		"item": item_list_popup._on_cancel_pressed()
		"target": target_select_popup._on_cancel_pressed()
		"defend": defense_confirm_popup._on_cancel_pressed()
	_sync_input_state()


func _close_menu() -> void:
	_menu = ""
	_option_actions.clear()
	if stage:
		stage.command_tray.set_expanded(false)
	if _menu_description:
		_menu_description.hide()
	_last_input_enabled = false


func set_teams(allies_data: Array, enemies_data: Array) -> void:
	super.set_teams(allies_data, enemies_data)
	if stage:
		stage.set_teams(allies, enemies, guest_actor, _build_status_abbrev_text)
		var context: Dictionary = combat_controller.battle_context if combat_controller else {}
		var path: String = String(context.get("stage_background", ""))
		if path.is_empty():
			path = resolve_stage_background(context)
		stage.set_background(path)


func set_guest_presentation(guest_data: Dictionary) -> void:
	super.set_guest_presentation(guest_data)
	if stage:
		stage.set_teams(allies, enemies, guest_actor, _build_status_abbrev_text)


func update_ally_panel() -> void:
	super.update_ally_panel()
	if stage:
		for actor in allies: stage.refresh_actor(actor)


func update_enemy_panel() -> void:
	super.update_enemy_panel()
	if stage:
		for actor in enemies: stage.refresh_actor(actor)


func update_ally_status(index: int, actor: Dictionary) -> void:
	super.update_ally_status(index, actor)
	if stage: stage.refresh_actor(actor)


func update_enemy_status(index: int, actor: Dictionary) -> void:
	super.update_enemy_status(index, actor)
	if stage: stage.refresh_actor(actor)


func play_attack_motion(actor: Dictionary) -> void:
	if stage_enabled and stage: stage.attack_motion(actor)
	else: super.play_attack_motion(actor)


func play_dodge_motion(actor: Dictionary) -> void:
	# Covers shared multi-target dispatch too; the single-target cinematic
	# reschedules this same local card motion at the start of its ribbon flight.
	if stage_enabled and stage: stage.react(actor, "dodge")
	else: super.play_dodge_motion(actor)


func play_damage_react(actor: Dictionary) -> void:
	if stage_enabled and stage: stage.react(actor, "hit")
	else: super.play_damage_react(actor)


func play_guard_react(actor: Dictionary) -> void:
	if stage_enabled and stage: stage.react(actor, "guard")
	else: super.play_guard_react(actor)


func play_defend_motion(actor: Dictionary) -> void:
	if stage_enabled and stage: stage.react(actor, "defend_on")
	else: super.play_defend_motion(actor)


func clear_defend_motion(actor: Dictionary) -> void:
	if stage_enabled and stage: stage.react(actor, "defend_off")
	else: super.clear_defend_motion(actor)


func show_battle_result(result: Dictionary) -> void:
	if target_picker: target_picker.close()
	skill_list_popup.hide()
	_close_menu()
	_restore_log_parent()
	_archive_open = false
	_archive_panel.hide()
	log_panel.visible = not stage_enabled
	super.show_battle_result(result)
	_sync_input_state()


func _prepare_action_list_layouts() -> void:
	var layout = preload("res://scripts/presentation/ActionItemListPanel.gd")
	layout.install(skill_list_popup, skill_list_popup.skill_list, skill_list_popup.description_label, skill_list_popup.confirm_button.get_parent(), "出招｜選擇武學")
	layout.install(inner_force_popup, inner_force_popup.force_list, inner_force_popup.description, inner_force_popup.confirm_button.get_parent(), "內功｜選擇心法")
	layout.install(item_list_popup, item_list_popup.item_list, item_list_popup.description, item_list_popup.btn_confirm.get_parent(), "道具｜選擇物品", item_list_popup.quantity_label)


func _action_popup_closed(popup: Window) -> void:
	var kind: String = "skill" if popup == skill_list_popup else ("inner_force" if popup == inner_force_popup else "item")
	if _menu == kind:
		_close_menu()
		_sync_input_state()


func _popup_shortcuts(event: InputEvent, popup: Window) -> void:
	if popup.is_input_handled(): return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		_toggle_mode()
		popup.set_input_as_handled()
	elif stage_enabled and ((event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE)):
		_cancel_menu()
		popup.set_input_as_handled()


func _start_target_select_for_skill(user: Dictionary, skill_data: Dictionary) -> void:
	if not stage_enabled or skill_data.has("stage_entity"):
		super._start_target_select_for_skill(user, skill_data)
		return
	_target_return_menu = "skill"
	var scope := String(skill_data.get("target_scope", "single"))
	var side := String(skill_data.get("target_side", ""))
	if side.is_empty():
		side = "ally" if String(skill_data.get("effect", "damage")) in ["heal", "heal_hp", "mp_heal", "buff_speed"] or scope.begins_with("ally") else "enemy"
	var candidates: Array = []
	var pool: Array = [user] if side == "self" else (allies if side == "ally" else enemies)
	for actor: Dictionary in pool:
		if int(actor.get("hp", 0)) > 0: candidates.append(actor)
	if candidates.is_empty():
		_log_system("目前沒有可選擇的目標。")
		_return_to_skill_list()
		return
	_menu = "target"
	_menu_description.hide()
	stage.command_tray.set_expanded(false)
	stage.command_tray.set_enabled(false)
	target_picker.begin(user, candidates)
	_sync_input_state()


func _confirm_stage_target(actor: Dictionary) -> void:
	_close_menu()
	_on_TargetSelectPopup_target_selected(actor)
	_sync_input_state()


func _return_to_skill_list() -> void:
	pending_skill = {}
	pending_skill_user = {}
	pending_item = {}
	pending_item_user = {}
	on_action_selection = true
	_close_menu()
	# Reopen the same list: keep selected index, effective skill and description.
	if _target_return_menu == "item": item_list_popup.popup_centered()
	else: skill_list_popup.popup_centered()
	_sync_input_state()

func _battle_message_blocked() -> bool:
	return _archive_open or not _menu.is_empty() or (target_picker and target_picker.active) or super._battle_message_blocked()

func _on_ItemListPopup_item_selected(item) -> void:
	if not stage_enabled or String(item.get("target_scope", "ally_single")) in ["enemy_all", "ally_all", "self"]:
		super._on_ItemListPopup_item_selected(item)
		return
	item_list_popup.hide()
	on_action_selection = false
	pending_item = item
	pending_item_user = current_actor
	_target_return_menu = "item"
	var targets: Array = combat_controller.get_valid_targets_for_item(item, current_actor)
	if targets.is_empty():
		_log_system("目前沒有可選擇的目標。")
		_return_to_skill_list()
		return
	_menu = "target"
	stage.command_tray.set_expanded(false)
	stage.command_tray.set_enabled(false)
	target_picker.begin(current_actor, targets, String(item.get("effect", "")) in ["revive", "revive_hp"])
	_sync_input_state()


func _position_bubble_on_portrait(slot: Control, box: PanelContainer) -> void:
	if not stage_enabled or not stage:
		super._position_bubble_on_portrait(slot, box)
		return
	var index: int = enemy_slots.find(slot)
	var enemy: bool = index >= 0
	if not enemy: index = ally_slots.find(slot)
	var actors: Array = enemies if enemy else allies
	if index < 0 or index >= actors.size(): return
	var rect: Rect2 = stage.card_screen_rect(actors[index])
	if rect.size == Vector2.ZERO: return
	var label: Label = box.get_node("Text")
	label.add_theme_font_override("font", MenuUIFont)
	label.add_theme_constant_override("outline_size", 0)
	label.custom_minimum_size = Vector2(216, 54)
	label.clip_text = true
	box.add_theme_stylebox_override("panel", _plate_style())
	box.size = Vector2(240, 82)
	var point := Vector2(rect.position.x - box.size.x - 12 if enemy else rect.end.x + 12, rect.get_center().y - box.size.y / 2.0)
	box.global_position = point.clamp(Vector2(12, 60), get_viewport_rect().size - box.size - Vector2(12, 160))


## Battle backdrop by place, from the battle context (an explicit `stage_background` wins).
## First matching rule wins; the default is the generic backdrop.
const BACKGROUND_RULES: Array = [
	{"any": ["molin_yanjiang", "stalactite"], "path": "res://assets/presentation/stalactite_stage.png"},
	{"any": ["old_fighter"], "path": "res://assets/presentation/bg_yuheng_arena.webp"},
	{"any": ["sewer"], "path": "res://assets/presentation/bg_sewer.webp"},
	{"any": ["bamboo"], "path": "res://assets/presentation/bg_bamboo.webp"},
]


static func resolve_stage_background(context: Dictionary) -> String:
	var haystack: String = ""
	for key: String in ["battle_id", "battle_tag", "zone_id", "map_id", "scene_name"]:
		haystack += " " + String(context.get(key, "")).to_lower()
	for rule: Dictionary in BACKGROUND_RULES:
		for token: String in rule.any:
			if haystack.contains(token):
				return String(rule.path)
	return "res://assets/background/battleUI/defult/Background_defult.jpg"
