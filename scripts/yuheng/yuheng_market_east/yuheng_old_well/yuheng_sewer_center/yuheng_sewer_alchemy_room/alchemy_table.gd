extends Node2D
class_name AlchemyTable

const FLAG_SOLVED := "sewer_alchemy_solved"
const FLAG_RECIPE_READ := "sewer_alchemy_recipe_read"
const FLAG_BITTER_YUMEI_DEFEATED := "sewer_alchemy_bitter_yumei_defeated"
const FLAG_FINAL_ROOM_INTRO_DONE := "event_yuheng_sewer_final_room_intro_done"

const CHOICE_CANCEL := "__cancel__"
const CHOICE_IGNITE := "__ignite__"
const CHOICE_REPROCESS := "__reprocess__"

const TREAT_REMOVE_ROOT_CHOP := "remove_root_chop"
const TREAT_GRIND_POWDER := "grind_powder"
const TREAT_KEEP_WHOLE := "keep_whole"

const CORRECT_HERBS: Array[String] = ["苦艾", "菖蒲", "紫蘇"]
const CORRECT_TREATMENTS: Array[String] = [
	TREAT_REMOVE_ROOT_CHOP,
	TREAT_GRIND_POWDER,
	TREAT_KEEP_WHOLE,
]
const TREATMENT_OPTIONS: Array[Dictionary] = [
	{"id": TREAT_REMOVE_ROOT_CHOP, "text": "將根部去除後切碎"},
	{"id": TREAT_GRIND_POWDER, "text": "研磨成末"},
	{"id": TREAT_KEEP_WHOLE, "text": "保持原形投入"},
]

@export var interact_action := "interact"
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var bitterness_portrait_path := "res://assets/Enemy/bitterness_tone_phantom.png"
@export var narration_speaker_id := 0
@export var enemy_speaker_id := 1

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
		await _show_dialog(["調香台中只餘一縷溫和草香，沿著舊水道慢慢散開。"])
		_finish_interaction()
		return

	if not _is_final_room_intro_done():
		await _show_dialog([
			"藥缽、藥舟，還有這爐未熄的薪火……",
			"（劉語塵微微俯身，嗅了嗅周遭的空氣。）",
			"空氣裡還浮著一縷淡淡的藥煙。",
			"看來這並非尋常煎藥之處，而是用來調和藥香、施行香療的調香台。",
			"只是用途未明。若隨意挪動其中器物，恐怕會擾亂原本的配伍。",
			"……先記下來，暫且別動。",
		])
		_finish_interaction()
		return

	if not bool(_get_flag(FLAG_RECIPE_READ, false)):
		await _show_dialog([
			"藥草徽印所指的，果然就是這座調香台。",
			"藥材、器具與薪火俱全……看來關鍵不只是選出藥草，還得找出正確的調和方式。",
			"只是配伍尚不清楚。先找找調香之人留下的藥方吧。",
		])
		_finish_interaction()
		return

	var selected_herbs := _get_selected_herbs()
	if selected_herbs.size() != 3:
		await _show_dialog([
			"藥缽、藥舟與薪火都已備妥。",
			"只是藥材尚未選齊。先去藥櫃依殘方取藥吧。",
		])
		_finish_interaction()
		return

	var battle_started := await _run_processing_flow(selected_herbs)
	if not battle_started:
		_finish_interaction()


func _run_processing_flow(selected_herbs: Array[String]) -> bool:
	var treatments := _get_treatments()
	if treatments.size() > selected_herbs.size():
		treatments.clear()
		_set_processing_methods([])

	if treatments.is_empty():
		await _show_dialog([
			"好了，藥缽、藥舟與薪火都在這裡。",
			"接下來，依藥性逐一處理吧。",
		])

	while true:
		while treatments.size() < selected_herbs.size():
			var index := treatments.size()
			var prompt := "第一味『%s』，我應當將它……" % selected_herbs[index]
			if index == 1:
				prompt = "第二味『%s』，我應當將它……" % selected_herbs[index]
			elif index == 2:
				prompt = "最後是『%s』。這味藥應當……" % selected_herbs[index]
			await _show_dialog([prompt])
			var treatment := await _request_treatment_choice()
			if treatment == CHOICE_CANCEL:
				return false
			treatments.append(treatment)
			_set_processing_methods(treatments)
			_refresh_sewer_puzzle_note()

		await _show_dialog(_build_formula_summary(selected_herbs, treatments))
		var confirmation := await _request_choice([
			{"text": "點燃藥香", "value": CHOICE_IGNITE},
			{"text": "重新配製", "value": CHOICE_REPROCESS},
			{"text": "取消", "value": CHOICE_CANCEL},
		])
		if confirmation == CHOICE_REPROCESS:
			treatments.clear()
			_set_processing_methods([])
			_refresh_sewer_puzzle_note()
			await _show_dialog(["再依藥性重新處理一次。"])
			continue
		if confirmation != CHOICE_IGNITE:
			return false
		return await _ignite_formula(selected_herbs, treatments)

	return false


func _request_treatment_choice() -> String:
	var options: Array = []
	for treatment_data in TREATMENT_OPTIONS:
		options.append({
			"text": String(treatment_data.get("text", "")),
			"value": String(treatment_data.get("id", "")),
		})
	options.append({"text": "暫停調香", "value": CHOICE_CANCEL})
	return await _request_choice(options)


func _build_formula_summary(herbs: Array[String], treatments: Array[String]) -> Array[String]:
	var lines: Array[String] = []
	for index in range(3):
		var prefix := "第一味"
		if index == 1:
			prefix = "第二味"
		elif index == 2:
			prefix = "第三味"
		lines.append("%s：『%s』，以『%s』處理。" % [
			prefix,
			herbs[index],
			_treatment_display_name(treatments[index]),
		])
	lines.append("將這三味藥材揉合成柱，點燃藥香嗎？")
	return lines


func _ignite_formula(herbs: Array[String], treatments: Array[String]) -> bool:
	if _is_correct_formula(herbs, treatments):
		await _show_dialog([
			"（火苗沿著藥香緩緩向上。最初微苦的煙氣並未變得刺鼻，反而漸漸澄澈。）",
			"（菖蒲的辛香在煙霧中開出一道清明的縫隙，最後又被紫蘇柔和的氣息收住。）",
			"不是以苦壓苦，也不是以烈驅濁……",
			"而是讓每一味藥，各自待在最合適的位置。",
			"（調香室深處傳來一聲低沉的機括響動，藥草徽印隨之亮起。）",
		])
		_set_flag(FLAG_SOLVED, true)
		_clear_formula_progress(false)
		_refresh_sewer_puzzle_note()
		return false

	await _show_dialog([
		"（藥香才剛觸火，煙氣便驟然變得濃黑苦澀。）",
		"不對……這不是調和。",
		"這股煙只是在用更強烈的痛苦，強行壓住原本的濁氣！",
	])
	if bool(_get_flag(FLAG_BITTER_YUMEI_DEFEATED, false)):
		await _show_dialog([
			"（辛辣刺鼻的黑煙猛然竄起，嗆得你幾乎無法呼吸。）",
			"唔……又搞錯了。",
			"把這些殘料清掉，再重新來一次吧。",
		])
		_clear_formula_progress(true)
		_refresh_sewer_puzzle_note()
		return false

	await _show_dialog_entries([
		_enemy_line("苦得還不夠……"),
		_enemy_line("只要再苦一些，就一定會好起來。"),
	])
	var room := get_parent()
	if room == null or not room.has_method("start_alchemy_bitter_yumei_battle"):
		push_warning("[調香室] 找不到固定苦息藥魅戰鬥入口。")
		return false
	var battle_started = await room.call("start_alchemy_bitter_yumei_battle", player_ref)
	return bool(battle_started)


func play_failure_battle_return_closeout() -> void:
	interaction_locked = true
	if player_ref == null:
		player_ref = get_node_or_null("/root/GameRoot/LiuYu")
	if player_ref == null:
		player_ref = get_node_or_null("/root/Player")
	_set_player_movable(false)
	await _show_dialog([
		"（你一邊咳嗽，一邊收起武器，慌忙揮手搧開仍未散盡的苦煙。）",
		"咳、咳咳……可惡。",
		"看來配方裡還有什麼地方弄錯了。",
		"先把這些殘料清掉，再重新配一次吧。",
	])
	interaction_locked = false


func _is_correct_formula(herbs: Array[String], treatments: Array[String]) -> bool:
	if herbs.size() != CORRECT_HERBS.size() or treatments.size() != CORRECT_TREATMENTS.size():
		return false
	for index in range(CORRECT_HERBS.size()):
		if herbs[index] != CORRECT_HERBS[index] or treatments[index] != CORRECT_TREATMENTS[index]:
			return false
	return true


func _treatment_display_name(treatment_id: String) -> String:
	for treatment_data in TREATMENT_OPTIONS:
		if String(treatment_data.get("id", "")) == treatment_id:
			return String(treatment_data.get("text", treatment_id))
	return treatment_id


func _clear_formula_progress(retry_needed := false) -> void:
	var room := get_parent()
	if room and room.has_method("clear_alchemy_formula"):
		room.call("clear_alchemy_formula", retry_needed)


func _request_choice(options: Array) -> String:
	var dialog_manager := _get_dialog_manager()
	if dialog_manager == null or not dialog_manager.has_method("show_choice"):
		push_warning("[調香台] 找不到可用的 DialogManager ChoiceBox。")
		return CHOICE_CANCEL
	var choice_box := dialog_manager.get_node_or_null("ChoiceBox")
	if choice_box == null or not choice_box.has_method("hide_choices"):
		push_warning("[調香台] 找不到 DialogManager/ChoiceBox。")
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


func _get_treatments() -> Array[String]:
	var room := get_parent()
	if room and room.has_method("get_alchemy_processing_methods"):
		var stored_value = room.call("get_alchemy_processing_methods")
		var result: Array[String] = []
		if stored_value is Array:
			for treatment in stored_value:
				result.append(String(treatment))
		return result
	var empty_result: Array[String] = []
	return empty_result


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
		push_warning("[調香台] 找不到 GlobalState，無法寫入：%s" % flag_name)
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
	var entries: Array = []
	for line in lines:
		entries.append(_narration_line(line))
	await _show_dialog_entries(entries)


func _show_dialog_entries(entries: Array) -> void:
	var dialog_manager := _get_dialog_manager()
	if dialog_manager == null:
		for entry_any in entries:
			if typeof(entry_any) == TYPE_DICTIONARY:
				print(String((entry_any as Dictionary).get("text", "")))
		return
	if dialog_manager.has_method("show_dialog_sequence"):
		_waiting_for_dialog = true
		dialog_manager.show_dialog_sequence(entries, self)
		await _wait_dialog_finished(dialog_manager)
		return
	for entry_any in entries:
		if typeof(entry_any) == TYPE_DICTIONARY:
			print(String((entry_any as Dictionary).get("text", "")))


func _narration_line(text: String) -> Dictionary:
	return {"text": text, "speaker": narration_speaker_id, "portrait": empty_portrait_path}


func _enemy_line(text: String) -> Dictionary:
	return {"text": text, "speaker": enemy_speaker_id, "portrait": bitterness_portrait_path}


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
