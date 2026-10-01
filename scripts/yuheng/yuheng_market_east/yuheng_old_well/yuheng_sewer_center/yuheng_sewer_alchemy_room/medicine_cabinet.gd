extends Node2D
class_name MedicineCabinet

const FLAG_SOLVED := "sewer_alchemy_solved"
const FLAG_RECIPE_READ := "sewer_alchemy_recipe_read"
const FLAG_FINAL_ROOM_INTRO_DONE := "event_yuheng_sewer_final_room_intro_done"

const CHOICE_CANCEL := "__cancel__"
const CHOICE_USE := "__use__"
const CHOICE_RESELECT := "__reselect__"

# 此順序就是正式藥櫃順序；ChoiceBox 依陣列加入按鈕，不會自行排序。
const HERB_OPTIONS: Array[Dictionary] = [
	{"name": "白芷", "description": "香氣濃烈，能通鼻竅，卻也容易壓過其他藥味。"},
	{"name": "苦艾", "description": "葉莖帶著沉穩苦香，根部的苦氣則重得近乎滯澀。"},
	{"name": "甘草", "description": "味甘性平，常用以調和藥性，燃後卻容易留下甜膩氣息。"},
	{"name": "菖蒲", "description": "根莖中藏著鮮明辛香，若不搗開，氣味便難以散出。"},
	{"name": "黃連", "description": "根部極苦，藥性峻烈，通常用於煎服而少用作燻香。"},
	{"name": "紫蘇", "description": "紫葉輕薄，香氣柔和；葉脈若被過度破壞，氣息便容易散失。"},
	{"name": "蒼朮", "description": "燥烈除濕，煙氣厚重，久燃反而使人口乾喉澀。"},
	{"name": "薄荷", "description": "氣息清涼，醒神迅速，燃後卻散得極快，難以收束藥香。"},
]

@export var interact_action := "interact"
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var narration_speaker_id := 0

@onready var interact_area: Area2D = $Area2D

signal dialog_closed
signal choice_resolved

var player_inside := false
var interaction_locked := false
var player_ref: Node = null
var _waiting_for_dialog := false
var _space_was_down := false
var _choice_active := false
var _choice_value := ""


func _ready() -> void:
	_space_was_down = Input.is_key_pressed(KEY_SPACE)
	if interact_area:
		if not interact_area.body_entered.is_connected(_on_body_entered):
			interact_area.body_entered.connect(_on_body_entered)
		if not interact_area.body_exited.is_connected(_on_body_exited):
			interact_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_inside and not interaction_locked and _is_interact_pressed():
		_interact()


func _on_body_entered(body: Node) -> void:
	if _is_player(body):
		player_inside = true
		player_ref = body


func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		player_inside = false
		if player_ref == body:
			player_ref = null


func _is_player(body: Node) -> bool:
	return body.name == "Player" or body.name == "LiuYu" or body.is_in_group("player")


func _is_interact_pressed() -> bool:
	var pressed_by_action := false
	if InputMap.has_action(interact_action):
		pressed_by_action = Input.is_action_just_pressed(interact_action)
	var space_down := Input.is_key_pressed(KEY_SPACE)
	var pressed_by_space := space_down and not _space_was_down
	_space_was_down = space_down
	return pressed_by_action or pressed_by_space


func _interact() -> void:
	interaction_locked = true
	_set_player_movable(false)

	if bool(_get_flag(FLAG_SOLVED, false)):
		await _show_dialog(["藥櫃中的藥氣已恢復清正，不再有先前那股濕悶霉氣。"])
		_finish_interaction()
		return

	if not _is_final_room_intro_done():
		await _show_dialog([
			"藥櫃中的藥材分門別類，像是依某種規律分置。",
			"但藥氣彼此交雜，尚不知調動後會引發什麼。先記下來吧。",
		])
		_finish_interaction()
		return

	if not bool(_get_flag(FLAG_RECIPE_READ, false)):
		await _show_dialog([
			"（藥櫃裡分門別類地收著不少藥材。）",
			"種類太多了。若不知道配伍之法，貿然拿取也只是白費工夫。",
			"附近或許留有調香之人寫下的藥方。",
		])
		_finish_interaction()
		return

	var confirmed := _get_selected_herbs()
	if confirmed.size() == 3:
		await _show_dialog([
			"先前選定的是『%s』、『%s』與『%s』。" % [confirmed[0], confirmed[1], confirmed[2]],
			"若要改換藥材，便得從第一味重新挑選。",
		])
		var existing_choice := await _request_choice([
			{"text": "保留這三味", "value": CHOICE_CANCEL},
			{"text": "重新挑選", "value": CHOICE_RESELECT},
		])
		if existing_choice != CHOICE_RESELECT:
			_finish_interaction()
			return
		_set_selected_herbs([])
		_set_processing_methods([])
		_refresh_sewer_puzzle_note()

	await _run_herb_selection()
	_finish_interaction()


func _run_herb_selection() -> void:
	while true:
		var draft: Array[String] = []
		await _show_dialog([
			"（你望著琳琅滿目的藥櫃，在心中重新默念那張殘方。）",
			"三味藥材……那麼，第一味先取……",
		])

		for index in range(3):
			if index == 1:
				await _show_dialog(["第二味，應當取……"])
			elif index == 2:
				await _show_dialog(["最後一味……就決定是……"])

			var herb := await _request_herb_choice(draft)
			if herb == CHOICE_CANCEL:
				return
			draft.append(herb)

		await _show_dialog([
			"我取了『%s』、『%s』與『%s』。" % [draft[0], draft[1], draft[2]],
		])
		var confirmation := await _request_choice([
			{"text": "就用這三味", "value": CHOICE_USE},
			{"text": "重新挑選", "value": CHOICE_RESELECT},
			{"text": "取消", "value": CHOICE_CANCEL},
		])
		if confirmation == CHOICE_RESELECT:
			continue
		if confirmation != CHOICE_USE:
			return

		_set_selected_herbs(draft)
		_set_processing_methods([])
		_refresh_sewer_puzzle_note()
		await _show_dialog(["三味藥材已選齊。接下來，把它們帶到調香台處理吧。"])
		return


func _request_herb_choice(already_selected: Array[String]) -> String:
	var options: Array = []
	for herb_data in HERB_OPTIONS:
		var herb_name := String(herb_data.get("name", ""))
		if herb_name == "" or already_selected.has(herb_name):
			continue
		options.append({
			"text": "%s｜%s" % [herb_name, String(herb_data.get("description", ""))],
			"value": herb_name,
		})
	options.append({"text": "取消取藥", "value": CHOICE_CANCEL})
	return await _request_choice(options)


func _request_choice(options: Array) -> String:
	var dialog_manager := _get_dialog_manager()
	if dialog_manager == null or not dialog_manager.has_method("show_choice"):
		push_warning("[調香室藥櫃] 找不到可用的 DialogManager ChoiceBox。")
		return CHOICE_CANCEL
	var choice_box := dialog_manager.get_node_or_null("ChoiceBox")
	if choice_box == null or not choice_box.has_method("hide_choices"):
		push_warning("[調香室藥櫃] 找不到 DialogManager/ChoiceBox。")
		return CHOICE_CANCEL

	var choice_data: Array = []
	for option_any in options:
		if typeof(option_any) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_any
		choice_data.append({
			"text": String(option.get("text", "")),
			"callback": Callable(self, "_resolve_choice").bind(String(option.get("value", CHOICE_CANCEL))),
		})
	if choice_data.is_empty():
		return CHOICE_CANCEL

	_choice_active = true
	_choice_value = CHOICE_CANCEL
	dialog_manager.call("show_choice", choice_data)
	await choice_resolved
	return _choice_value


func _resolve_choice(value: String) -> void:
	if not _choice_active:
		return
	_choice_active = false
	_choice_value = value
	var dialog_manager := _get_dialog_manager()
	if dialog_manager:
		var choice_box := dialog_manager.get_node_or_null("ChoiceBox")
		if choice_box and choice_box.has_method("hide_choices"):
			choice_box.call("hide_choices")
	choice_resolved.emit()


func _finish_interaction() -> void:
	if _choice_active:
		_resolve_choice(CHOICE_CANCEL)
	_set_player_movable(true)
	interaction_locked = false


func _get_selected_herbs() -> Array[String]:
	var room := get_parent()
	if room and room.has_method("get_selected_alchemy_herbs"):
		var stored_value = room.call("get_selected_alchemy_herbs")
		var result: Array[String] = []
		if stored_value is Array:
			for herb in stored_value:
				result.append(String(herb))
		return result
	var empty_result: Array[String] = []
	return empty_result


func _set_selected_herbs(value: Array[String]) -> void:
	var room := get_parent()
	if room and room.has_method("set_selected_alchemy_herbs"):
		room.call("set_selected_alchemy_herbs", value.duplicate())


func _set_processing_methods(value: Array[String]) -> void:
	var room := get_parent()
	if room and room.has_method("set_alchemy_processing_methods"):
		room.call("set_alchemy_processing_methods", value.duplicate())


func _is_final_room_intro_done() -> bool:
	return bool(_get_flag(FLAG_FINAL_ROOM_INTRO_DONE, false))


func _refresh_sewer_puzzle_note() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager and quest_manager.has_method("refresh_sewer_puzzle_note"):
		quest_manager.call("refresh_sewer_puzzle_note")


func _get_flag(flag_name: String, default_value = null):
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state == null:
		global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state == null:
		return default_value
	var flags_value = global_state.get("flags")
	if flags_value is Dictionary and (flags_value as Dictionary).has(flag_name):
		return (flags_value as Dictionary).get(flag_name, default_value)
	if global_state.has_method("get_flag"):
		var value = global_state.get_flag(flag_name)
		return default_value if value == null else value
	var value = global_state.get(flag_name)
	return default_value if value == null else value


func _set_flag(flag_name: String, value: bool) -> void:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state == null:
		global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state == null:
		push_warning("[調香室藥櫃] 找不到 GlobalState，無法寫入：%s" % flag_name)
		return
	if global_state.has_method("set_flag"):
		global_state.set_flag(flag_name, value)
	else:
		global_state.set(flag_name, value)


func _set_player_movable(value: bool) -> void:
	var target := player_ref
	if target == null:
		target = get_node_or_null("/root/GameRoot/LiuYu")
	if target == null:
		target = get_node_or_null("/root/Player")
	if target:
		target.set("can_move", value)


func _show_dialog(lines: Array[String]) -> void:
	var dialog_manager := _get_dialog_manager()
	if dialog_manager == null:
		for line in lines:
			print(line)
		return
	if dialog_manager.has_method("show_dialog_sequence"):
		_waiting_for_dialog = true
		dialog_manager.show_dialog_sequence(_to_dialog_lines(lines), self)
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
	return get_node_or_null("/root/DialogManager")


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
