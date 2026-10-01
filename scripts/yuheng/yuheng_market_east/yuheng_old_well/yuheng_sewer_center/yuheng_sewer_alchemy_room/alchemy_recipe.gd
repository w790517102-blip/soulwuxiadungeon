extends Node2D
class_name AlchemyRecipe

const FLAG_SOLVED := "sewer_alchemy_solved"
const FLAG_RECIPE_READ := "sewer_alchemy_recipe_read"
const FLAG_FINAL_ROOM_INTRO_DONE := "event_yuheng_sewer_final_room_intro_done"

@export var interact_action := "interact"
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var narration_speaker_id := 0

@onready var interact_area: Area2D = $Area2D

signal dialog_closed

var player_inside := false
var interaction_locked := false
var player_ref: Node = null
var _waiting_for_dialog := false
var _space_was_down := false


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

	if not bool(_get_flag(FLAG_FINAL_ROOM_INTRO_DONE, false)) and not bool(_get_flag(FLAG_SOLVED, false)):
		await _show_dialog([
			"（牆邊壓著一張被藥煙燻黑的舊箋，字跡已被煙垢遮去大半。）",
			"眼下尚不清楚這間石室的用途，先記下它的位置吧。",
		])
		_finish_interaction()
		return

	await _show_dialog([
		"（牆邊留著一張被藥煙燻黑的舊箋。紙角雖已殘破，字跡尚可辨認。）",
		"取苦以沉濁，卻不可用至苦之根。",
		"取蒲以通竅，其香藏於根中，非研不得出。",
		"取紫葉以和氣，葉脈不可再傷，當留其原形。",
		"先沉濁，次通竅，末以柔香收束。",
		"取苦、取蒲、取紫葉……",
		"先沉濁，再通竅，最後收束藥香。",
		"所需藥材與處理方法，應當都藏在這幾句裡。",
	])

	if not bool(_get_flag(FLAG_RECIPE_READ, false)):
		_set_flag(FLAG_RECIPE_READ, true)
		_refresh_sewer_puzzle_note()
	_finish_interaction()


func _finish_interaction() -> void:
	_set_player_movable(true)
	interaction_locked = false


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


func _set_flag(flag_name: String, value) -> void:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state == null:
		global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state == null:
		push_warning("[調香室殘方] 找不到 GlobalState，無法寫入：%s" % flag_name)
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
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		dialog_manager = get_node_or_null("/root/DialogManager")
	if dialog_manager == null:
		for line in lines:
			print(line)
		return
	if dialog_manager.has_method("show_dialog_sequence"):
		_waiting_for_dialog = true
		dialog_manager.show_dialog_sequence(_to_dialog_lines(lines), self)
		if dialog_manager.has_signal("dialog_sequence_finished"):
			await dialog_manager.dialog_sequence_finished
		elif _waiting_for_dialog:
			await dialog_closed
		_waiting_for_dialog = false
		return
	for line in lines:
		print(line)


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
