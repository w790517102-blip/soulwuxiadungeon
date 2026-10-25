extends Node2D

@export var yuheng_market_east_night: String = "res://scenes/yuheng/yuheng_market_east/yuheng_market_east_night.tscn"
@onready var yuheng_sewer_center: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_center.tscn"
@onready var overlay := $BlackOverlay
@onready var sewer_transition: Area2D = get_node_or_null("To_yuheng_sewer_center") as Area2D
@onready var sewer_transition_collision: CollisionShape2D = get_node_or_null("To_yuheng_sewer_center/CollisionShape2D") as CollisionShape2D
@onready var well_barrier_collision: CollisionPolygon2D = get_node_or_null("well_locked/WellBarrier/CollisionPolygon2D") as CollisionPolygon2D
@onready var well_locked_sprite: Sprite2D = get_node_or_null("well_locked/old_well_locked") as Sprite2D
@export var music_tag := "yuheng_old_well"
@export var map_display_name: String = "醉月茶坊後巷廢井"
## 開井動畫的音效，之後在 Inspector 補上：震動（持續整個震動期間）、石塊崩落（封蓋圖消失的瞬間）。
@export var well_shake_sfx: AudioStream
@export var well_collapse_sfx: AudioStream

const F_OLD_WELL_UNLOCKED := "event_yuheng_old_well_unlocked"
const F_GOT_HALF_STRING_BUTTON := "main_yh_got_half_string_copper_button"
const F_DABAO_MAP_SHOWN := "yh_side_dabao_map_shown"
const F_DABAO_COIN_HINT := "yh_side_dabao_01_coin_hint"
const F_DABAO_COIN_TAKEN := "yh_side_dabao_01_coin_taken"
const F_FISH_BOSS_WON := "battle_stalactite_fish_boss_won"
const ITEM_HALF_STRING_BUTTON := "item_half_string_copper_button"
const DABAO_QUEST_ID := "yh_side_dabao_01"
const MAIN_QUEST_ID := "main_001"
const OPEN_WELL_OBJECTIVE := "進入已開啟的廢井，調查玉衡鎮舊水道。"
const LIUYU_PORTRAIT_PATH := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const LIUYU_SPEAKER_ID := 2
const NARRATION_SPEAKER_ID := 0

enum KeyholeAction {
	NONE,
	CLAIM_TREASURE,
	UNLOCK_WELL,
	CLAIM_TREASURE_AND_UNLOCK,
}

## 滑鼠／走近互動（InteractionZones 底下）：出口與下井走原本的 body_entered 流程，扣孔走 _run_keyhole_interaction。
const ZONE_EXIT_METHODS := {
	"exit_market_east": "_on_to_yuheng_market_east_night_body_entered",
	"sewer_entrance": "_on_to_yuheng_sewer_center_body_entered",
}
const WELL_OPEN_SHAKE_SECONDS := 1.2
const WELL_OPEN_SHAKE_PIXELS := 2.5
## 封蓋圖底部（石階前）揚塵的位置與範圍，場景區域座標。
const WELL_DUST_CENTER := Vector2(112, 124)
const WELL_DUST_EXTENTS := Vector2(48, 8)

var _keyhole_busy := false
var _keyhole_menu_was_locked := false
var _sewer_transition_busy := false
var _leaving := false
var _well_opening := false


func _ready():
	_apply_sewer_route_state()
	_bind_interaction_zones()

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
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_old_well_night"
		get_node("/root/GameRoot").change_map_to(yuheng_market_east_night)


func _on_to_yuheng_sewer_center_body_entered(body: Node2D) -> void:
	if _sewer_transition_busy or _leaving or _well_opening:
		return
	if not _is_sewer_route_unlocked():
		return
	if MapTransitionGuard.can_transition(body, sewer_transition):
		_sewer_transition_busy = true
		_leaving = true
		_advance_main_quest_to_sewer_mechanisms()
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_old_well_night"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_center)


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


func _bind_interaction_zones() -> void:
	var zones := get_node_or_null("InteractionZones")
	if zones == null:
		return
	for child in zones.get_children():
		var target := child as InteractionTarget
		if target == null:
			continue
		var zone_name := String(target.name)
		if ZONE_EXIT_METHODS.has(zone_name):
			var method: String = ZONE_EXIT_METHODS[zone_name]
			target.availability = func() -> bool:
				if _leaving or _well_opening:
					return false
				return zone_name != "sewer_entrance" or _is_sewer_route_unlocked()
			target.handler = func(player: Node2D) -> void:
				await call(method, player)
		elif zone_name == "well_keyhole":
			target.availability = func() -> bool: return not _keyhole_busy and not _leaving
			target.handler = func(_player: Node2D) -> void:
				await _run_keyhole_interaction()


## 與其他場景的出口一致：交給 GameRoot 的出口防呆（剛換場景的冷卻時間、讀檔中、鎖定中都不能換）。
func _exit_allowed(body: Node) -> bool:
	if _leaving:
		return false
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root == null or not game_root.has_method("can_use_map_transition"):
		return true
	return bool(game_root.call("can_use_map_transition", body, null))


func _run_keyhole_interaction() -> void:
	if _keyhole_busy:
		return
	if _is_sewer_route_unlocked():
		if _can_claim_dabao_treasure():
			await _play_keyhole_sequence(
				_build_dabao_treasure_lines(),
				KeyholeAction.CLAIM_TREASURE
			)
		else:
			await _play_keyhole_sequence(_build_unlocked_keyhole_lines())
		return

	var treasure_available := _can_claim_dabao_treasure()
	var can_unlock := _can_unlock_well()
	if treasure_available and can_unlock:
		await _play_keyhole_sequence(
			_build_treasure_and_unlock_lines(),
			KeyholeAction.CLAIM_TREASURE_AND_UNLOCK
		)
	elif treasure_available:
		await _play_keyhole_sequence(
			_build_dabao_treasure_lines(),
			KeyholeAction.CLAIM_TREASURE
		)
	elif can_unlock:
		await _play_keyhole_sequence(
			_build_unlock_well_lines(),
			KeyholeAction.UNLOCK_WELL
		)
	else:
		await _play_keyhole_sequence(_build_missing_keyhole_item_lines())


func _play_keyhole_sequence(lines: Array, action_after_close: int = KeyholeAction.NONE) -> void:
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

	match action_after_close:
		KeyholeAction.CLAIM_TREASURE:
			_claim_dabao_treasure()
		KeyholeAction.UNLOCK_WELL:
			await _unlock_well_with_button()
		KeyholeAction.CLAIM_TREASURE_AND_UNLOCK:
			_claim_dabao_treasure()
			await _unlock_well_with_button()

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


func _can_unlock_well() -> bool:
	return (
		not _is_sewer_route_unlocked()
		and GlobalState.get_flag(F_GOT_HALF_STRING_BUTTON)
		and InventorySync.has_item(ITEM_HALF_STRING_BUTTON, 1)
		and _is_main_quest_stage(QuestManager.STAGE_YH_SEWER_STARTED)
	)


func _unlock_well_with_button() -> bool:
	if not _can_unlock_well():
		return false
	var count_before := InventorySync.get_item_count(ITEM_HALF_STRING_BUTTON)
	InventorySync.consume_item(ITEM_HALF_STRING_BUTTON, 1, true)
	var count_after := InventorySync.get_item_count(ITEM_HALF_STRING_BUTTON)
	if count_after != count_before - 1:
		push_warning("[OldWellNight] 半弦銅釦移除失敗，未開啟廢井。")
		return false

	GlobalState.set_flag(F_OLD_WELL_UNLOCKED, true)
	_set_open_well_objective()
	await _play_well_open_animation()
	_apply_sewer_route_state()
	return true


## 開井：封蓋圖震動 WELL_OPEN_SHAKE_SECONDS 秒、地面揚塵，時間到封蓋圖消失（露出打開的井、通路與下井入口同時生效），再補一波崩落的塵土。
func _play_well_open_animation() -> void:
	_well_opening = true
	var dust := _make_dust_emitter(40, false, 14.0, 34.0)
	add_child(dust)
	dust.position = WELL_DUST_CENTER
	dust.emitting = true
	_play_well_sfx(well_shake_sfx)

	if well_locked_sprite:
		var rest := well_locked_sprite.position
		var shake := create_tween()
		shake.tween_method(func(t: float) -> void:
			var amp := WELL_OPEN_SHAKE_PIXELS * (0.35 + 0.65 * t)
			well_locked_sprite.position = rest + Vector2(randf_range(-amp, amp), randf_range(-amp, amp) * 0.5),
			0.0, 1.0, WELL_OPEN_SHAKE_SECONDS)
		await shake.finished
		well_locked_sprite.position = rest
	else:
		await get_tree().create_timer(WELL_OPEN_SHAKE_SECONDS).timeout

	_play_well_sfx(well_collapse_sfx)
	_apply_sewer_route_state()
	var burst := _make_dust_emitter(36, true, 30.0, 70.0)
	add_child(burst)
	burst.position = WELL_DUST_CENTER
	burst.emitting = true
	dust.emitting = false
	await get_tree().create_timer(1.4).timeout
	dust.queue_free()
	burst.queue_free()
	_well_opening = false


func _make_dust_emitter(amount: int, one_shot: bool, speed_min: float, speed_max: float) -> CPUParticles2D:
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var puff := GradientTexture2D.new()
	puff.gradient = fade
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 48
	puff.height = 48

	var tint := Gradient.new()
	tint.set_color(0, Color(0.66, 0.6, 0.5, 0.42))
	tint.set_color(1, Color(0.66, 0.6, 0.5, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.6))

	var emitter := CPUParticles2D.new()
	emitter.z_index = 1
	emitter.texture = puff
	emitter.amount = amount
	emitter.one_shot = one_shot
	emitter.explosiveness = 0.9 if one_shot else 0.0
	emitter.lifetime = 1.2
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_rect_extents = WELL_DUST_EXTENTS
	emitter.direction = Vector2(0, -1)
	emitter.spread = 40.0
	emitter.gravity = Vector2.ZERO
	emitter.initial_velocity_min = speed_min
	emitter.initial_velocity_max = speed_max
	emitter.damping_min = 20.0
	emitter.damping_max = 40.0
	emitter.scale_amount_min = 0.5
	emitter.scale_amount_max = 1.0
	emitter.scale_amount_curve = grow
	emitter.color_ramp = tint
	emitter.emitting = false
	return emitter


func _play_well_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _is_main_quest_stage(stage_value: int) -> bool:
	var state := _get_main_quest_state()
	return (
		str(state.get("id", "")) == MAIN_QUEST_ID
		and int(state.get("stage", 0)) == stage_value
	)


func _get_main_quest_state() -> Dictionary:
	var quest_manager := _get_quest_manager()
	if quest_manager and quest_manager.has_method("get_main_quest_state"):
		return quest_manager.get_main_quest_state()
	return {}


func _get_quest_manager() -> Node:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager == null:
		quest_manager = get_node_or_null("/root/GameRoot/QuestManager")
	return quest_manager


func _set_open_well_objective() -> void:
	if not _is_main_quest_stage(QuestManager.STAGE_YH_SEWER_STARTED):
		return
	var quest_manager := _get_quest_manager()
	if quest_manager and quest_manager.has_method("set_main_objective"):
		quest_manager.set_main_objective(OPEN_WELL_OBJECTIVE)


func _advance_main_quest_to_sewer_mechanisms() -> void:
	if not _is_main_quest_stage(QuestManager.STAGE_YH_SEWER_STARTED):
		return
	var quest_manager := _get_quest_manager()
	if quest_manager and quest_manager.has_method("advance_main_quest"):
		quest_manager.advance_main_quest(QuestManager.STAGE_YH_SEWER_MECHANISMS)


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


func _build_unlock_well_lines() -> Array:
	return [
		_n("劉語塵取出半弦銅釦，將它嵌入井沿的扣孔。"),
		_n("銅釦與扣孔嚴絲合縫。下一瞬，井身傳來一陣細微震動。"),
		_n("封住入口的磚石依次下沉，露出一段通往地下的石階。"),
		_l("……果然是它。"),
	]


func _build_treasure_and_unlock_lines() -> Array:
	var lines := _build_dabao_treasure_lines()
	lines.append(_n("收好銅錢後，劉語塵重新看向井沿那道奇異扣孔。"))
	lines.append_array(_build_unlock_well_lines())
	return lines


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


func _on_to_yuheng_market_east_night_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu" and _exit_allowed(body):
		_leaving = true
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_old_well_night"
		get_node("/root/GameRoot").change_map_to(yuheng_market_east_night)
