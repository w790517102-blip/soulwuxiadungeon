extends Node2D

@export var Bamboo_Grove_Suburb: String = "res://scenes/yuheng/Bamboo_Grove_Suburb/Bamboo_Grove_Suburb.tscn"
@export var Bai_Jian_Jue: String = "res://scenes/yuheng/yuheng_market_west/Bai_Jian_Jue/bai_jian_jue.tscn"
@export var yuheng_pharmacy: String = "res://scenes/yuheng/yuheng_market_west/yuheng_pharmacy/yuheng_pharmacy.tscn"
@export var yuheng_market_east: String = "res://scenes/yuheng/yuheng_market_east/yuheng_market_east.tscn"
@export var yuheng_weapon_shop: String = "res://scenes/yuheng/yuheng_market_west/yuheng_weapon_shop/yuheng_weapon_shop.tscn"
@onready var overlay: ColorRect = get_node_or_null("BlackOverlay") as ColorRect
@onready var manor_route_return_marker: Marker2D = get_node_or_null("SpawnPoints/ManorRouteReturnMarker") as Marker2D
@export var music_tag := "yuheng"
@export var map_display_name: String = "玉衡鎮市集西邊"

const MAIN_QUEST_ID := "main_001"
const MET_SU_MIEN_FLAG := "met_Su_Mien"
const LIUYU_PORTRAIT_PATH := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const LIUYU_SPEAKER_ID := 2

var _manor_route_gate_busy := false
var _manor_route_requires_exit := false
var _manor_route_menu_was_locked := false


func _ready():
	if overlay:
		overlay.visible = true
		overlay.modulate.a = 1.5
		var tween_in = overlay.create_tween()
		tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
		await tween_in.finished
	else:
		push_warning("[玉衡西市集] 找不到 BlackOverlay，進出場淡入效果將略過。")
	
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
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(yuheng_market_east)


func _on_to_yuheng_weapon_shop_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(yuheng_weapon_shop)


func _on_pharmacy_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(yuheng_pharmacy)


func _on_to_bai_jian_jue_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(Bai_Jian_Jue)


func _on_to_bamboo_grove_suburb_body_entered(body: Node2D) -> void:
	var area := get_node_or_null("to_Bamboo_Grove_Suburb") as Area2D
	if not MapTransitionGuard.can_transition(body, area):
		return
	if _can_enter_bamboo_grove_suburb():
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(Bamboo_Grove_Suburb)
		return

	if _manor_route_gate_busy or _manor_route_requires_exit:
		return
	await _play_manor_route_block_dialog(body)


func _on_to_bamboo_grove_suburb_body_exited(body: Node2D) -> void:
	if body and body.name == "LiuYu" and not _manor_route_gate_busy:
		_manor_route_requires_exit = false


func _can_enter_bamboo_grove_suburb() -> bool:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager == null or not quest_manager.has_method("get_main_quest_state"):
		return false

	var main_quest: Dictionary = quest_manager.get_main_quest_state()
	if String(main_quest.get("id", "")) != MAIN_QUEST_ID:
		# 後續章節返回玉衡鎮時，不以 main_002 的 stage 1 誤判為初期主線。
		return true

	var required_stage := QuestManager.STAGE_YH_GO_TO_MANOR
	return int(main_quest.get("stage", 1)) >= required_stage and GlobalState.get_flag(MET_SU_MIEN_FLAG)


func _play_manor_route_block_dialog(body: Node2D) -> void:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager == null or bool(dialog_manager.get("dialog_active")):
		return

	_manor_route_gate_busy = true
	_manor_route_requires_exit = true
	_manor_route_menu_was_locked = bool(GlobalState.get_meta("menu_locked", false))
	var moved_to_return_marker := false
	var system_menu := get_node_or_null("/root/SystemMenu")
	if system_menu and system_menu.has_method("close_menu_if_open"):
		system_menu.close_menu_if_open()
	GlobalState.set_meta("menu_locked", true)
	_lock_player_for_manor_route(body)

	dialog_manager.show_dialog_sequence(_build_manor_route_block_lines(), self)
	await dialog_manager.dialog_sequence_finished

	# Dialog finished != interaction flow finished.  DialogManager 可能已嘗試還原控制，
	# 因此在黑幕退回流程開始前再次持有鎖，直到淡出結束才統一釋放。
	_lock_player_for_manor_route(body)
	await _fade_manor_route_overlay_to(1.0)

	if manor_route_return_marker:
		body.global_position = manor_route_return_marker.global_position
		moved_to_return_marker = true
		_clear_player_motion(body)
		await get_tree().process_frame
	else:
		push_warning("[玉衡西市集] 找不到 ManorRouteReturnMarker，略過退回傳送但仍會釋放事件鎖。")

	await _fade_manor_route_overlay_to(0.0)
	if moved_to_return_marker:
		await _refresh_manor_route_reentry_state(body)
	_finish_manor_route_block_flow(body)

func _lock_player_for_manor_route(body: Node2D) -> void:
	if body == null:
		push_warning("[玉衡西市集] 找不到 LiuYu，無法完整鎖定竹林入口阻擋流程。")
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


func _fade_manor_route_overlay_to(target_alpha: float) -> void:
	if overlay == null:
		push_warning("[玉衡西市集] 找不到 BlackOverlay，竹林入口退回流程將略過黑幕淡入淡出。")
		return
	overlay.visible = true
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", target_alpha, 0.45)
	await tween.finished
	if is_equal_approx(target_alpha, 0.0):
		overlay.visible = false


func _refresh_manor_route_reentry_state(body: Node2D) -> void:
	var area := get_node_or_null("to_Bamboo_Grove_Suburb") as Area2D
	if area == null or body == null:
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not area.get_overlapping_bodies().has(body):
		_manor_route_requires_exit = false
		return
	push_warning("[玉衡西市集] 玩家退回後仍被判定在竹林入口 Area2D 內，將維持需離開後重觸發保護。")


func _finish_manor_route_block_flow(body: Node2D) -> void:
	if body:
		_clear_player_motion(body)
		if body.has_method("_restore_idle_animation"):
			body._restore_idle_animation()
		body.set("can_move", true)
	GlobalState.set_meta("menu_locked", _manor_route_menu_was_locked)
	_manor_route_gate_busy = false


func _build_manor_route_block_lines() -> Array:
	return [
		_l("劉語塵心想：前方似乎是往飲月山莊的方向……"),
		_l("「就這樣直接登門，恐怕連左飲的面都見不到。」"),
		_l("「還是先在鎮上多打聽一些消息。」"),
	]


func _l(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": LIUYU_SPEAKER_ID,
		"portrait": LIUYU_PORTRAIT_PATH,
	}


func reset_dialog_state() -> void:
	# DialogManager 在 emit dialog_sequence_finished 前會呼叫這裡；
	# 實際解鎖與回退位置必須等 _play_manor_route_block_dialog() 收束。
	pass
