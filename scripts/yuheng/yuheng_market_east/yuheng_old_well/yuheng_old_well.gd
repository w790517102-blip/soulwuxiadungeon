extends Node2D

@export var yuheng_market_east: String = "res://scenes/yuheng/yuheng_market_east/yuheng_market_east.tscn"
@export var yuheng_sewer_true: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_true/yuheng_sewer_true.tscn"
@onready var overlay := $BlackOverlay
@onready var sewer_transition: Area2D = get_node_or_null("To_yuheng_sewer_center") as Area2D
@onready var sewer_transition_collision: CollisionShape2D = get_node_or_null("To_yuheng_sewer_center/CollisionShape2D") as CollisionShape2D
@onready var well_barrier_collision: CollisionShape2D = get_node_or_null("well_locked/WellBarrier/CollisionShape2D") as CollisionShape2D
@onready var well_keyhole: Area2D = get_node_or_null("well_locked/well_keyhole") as Area2D
@export var music_tag := "yuheng"
@export var map_display_name: String = "醉月茶坊後巷廢井"

const LIUYU_PORTRAIT_PATH := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const LIUYU_SPEAKER_ID := 2

var _player_at_keyhole := false
var _keyhole_busy := false
var _keyhole_menu_was_locked := false


func _ready():
	_apply_sewer_route_state()
	if well_keyhole:
		well_keyhole.body_entered.connect(_on_well_keyhole_body_entered)
		well_keyhole.body_exited.connect(_on_well_keyhole_body_exited)
	set_process_unhandled_input(true)

	overlay.modulate.a = 1.5
	var tween_in = overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished
	
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

func _on_to_yuheng_market_east_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_old_well"
		get_node("/root/GameRoot").change_map_to(yuheng_market_east)


func _on_to_yuheng_sewer_center_body_entered(body: Node2D) -> void:
	if not _is_sewer_route_unlocked():
		return
	if MapTransitionGuard.can_transition(body, sewer_transition):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_old_well"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_true)


func _is_sewer_route_unlocked() -> bool:
	# TODO: 正式接紅徽音特殊委託後，集中在此判定：
	# - 當前主線為 main_001。
	# - 已進入舊水道調查 stage。
	# - 紅徽音特殊委託演出完成。
	# - 舊水道調查主線正式開始。
	# 本輪不建立候選 flag，主線初期一律保持封鎖。
	return false


func _apply_sewer_route_state() -> void:
	var unlocked := _is_sewer_route_unlocked()
	if sewer_transition:
		sewer_transition.monitoring = unlocked
		sewer_transition.monitorable = unlocked
	if sewer_transition_collision:
		sewer_transition_collision.set_deferred("disabled", not unlocked)
	if well_barrier_collision:
		well_barrier_collision.set_deferred("disabled", unlocked)


func _on_well_keyhole_body_entered(body: Node2D) -> void:
	if body and body.name == "LiuYu":
		_player_at_keyhole = true


func _on_well_keyhole_body_exited(body: Node2D) -> void:
	if body and body.name == "LiuYu":
		_player_at_keyhole = false


func _unhandled_input(event: InputEvent) -> void:
	if _keyhole_busy or not _player_at_keyhole or _is_sewer_route_unlocked():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		await _play_initial_keyhole_investigation()
		get_viewport().set_input_as_handled()


func _play_initial_keyhole_investigation() -> void:
	var player := get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if player == null or dialog_manager == null or bool(dialog_manager.get("dialog_active")):
		return

	_keyhole_busy = true
	_keyhole_menu_was_locked = bool(GlobalState.get_meta("menu_locked", false))
	var system_menu := get_node_or_null("/root/SystemMenu")
	if system_menu and system_menu.has_method("close_menu_if_open"):
		system_menu.close_menu_if_open()
	GlobalState.set_meta("menu_locked", true)
	player.set("can_move", false)

	dialog_manager.show_dialog_sequence(_build_initial_keyhole_lines(), self)
	await dialog_manager.dialog_sequence_finished

	player.set("can_move", true)
	GlobalState.set_meta("menu_locked", _keyhole_menu_was_locked)
	_keyhole_busy = false


func _build_initial_keyhole_lines() -> Array:
	return [
		_l("劉語塵端詳井旁怪異的銅製孔洞，心想："),
		_l("「這個孔洞的用途是什麼呢？看起來不像是掛水桶用的……」"),
		_l("「算了，眼下先去打聽左飲的情報要緊……」"),
	]


func _l(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": LIUYU_SPEAKER_ID,
		"portrait": LIUYU_PORTRAIT_PATH,
	}


func reset_dialog_state() -> void:
	# DialogManager 在序列 signal 之前重設 provider；這裡保持鎖定，
	# 由呼叫端在對話收束後統一恢復玩家與選單狀態。
	pass
