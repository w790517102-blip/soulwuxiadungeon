extends Node2D
class_name YuhengSewerFinalRoom

# ------------------------------------------------------------
# 場景路徑 / 基本設定
# ------------------------------------------------------------
@onready var yuheng_sewer_center: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_center.tscn"
@onready var yuheng_stalactite_cave: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_final_room/yuheng_stalactite_cave/yuheng_stalactite_cave.tscn"

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var qin_totem: CanvasItem = get_node_or_null("totem/qin_totem")
@onready var herb_totem: CanvasItem = get_node_or_null("totem/herb_totem")
@onready var talisman_totem: CanvasItem = get_node_or_null("totem/talisman_totem")
@onready var final_seal: Node2D = get_node_or_null("talisman")

@export var music_tag := "yuheng"
@export var map_display_name: String = "玉衡鎮下水道終端房間"

@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var narration_speaker_id := 0

signal dialog_closed

# ------------------------------------------------------------
# 三機關 Flag
# ------------------------------------------------------------
const F_ALCHEMY_SOLVED := "sewer_alchemy_solved"       # 藥／調香室
const F_MUSIC_SOLVED := "sewer_music_solved"           # 琴／調音室
const F_TALISMAN_SOLVED := "sewer_talisman_solved"     # 符／補封室
const F_FINAL_SEAL_OPENED := "sewer_final_seal_opened" # 終端房封印已解除

var transition_locked := false
var seal_dialog_locked := false
var _waiting_for_dialog := false


func _ready() -> void:
	_apply_totem_and_seal_state(false)
	await _play_entry_fade()
	await show_map_name()

	# 進房間後再檢查一次。若三個機關都完成，第一次進終端房時播放封印解除演出。
	await _refresh_final_room_state()


func get_map_display_name() -> String:
	return map_display_name


# ------------------------------------------------------------
# 進場淡入 / 地圖名稱
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# 終端房狀態
# ------------------------------------------------------------
func _refresh_final_room_state() -> void:
	_apply_totem_and_seal_state(false)

	if _all_puzzles_solved():
		if not _get_flag(F_FINAL_SEAL_OPENED, false):
			await _play_final_seal_open_event()
		else:
			_apply_totem_and_seal_state(true)


func _apply_totem_and_seal_state(final_opened_override := false) -> void:
	var alchemy_done := _get_flag(F_ALCHEMY_SOLVED, false)
	var music_done := _get_flag(F_MUSIC_SOLVED, false)
	var talisman_done := _get_flag(F_TALISMAN_SOLVED, false)
	var final_opened := final_opened_override or _get_flag(F_FINAL_SEAL_OPENED, false) or (alchemy_done and music_done and talisman_done)

	_set_totem_lit(qin_totem, music_done)
	_set_totem_lit(herb_totem, alchemy_done)
	_set_totem_lit(talisman_totem, talisman_done)

	if final_seal:
		final_seal.visible = not final_opened


func _set_totem_lit(node: CanvasItem, lit: bool) -> void:
	if node == null:
		return

	node.visible = lit
	node.modulate.a = 1.0 if lit else 0.0


func _all_puzzles_solved() -> bool:
	return _get_flag(F_ALCHEMY_SOLVED, false) \
		and _get_flag(F_MUSIC_SOLVED, false) \
		and _get_flag(F_TALISMAN_SOLVED, false)


func _play_final_seal_open_event() -> void:
	_set_player_movable(false)

	# 確保三枚徽印先全部亮著，再播放封印消失。
	_set_totem_lit(qin_totem, true)
	_set_totem_lit(herb_totem, true)
	_set_totem_lit(talisman_totem, true)

	await _show_dialog([
		"終端房內，三枚徽印同時亮起。",
		"琴音歸正，藥香流開，符光補封。",
		"原本覆在石門前的符咒開始顫動，像是壓在水底多年的話，終於鬆了一口氣。",
		"劉語塵低聲道：「琴、藥、符……都應了。」",
		"「這扇門，不是靠鑰匙開的。」",
		"「是要來者先看懂，這裡曾經如何救人，又如何被污染逼成如今模樣。」",
		"藥能救人，也能被悶成毒。",
		"音能教人，也能被扭成雜響。",
		"符能護人，也能被迫變成封印。",
		"劉語塵望著逐漸散去的符光。",
		"「這地方不是邪。」",
		"「是傷得太深。」",
		"前方通往鐘乳石洞的封印消失了。"
	])

	_set_flag(F_FINAL_SEAL_OPENED, true)
	await _fade_out_final_seal()
	_apply_totem_and_seal_state(true)

	_set_player_movable(true)


func _fade_out_final_seal() -> void:
	if final_seal == null:
		return

	final_seal.visible = true
	final_seal.modulate.a = 1.0

	var tween := final_seal.create_tween()
	tween.tween_property(final_seal, "modulate:a", 0.0, 0.8)
	await tween.finished

	final_seal.visible = false


# ------------------------------------------------------------
# 轉場：回中央區
# ------------------------------------------------------------
func _on_to_yuheng_sewer_center_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if transition_locked:
		return

	transition_locked = true
	_set_player_movable(false)

	await _fade_out()

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = "from_yuheng_sewer_final_room"
		if game_root.has_method("change_map_to"):
			game_root.change_map_to(yuheng_sewer_center)
			return

	get_tree().change_scene_to_file(yuheng_sewer_center)


# ------------------------------------------------------------
# 轉場：前往鐘乳石洞
# ------------------------------------------------------------
func _on_to_yuheng_stalactite_cave_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if transition_locked or seal_dialog_locked:
		return

	if not _all_puzzles_solved():
		await _show_sealed_message()
		return

	if not _get_flag(F_FINAL_SEAL_OPENED, false):
		await _play_final_seal_open_event()

	transition_locked = true
	_set_player_movable(false)

	await _fade_out()

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = "from_yuheng_sewer_final_room"
		if game_root.has_method("change_map_to"):
			game_root.change_map_to(yuheng_stalactite_cave)
			return

	get_tree().change_scene_to_file(yuheng_stalactite_cave)


func _show_sealed_message() -> void:
	seal_dialog_locked = true
	_set_player_movable(false)

	await _show_dialog(_build_sealed_lines())

	_set_player_movable(true)
	seal_dialog_locked = false


func _build_sealed_lines() -> Array[String]:
	var missing: Array[String] = []
	if not _get_flag(F_MUSIC_SOLVED, false):
		missing.append("琴")
	if not _get_flag(F_ALCHEMY_SOLVED, false):
		missing.append("藥")
	if not _get_flag(F_TALISMAN_SOLVED, false):
		missing.append("符")

	var missing_text := "、".join(missing)

	return [
		"石門前的符咒仍未散去。",
		"牆上的三枚徽印尚未全亮。",
		"劉語塵看向那些黯淡的紋路。",
		"「還少了%s。」" % missing_text,
		"「先把舊水道裡未歸位的東西補齊，再回來。」"
	]


# ------------------------------------------------------------
# 共用：淡出 / 玩家 / 對話
# ------------------------------------------------------------
func _fade_out() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 0.0

	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	await tween.finished


func _is_player(body: Node) -> bool:
	return body.name == "LiuYu" or body.name == "Player" or body.is_in_group("player")


func _set_player_movable(value: bool) -> void:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player == null:
		player = get_node_or_null("/root/Player")

	if player:
		player.set("can_move", value)


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
# GlobalState
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
