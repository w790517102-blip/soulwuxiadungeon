extends SceneTree

const MANAGER_SOURCE := "res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_music_room/Music_Room_Manager.gd"
const PLATE_SOURCE := "res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_music_room/Music_Plate.gd"
const QIN_SOURCE := "res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_music_room/Gu_qin_Interactable.gd"
const DIALOG_SOURCE := "res://scripts/DialogManager.gd"
const QUEST_SOURCE := "res://scripts/QuestManager.gd"
const MUSIC_ROOM_SCENE := "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_music_room/yuheng_sewer_music_room.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_manager_contract()
	_test_step_trigger_contract()
	_test_scene_contract()
	_test_note_contract()
	if _failures.is_empty():
		print("PASS: sewer music room static puzzle contracts")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_manager_contract() -> void:
	var source := FileAccess.get_file_as_string(MANAGER_SOURCE)
	_expect(source.contains('const CORRECT_SEQUENCE: Array[String] = ["gong", "jue", "yu"]'), "correct sequence must remain gong, jue, yu")
	_expect(source.contains('const FLAG_FINAL_ROOM_INTRO_DONE := "event_yuheng_sewer_final_room_intro_done"'), "final-room intro must gate the puzzle")
	_expect(source.contains('const FLAG_HINT_READ := "sewer_music_hint_read"'), "existing recognition flag must be reused")
	_expect(source.contains("and _is_final_room_intro_done()"), "case A: pre-intro plate entry must not be accepted")
	_expect(source.contains("and hint_read"), "case B: intro alone must not record input until the puzzle is recognized")
	_expect(source.contains("_set_flag(FLAG_HINT_READ, true)"), "case B: completed recognition must persist puzzle activation")
	_expect(source.contains("if not can_accept_plate_input():"), "plates must reject input before recognition and after completion")
	_expect(source.contains("if not _is_current_sequence_valid():"), "input must use prefix validation")
	_expect(source.contains("current_sequence.clear()"), "cases D/E/F: wrong prefixes must clear before a retry")
	_expect(source.contains('const FLAG_SEQUENCE_GONG := "sewer_music_sequence_gong"'), "the first valid note must have persistent progress")
	_expect(source.contains('const FLAG_SEQUENCE_JUE := "sewer_music_sequence_jue"'), "the second valid note must have persistent progress")
	_expect(source.contains("_restore_sequence_progress()"), "battle return and scene reload must restore the valid prefix")
	_expect(source.contains("_persist_sequence_progress()"), "each valid note must persist immediately")
	_expect(source.contains("_clear_sequence_progress()"), "wrong input, explicit reset, and completion must clear partial progress")
	_expect(source.contains('"「……音序不對。」"'), "wrong input must explain the reset")
	_expect(source.contains("_set_flag(FLAG_SOLVED, true)"), "success must persist sewer_music_solved")
	_expect(source.contains("and not puzzle_solved"), "case G: solved plates must no longer accumulate input")
	_expect(source.contains("_refresh_sewer_puzzle_note()"), "recognition and success must refresh the shared Note")
	_expect(source.contains("dialog_owner: Node2D = null"), "DialogManager owner must retain its formal Node2D type")
	_expect(source.contains("show_dialog_sequence(_to_dialog_lines(lines), dialog_owner)"), "the actual Node2D interactable must own the dialog")
	_expect(not source.contains("show_dialog_sequence(_to_dialog_lines(lines), self)"), "Node-only manager must never pass itself as DialogManager's Node2D owner")
	_expect(not source.contains('_set_flag("current_sequence"'), "case H: partial sequence must never be written through the flag API")
	_expect(not source.contains("sewer_talisman_solved") and not source.contains("sewer_alchemy_solved"), "case I: music room must not alter other puzzle flags")


func _test_step_trigger_contract() -> void:
	var source := FileAccess.get_file_as_string(PLATE_SOURCE)
	_expect(source.contains("func _on_body_entered(body: Node) -> void:"), "plate must use Area2D body_entered")
	_expect(not source.contains("_trigger_plate()"), "case E: body_entered must never submit a note")
	_expect(source.contains("await manager.inspect_plate(note_id, self)"), "Space interaction must inspect the specific plate")
	_expect(source.contains('{"text": "踏下"'), "case C: active plate must offer the step choice")
	_expect(source.contains('{"text": "先不要"'), "case D: active plate must offer a safe cancel choice")
	_expect(source.contains("if confirmed:"), "only an explicit confirmation may submit a note")
	_expect(source.contains("await manager.try_press_plate(note_id, self)"), "confirmed choice must submit exactly one stable note id")
	_expect(source.contains('return "觀察石板"'), "case A/J: inactive or solved plate prompt must remain observation")
	_expect(source.contains('return "踏下石板"'), "case B: recognized active plate prompt must describe stepping")
	_expect(source.contains("func _unhandled_input(event: InputEvent) -> void:"), "world interaction must use handled input propagation")
	_expect(source.contains("get_viewport().set_input_as_handled()"), "accepted Space must be consumed before another interactable sees it")
	_expect(source.contains('dialog_manager.get("dialog_active")'), "case G: dialog Space must not leak into plate interaction")
	_expect(source.contains('dialog_manager.get("choice_box")'), "case H: ChoiceBox Space must not leak into plate interaction")
	_expect(source.contains("choice_box.get_child_count() > 0"), "an empty visible ChoiceBox must not block every world interaction")
	_expect(source.contains("func _on_body_exited(body: Node) -> void:"), "leaving the plate must clear proximity")

	var qin_source := FileAccess.get_file_as_string(QIN_SOURCE)
	_expect(qin_source.contains("func _unhandled_input(event: InputEvent) -> void:"), "qin must share the same consumed world-interaction path")
	_expect(qin_source.contains("get_viewport().set_input_as_handled()"), "overlapping qin and plate ranges must consume Space only once")
	_expect(qin_source.contains('dialog_manager.get("dialog_active")'), "closing dialog Space must not immediately reopen qin")

	var dialog_source := FileAccess.get_file_as_string(DIALOG_SOURCE)
	_expect(dialog_source.contains("if not dialog_active:\n\t\treturn"), "idle DialogManager must leave Space for world interaction")


func _test_scene_contract() -> void:
	var packed := load(MUSIC_ROOM_SCENE) as PackedScene
	_expect(packed != null, "music room scene must remain loadable")
	if packed == null:
		return
	var room := packed.instantiate()
	var spawn := room.get_node_or_null("SpawnPoints/from_yuheng_sewer_center") as Node2D
	var exit_area := room.get_node_or_null("To_yuheng_sewer_center") as Area2D
	var exit_shape := room.get_node_or_null("To_yuheng_sewer_center/CollisionShape2D") as CollisionShape2D
	_expect(spawn != null and exit_area != null and exit_shape != null, "music-room entrance must retain a working return Area2D")
	if spawn and exit_area and exit_shape:
		var exit_center := exit_area.position + exit_shape.position
		_expect(spawn.position.distance_to(exit_center) < 250.0, "return Area2D must remain beside the room entrance")
		_expect(exit_area.monitoring and not exit_shape.disabled, "return Area2D must remain enabled in every puzzle state")
	var expected := {
		"plate_gong_heart": "gong",
		"plate_shang_fire": "shang",
		"plate_jue_sound": "jue",
		"plate_zhi_wind": "zhi",
		"plate_yu_water": "yu",
	}
	var manager_source := FileAccess.get_file_as_string(MANAGER_SOURCE)
	_expect(manager_source.contains('"gong": "心"'), "gong art mapping must remain heart")
	_expect(manager_source.contains('"jue": "聲"'), "jue art mapping must remain sound")
	_expect(manager_source.contains('"yu": "水"'), "yu art mapping must remain water")
	for node_name in expected:
		var plate := room.get_node_or_null(node_name)
		_expect(plate != null, "plate node must exist: %s" % node_name)
		if plate:
			_expect(String(plate.get("note_id")) == expected[node_name], "plate must keep stable note id: %s" % node_name)
			var audio := plate.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
			_expect(audio != null and audio.stream != null, "plate must retain its existing note sound: %s" % node_name)
	room.free()


func _test_note_contract() -> void:
	var source := FileAccess.get_file_as_string(QUEST_SOURCE)
	_expect(source.contains('const F_YH_SEWER_MUSIC_HINT_READ := "sewer_music_hint_read"'), "QuestManager must read the recognition flag")
	_expect(source.contains('return "依「宮、角、羽」的順序踏過調音室石板。"'), "recognized puzzle must expose its detailed Note")
	_expect(source.contains("var solved_count := int(music_done) + int(talisman_done) + int(alchemy_done)"), "success must continue through the shared remaining-puzzle Note resolver")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
