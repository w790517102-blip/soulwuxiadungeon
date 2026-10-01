extends SceneTree

const TALISMAN_SOURCE := "res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_talisman_room/yuheng_sewer_talisman_room.gd"
const MUSIC_SOURCE := "res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_music_room/Music_Room_Manager.gd"
const ALCHEMY_SOURCE := "res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_alchemy_room/yuheng_sewer_alchemy_room.gd"
const GLOBAL_SOURCE := "res://scripts/GlobalState.gd"
const SAVE_SOURCE := "res://scripts/SaveManager.gd"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_talisman_progress_contract()
	_test_music_progress_contract()
	_test_alchemy_progress_contract()
	if _failures.is_empty():
		print("PASS: sewer puzzle persistence static contracts")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_talisman_progress_contract() -> void:
	var source := FileAccess.get_file_as_string(TALISMAN_SOURCE)
	for talisman_id in ["heart", "mouth", "water"]:
		_expect(source.contains('"sewer_talisman_%s_resealed"' % talisman_id), "%s repair needs its own persistent flag" % talisman_id)
	_expect(source.contains("_restore_talisman_progress()"), "talisman scene rebuild must restore the valid repaired prefix")
	_expect(source.contains("_set_talisman_resealed(talisman_id, true)"), "each valid repair must persist immediately")
	_expect(source.contains("_reset_talisman_progress()"), "a genuinely wrong order must reset all partial repair state")
	_expect(source.contains("_setup_talisman_repair_visuals()"), "repaired talisman visuals must be reconstructed after scene reload")
	_expect(source.contains("current_sequence.has(talisman_id)"), "restored talismans must retain already-repaired interaction behavior")
	_expect(source.contains("_set_flag(FLAG_SOLVED, true)"), "only the complete talisman sequence may set the solved flag")


func _test_music_progress_contract() -> void:
	var source := FileAccess.get_file_as_string(MUSIC_SOURCE)
	_expect(source.contains('"sewer_music_sequence_gong"'), "gong prefix must survive battle return")
	_expect(source.contains('"sewer_music_sequence_jue"'), "gong-jue prefix must survive battle return")
	_expect(source.contains("_restore_sequence_progress()"), "music scene rebuild must restore the valid prefix")
	_expect(source.contains("_persist_sequence_progress()"), "valid music input must persist immediately")
	_expect(source.contains("_clear_sequence_progress()"), "wrong input and explicit reset must clear persistent music progress")
	_expect(source.contains("_set_flag(FLAG_SOLVED, true)"), "the full music sequence must still use its existing solved flag")


func _test_alchemy_progress_contract() -> void:
	var room_source := FileAccess.get_file_as_string(ALCHEMY_SOURCE)
	var global_source := FileAccess.get_file_as_string(GLOBAL_SOURCE)
	var save_source := FileAccess.get_file_as_string(SAVE_SOURCE)
	_expect(room_source.contains("_restore_alchemy_puzzle_state()"), "alchemy room must restore its existing formula state")
	_expect(room_source.contains("_persist_alchemy_puzzle_state()"), "alchemy selections and processing methods must use the existing persistence path")
	_expect(global_source.contains("var alchemy_puzzle_state: Dictionary = {}"), "alchemy state must remain separate from boolean flags")
	_expect(save_source.contains('"alchemy_puzzle_state"'), "alchemy partial progress must remain save-file backed")
	_expect(not room_source.contains('set_flag("selected_herbs"'), "alchemy arrays must never be stored through the boolean flag API")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
