extends Node
class_name MusicRoomManager

signal music_puzzle_solved
signal sequence_changed(current_sequence: Array[String])
signal sequence_reset
signal dialog_closed

const FLAG_SOLVED := "sewer_music_solved"
const FLAG_HINT_READ := "sewer_music_hint_read"
const FLAG_FINAL_ROOM_INTRO_DONE := "event_yuheng_sewer_final_room_intro_done"
const FLAG_SEQUENCE_GONG := "sewer_music_sequence_gong"
const FLAG_SEQUENCE_JUE := "sewer_music_sequence_jue"

const CORRECT_SEQUENCE: Array[String] = ["gong", "jue", "yu"]

# 五音在本房間中的圖像／意義定案：
# 宮 = 心，商 = 火，角 = 聲，徵 = 風，羽 = 水
const NOTE_LABELS := {
	"gong": "宮",
	"shang": "商",
	"jue": "角",
	"zhi": "徵",
	"yu": "羽"
}

const NOTE_SYMBOLS := {
	"gong": "心",
	"shang": "火",
	"jue": "聲",
	"zhi": "風",
	"yu": "水"
}

@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var narration_speaker_id := 0

var hint_read := false
var puzzle_solved := false
var current_sequence: Array[String] = []
var interaction_locked := false
var _waiting_for_dialog := false


func _ready() -> void:
	hint_read = bool(_get_flag(FLAG_HINT_READ, false))
	puzzle_solved = bool(_get_flag(FLAG_SOLVED, false))
	_restore_sequence_progress()


func inspect_qin(dialog_owner: Node2D = null) -> void:
	if interaction_locked:
		return

	interaction_locked = true

	if puzzle_solved:
		await _show_dialog([
			"三音已經調和，機關不再回應。"
		], dialog_owner)
		interaction_locked = false
		return

	if not _is_final_room_intro_done():
		await _show_dialog(_pre_intro_observation_lines(), dialog_owner)
		interaction_locked = false
		return

	if not hint_read:
		await _show_dialog([
			"「終端房裡的『琴』印……指的應該就是這裡。」",
			"「宮、商、角、徵、羽……是五音。」",
			"「這些石板又分別刻著心、水、風、聲、火的圖樣。」",
			"「宮為定心，角為引聲，羽為歸水……」",
			"「宮、角、羽。照這個順序試試。」"
		], dialog_owner)
		hint_read = true
		_set_flag(FLAG_HINT_READ, true)
		_refresh_sewer_puzzle_note()
	else:
		await _show_dialog([
			"「順序是宮、角、羽。」",
			"「對應的圖樣……心、聲、水。」"
		], dialog_owner)

	interaction_locked = false


func inspect_plate(note_id: String, dialog_owner: Node2D = null) -> bool:
	if interaction_locked:
		return false
	if not NOTE_LABELS.has(note_id):
		push_warning("未知五音石板 note_id: " + note_id)
		return false

	var symbol := get_note_symbol(note_id)
	interaction_locked = true
	if puzzle_solved:
		await _show_dialog([
			"三音已經調和，石板不再回應。"
		], dialog_owner)
	elif not _is_final_room_intro_done():
		await _show_dialog([
			"「這塊石板上刻著『%s』的圖樣。」" % symbol,
			"「似乎與音律有關……但眼下還不知道該如何使用。」"
		], dialog_owner)
	elif not hint_read:
		await _show_dialog([
			"「這塊石板上刻著『%s』的圖樣。」" % symbol,
			"「終端房的琴印應該與此有關；先調查石室裡的琴吧。」"
		], dialog_owner)
	else:
		await _show_dialog([
			"「這是刻有『%s』圖樣的石板。」" % symbol,
			"「要踏下去嗎？」"
		], dialog_owner)
		interaction_locked = false
		return true
	interaction_locked = false
	return false


func try_press_plate(note_id: String, dialog_owner: Node2D = null) -> bool:
	if not can_accept_plate_input():
		return false

	if not NOTE_LABELS.has(note_id):
		push_warning("未知五音石板 note_id: " + note_id)
		return false

	interaction_locked = true
	current_sequence.append(note_id)
	emit_signal("sequence_changed", current_sequence)

	if not _is_current_sequence_valid():
		current_sequence.clear()
		_clear_sequence_progress()
		emit_signal("sequence_reset")
		await _show_dialog([
			"「……音序不對。」",
			"「是宮、角、羽。再來一次。」"
		], dialog_owner)
		interaction_locked = false
		return false

	_persist_sequence_progress()

	if current_sequence.size() >= CORRECT_SEQUENCE.size():
		await _solve_puzzle(dialog_owner)
		interaction_locked = false
		return true

	interaction_locked = false
	return false


func can_accept_plate_input() -> bool:
	return not interaction_locked and is_plate_step_available()


func is_plate_step_available() -> bool:
	return not puzzle_solved \
		and _is_final_room_intro_done() \
		and hint_read


func _is_final_room_intro_done() -> bool:
	return bool(_get_flag(FLAG_FINAL_ROOM_INTRO_DONE, false))


func _is_current_sequence_valid() -> bool:
	if current_sequence.size() > CORRECT_SEQUENCE.size():
		return false

	for i in range(current_sequence.size()):
		if current_sequence[i] != CORRECT_SEQUENCE[i]:
			return false

	return true


func _solve_puzzle(dialog_owner: Node2D = null) -> void:
	puzzle_solved = true
	current_sequence.clear()
	_clear_sequence_progress()

	_set_flag(FLAG_SOLVED, true)

	await _show_dialog([
		"（三道音色依次回盪，石室深處隨之傳來低沉的共鳴。）",
		"「……對了。」",
		"「宮、角、羽三音相繼應和。」",
		"「看來琴印這一處，已經解開了。」"
	], dialog_owner)

	_refresh_sewer_puzzle_note()
	emit_signal("music_puzzle_solved")


func _refresh_sewer_puzzle_note() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager and quest_manager.has_method("refresh_sewer_puzzle_note"):
		quest_manager.call("refresh_sewer_puzzle_note")


func reset_sequence() -> void:
	current_sequence.clear()
	_clear_sequence_progress()
	emit_signal("sequence_reset")


func _restore_sequence_progress() -> void:
	current_sequence.clear()
	if puzzle_solved:
		_clear_sequence_progress()
		return

	var gong_entered := bool(_get_flag(FLAG_SEQUENCE_GONG, false))
	var jue_entered := bool(_get_flag(FLAG_SEQUENCE_JUE, false))
	if jue_entered and not gong_entered:
		push_warning("[調音室] 偵測到不完整的音序保存狀態，已安全重置。")
		_clear_sequence_progress()
		return
	if gong_entered:
		current_sequence.append("gong")
	if jue_entered:
		current_sequence.append("jue")


func _persist_sequence_progress() -> void:
	# Only valid incomplete prefixes are persisted. The third correct note is
	# represented by FLAG_SOLVED instead of a second completion state.
	_set_flag(FLAG_SEQUENCE_GONG, current_sequence.size() >= 1)
	_set_flag(FLAG_SEQUENCE_JUE, current_sequence.size() >= 2)


func _clear_sequence_progress() -> void:
	_set_flag(FLAG_SEQUENCE_GONG, false)
	_set_flag(FLAG_SEQUENCE_JUE, false)


func get_note_label(note_id: String) -> String:
	return str(NOTE_LABELS.get(note_id, note_id))


func get_note_symbol(note_id: String) -> String:
	return str(NOTE_SYMBOLS.get(note_id, ""))


func _pre_intro_observation_lines() -> Array[String]:
	return [
		"「這張琴似乎與四周的石板有所呼應。」",
		"「只是若不知道要奏出什麼，胡亂試音也沒什麼意義。」",
		"「先看看其他地方是否有線索。」",
	]


func _show_dialog(lines: Array[String], dialog_owner: Node2D = null) -> void:
	var dialog_manager := _get_dialog_manager()

	if dialog_manager == null:
		for line in lines:
			print(line)
		return

	if dialog_manager.has_method("show_dialog_sequence"):
		_waiting_for_dialog = true
		dialog_manager.show_dialog_sequence(_to_dialog_lines(lines), dialog_owner)
		await _wait_dialog_finished(dialog_manager)
		return

	if dialog_manager.has_method("start_dialog"):
		dialog_manager.start_dialog(lines)
		await _wait_dialog_finished(dialog_manager)
		return

	for line in lines:
		print(line)


func _get_dialog_manager() -> Node:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager:
		return dialog_manager

	dialog_manager = get_node_or_null("/root/DialogManager")
	if dialog_manager:
		return dialog_manager

	return null


func _wait_dialog_finished(dialog_manager: Node) -> void:
	if dialog_manager.has_signal("dialog_sequence_finished"):
		await dialog_manager.dialog_sequence_finished
	elif _waiting_for_dialog:
		await dialog_closed

	_waiting_for_dialog = false


func reset_dialog_state() -> void:
	if _waiting_for_dialog:
		_waiting_for_dialog = false
		dialog_closed.emit()


func _to_dialog_lines(lines: Array[String]) -> Array:
	var result: Array = []
	for line in lines:
		result.append({
			"text": line,
			"speaker": narration_speaker_id,
			"portrait": empty_portrait_path,
		})
	return result


func _get_flag(flag_name: String, default_value = null):
	var global_state := _get_global_state()
	if global_state == null:
		return default_value

	if global_state.has_method("get_flag"):
		var value = global_state.get_flag(flag_name)
		if value == null:
			return default_value
		return value

	var value = global_state.get(flag_name)
	if value == null:
		return default_value

	return value


func _set_flag(flag_name: String, value: bool) -> void:
	var global_state := _get_global_state()
	if global_state == null:
		push_warning("找不到 GlobalState，無法寫入：" + flag_name)
		return

	if global_state.has_method("set_flag"):
		global_state.set_flag(flag_name, value)
	else:
		global_state.set(flag_name, value)


func _get_global_state() -> Node:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state:
		return global_state

	global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state:
		return global_state

	return null
