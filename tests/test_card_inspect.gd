extends SceneTree
## Card Inspect: the data container for a party member, an enemy and a support card (real fields only, statuses
## with source and turns left, icon-or-word rows), and the session on the real Card Stage: the card is pulled in
## front of the camera, the stage is dimmed, the panel slides in, closing puts the card back exactly.
## Run: --headless --path . --script tests/test_card_inspect.gd

const InspectData = preload("res://scripts/presentation/CardInspectData.gd")
const LinfuTalisman = preload("res://scripts/battlescripts/LinfuTalisman.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _joined(data: Dictionary) -> String:
	var parts: Array[String] = [String(data.get("title", "")), String(data.get("subtitle", ""))]
	for block: Dictionary in data.get("blocks", []):
		parts.append(String(block.get("heading", "")))
		for line: Variant in block.get("lines", []):
			parts.append(String(line))
	for note: Variant in data.get("notes", []):
		parts.append(String(note))
	return "\n".join(parts)


func _run() -> void:
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	_expect(fixture.prepared, "the card stage prepares")
	if fixture.prepared:
		await _check(fixture)
	fixture.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: card inspect")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check(fixture: Node) -> void:
	var ui: Node = fixture.ui
	var controller: Node = fixture.controller
	var context: Dictionary = fixture.build_preview_context()
	var ally: Dictionary = (context.player_party[0] as Dictionary).duplicate(true)
	var foe: Dictionary = (context.enemy_party[0] as Dictionary).duplicate(true)
	ally["battle_uid"] = "inspect_ally"
	foe["battle_uid"] = "inspect_foe"
	foe["is_enemy"] = true
	ally["status_effects"] = {
		"atk_up": {"payload": {"atk_delta": 15}, "turns_left": 3, "source": {"kind": "item", "name": "二鍋頭", "by": "劉語塵"}},
		"poison": {"payload": {}, "turns_left": 2},
		"stat_debuff_agi": {"payload": {"stat_delta": -10}, "turns_left": 1, "source": {"kind": "skill", "name": "亂弦", "by": "敵"}},
	}
	foe["status_effects"] = {"yumei_entanglement": {"payload": {}, "turns_left": 1, "decrement_timing": "manual", "source": {"kind": "self", "name": "自身招式"}}}
	controller.player_party = [ally]
	controller.enemy_party = [foe]
	controller.ruleset = context.ruleset
	ui.set_teams([ally], [foe])
	var stage: Node3D = ui.stage

	# --- data: a party member
	var data: Dictionary = InspectData.for_actor(ui, ally, false)
	var text: String = _joined(data)
	_expect(text.contains("氣血") and text.contains("數值"), "a party member shows HP and the numbers")
	var by_name: Dictionary = {}
	for status: Dictionary in data.statuses:
		by_name[String(status.name)] = status
	_expect(by_name.has("昂勢") and String(by_name["昂勢"].effect) == "攻擊 +15" and String(by_name["昂勢"].turns) == "3 回合", "an attack buff: name, value and turns left")
	_expect(String(by_name["昂勢"].source).contains("二鍋頭"), "...and where it came from (an item)")
	_expect(by_name.has("中毒") and String(by_name["中毒"].source) == "", "a status whose source was never recorded shows no invented source")
	_expect(by_name.has("亂弦") and String(by_name["亂弦"].effect).contains("敏捷") and String(by_name["亂弦"].kind) == "debuff", "an attribute debuff is told as a debuff")

	# --- data: an enemy (boss shield is a guard, not a debuff)
	var foe_data: Dictionary = InspectData.for_actor(ui, foe, true)
	var foe_text: String = _joined(foe_data)
	_expect(foe_text.contains("氣血"), "an enemy shows HP")
	_expect(foe_text.contains("魘鱗護體"), "the boss shield is named 魘鱗護體 in the intel")
	var shield: Dictionary = foe_data.statuses[0]
	_expect(String(shield.kind) == "guard" and String(shield.name) == "魘鱗護體" and String(shield.turns) == "至被破除" and String(shield.source).contains("自身招式"), "the shield is a guard with its own turns rule and source")

	# --- data: a support card
	var card := LinfuTalisman.new()
	card.apply_config({"entity_id": "inspect_card", "display_name": "護脈符", "faction": "player", "owner_id": "shumian", "duration_turns": 3,
		"adjacency_pattern": "both", "adjacency_effects": [{"family": "DEFENSE_UP", "value": 15.0}]})
	var card_data: Dictionary = InspectData.for_entity(ui, card)
	var card_text: String = _joined(card_data)
	_expect(card_text.contains("剩餘回合") and card_text.contains("不吃角色速度") and card_text.contains("防禦提升"), "a support card: turns left, how it is placed, its effect")
	_expect(String(card_data.subtitle).contains("僚卡"), "...and it is called a support card")

	# --- the session on the stage
	var inspect: Node = ui._inspect
	_expect(inspect != null, "the UI owns a Card Inspect")
	var key: String = stage.actor_key(ally)
	var node: Node3D = stage.cards.get(key) as Node3D
	_expect(node != null, "the party card exists on the stage")
	if node == null:
		return
	var home: Vector3 = node.home_position
	var rotation_home: Vector3 = node.home_rotation
	var camera: Camera3D = stage.camera
	var before_distance: float = camera.global_position.distance_to(node.global_position)
	_expect(inspect.open_key(key), "opening the card works")
	_expect(inspect.is_open() and stage.busy, "while open, the stage is held still")
	_expect(Engine.time_scale < 0.01, "...and time on the battlefield stands still (time scale %f)" % Engine.time_scale)
	await _wait(0.7)
	var after_distance: float = camera.global_position.distance_to(node.global_position)
	_expect(after_distance < before_distance, "the card was taken toward the camera (%.2f -> %.2f)" % [before_distance, after_distance])
	_expect(node.rotation.is_equal_approx(Vector3.ZERO), "...and turned to face the player")
	_expect(node.home_position == home, "its place in the line-up was not touched")
	_expect(inspect._dim != null and (inspect._dim.material_override as StandardMaterial3D).albedo_color.a > 0.3, "the rest of the stage is dimmed")
	_expect(inspect.panel.visible and inspect.panel.modulate.a > 0.9, "the panel slid in")
	inspect.close()
	await _wait(0.8)
	_expect(not inspect.is_open() and not stage.busy, "closing releases the stage")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "...and time runs again")
	_expect(node.position.is_equal_approx(home) and node.rotation.is_equal_approx(rotation_home), "the card is back on its slot")
	_expect(inspect._dim == null and not inspect.panel.visible, "the dimming and the panel are gone")
	await _check_input(ui, stage, ally, foe)


func _click(position: Vector2, button: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = true
	return event


## The mouse rules: left or right on any card opens it; the card that can act now keeps its left click.
func _check_input(ui: Node, stage: Node3D, ally: Dictionary, foe: Dictionary) -> void:
	ui.on_action_selection = true
	ui._view_ready = true
	var ally_point: Vector2 = stage.card_screen_rect(ally).get_center()
	var foe_point: Vector2 = stage.card_screen_rect(foe).get_center()
	ui.current_actor = {}
	_expect(ui.inspect_allowed(), "inspect is allowed while the player is choosing")
	_expect(ui._handle_inspect_input(_click(foe_point, MOUSE_BUTTON_LEFT)) and ui.is_inspecting(), "left click on an enemy card opens it")
	await _wait(0.5)
	_expect(ui._handle_inspect_input(_click(Vector2(10, 10), MOUSE_BUTTON_RIGHT)), "a right click while open is taken")
	await _wait(0.8)
	_expect(not ui.is_inspecting(), "right click closes it")
	ui.current_actor = ally
	_expect(not ui._handle_inspect_input(_click(ally_point, MOUSE_BUTTON_LEFT)) and not ui.is_inspecting(), "left click on the card that can act now is not an inspect")
	_expect(ui._handle_inspect_input(_click(ally_point, MOUSE_BUTTON_RIGHT)) and ui.is_inspecting(), "right click on it is")
	await _wait(0.5)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_expect(ui._handle_inspect_input(escape), "ESC is taken while open")
	await _wait(0.8)
	_expect(not ui.is_inspecting() and not stage.busy, "ESC closes it and releases the stage")
	ui.on_action_selection = false
	_expect(not ui.inspect_allowed(), "not allowed outside the player's choosing")


## Real seconds (the battlefield may be frozen by Card Inspect, so SceneTree timers are not trusted here).
func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - start) < seconds * 1000.0:
		await process_frame
