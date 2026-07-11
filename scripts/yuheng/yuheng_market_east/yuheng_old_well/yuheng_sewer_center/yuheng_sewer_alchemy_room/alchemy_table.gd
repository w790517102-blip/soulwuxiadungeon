extends Node2D
class_name AlchemyTable

const FLAG_SOLVED := "sewer_alchemy_solved"
const FLAG_POT_INSPECTED := "sewer_alchemy_pot_inspected"
const FLAG_HELD_HERB := "sewer_alchemy_held_herb"
const FLAG_ADDED_HERBS := "sewer_alchemy_added_herbs"

const CORRECT_SEQUENCE: Array[String] = [
	"苦艾",
	"菖蒲",
	"紫蘇"
]

@export var interact_action := "interact"
@export var fail_battle_id := "sewer_alchemy_fail"
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

	if _get_flag(FLAG_SOLVED, false):
		await _show_dialog([
			"調香釜中只餘一縷溫和草香，沿著舊水道慢慢散開。"
		])
		_finish_interaction()
		return

	if not _get_flag(FLAG_POT_INSPECTED, false):
		await _discover_pot()
		_finish_interaction()
		return

	var held_herb := _get_held_herb()
	if held_herb != "":
		await _put_herb_into_pot(held_herb)
		_finish_interaction()
		return

	var added_herbs := _get_added_herbs()
	if added_herbs.size() >= 3:
		await _brew()
		_finish_interaction()
		return

	await _show_dialog([
		"調香釜中仍殘留著一點餘香。",
		"若能依照藥師留下的藥訣取藥，也許能驅散此處的濕悶霉氣。"
	])

	_finish_interaction()


func _finish_interaction() -> void:
	_set_player_movable(true)
	interaction_locked = false


func _discover_pot() -> void:
	_set_flag(FLAG_POT_INSPECTED, true)

	await _show_dialog([
		"調香釜裡還殘留著一縷極淡的餘香。",
		"奇妙的是，這股餘香竟隱隱中和了四周的濕悶霉氣。",
		"劉語塵低聲道：「也許……能找些可用的藥材，重新調香祛穢。」"
	])


func _put_herb_into_pot(herb_name: String) -> void:
	var added_herbs := _get_added_herbs()
	added_herbs.append(herb_name)

	_set_flag(FLAG_ADDED_HERBS, added_herbs)
	_set_flag(FLAG_HELD_HERB, "")
	_remove_herb_from_inventory(herb_name)

	await _show_dialog([
		"你將「%s」投入調香釜。" % herb_name
	])

	if added_herbs.size() >= 3:
		await _show_dialog([
			"三味藥材已入釜中。",
			"釜中草氣翻湧，似乎可以開始調香了。"
		])


func _brew() -> void:
	var added_herbs := _get_added_herbs()

	if _is_correct_sequence(added_herbs):
		_set_flag(FLAG_SOLVED, true)

		await _show_dialog([
			"劉語塵依訣調香，釜中藥氣先濁後清，最後歸於平和。",
			"原本濕悶霉濁的氣息漸漸散去，只餘一縷溫和草香，沿著舊水道慢慢流開。",
			"遠方傳來機關開啟的聲音。"
		])
	else:
		await _show_dialog([
			"調香釜中的藥氣忽然反衝。",
			"方才投入的藥序似乎不對。",
			"濕悶霉氣變得更加刺鼻，陰冷的氣息自釜底翻起。"
		])

		_set_flag(FLAG_ADDED_HERBS, [])
		_set_flag(FLAG_HELD_HERB, "")

		_start_fail_battle()


func _is_correct_sequence(added_herbs: Array[String]) -> bool:
	if added_herbs.size() != CORRECT_SEQUENCE.size():
		return false

	for i in range(CORRECT_SEQUENCE.size()):
		if added_herbs[i] != CORRECT_SEQUENCE[i]:
			return false

	return true


func _start_fail_battle() -> void:
	# 給 Codex 大小姐接戰鬥系統用。
	var battle_manager := get_node_or_null("/root/BattleManager")
	if battle_manager and battle_manager.has_method("start_battle"):
		battle_manager.start_battle(fail_battle_id)
		return

	var battle_transition := get_node_or_null("/root/BattleTransition")
	if battle_transition and battle_transition.has_method("start_battle"):
		battle_transition.start_battle(fail_battle_id)
		return

	var game_root_battle_transition := get_node_or_null("/root/GameRoot/BattleTransition")
	if game_root_battle_transition and game_root_battle_transition.has_method("start_battle"):
		game_root_battle_transition.start_battle(fail_battle_id)
		return

	print("調香失敗，應進入戰鬥：", fail_battle_id)


func _remove_herb_from_inventory(herb_name: String) -> void:
	# 給 Codex 大小姐接背包系統用。
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory and inventory.has_method("remove_item"):
		inventory.remove_item(herb_name, 1)
		return

	var inventory_sync := get_node_or_null("/root/InventorySync")
	if inventory_sync and inventory_sync.has_method("remove_item"):
		inventory_sync.remove_item(herb_name, 1)
		return

	var game_root_inventory := get_node_or_null("/root/GameRoot/InventoryManager")
	if game_root_inventory and game_root_inventory.has_method("remove_item"):
		game_root_inventory.remove_item(herb_name, 1)
		return

	var game_root_inventory_sync := get_node_or_null("/root/GameRoot/InventorySync")
	if game_root_inventory_sync and game_root_inventory_sync.has_method("remove_item"):
		game_root_inventory_sync.remove_item(herb_name, 1)


func _get_held_herb() -> String:
	return str(_get_flag(FLAG_HELD_HERB, ""))


func _get_added_herbs() -> Array[String]:
	var value = _get_flag(FLAG_ADDED_HERBS, [])

	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))

	return result


func _get_flag(flag_name: String, default_value = null):
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state == null:
		global_state = get_node_or_null("/root/GameRoot/GlobalState")
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


func _set_flag(flag_name: String, value) -> void:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state == null:
		global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state == null:
		push_warning("找不到 GlobalState，無法寫入：" + flag_name)
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
