extends Node2D
class_name YuhengSewerTalismanRoom

signal dialog_closed

# ------------------------------------------------------------
# 地圖 / 轉場設定
# ------------------------------------------------------------
@export var yuheng_sewer_center: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_center.tscn"
@export var music_tag := "yuheng"
@export var map_display_name: String = "玉衡鎮下水道符咒間"

# 回到中央區時，要讓 GameRoot 把劉語塵放到這個 spawn point。
@export var return_spawn_point_name := "from_yuheng_sewer_talisman_room"

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var to_yuheng_sewer_center: Area2D = get_node_or_null("To_yuheng_sewer_center")

# ------------------------------------------------------------
# 符咒機關設定
# ------------------------------------------------------------
const FLAG_SOLVED := "sewer_talisman_solved"
const FLAG_HINT_READ := "sewer_talisman_hint_read"

# 正解來自石刻：
# 心亂則語生，語腐則水濁，水濁則夢驚。
# 所以補封順序為：心 → 語 → 水
const CORRECT_SEQUENCE: Array[String] = [
	"heart",
	"mouth",
	"water"
]

const TALISMAN_NAMES := {
	"heart": "心符",
	"mouth": "語符",
	"water": "水符"
}

const TALISMAN_AREA_PATHS := {
	"heart": "heart_talisman/Area2D",
	"mouth": "mouth_talisman/Area2D",
	"water": "water_talisman/Area2D"
}

@export var interact_action := "interact"
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var narration_speaker_id := 0

var current_target_id := ""
var current_sequence: Array[String] = []
var interaction_locked := false
var transition_locked := false
var player_ref: Node = null
var _waiting_for_dialog := false
var _space_was_down := false


func _ready() -> void:
	_connect_talisman_areas()
	_connect_return_area()

	await _play_entry_fade()
	await show_map_name()


func get_map_display_name() -> String:
	return map_display_name


func _play_entry_fade() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 1.5

	var tween_in := overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished


func show_map_name() -> void:
	var map_popup := get_node_or_null("CanvasLayer/MapNamePopup")
	if map_popup:
		map_popup.text = map_display_name
		map_popup.visible = true
		map_popup.modulate.a = 1.0

		await get_tree().create_timer(2.0).timeout

		var popup_tween := map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished

		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")


func _process(_delta: float) -> void:
	if current_target_id == "":
		return

	if interaction_locked:
		return

	if _is_interact_pressed():
		await _interact_talisman(current_target_id)


# ------------------------------------------------------------
# 符咒機關主流程
# ------------------------------------------------------------
func _interact_talisman(talisman_id: String) -> void:
	if _get_flag(FLAG_SOLVED, false):
		interaction_locked = true
		_set_player_movable(false)
		await _show_dialog(_build_after_solved_lines())
		_set_player_movable(true)
		interaction_locked = false
		return

	interaction_locked = true
	_set_player_movable(false)

	if not _get_flag(FLAG_HINT_READ, false):
		_set_flag(FLAG_HINT_READ, true)
		await _show_dialog(_build_first_investigation_lines())
		_set_player_movable(true)
		interaction_locked = false
		return

	current_sequence.append(talisman_id)

	if not _is_current_sequence_valid():
		await _show_dialog(_build_wrong_sequence_lines(talisman_id))
		current_sequence.clear()
		_set_player_movable(true)
		interaction_locked = false
		return

	if current_sequence.size() >= CORRECT_SEQUENCE.size():
		await _solve_talisman_puzzle()
		_set_player_movable(true)
		interaction_locked = false
		return

	await _show_dialog(_build_correct_step_lines(talisman_id))
	_set_player_movable(true)
	interaction_locked = false


func _is_current_sequence_valid() -> bool:
	if current_sequence.size() > CORRECT_SEQUENCE.size():
		return false

	for i in range(current_sequence.size()):
		if current_sequence[i] != CORRECT_SEQUENCE[i]:
			return false

	return true


func _solve_talisman_puzzle() -> void:
	_set_flag(FLAG_SOLVED, true)
	current_sequence.clear()

	await _show_dialog([
		"三道符光一齊定住。",
		"心符沉下，語符歸線，水符收濁。",
		"原本從牆縫滲出的紫黑霧氣，被一寸寸壓回裂口深處。",
		"石壁裡傳來細細的聲響，像有人替一處快裂開的傷口重新繫上線。",
		"劉語塵低聲道：「封住了。」",
		"他停了一下，望著那些被水氣泡皺的符紙。",
		"「但不像治好。」",
		"「只是替快裂的牆，再壓上一隻手。」",
		"「書眠……這些年到底一個人補過多少次？」",
		"遠方傳來機關開啟的聲音。"
	])


func _build_first_investigation_lines() -> Array[String]:
	return [
		"牆上貼著三道舊符。",
		"符紙原本應是祈平安、護身息的家常符，可如今筆畫沉重，符尾被潮氣泡得發暗。",
		"三道符後，各自壓著一道細小裂縫。",
		"裂縫中有紫黑霧氣滲出，像被壓在牆裡的惡夢，仍不肯安分。",
		"旁邊的石壁上刻著一行小字：",
		"「心亂則語生，語腐則水濁，水濁則夢驚。」",
		"劉語塵看了許久。",
		"「這不像一句咒語。」",
		"「倒像是在說，污染是怎麼一步一步長出來的。」",
		"「先亂其心，再腐其語，最後連水與夢都不得安寧。」",
		"他望向三道符。",
		"「若要補封，順序恐怕不能錯。」"
	]


func _build_correct_step_lines(talisman_id: String) -> Array[String]:
	match talisman_id:
		"heart":
			return [
				"你按住心符。",
				"符紙下方的裂縫微微一震，原本躁動的霧氣短暫沉下。",
				"劉語塵道：「先定其心。」"
			]
		"mouth":
			return [
				"你按住語符。",
				"符上的墨線重新接起，像把一句快腐爛的話，勉強收回紙面。",
				"劉語塵道：「心定，語才不亂。」"
			]
		"water":
			return [
				"你按住水符。",
				"符尾浸入牆縫的水痕之中，濁氣被慢慢引回裂口深處。",
				"劉語塵道：「語若歸正，水才有路可清。」"
			]
		_:
			return [
				"符紙微微一震。"
			]


func _build_wrong_sequence_lines(talisman_id: String) -> Array[String]:
	var talisman_name := str(TALISMAN_NAMES.get(talisman_id, "符紙"))
	return [
		"你按住%s。" % talisman_name,
		"符光才剛亮起，便忽然一亂。",
		"三道裂縫同時滲出冷霧，水聲也變得沉濁。",
		"劉語塵皺眉：「順序錯了。」",
		"「那行字不是三個名詞，是一條流向。」",
		"符光散去，機關似乎重置了。"
	]


func _build_after_solved_lines() -> Array[String]:
	return [
		"三道符紙已經重新壓穩。",
		"牆縫中仍有寒意，卻不再繼續外滲。",
		"劉語塵道：「封印暫時穩住了。」"
	]


# ------------------------------------------------------------
# 符咒 Area2D
# ------------------------------------------------------------
func _connect_talisman_areas() -> void:
	for talisman_id in TALISMAN_AREA_PATHS.keys():
		_connect_talisman_area(talisman_id, str(TALISMAN_AREA_PATHS[talisman_id]))


func _connect_talisman_area(talisman_id: String, area_path: String) -> void:
	var area := get_node_or_null(area_path) as Area2D
	if area == null:
		push_warning("找不到符咒互動區：" + area_path)
		return

	if not area.body_entered.is_connected(_on_talisman_body_entered):
		area.body_entered.connect(_on_talisman_body_entered.bind(talisman_id))

	if not area.body_exited.is_connected(_on_talisman_body_exited):
		area.body_exited.connect(_on_talisman_body_exited.bind(talisman_id))


func _on_talisman_body_entered(body: Node, talisman_id: String) -> void:
	if _is_player(body):
		current_target_id = talisman_id
		player_ref = body


func _on_talisman_body_exited(body: Node, talisman_id: String) -> void:
	if _is_player(body) and current_target_id == talisman_id:
		current_target_id = ""
		if player_ref == body:
			player_ref = null


# ------------------------------------------------------------
# 回到舊水道中央
# ------------------------------------------------------------
func _connect_return_area() -> void:
	if to_yuheng_sewer_center == null:
		push_warning("To_yuheng_sewer_center 找不到！")
		return

	if not to_yuheng_sewer_center.body_entered.is_connected(_on_to_yuheng_sewer_center_body_entered):
		to_yuheng_sewer_center.body_entered.connect(_on_to_yuheng_sewer_center_body_entered)


func _on_to_yuheng_sewer_center_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if transition_locked:
		return

	transition_locked = true
	player_ref = body
	_set_player_movable(false)

	await _fade_out_and_return_to_center()


func _fade_out_and_return_to_center() -> void:
	if overlay:
		overlay.visible = true
		overlay.modulate.a = 0.0

		var tween := overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = return_spawn_point_name

		if game_root.has_method("change_map_to"):
			game_root.change_map_to(yuheng_sewer_center)
			return

	get_tree().change_scene_to_file(yuheng_sewer_center)


# ------------------------------------------------------------
# 共用工具
# ------------------------------------------------------------
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


func _set_player_movable(value: bool) -> void:
	var target := player_ref
	if target == null:
		target = get_node_or_null("/root/GameRoot/LiuYu")
	if target == null:
		target = get_node_or_null("/root/Player")

	if target:
		target.set("can_move", value)


# ------------------------------------------------------------
# Dialog helpers
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# GlobalState helpers
# ------------------------------------------------------------
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


func _set_flag(flag_name: String, value) -> void:
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
