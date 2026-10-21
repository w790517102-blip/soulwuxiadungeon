extends SceneTree
## Isolated UI integration tests. Item definitions are copied into a popup;
## no Inventory grants/consumption, saves or campaign battle returns occur.
var _failures: Array[String] = []
var _count := 0
var fixture: Node
var ui: Node

class ItemConsumerProbe extends Node:
	var _ending := false
	var battle_finished := false
	var battle_context: Dictionary = {}
	var calls: Array = []
	func can_use_items() -> bool: return true
	func can_switch_inner_force() -> bool: return true
	func use_item(user: Dictionary, item: Dictionary, target: Dictionary) -> void:
		calls.append([user, item, target])

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var inventory: Node = root.get_node("InventorySync")
	var inventory_before: Dictionary = inventory.export_inventory_state().duplicate(true)
	fixture = load("res://scenes/presentation/combat_stage_prototype.tscn").instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	while not fixture.prepared: await process_frame
	ui = fixture.ui
	var context: Dictionary = fixture.build_preview_context()
	fixture.controller.player_party = context.player_party
	fixture.controller.enemy_party = context.enemy_party
	fixture.controller.ruleset = context.ruleset
	context.enemy_party[0]["battle_uid"] = "menu_test_enemy#0"
	context.enemy_party[0]["is_enemy"] = true
	ui.set_teams(context.player_party, context.enemy_party)
	ui._opening_overlay.hide()
	ui._battle_black_overlay.hide()
	ui.log_panel._chars_per_sec = 1000000
	ui.begin_turn(context.player_party[0])
	await _drain_logs()
	ui._sync_input_state()
	await _menus(context.player_party[0])
	await _messages()
	await _archive()
	await _intro()
	_expect(inventory.export_inventory_state() == inventory_before, "all UI tests preserve the campaign inventory")
	fixture.queue_free()
	await process_frame
	if _failures.is_empty(): print("PASS: ", _count, " assertions; shared menus, archive interaction and message input priority")
	else:
		for failure in _failures: push_error("FAIL: " + failure)
	quit(0 if _failures.is_empty() else 1)

func _menus(actor: Dictionary) -> void:
	var font: Font = load("res://assets/fonts/UIFontKaiti.tres")
	for popup: Window in [ui.skill_list_popup, ui.inner_force_popup, ui.item_list_popup]:
		var panel: Control = popup.get_node("ActionItemListPanel")
		_expect(panel.has_node("PageControls") and panel.has_node("ConfirmAndCancel") and panel.has_node("ListAndDescription/DescriptionArea"), "all three menus share the same framework")
		_expect(popup.size == Vector2i(820, 450), "all three menus share window dimensions")
	for list: ItemList in [ui.skill_list_popup.skill_list, ui.inner_force_popup.force_list, ui.item_list_popup.item_list]:
		_expect(list.get_theme_font("font") == font and list.get_theme_font_size("font_size") == 20, "all lists share font and text metrics")
		_expect(list.get_theme_constant("v_separation") == 10 and list.has_theme_stylebox_override("selected_focus"), "all lists share row spacing and focus presentation")
	ui.dispatch_stage_command("inner_force")
	_expect(ui.inner_force_popup.visible and ui._menu == "inner_force", "inner force uses the native shared ItemList popup")
	_expect(ui.inner_force_popup.description.text.contains("狀態：") and ui.inner_force_popup.description.text.contains("切換："), "inner force description includes running state and switching condition")
	ui._cancel_menu()
	await _drain_logs()
	var item: Dictionary = load("res://scripts/db/ItemDB.gd").get_def("med_bandage").duplicate(true)
	item["quantity"] = 3
	var popup: Window = ui.item_list_popup
	popup.user_actor = actor
	popup.item_list.clear()
	popup.current_items.clear()
	for index in range(12):
		popup.current_items.append(item.duplicate(true))
		popup.item_list.add_item("繃帶 ×3")
	popup.popup_centered()
	_expect(popup.visible and ui._menu == "item", "items use the same native ItemList popup")
	ui.select_stage_option(0)
	_expect(popup.description.text.contains("我方單人") and popup.description.text.contains("回復氣血") and popup.quantity_label.text.contains("3"), "item details preserve effect, target and quantity")
	popup.get_node("ActionItemListPanel/PageControls/NextPage").pressed.emit()
	_expect(popup.selected_index == 8, "shared next-page navigation selects the next page without using an item")
	popup.get_node("ActionItemListPanel/PageControls/PreviousPage").pressed.emit()
	_expect(popup.selected_index == 0, "shared previous-page navigation restores the first page")
	popup._on_confirm_pressed()
	_expect(ui.target_picker.active and not ui.pending_item.is_empty(), "single-target item waits for target selection even with one ally")
	ui.target_picker.cancel_layer()
	_expect(popup.visible and popup.selected_index == 0 and ui._menu == "item", "item target cancellation returns to the same item selection")
	ui._cancel_menu()
	await _drain_logs()
	# Probe only the no-target dispatch boundary, not real inventory mutation.
	var original: Node = ui.combat_controller
	var probe := ItemConsumerProbe.new()
	root.add_child(probe)
	ui.combat_controller = probe
	item["target_scope"] = "self"
	ui._on_ItemListPopup_item_selected(item)
	_expect(probe.calls.size() == 1 and not ui.target_picker.active, "self-use item takes the existing direct-use callback once without selecting an enemy")
	ui.combat_controller = original
	probe.queue_free()
	ui.on_action_selection = true
	await _drain_logs()

func _messages() -> void:
	for kind: String in ["space", "escape", "left"]:
		ui.log_panel._chars_per_sec = 1
		var first := "當前戰報：" + kind + "，完整保留。"
		var second := "下一則：" + kind
		ui.log_panel.log(first)
		ui.log_panel.log(second)
		_expect(ui.log_panel.is_typewriter_active(), "message starts in typing state")
		var command_rect: Rect2 = ui.stage.command_tray.get_button_screen_rects(ui.stage.camera)[0]
		_send(kind, command_rect.get_center())
		_expect(ui.log_panel.visible_characters == -1 and ui.log_panel.waiting_for_message_advance(), "first input completes the current message immediately")
		_expect(ui.log_panel.get_parsed_text().contains(first) and not ui.log_panel.get_parsed_text().contains(second), "first input preserves current text and does not remove/advance the next message")
		_expect(ui._menu.is_empty(), "message completion input cannot click through into a main command")
		_send(kind, command_rect.get_center())
		await process_frame
		await process_frame
		_expect(ui.log_panel.get_parsed_text().contains(second), "second input advances to the next message")
		ui.log_panel._chars_per_sec = 1000000
		await _drain_logs()
	# A typewriter is the exception to target/modal priority, exactly once.
	ui.pending_skill = {"target_side": "enemy", "target_scope": "single"}
	ui.pending_skill_user = ui.current_actor
	ui._start_target_select_for_skill(ui.current_actor, ui.pending_skill)
	ui.log_panel._chars_per_sec = 1
	ui.log_panel.log("這一次只補完文字，不選敵人。")
	var target_point: Vector2 = ui.stage.card_screen_rect(ui.enemies[0]).get_center()
	_send("left", target_point)
	_expect(ui.target_picker.state == ui.target_picker.State.PICKING and ui.log_panel.waiting_for_message_advance(), "typewriter left click is consumed before target picking")
	_send("escape", target_point)
	_expect(ui.skill_list_popup.visible and not ui.target_picker.active, "once text is complete ESC follows target cancellation priority")
	ui._cancel_menu()
	ui.log_panel._chars_per_sec = 1000000
	await _drain_logs()
	# Embedded Popup input must not both complete text and cancel the menu.
	ui.dispatch_stage_command("inner_force")
	ui.log_panel._chars_per_sec = 1
	ui.log_panel.log("選單上方仍在播放的文字。")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	ui.inner_force_popup.push_input(escape, true)
	_expect(ui.inner_force_popup.visible and ui.log_panel.waiting_for_message_advance(), "popup ESC completes current typewriter without cancelling the popup")
	ui._cancel_menu()
	ui.log_panel._chars_per_sec = 1000000
	await _drain_logs()

func _archive() -> void:
	ui.log_panel._chars_per_sec = 1000000
	for index in range(60): ui.log_panel.log("歷史戰報 %02d：從開戰起的紀錄保留在此。" % index)
	await _drain_logs()
	ui._toggle_archive()
	await process_frame
	await process_frame
	var bar: VScrollBar = ui.log_panel.get_v_scroll_bar()
	_expect(ui.log_panel.mouse_filter == Control.MOUSE_FILTER_STOP and ui.log_panel.scroll_active, "archive RichTextLabel accepts mouse scrolling")
	_expect(bar.visible and bar.max_value > bar.page and bar.value > 0, "first open shows latest with an actual scrollbar")
	var bottom := bar.value
	_send_wheel(ui.log_panel.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	_expect(bar.value < bottom, "mouse wheel scrolls to earlier history")
	bar.value = 0
	await process_frame
	ui.log_panel.log("閱讀舊紀錄時新增的一則訊息。")
	await _drain_logs()
	await process_frame
	_expect(is_zero_approx(bar.value), "incoming log cannot pull manual history reading to the bottom")
	var rectangle := bar.get_global_rect()
	_send("left", rectangle.position + Vector2(rectangle.size.x / 2, 20), false)
	var motion := InputEventMouseMotion.new()
	motion.position = rectangle.position + Vector2(rectangle.size.x / 2, rectangle.size.y * 0.6)
	motion.relative = Vector2(0, rectangle.size.y * 0.6 - 20)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	_release(motion.position)
	_expect(bar.value > 0, "native scrollbar thumb can be dragged")
	var before_track := bar.value
	_send("left", rectangle.position + Vector2(rectangle.size.x / 2, rectangle.size.y * 0.85))
	await process_frame
	_expect(bar.value != before_track, "native scrollbar track/arrow supports clicking")
	ui._archive_panel.get_node("Latest").pressed.emit()
	await process_frame
	_expect(bar.value >= bar.max_value - bar.page - 2, "explicit latest returns to the newest message")
	ui._toggle_archive()
	ui._toggle_archive()
	await process_frame
	await process_frame
	_expect(bar.value >= bar.max_value - bar.page - 2, "reopening archive returns to latest")
	ui._toggle_archive()

func _intro() -> void:
	var confirms: Array = []
	ui.battle_opening_confirmed.connect(func(): confirms.append(true))
	for kind: String in ["space", "escape", "left"]:
		var before := confirms.size()
		ui.play_battle_opening("敵人逼近，你凝神迎戰。")
		await process_frame
		_send(kind, Vector2(600, 300))
		_expect(ui._opening_intro_label.visible_characters == -1 and confirms.size() == before, "intro first input completes text without advancing")
		_send(kind, Vector2(600, 300))
		_expect(confirms.size() == before + 1, "intro second input advances exactly once")
		while ui._battle_opening_locked: await process_frame

func _drain_logs() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while ui.log_panel._typing or not ui.log_panel._queue.is_empty():
		if ui.log_panel.waiting_for_message_advance(): ui.log_panel.handle_message_input()
		if Time.get_ticks_msec() > deadline:
			_expect(false, "log drain timed out")
			break
		await process_frame

func _send(kind: String, point: Vector2, release: bool = true) -> void:
	if kind == "left":
		var move := InputEventMouseMotion.new()
		move.position = point
		root.push_input(move, true)
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.pressed = true
		root.push_input(event, true)
		if release: _release(point)
	else:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE if kind == "space" else KEY_ESCAPE
		event.pressed = true
		root.push_input(event, true)
		event.pressed = false
		root.push_input(event, true)

func _release(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	root.push_input(event, true)

func _send_wheel(point: Vector2, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func _expect(condition: bool, message: String) -> void:
	_count += 1
	if not condition: _failures.append(message)
