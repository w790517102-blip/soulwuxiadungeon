extends Node2D

@export var yuheng_market_east: String = "res://scenes/yuheng/yuheng_market_east/yuheng_market_east.tscn"
@export var yuheng_sewer_true: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_true/yuheng_sewer_true.tscn"
@onready var overlay := $BlackOverlay
@onready var sewer_transition: Area2D = get_node_or_null("To_yuheng_sewer_center") as Area2D
@onready var sewer_transition_collision: CollisionShape2D = get_node_or_null("To_yuheng_sewer_center/CollisionShape2D") as CollisionShape2D
@onready var well_barrier_collision: CollisionShape2D = get_node_or_null("well_locked/WellBarrier/CollisionShape2D") as CollisionShape2D
@onready var well_keyhole: Area2D = get_node_or_null("well_locked/well_keyhole") as Area2D
@onready var well_locked_sprite: Sprite2D = get_node_or_null("well_locked/well_locked") as Sprite2D
@export var music_tag := "yuheng_old_well"
@export var map_display_name: String = "醉月茶坊後巷廢井"

const F_OLD_WELL_UNLOCKED := "event_yuheng_old_well_unlocked"
const F_DABAO_MAP_SHOWN := "yh_side_dabao_map_shown"
const F_DABAO_COIN_HINT := "yh_side_dabao_01_coin_hint"
const F_DABAO_COIN_TAKEN := "yh_side_dabao_01_coin_taken"
const F_FISH_BOSS_WON := "battle_stalactite_fish_boss_won"
const DABAO_QUEST_ID := "yh_side_dabao_01"
const MAIN_QUEST_ID := "main_001"
const LIUYU_PORTRAIT_PATH := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const LIUYU_SPEAKER_ID := 2
const NARRATION_SPEAKER_ID := 0

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
	return GlobalState.get_flag(F_OLD_WELL_UNLOCKED)


func _apply_sewer_route_state() -> void:
	var unlocked := _is_sewer_route_unlocked()
	if well_locked_sprite:
		well_locked_sprite.visible = not unlocked
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
	if _keyhole_busy or not _player_at_keyhole:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		await _run_keyhole_interaction()
		get_viewport().set_input_as_handled()


func _run_keyhole_interaction() -> void:
	if _is_sewer_route_unlocked():
		if _can_claim_dabao_treasure():
			await _play_keyhole_sequence(_build_dabao_treasure_lines(), true)
		else:
			await _play_keyhole_sequence(_build_unlocked_keyhole_lines())
		return

	if _can_claim_dabao_treasure():
		await _play_keyhole_sequence(_build_dabao_treasure_lines(), true)
		return

	if _is_early_main_quest_state():
		await _play_keyhole_sequence(_build_early_keyhole_lines())
	else:
		await _play_keyhole_sequence(_build_missing_keyhole_item_lines())


func _play_keyhole_sequence(lines: Array, claim_treasure_after_close: bool = false) -> void:
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

	dialog_manager.show_dialog_sequence(lines, self)
	await dialog_manager.dialog_sequence_finished

	if claim_treasure_after_close:
		_claim_dabao_treasure()

	player.set("can_move", true)
	GlobalState.set_meta("menu_locked", _keyhole_menu_was_locked)
	_keyhole_busy = false


func _has_dabao_treasure_clue() -> bool:
	return (
		GlobalState.get_flag(F_DABAO_MAP_SHOWN)
		or GlobalState.get_flag(F_DABAO_COIN_HINT)
	)


func _can_claim_dabao_treasure() -> bool:
	return (
		_has_dabao_treasure_clue()
		and not GlobalState.get_flag(F_DABAO_COIN_TAKEN)
		and not GlobalState.get_flag(F_FISH_BOSS_WON)
	)


func _claim_dabao_treasure() -> bool:
	if not _can_claim_dabao_treasure():
		return false
	InventorySync.add_gold(50, true)
	GlobalState.set_flag(F_DABAO_COIN_TAKEN, true)
	if not SideQuestManager.is_quest_finished(DABAO_QUEST_ID):
		SideQuestManager.complete_quest(DABAO_QUEST_ID)
	return true


func _is_early_main_quest_state() -> bool:
	var state := _get_main_quest_state()
	return (
		str(state.get("id", "")) == MAIN_QUEST_ID
		and int(state.get("stage", 0)) < QuestManager.STAGE_YH_GO_TO_MANOR
	)


func _get_main_quest_state() -> Dictionary:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager == null:
		quest_manager = get_node_or_null("/root/GameRoot/QuestManager")
	if quest_manager and quest_manager.has_method("get_main_quest_state"):
		return quest_manager.get_main_quest_state()
	return {}


func _build_early_keyhole_lines() -> Array:
	return [
		_l("(井身上嵌著一個形狀奇特的金屬扣孔。)"),
		_l("這東西不像是用來繫水桶的……"),
		_l("算了,沒時間研究了…眼下還是先打聽左飲的消息要緊。"),
	]


func _build_missing_keyhole_item_lines() -> Array:
	return [
		_l("(井身上嵌著一個形狀奇特的金屬扣孔。)"),
		_l("此處似乎另藏機關，只是眼下還缺了能與之契合的東西。"),
	]


func _build_dabao_treasure_lines() -> Array:
	return [
		_n("井旁的土石有些鬆動，正是大寶以細線指出的位置。"),
		_l("……亮光就在這下面。"),
		_n("劉語塵移開石塊，從泥土中取出一小串銅錢。"),
	]


func _build_unlocked_keyhole_lines() -> Array:
	return [
		_n("劉語塵看著嵌在井身上的半弦銅釦。銅釦與扣孔嚴絲合縫。"),
		_l("沒想到這口看似尋常的廢井，竟藏著如此精巧的機關。"),
	]


func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": NARRATION_SPEAKER_ID,
		"portrait": "",
	}


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
