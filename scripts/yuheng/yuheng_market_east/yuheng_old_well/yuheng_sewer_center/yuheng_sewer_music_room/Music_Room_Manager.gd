extends Node
class_name MusicRoomManager

signal music_puzzle_solved
signal sequence_changed(current_sequence: Array[String])
signal sequence_reset

const FLAG_SOLVED := "sewer_music_solved"
const FLAG_HINT_READ := "sewer_music_hint_read"

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

@export var show_reset_hint := false

var hint_read := false
var puzzle_solved := false
var current_sequence: Array[String] = []
var interaction_locked := false


func _ready() -> void:
	hint_read = bool(_get_flag(FLAG_HINT_READ, false))
	puzzle_solved = bool(_get_flag(FLAG_SOLVED, false))


func inspect_qin() -> void:
	if interaction_locked:
		return
	
	interaction_locked = true
	
	if puzzle_solved:
		await _show_dialog([
			"古琴與藥師筆記靜靜擺在一旁。",
			"方才歸正的音律，彷彿仍在水道深處迴盪。"
		])
		interaction_locked = false
		return
	
	if not hint_read:
		hint_read = true
		_set_flag(FLAG_HINT_READ, true)
		
		await _show_dialog([
			"古琴旁壓著一本潮濕的舊筆記，紙角已被水氣泡得發皺。",
			"上頭仍可辨出幾行字：",
			"「宮定其心，角引其聲，羽歸其水。」",
			"劉語塵低頭看了看筆記，又望向地上的五塊石板。",
			"「這些圖案不就和地上的機關一樣嗎？」",
			"「嗯……也許那些石板機關跟這訊息有甚麼關連也說不定……」",
			"「雖說有點危險，但事到如今也只能去調查看看了。」"
		])
	else:
		await _show_dialog([
			"藥師留下的筆記上寫著：",
			"「宮定其心，角引其聲，羽歸其水。」"
		])
	
	interaction_locked = false


func try_press_plate(note_id: String) -> bool:
	if puzzle_solved:
		return true
	
	if not hint_read:
		if not interaction_locked:
			interaction_locked = true
			await _show_dialog([
				"地上的石板看起來是某種機關。",
				"劉語塵沉吟道：「以防萬一，小心一點，不要亂觸碰到它們。」"
			])
			interaction_locked = false
		return false
	
	if not NOTE_LABELS.has(note_id):
		push_warning("未知五音石板 note_id: " + note_id)
		return false
	
	current_sequence.append(note_id)
	emit_signal("sequence_changed", current_sequence)
	
	if not _is_current_sequence_valid():
		current_sequence.clear()
		emit_signal("sequence_reset")
		
		if show_reset_hint and not interaction_locked:
			interaction_locked = true
			await _show_dialog([
				"回聲散了一瞬，水面又恢復沉默。"
			])
			interaction_locked = false
		
		return false
	
	if current_sequence.size() >= CORRECT_SEQUENCE.size():
		await _solve_puzzle()
		return true
	
	return false


func _is_current_sequence_valid() -> bool:
	if current_sequence.size() > CORRECT_SEQUENCE.size():
		return false
	
	for i in range(current_sequence.size()):
		if current_sequence[i] != CORRECT_SEQUENCE[i]:
			return false
	
	return true


func _solve_puzzle() -> void:
	puzzle_solved = true
	current_sequence.clear()
	
	_set_flag(FLAG_SOLVED, true)
	
	await _show_dialog([
		"宮音一沉，角音微振，羽音落入水脈。",
		"混亂的回聲逐漸歸正。",
		"……遠處傳來機關開啟的聲音。"
	])
	
	emit_signal("music_puzzle_solved")


func reset_sequence() -> void:
	current_sequence.clear()
	emit_signal("sequence_reset")


func get_note_label(note_id: String) -> String:
	return str(NOTE_LABELS.get(note_id, note_id))


func get_note_symbol(note_id: String) -> String:
	return str(NOTE_SYMBOLS.get(note_id, ""))


func _show_dialog(lines: Array[String]) -> void:
	var dialog_manager := get_node_or_null("/root/DialogManager")
	
	if dialog_manager and dialog_manager.has_method("start_dialog"):
		dialog_manager.start_dialog(lines)
		
		if dialog_manager.has_signal("dialog_sequence_finished"):
			await dialog_manager.dialog_sequence_finished
	else:
		for line in lines:
			print(line)


func _get_flag(flag_name: String, default_value = null):
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state == null:
		return default_value
	
	if global_state.has_method("get_flag"):
		return global_state.get_flag(flag_name, default_value)
	
	var value = global_state.get(flag_name)
	if value == null:
		return default_value
	
	return value


func _set_flag(flag_name: String, value) -> void:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state == null:
		push_warning("找不到 GlobalState，無法寫入：" + flag_name)
		return
	
	if global_state.has_method("set_flag"):
		global_state.set_flag(flag_name, value)
	else:
		global_state.set(flag_name, value)
