extends SceneTree
## Bottom-left hint by what the pointer is over, the caption at the top (skill / item / inner force names), the option
## buttons standing in front of the player's cards, and the round title's size.
## Run: --headless --path . --script tests/test_stage_hint_caption.gd

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - start) < seconds * 1000.0:
		await process_frame


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
		print("PASS: stage hint and caption")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check(fixture: Node) -> void:
	var ui: Node = fixture.ui
	var stage: Node3D = ui.stage
	var context: Dictionary = fixture.build_preview_context()
	var ally: Dictionary = (context.player_party[0] as Dictionary).duplicate(true)
	var foe: Dictionary = (context.enemy_party[0] as Dictionary).duplicate(true)
	ally["battle_uid"] = "hint_ally"
	foe["battle_uid"] = "hint_foe"
	foe["is_enemy"] = true
	ui.set_teams([ally], [foe])
	ui.current_actor = ally
	# the hint
	_expect(ui._hint_for_key("") == "將游標移動到卡片上", "no card under the pointer: move the cursor onto a card")
	_expect(ui._hint_for_key(stage.actor_key(ally)) == "按左鍵進行戰鬥指令或右鍵檢視卡片資訊", "the active character: left = commands, right = inspect")
	_expect(ui._hint_for_key(stage.actor_key(foe)) == "按左鍵或右鍵檢視卡片資訊", "any other card (enemy, support card, other ally): left or right = inspect")
	_expect(ui._hint_for_key("some_support_card") == "按左鍵或右鍵檢視卡片資訊", "a support card too")
	# the caption
	var presenter: Node = ui.event_presenter
	presenter.history.clear()
	ui.show_action_caption("流塵連決劍")
	ui.show_action_caption("")
	_expect(presenter.history.size() == 1 and String(presenter.history[0].text) == "流塵連決劍" and String(presenter.history[0].type) == "caption", "the caption shows a name (and nothing for an empty one)")
	ui.show_action_caption("回春散")
	await process_frame
	var plates: int = 0
	for child: Node in presenter.get_children():
		if child is PanelContainer:
			plates += 1
	_expect(plates == 1, "a new caption replaces the old one (%d on screen)" % plates)
	var plate: Control = null
	for child: Node in presenter.get_children():
		if child is PanelContainer:
			plate = child
	var screen: Vector2 = presenter.get_viewport_rect().size
	_expect(plate != null and plate.position.y < screen.y * 0.2 and absf(plate.position.x + plate.size.x * 0.5 - screen.x * 0.5) < 2.0, "it sits at the top, centred")
	# the controller reports skills, items and inner forces to it
	var controller: Node = fixture.controller
	presenter.history.clear()
	controller._show_caption("伏潮訣")
	_expect(presenter.history.size() == 1 and String(presenter.history[0].text) == "伏潮訣", "the controller hands names to the caption")
	await _wait(2.2)
	_expect(not is_instance_valid(plate), "the caption goes away by itself")
	# the option buttons are in front of the player's cards and look the same on screen
	var tray: Node3D = stage.command_tray
	tray.set_enabled(true)
	tray.set_expanded(true)
	tray.set_options([], ["確認", "取消"])
	await _wait(0.6)
	var options: Array = tray.get("_options")
	_expect(options.size() == 2, "the confirm and cancel buttons exist")
	if options.size() == 2:
		var option: Node3D = options[0]
		_expect(option.global_position.z > stage.player_depth + 0.8, "the buttons stand in front of the player's cards (z %.2f vs cards %.2f)" % [option.global_position.z, stage.player_depth])
		var unforward: Vector3 = option.position
		var camera: Camera3D = stage.camera
		var shown: Vector2 = camera.unproject_position(option.global_position)
		var original: Vector2 = camera.unproject_position(tray.to_global(unforward))
		_expect(shown.distance_to(original) < 1.0, "...and sit where they always did on screen")
		var point: Vector2 = shown
		_expect(tray.pick_option(camera, point) == 0, "they can still be picked there")
	# 開始 is twice the size it was
	var Title: Script = load("res://scripts/presentation/BattleRoundTitle.gd")
	_expect(is_equal_approx(Title.BEGIN_HEIGHT, 0.60), "開始 is shown at twice its former size")
