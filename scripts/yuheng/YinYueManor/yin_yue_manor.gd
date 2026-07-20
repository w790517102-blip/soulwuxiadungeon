extends Node2D

@export var yuheng_bamboo_outskirts: String = "res://scenes/yuheng/yuheng_bamboo_outskirts/yuheng_bamboo_outskirts.tscn"
@export var yin_yue_manor_room_day: String = "res://scenes/yuheng/YinYueManor/yin_yue_manor_room/yin_yue_manor_room(day).tscn"
@onready var overlay: ColorRect = get_node_or_null("BlackOverlay") as ColorRect
@onready var gushi_forbidden_return_marker: Marker2D = get_node_or_null("SpawnPoints/GushiForbiddenReturnMarker") as Marker2D
@export var music_tag := "station_stillwind"
@export var map_display_name: String = "飲月山莊"

const F_MET_GUSHI := "met_gushi"
const F_FISH_BOSS_WON := "battle_stalactite_fish_boss_won"
const LIUYU_PORTRAIT_PATH := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const GUSHI_PORTRAIT_PATH := "res://assets/sprites/empty.png"
const GUSHI_SPEAKER_ID := 1
const LIUYU_SPEAKER_ID := 2
const NARRATION_SPEAKER_ID := 0

var _forbidden_gate_busy := false
var _forbidden_requires_exit := false
var _forbidden_menu_was_locked := false


func _ready():
	if overlay:
		overlay.visible = true
		overlay.modulate.a = 1.5
		var tween_in = overlay.create_tween()
		tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
		await tween_in.finished
	else:
		push_warning("[飲月山莊] 找不到 BlackOverlay，進出場淡入效果將略過。")
	
	show_map_name()

func get_map_display_name() -> String:
	return map_display_name

func show_map_name():
	var map_popup = get_node_or_null("CanvasLayer/MapNamePopup")
	if map_popup:
		map_popup.text = map_display_name
		map_popup.visible = true
		map_popup.modulate.a = 1.0
		await get_tree().create_timer(2.0).timeout
		var popup_tween = map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished
		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")


func _on_to_yuheng_bamboo_jungle_body_entered(body: Node2D) -> void:
	if MapTransitionGuard.can_transition(body, get_node_or_null("to_yuheng_bamboo_jungle")):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_YinYueManor"
		get_node("/root/GameRoot").change_map_to(yuheng_bamboo_outskirts)


func _on_to_yin_yue_manor_roomday_body_entered(body: Node2D) -> void:
	if not _can_enter_manor_room():
		return
	if MapTransitionGuard.can_transition(body, get_node_or_null("to_yin_yue_manor_room(day)")):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_YinYueManor"
		get_node("/root/GameRoot").change_map_to(yin_yue_manor_room_day)


func _on_forbidden_zone_body_entered(body: Node2D) -> void:
	if not MapTransitionGuard.can_transition(body, get_node_or_null("forbidden_zone")):
		return
	if _can_enter_manor_room():
		return
	if _forbidden_gate_busy or _forbidden_requires_exit:
		return
	await _play_forbidden_zone_block_flow(body)


func _on_forbidden_zone_body_exited(body: Node2D) -> void:
	if body and body.name == "LiuYu" and not _forbidden_gate_busy:
		_forbidden_requires_exit = false


func _can_enter_manor_room() -> bool:
	return GlobalState.get_flag(F_FISH_BOSS_WON)


func _play_forbidden_zone_block_flow(body: Node2D) -> void:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager == null or bool(dialog_manager.get("dialog_active")):
		return

	_forbidden_gate_busy = true
	_forbidden_requires_exit = true
	_forbidden_menu_was_locked = bool(GlobalState.get_meta("menu_locked", false))
	var moved_to_return_marker := false
	var system_menu := get_node_or_null("/root/SystemMenu")
	if system_menu and system_menu.has_method("close_menu_if_open"):
		system_menu.close_menu_if_open()
	GlobalState.set_meta("menu_locked", true)
	_lock_player_for_forbidden_gate(body)

	dialog_manager.show_dialog_sequence(_build_forbidden_zone_lines(), self)
	await dialog_manager.dialog_sequence_finished

	_lock_player_for_forbidden_gate(body)
	await _fade_forbidden_overlay_to(1.0)
	if gushi_forbidden_return_marker:
		body.global_position = gushi_forbidden_return_marker.global_position
		moved_to_return_marker = true
		_clear_player_motion(body)
		await get_tree().process_frame
	else:
		push_warning("[飲月山莊] 找不到 GushiForbiddenReturnMarker，略過退回傳送但仍會釋放事件鎖。")

	await _fade_forbidden_overlay_to(0.0)
	if moved_to_return_marker:
		await _refresh_forbidden_reentry_state(body)
	_finish_forbidden_zone_block_flow(body)


func _build_forbidden_zone_lines() -> Array:
	var warning_name := "劉少俠" if GlobalState.get_flag(F_MET_GUSHI) else "這位少俠"
	return [
		_l("%s！切莫再向前一步！" % warning_name, GUSHI_SPEAKER_ID, GUSHI_PORTRAIT_PATH),
		_l("否則，休怪顧某掌中棍不留情！", GUSHI_SPEAKER_ID, GUSHI_PORTRAIT_PATH),
		_l("抱歉，是在下失禮了。", LIUYU_SPEAKER_ID, LIUYU_PORTRAIT_PATH),
		_l("方才被他身後的山莊景色分了神，竟不知不覺逾了矩。", LIUYU_SPEAKER_ID, LIUYU_PORTRAIT_PATH),
	]


func _l(text: String, speaker: int, portrait: String) -> Dictionary:
	return {
		"text": "「%s」" % text,
		"speaker": speaker,
		"portrait": portrait,
	}


func _lock_player_for_forbidden_gate(body: Node2D) -> void:
	if body == null:
		push_warning("[飲月山莊] 找不到 LiuYu，無法完整鎖定 Forbidden Zone 阻擋流程。")
		return
	body.set("can_move", false)
	_clear_player_motion(body)


func _clear_player_motion(body: Node2D) -> void:
	if body == null:
		return
	if body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO
	body.set("direction", Vector2.ZERO)
	body.set("override_idle_animation", false)


func _fade_forbidden_overlay_to(target_alpha: float) -> void:
	if overlay == null:
		push_warning("[飲月山莊] 找不到 BlackOverlay，Forbidden Zone 退回流程將略過黑幕淡入淡出。")
		return
	overlay.visible = true
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", target_alpha, 0.45)
	await tween.finished
	if is_equal_approx(target_alpha, 0.0):
		overlay.visible = false


func _refresh_forbidden_reentry_state(body: Node2D) -> void:
	var area := get_node_or_null("forbidden_zone") as Area2D
	if area == null or body == null:
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not area.get_overlapping_bodies().has(body):
		_forbidden_requires_exit = false
		return
	push_warning("[飲月山莊] 玩家退回後仍被判定在 Forbidden Zone 內，將維持需離開後重觸發保護。")


func _finish_forbidden_zone_block_flow(body: Node2D) -> void:
	if body:
		_clear_player_motion(body)
		if body.has_method("_restore_idle_animation"):
			body._restore_idle_animation()
		body.set("can_move", true)
	GlobalState.set_meta("menu_locked", _forbidden_menu_was_locked)
	_forbidden_gate_busy = false


func reset_dialog_state() -> void:
	# DialogManager 會在 emit dialog_sequence_finished 前呼叫 reset；
	# Forbidden Zone 的黑幕退回流程必須在 _play_forbidden_zone_block_flow() 統一解鎖。
	pass
