extends Node2D
class_name MedicineCabinet

const FLAG_SOLVED := "sewer_alchemy_solved"
const FLAG_POT_INSPECTED := "sewer_alchemy_pot_inspected"
const FLAG_HELD_HERB := "sewer_alchemy_held_herb"
const FLAG_ADDED_HERBS := "sewer_alchemy_added_herbs"

const HERB_OPTIONS: Array[String] = [
	"苦艾",
	"菖蒲",
	"紫蘇",
	"薄荷",
	"甘草",
	"白芷",
	"藿香",
	"陳皮"
]

@export var interact_action := "interact"
@export var choice_box_path: NodePath
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
			"藥櫃中的藥氣已恢復清正，不再有先前那股濕悶霉氣。"
		])
		_finish_interaction()
		return

	if not _get_flag(FLAG_POT_INSPECTED, false):
		await _show_dialog([
			"藥櫃中收著許多藥材，雖然此處陰濕，藥材卻都曾仔細封存。",
			"可如今櫃中仍泛著一股濕悶霉氣，沉在鼻腔裡，久久不散。",
			"劉語塵皺眉：「不妙……再在這舊水道待下去，怕是連我都要被這霉氣薰鈍了。」"
		])
		_finish_interaction()
		return

	var held_herb := _get_held_herb()
	if held_herb != "":
		await _show_dialog([
			"你手上已拿著「%s」。" % held_herb,
			"得先將它投入調香釜，才能再取下一味藥。"
		])
		_finish_interaction()
		return

	var added_herbs := _get_added_herbs()
	if added_herbs.size() >= 3:
		await _show_dialog([
			"三味藥材已經投入調香釜。",
			"接下來該去查看調香釜，讓藥氣歸正。"
		])
		_finish_interaction()
		return

	await _show_dialog([
		"藥櫃深處有一片舊木牌，上頭刻著藥師留下的殘句：",
		"「苦艾祛穢，菖蒲醒神，紫蘇安息。」",
		"要取哪一味藥？"
	])

	_open_herb_choice_box()


func _finish_interaction() -> void:
	_set_player_movable(true)
	interaction_locked = false


func _open_herb_choice_box() -> void:
	var choice_box: Node = null

	if choice_box_path != NodePath():
		choice_box = get_node_or_null(choice_box_path)

	if choice_box == null:
		choice_box = get_node_or_null("/root/ChoiceBox")

	if choice_box == null:
		choice_box = get_node_or_null("/root/GameRoot/ChoiceBox")

	if choice_box == null:
		push_warning("找不到 ChoiceBox。請在 MedicineCabinet.gd 的 choice_box_path 接上你的 ChoiceBox。")
		print("可選藥材：", HERB_OPTIONS)
		_finish_interaction()
		return

	# 依目前專案 ChoiceBox API 做兼容。目標：玩家選完後呼叫 _on_herb_selected(choice_value)。
	if choice_box.has_method("open"):
		choice_box.open(HERB_OPTIONS, Callable(self, "_on_herb_selected"))
	elif choice_box.has_method("show_choices"):
		choice_box.show_choices(HERB_OPTIONS, Callable(self, "_on_herb_selected"))
	elif choice_box.has_method("show_choice_box"):
		choice_box.show_choice_box(HERB_OPTIONS, Callable(self, "_on_herb_selected"))
	else:
		push_warning("ChoiceBox 找到了，但沒有 open/show_choices/show_choice_box 方法。")
		print("可選藥材：", HERB_OPTIONS)
		_finish_interaction()


func _on_herb_selected(choice_value) -> void:
	var herb_name := _normalize_choice_to_herb_name(choice_value)
	if herb_name == "":
		_finish_interaction()
		return

	_set_flag(FLAG_HELD_HERB, herb_name)
	_add_herb_to_inventory(herb_name)

	await _show_dialog([
		"你取出了「%s」。" % herb_name,
		"得先將它投入調香釜，才能再取下一味。"
	])

	_finish_interaction()


func _normalize_choice_to_herb_name(choice_value) -> String:
	if choice_value is int:
		var index := int(choice_value)
		if index >= 0 and index < HERB_OPTIONS.size():
			return HERB_OPTIONS[index]
		return ""

	var text := str(choice_value)
	if HERB_OPTIONS.has(text):
		return text

	# 若 ChoiceBox 回傳的是帶序號的文字，例如「1. 苦艾」，就用包含判定取回藥名。
	for herb_name in HERB_OPTIONS:
		if text.contains(herb_name):
			return herb_name

	return text


func _add_herb_to_inventory(herb_name: String) -> void:
	# 給 Codex 大小姐接背包系統用。
	# 若目前還沒接 Inventory，先用 GlobalState 的 held_herb 就能跑解謎流程。
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory and inventory.has_method("add_item"):
		inventory.add_item(herb_name, 1)
		return

	var inventory_sync := get_node_or_null("/root/InventorySync")
	if inventory_sync and inventory_sync.has_method("add_item"):
		inventory_sync.add_item(herb_name, 1)
		return

	var game_root_inventory := get_node_or_null("/root/GameRoot/InventoryManager")
	if game_root_inventory and game_root_inventory.has_method("add_item"):
		game_root_inventory.add_item(herb_name, 1)
		return

	var game_root_inventory_sync := get_node_or_null("/root/GameRoot/InventorySync")
	if game_root_inventory_sync and game_root_inventory_sync.has_method("add_item"):
		game_root_inventory_sync.add_item(herb_name, 1)


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
