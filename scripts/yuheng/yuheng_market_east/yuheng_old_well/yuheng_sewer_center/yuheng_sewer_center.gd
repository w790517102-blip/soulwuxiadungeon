extends Node2D

signal dialog_closed

const EnemyDB = preload("res://scripts/db/EnemyDB.gd")
const CENTER_SCENE_PATH := "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_center.tscn"
const BATTLE_SCENE_PATH := "res://scenes/battle_scene.tscn"

@onready var yuheng_old_well_night: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_old_well_night.tscn"
@onready var yuheng_sewer_secret_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_secret_room/yuheng_sewer_secret_room.tscn"
@onready var yuheng_sewer_music_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_music_room/yuheng_sewer_music_room.tscn"
@onready var yuheng_sewer_talisman_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_talisman_room/yuheng_sewer_talisman_room.tscn"
@onready var yuheng_sewer_alchemy_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_alchemy_room/yuheng_sewer_alchemy_room.tscn"
@onready var yuheng_sewer_final_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_final_room/yuheng_sewer_final_room.tscn"
@onready var overlay := $BlackOverlay
@onready var first_battle_area: Area2D = get_node_or_null("yuheng_sewer_center_battle_event/Area2D")
@onready var first_battle_collision: CollisionShape2D = get_node_or_null("yuheng_sewer_center_battle_event/Area2D/CollisionShape2D")
@onready var bitterness_follow: PathFollow2D = get_node_or_null("enemies/bitterness_tone_phantom/PathFollow2D")
@onready var bitterness_actor: Node2D = get_node_or_null("enemies/bitterness_tone_phantom/PathFollow2D/bitterness_tone_phantom")
@onready var turbid_follow: PathFollow2D = get_node_or_null("enemies/turbid_tone_phantom/PathFollow2D")
@onready var turbid_actor: Node2D = get_node_or_null("enemies/turbid_tone_phantom/PathFollow2D/turbid_tone_phantom")
@export var music_tag := "yuheng_sewer"
@export var map_display_name: String = "玉衡鎮下水道中央"

const F_FIRST_YUMEI_BATTLE_DONE := "event_yuheng_sewer_center_first_yumei_battle_done"
const META_FIRST_YUMEI_BATTLE_PENDING := "pending_yuheng_sewer_center_first_yumei_battle"
const FIRST_YUMEI_BATTLE_KEY := "yuheng_sewer_center_first_yumei_battle"
const FIRST_YUMEI_ENEMY_IDS := [
	"bitterness_tone_phantom",
	"turbid_tone_phantom",
]
const LIUYU_PORTRAIT_PATH := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const EMPTY_PORTRAIT_PATH := "res://assets/sprites/empty.png"
const NARRATION_SPEAKER_ID := 0
const YUMEI_SPEAKER_ID := 1
const LIUYU_SPEAKER_ID := 2
const LIUYU_FIGHT_ANIMATION := &"ready_fight_right_down"
const LIUYU_LOOK_DIRECTION_SECONDS := 0.22
const YUMEI_PATH_SPEED_MULTIPLIER := 2.5
const BITTERNESS_PATH_DURATION := 2.15 / YUMEI_PATH_SPEED_MULTIPLIER
const TURBID_PATH_DURATION := 2.45 / YUMEI_PATH_SPEED_MULTIPLIER

const SEWER_ZONE_ID := "yuheng_sewer"
const SEWER_CENTER_ENCOUNTER_CONFIG := {
	"encounter_region_id": "yuheng_sewer",
	"encounter_profile_id": "yuheng_sewer_pressure_v1",
	"distance_threshold": 240.0,
	"chance": 0.30,
	"cooldown_distance": 280.0,
	"intro_key": "yuheng_sewer_center_random"
}
const SEWER_CENTER_ENCOUNTER_TABLE := [
	{"w": 22, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 12, "enemies": ["yumei_sewer_bat", "yumei_sewer_bat"]},
	{"w": 15, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 14, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 10, "enemies": ["yumei_sewer_rat", "yumei_sewer_bat", "yumei_sewer_bat"]},
	{"w": 17, "enemies": ["turbid_tone_phantom", "yumei_sewer_rat"]},
	{"w": 10, "enemies": ["turbid_tone_phantom", "yumei_sewer_bat"]}
]

var event_in_progress := false
var _entry_transition_active := true
var _event_body_waiting: Node2D = null
var _waiting_for_dialog := false
var _bitterness_idle_wobble: Tween = null
var _turbid_idle_wobble: Tween = null
var _bitterness_idle_base: Dictionary = {}
var _turbid_idle_base: Dictionary = {}
var _first_battle_victory_return_pending := false


func _ready():
	var game_root := get_node_or_null("/root/GameRoot")
	var entry_spawn_point := str(game_root.spawn_point_name) if game_root else ""
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player:
		player.set("can_move", false)
		player.set("velocity", Vector2.ZERO)

	_resolve_first_battle_return()
	if _first_battle_victory_return_pending:
		prepare_battle_return_actor(player)
	elif player:
		_set_liuyu_idle_for_entry(player, entry_spawn_point)
	_apply_first_battle_scene_state()

	overlay.modulate.a = 1.5
	var tween_in = overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished

	_entry_transition_active = false
	if _first_battle_victory_return_pending:
		await _run_first_battle_victory_epilogue(player)
	elif player:
		player.set("velocity", Vector2.ZERO)
		player.set("direction", Vector2.ZERO)
		if player.has_method("restore_idle_control"):
			player.call("restore_idle_control")
		player.set("can_move", true)

	show_map_name()
	_try_start_waiting_first_battle()

func get_map_display_name() -> String:
	return map_display_name

func get_encounter_zone_config(zone_id: String) -> Dictionary:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_CENTER_ENCOUNTER_CONFIG.duplicate(true)
	return {}

func get_encounter_table(zone_id: String) -> Array:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_CENTER_ENCOUNTER_TABLE.duplicate(true)
	return []


func _on_yuheng_sewer_center_battle_event_body_entered(body: Node2D) -> void:
	if body.name != "LiuYu":
		return
	if _is_first_battle_completed() or event_in_progress:
		return
	_event_body_waiting = body
	if not _entry_transition_active:
		_try_start_waiting_first_battle()


func _try_start_waiting_first_battle() -> void:
	if _event_body_waiting == null or not is_instance_valid(_event_body_waiting):
		return
	if _is_first_battle_completed() or event_in_progress or _entry_transition_active:
		return
	if not _can_start_first_battle_event():
		_retry_waiting_first_battle()
		return
	var player := _event_body_waiting
	_event_body_waiting = null
	_run_first_yumei_event(player)


func _retry_waiting_first_battle() -> void:
	await get_tree().create_timer(0.1).timeout
	if _event_body_waiting == null or not is_instance_valid(_event_body_waiting):
		return
	if first_battle_area and not first_battle_area.get_overlapping_bodies().has(_event_body_waiting):
		_event_body_waiting = null
		return
	_try_start_waiting_first_battle()


func _can_start_first_battle_event() -> bool:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[下水道首戰] 找不到 DialogManager，暫不啟動事件。")
		return false
	if bool(dialog_manager.get("dialog_active")):
		return false
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root and game_root.has_method("is_map_transition_locked") \
			and bool(game_root.call("is_map_transition_locked")):
		return false
	return get_tree().root.find_child("BattleScene", true, false) == null


func _run_first_yumei_event(player: Node2D) -> void:
	event_in_progress = true
	_set_first_battle_trigger_enabled(false)
	_lock_player_for_event(player)

	await _show_dialog(_build_first_sensory_lines())
	await get_tree().create_timer(0.45).timeout
	await _show_dialog(_build_second_sensory_lines())
	await _show_dialog(_build_shumian_suspicion_lines())
	await _show_dialog(_build_liuyu_resolve_lines())
	await get_tree().create_timer(0.4).timeout

	# 第一聲來自尚未顯形的黑暗；兩隻語魅在劉語塵追問前都保持隱藏。
	_hide_story_actor(bitterness_actor)
	_hide_story_actor(turbid_actor)
	await _show_dialog([
		_yumei_line("書眠很痛苦……那就對了。"),
	])
	await _look_around_for_voice(player)
	await _show_dialog([
		_liuyu_line("！？是誰？"),
	])
	await _reveal_yumei_actors()
	await _show_dialog([
		_yumei_line("痛，才證明藥正在起效。"),
		_yumei_line("我不准你去中斷她的療程！"),
	])

	await _show_dialog([
		_yumei_line("你確定……書眠需要你？"),
	])
	await _show_dialog([
		_yumei_line("其實，你與紅徽音只是一廂情願地認為，她需要幫助。"),
		_yumei_line("說到底，你們只是不能接受——她根本不需要你們。"),
		_yumei_line("書眠在這裡很好。你們，才是她痛苦的根源。"),
	])

	_face_player_toward_enemies(player)
	await _show_dialog([
		_liuyu_line("……語魅！？"),
		_yumei_line("她正在接受治療。"),
		_yumei_line("而你，才是她始終無法痊癒的原因。"),
		_narration_line("兩隻語魅同時低笑。"),
		_yumei_line("在這裡……你才是擾亂書眠內心的惡靈。"),
	])

	_play_liuyu_ready_fight(player)
	var reached_battle_positions := await _move_yumei_to_battle_positions()
	if not reached_battle_positions:
		_abort_first_battle_event(player, "既有語魅 Path2D／PathFollow2D 結構不完整。")
		return

	var battle_started := await _start_first_yumei_battle(player)
	if not battle_started:
		_abort_first_battle_event(player, "固定語魅戰鬥無法建立。")


func _build_first_sensory_lines() -> Array:
	return [
		_liuyu_line("陰暗、濕悶。"),
		_liuyu_line("撲鼻而來的霉味滯留在鼻腔深處，怎麼也揮之不去。"),
		_liuyu_line("換作尋常人，恐怕早已被薰得神志不清。"),
	]


func _build_second_sensory_lines() -> Array:
	return [
		_liuyu_line("遠處傳來的……不是水滴聲。"),
		_liuyu_line("也不像是我的腳步在甬道裡形成的回音。"),
		_liuyu_line("更像有人躲在看不見的角落，一遍又一遍地低聲呢喃。"),
	]


func _build_shumian_suspicion_lines() -> Array:
	return [
		_liuyu_line("書眠為何會在關閉白箋居後，立刻來到這種地方？"),
		_liuyu_line("不……紅姑娘說過，她每晚都會來。"),
		_liuyu_line("也就是說，這裡早已成為她生活的一部分。"),
		_liuyu_line("是被語魅操控？"),
		_liuyu_line("還是受了什麼邪術蠱惑？"),
		_liuyu_line("更糟的是……她是否早已不是玉衡鎮眾人熟悉的那個書眠？"),
	]


func _build_liuyu_resolve_lines() -> Array:
	return [
		_liuyu_line("……不。"),
		_liuyu_line("在親眼見到她以前，這些都只是我的揣測。"),
		_liuyu_line("與其留在這裡胡思亂想，不如趕緊找到她本人。"),
	]


func _look_around_for_voice(player: Node2D) -> void:
	if player == null or not player.has_method("play_idle_direction"):
		return
	for direction_name in ["left", "up", "down", "right"]:
		player.call("play_idle_direction", direction_name)
		await get_tree().create_timer(LIUYU_LOOK_DIRECTION_SECONDS).timeout


func _play_liuyu_ready_fight(player: Node2D) -> void:
	if player == null:
		return
	player.set("can_move", false)
	player.set("velocity", Vector2.ZERO)
	player.set("direction", Vector2.ZERO)
	player.set("override_idle_animation", true)
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		push_warning("[下水道首戰] 找不到 LiuYu/AnimatedSprite2D，無法播放備戰動畫。")
		return
	if sprite.sprite_frames == null \
			or not sprite.sprite_frames.has_animation(LIUYU_FIGHT_ANIMATION):
		push_warning("[下水道首戰] LiuYu 缺少 ready_fight_right_down 動畫。")
		return
	sprite.play(LIUYU_FIGHT_ANIMATION)


func _reveal_yumei_actors() -> void:
	if bitterness_actor == null or turbid_actor == null:
		return
	_stop_yumei_idle_wobbles()
	var bitterness_base_position := bitterness_actor.position
	var bitterness_base_rotation := bitterness_actor.rotation
	var bitterness_base_scale := bitterness_actor.scale
	var turbid_base_position := turbid_actor.position
	var turbid_base_rotation := turbid_actor.rotation
	var turbid_base_scale := turbid_actor.scale

	bitterness_actor.visible = true
	bitterness_actor.modulate = Color(1.0, 1.0, 1.0, 0.0)
	bitterness_actor.scale = bitterness_base_scale * Vector2(0.82, 1.16)
	bitterness_actor.rotation = bitterness_base_rotation - 0.07

	turbid_actor.visible = true
	turbid_actor.modulate = Color(0.72, 0.78, 0.72, 0.0)
	turbid_actor.scale = turbid_base_scale * Vector2(0.72, 1.06)
	turbid_actor.position = turbid_base_position + Vector2(-5.0, 3.0)

	# 單一有限 master Tween 同步控制兩隻語魅；它不循環，finished 必定可等待。
	var reveal_master := create_tween()
	reveal_master.set_parallel(true)
	reveal_master.tween_property(bitterness_actor, "modulate:a", 1.0, 0.55)
	reveal_master.tween_property(
		bitterness_actor,
		"scale",
		bitterness_base_scale * Vector2(1.08, 0.94),
		0.32
	)
	reveal_master.tween_property(
		bitterness_actor,
		"rotation",
		bitterness_base_rotation + 0.08,
		0.32
	)
	reveal_master.tween_property(
		bitterness_actor,
		"position",
		bitterness_base_position + Vector2(7.0, -2.0),
		0.25
	)
	reveal_master.tween_property(turbid_actor, "modulate", Color(0.88, 0.91, 0.86, 1.0), 0.85)
	reveal_master.tween_property(
		turbid_actor,
		"scale",
		turbid_base_scale * Vector2(1.1, 0.98),
		0.62
	)
	reveal_master.tween_property(
		turbid_actor,
		"position",
		turbid_base_position + Vector2(4.0, 1.0),
		0.45
	)
	reveal_master.tween_property(
		turbid_actor,
		"rotation",
		turbid_base_rotation - 0.035,
		0.45
	)

	# 第一階段全部完成後，兩隻一起收束回正式辨識狀態。
	reveal_master.chain().tween_property(bitterness_actor, "scale", bitterness_base_scale, 0.24)
	reveal_master.parallel().tween_property(
		bitterness_actor,
		"rotation",
		bitterness_base_rotation,
		0.24
	)
	reveal_master.parallel().tween_property(
		bitterness_actor,
		"position",
		bitterness_base_position,
		0.24
	)
	reveal_master.parallel().tween_property(bitterness_actor, "modulate:a", 0.88, 0.12)
	reveal_master.parallel().tween_property(turbid_actor, "modulate", Color.WHITE, 0.3)
	reveal_master.parallel().tween_property(turbid_actor, "scale", turbid_base_scale, 0.3)
	reveal_master.parallel().tween_property(turbid_actor, "position", turbid_base_position, 0.3)
	reveal_master.parallel().tween_property(
		turbid_actor,
		"rotation",
		turbid_base_rotation,
		0.3
	)
	reveal_master.chain().tween_property(bitterness_actor, "modulate:a", 1.0, 0.12)
	await reveal_master.finished

	_start_yumei_idle_wobbles()


func _start_yumei_idle_wobbles() -> void:
	_bitterness_idle_base = _capture_yumei_transform(bitterness_actor)
	_turbid_idle_base = _capture_yumei_transform(turbid_actor)
	_bitterness_idle_wobble = _create_yumei_idle_wobble(
		bitterness_actor,
		_bitterness_idle_base,
		0.018,
		Vector2(1.5, -1.0),
		0.58
	)
	_turbid_idle_wobble = _create_yumei_idle_wobble(
		turbid_actor,
		_turbid_idle_base,
		0.012,
		Vector2(-1.2, -1.5),
		0.72
	)


func _capture_yumei_transform(actor: Node2D) -> Dictionary:
	if actor == null:
		return {}
	return {
		"position": actor.position,
		"rotation": actor.rotation,
		"scale": actor.scale,
		"modulate": actor.modulate,
	}


func _create_yumei_idle_wobble(
	actor: Node2D,
	base: Dictionary,
	rotation_amount: float,
	drift: Vector2,
	duration: float
) -> Tween:
	var base_position: Vector2 = base.get("position", actor.position)
	var base_rotation := float(base.get("rotation", actor.rotation))
	var base_scale: Vector2 = base.get("scale", actor.scale)
	var wobble := actor.create_tween()
	wobble.set_loops()
	wobble.set_parallel(true)
	wobble.tween_property(actor, "rotation", base_rotation + rotation_amount, duration)
	wobble.tween_property(actor, "position", base_position + drift, duration)
	wobble.tween_property(actor, "scale", base_scale * Vector2(1.015, 0.985), duration)
	wobble.tween_property(actor, "modulate:a", 0.92, duration)
	wobble.chain().tween_property(actor, "rotation", base_rotation - rotation_amount, duration)
	wobble.parallel().tween_property(actor, "position", base_position - drift, duration)
	wobble.parallel().tween_property(actor, "scale", base_scale * Vector2(0.985, 1.015), duration)
	wobble.parallel().tween_property(actor, "modulate:a", 1.0, duration)
	return wobble


func _stop_yumei_idle_wobbles() -> void:
	if _bitterness_idle_wobble != null and _bitterness_idle_wobble.is_valid():
		_bitterness_idle_wobble.kill()
	if _turbid_idle_wobble != null and _turbid_idle_wobble.is_valid():
		_turbid_idle_wobble.kill()
	_restore_yumei_transform(bitterness_actor, _bitterness_idle_base)
	_restore_yumei_transform(turbid_actor, _turbid_idle_base)
	_bitterness_idle_wobble = null
	_turbid_idle_wobble = null
	_bitterness_idle_base.clear()
	_turbid_idle_base.clear()


func _restore_yumei_transform(actor: Node2D, base: Dictionary) -> void:
	if actor == null or base.is_empty():
		return
	var base_position: Vector2 = base.get("position", actor.position)
	var base_rotation := float(base.get("rotation", actor.rotation))
	var base_scale: Vector2 = base.get("scale", actor.scale)
	var base_modulate: Color = base.get("modulate", actor.modulate)
	actor.position = base_position
	actor.rotation = base_rotation
	actor.scale = base_scale
	actor.modulate = base_modulate


func _move_yumei_to_battle_positions() -> bool:
	_stop_yumei_idle_wobbles()
	if bitterness_follow == null or bitterness_actor == null \
			or turbid_follow == null or turbid_actor == null:
		return false

	bitterness_follow.progress_ratio = 0.0
	turbid_follow.progress_ratio = 0.0
	var bitterness_rotation := bitterness_actor.rotation
	var turbid_rotation := turbid_actor.rotation
	var bitterness_wobble := _start_actor_wobble(bitterness_actor, bitterness_rotation, 0.045, 0.12)
	var turbid_wobble := _start_actor_wobble(turbid_actor, turbid_rotation, 0.025, 0.18)

	var charge_move := create_tween()
	charge_move.set_parallel(true)
	charge_move.set_trans(Tween.TRANS_SINE)
	charge_move.set_ease(Tween.EASE_IN_OUT)
	charge_move.tween_property(
		bitterness_follow,
		"progress_ratio",
		1.0,
		BITTERNESS_PATH_DURATION
	)
	charge_move.tween_property(
		turbid_follow,
		"progress_ratio",
		1.0,
		TURBID_PATH_DURATION
	)

	await charge_move.finished
	bitterness_wobble.kill()
	turbid_wobble.kill()
	bitterness_actor.rotation = bitterness_rotation
	turbid_actor.rotation = turbid_rotation
	return true


func _start_actor_wobble(
	actor: Node2D,
	base_rotation: float,
	amplitude: float,
	duration: float
) -> Tween:
	var wobble := actor.create_tween()
	wobble.set_loops()
	wobble.tween_property(actor, "rotation", base_rotation + amplitude, duration)
	wobble.tween_property(actor, "rotation", base_rotation - amplitude, duration)
	return wobble


func _start_first_yumei_battle(player: Node2D) -> bool:
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root == null or player == null:
		return false
	var player_party: Array = TeamData.get_active_party()
	if player_party.is_empty():
		return false

	var enemy_party: Array = []
	for enemy_id in FIRST_YUMEI_ENEMY_IDS:
		var enemy := EnemyDB.make_enemy(enemy_id)
		if enemy.is_empty():
			push_warning("[下水道首戰] 找不到 EnemyDB ID：%s" % enemy_id)
			return false
		enemy["ui_index"] = enemy_party.size()
		enemy_party.append(enemy)

	var scene_name := String(name)
	var battle_bgm_path := "res://assets/BGM/battle_1.ogg"
	var context := {
		"player_party": player_party,
		"enemy_party": enemy_party,
		"ruleset": {"id": "default"},
		"regen_policy": {"id": "round_end_mp_regen_default"},
		"tone": {"intro_key": FIRST_YUMEI_BATTLE_KEY},
		"battle_tag": FIRST_YUMEI_BATTLE_KEY,
		"zone_id": FIRST_YUMEI_BATTLE_KEY,
		"map_id": CENTER_SCENE_PATH,
		"scene_name": scene_name,
		"battle_bgm_path": battle_bgm_path,
	}

	GlobalState.set_meta("return_map_path", CENTER_SCENE_PATH)
	GlobalState.set_meta("return_player_pos", player.global_position)
	GlobalState.set_meta(
		"return_encounter_cooldown",
		float(SEWER_CENTER_ENCOUNTER_CONFIG["cooldown_distance"])
	)
	GlobalState.set_meta(META_FIRST_YUMEI_BATTLE_PENDING, true)
	GlobalState.set_meta("pending_battle_context", context)
	if game_root.has_method("pause_world_bgm_for_battle"):
		game_root.call("pause_world_bgm_for_battle")
	if player.has_method("lock_for_battle"):
		# 固定首戰需讓拔劍備戰動畫維持至戰鬥轉場接管畫面。
		player.call("lock_for_battle", false)
	if player.has_method("_play_encounter_transition"):
		await player.call("_play_encounter_transition", {})
	player.visible = false
	game_root.change_map_to(BATTLE_SCENE_PATH)
	return true


func _resolve_first_battle_return() -> void:
	if not bool(GlobalState.get_meta(META_FIRST_YUMEI_BATTLE_PENDING, false)):
		return
	var result_meta = GlobalState.get_meta("pending_battle_result", {})
	if typeof(result_meta) != TYPE_DICTIONARY:
		return
	var result := String((result_meta as Dictionary).get("result", ""))
	if result == "victory":
		_first_battle_victory_return_pending = true
		event_in_progress = true
		GlobalState.set_meta("menu_locked", true)
		return
	GlobalState.remove_meta(META_FIRST_YUMEI_BATTLE_PENDING)
	GlobalState.remove_meta("pending_battle_result")
	GlobalState.set_meta("menu_locked", false)


func _run_first_battle_victory_epilogue(player: Node2D) -> void:
	if player:
		player.set("can_move", false)
		player.set("velocity", Vector2.ZERO)
		player.set("direction", Vector2.ZERO)
		if player.has_method("set_encounter_paused"):
			player.call("set_encounter_paused", true)
		await _play_liuyu_sheathe_animation(player)

	await _show_dialog([
		_liuyu_line("苦息藥魅……我曾聽說，有一隻同類附著在一面寫著\n『良藥苦口』的匾額上。"),
		_liuyu_line("那間藥鋪從此開方不問藥理，只一味選用至苦之物。\n到了最後，甚至叫病人生嚼黃連、生吞蛇膽。"),
		_liuyu_line("胡亂用藥，病不但沒有治好，反而愈發嚴重。可他們\n竟又把病情加劇帶來的痛苦，當成藥效正在發作的證明。"),
		_liuyu_line("最後……整座村莊，就這麼沒了。"),
		_liuyu_line("我現在慢慢明白，紅徽音為何要以琴音壓住鎮民的情，\n讓他們有苦，也不輕易言之。"),
		_liuyu_line("只是，把苦壓下去，終究不等於把苦解開。"),
		_liuyu_line("嗯...還是先找到書眠吧。"),
		_liuyu_line("這下水道不知道還有甚麼牛鬼蛇神，得要多提防點才是..."),
	])

	GlobalState.set_flag(F_FIRST_YUMEI_BATTLE_DONE, true)
	GlobalState.remove_meta(META_FIRST_YUMEI_BATTLE_PENDING)
	GlobalState.remove_meta("pending_battle_result")
	GlobalState.set_meta("menu_locked", false)
	_first_battle_victory_return_pending = false
	event_in_progress = false
	_set_first_battle_trigger_enabled(false)
	if player:
		player.set("velocity", Vector2.ZERO)
		player.set("direction", Vector2.ZERO)
		if player.has_method("restore_idle_control"):
			player.call("restore_idle_control")
		player.set("can_move", true)
		if player.has_method("set_encounter_paused"):
			player.call("set_encounter_paused", false)
		if player.has_method("refresh_danger_zone_from_position"):
			player.call("refresh_danger_zone_from_position", 0.0)


func _play_liuyu_sheathe_animation(player: Node2D) -> void:
	if player == null:
		return
	if not _hold_liuyu_fight_final_frame(player):
		return
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	sprite.play_backwards(LIUYU_FIGHT_ANIMATION)
	await sprite.animation_finished
	_set_liuyu_idle_right_down(player)


func prepare_battle_return_actor(player: Node2D) -> void:
	if not _first_battle_victory_return_pending:
		return
	_hold_liuyu_fight_final_frame(player)


func _hold_liuyu_fight_final_frame(player: Node2D) -> bool:
	if player == null:
		return false
	player.set("can_move", false)
	player.set("velocity", Vector2.ZERO)
	player.set("direction", Vector2.ZERO)
	player.set("override_idle_animation", true)
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null \
			or not sprite.sprite_frames.has_animation(LIUYU_FIGHT_ANIMATION):
		push_warning("[下水道首戰] 找不到 ready_fight_right_down，回退至 idle_right_down。")
		_set_liuyu_idle_right_down(player)
		return false
	var frame_count := sprite.sprite_frames.get_frame_count(LIUYU_FIGHT_ANIMATION)
	if frame_count <= 0:
		push_warning("[下水道首戰] ready_fight_right_down 沒有影格，回退至 idle_right_down。")
		_set_liuyu_idle_right_down(player)
		return false
	sprite.animation = LIUYU_FIGHT_ANIMATION
	sprite.set_frame_and_progress(frame_count - 1, 1.0)
	sprite.pause()
	return true


func _set_liuyu_idle_right_down(player: Node2D) -> void:
	if player and player.has_method("play_idle_direction"):
		player.call("play_idle_direction", "right_down")


func _set_liuyu_idle_for_entry(player: Node2D, spawn_point_name: String) -> void:
	if player == null or not player.has_method("play_idle_direction"):
		return

	match spawn_point_name:
		"from_yuheng_sewer_talisman_room":
			player.call("play_idle_direction", "right_up")
		"from_yuheng_sewer_alchemy_room":
			player.call("play_idle_direction", "left_down")
		_:
			player.call("play_idle_direction", "right_down")


func _apply_first_battle_scene_state() -> void:
	_stop_yumei_idle_wobbles()
	_hide_story_actor(bitterness_actor)
	_hide_story_actor(turbid_actor)
	_set_first_battle_trigger_enabled(
		not _is_first_battle_completed() and not _first_battle_victory_return_pending
	)


func _hide_story_actor(actor: Node2D) -> void:
	if actor == null:
		return
	actor.visible = false
	actor.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var collision := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", true)


func _set_first_battle_trigger_enabled(enabled: bool) -> void:
	if first_battle_area:
		first_battle_area.set_deferred("monitoring", enabled)
		first_battle_area.set_deferred("monitorable", enabled)
	if first_battle_collision:
		first_battle_collision.set_deferred("disabled", not enabled)


func _lock_player_for_event(player: Node2D) -> void:
	GlobalState.set_meta("menu_locked", true)
	player.set("can_move", false)
	player.set("velocity", Vector2.ZERO)
	player.set("direction", Vector2.ZERO)
	if player.has_method("reset_encounter_state"):
		player.call("reset_encounter_state")
	if player.has_method("set_encounter_paused"):
		player.call("set_encounter_paused", true)


func _abort_first_battle_event(player: Node2D, reason: String) -> void:
	push_warning("[下水道首戰] %s" % reason)
	GlobalState.set_meta("menu_locked", false)
	event_in_progress = false
	_stop_yumei_idle_wobbles()
	_hide_story_actor(bitterness_actor)
	_hide_story_actor(turbid_actor)
	_set_first_battle_trigger_enabled(true)
	if player:
		player.set("velocity", Vector2.ZERO)
		player.set("can_move", true)
		if player.has_method("restore_idle_control"):
			player.call("restore_idle_control")
		if player.has_method("set_encounter_paused"):
			player.call("set_encounter_paused", false)
		if player.has_method("refresh_danger_zone_from_position"):
			player.call("refresh_danger_zone_from_position", 0.0)


func _face_player_toward_enemies(player: Node2D) -> void:
	if player and player.has_method("play_idle_direction"):
		player.call("play_idle_direction", "right")


func _is_first_battle_completed() -> bool:
	return bool(GlobalState.get_flag(F_FIRST_YUMEI_BATTLE_DONE))


func _show_dialog(lines: Array) -> void:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[下水道首戰] 找不到 DialogManager。")
		return
	_waiting_for_dialog = true
	dialog_manager.show_dialog_sequence(lines, self)
	await dialog_manager.dialog_sequence_finished
	_waiting_for_dialog = false


func reset_dialog_state() -> void:
	if _waiting_for_dialog:
		_waiting_for_dialog = false
		dialog_closed.emit()


func _liuyu_line(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": LIUYU_SPEAKER_ID,
		"portrait": LIUYU_PORTRAIT_PATH,
	}


func _yumei_line(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": YUMEI_SPEAKER_ID,
		"portrait": EMPTY_PORTRAIT_PATH,
	}


func _narration_line(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": NARRATION_SPEAKER_ID,
		"portrait": EMPTY_PORTRAIT_PATH,
	}


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

func _on_to_yuheng_old_well_body_entered(body: Node2D):
	if MapTransitionGuard.can_transition(body, get_node_or_null("To_yuheng_old_well") as Area2D):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_old_well_night)


func _on_to_yuheng_sewer_secrect_room_body_entered(body: Node2D) -> void:
	if MapTransitionGuard.can_transition(body, get_node_or_null("To_yuheng_sewer_secrect_room") as Area2D):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_secret_room)


func _on_to_yuheng_sewer_talisman_room_body_entered(body: Node2D) -> void:
	if MapTransitionGuard.can_transition(body, get_node_or_null("To_yuheng_sewer_talisman_room") as Area2D):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_talisman_room)


func _on_to_yuheng_sewer_alchemy_room_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if MapTransitionGuard.can_transition(body, get_node_or_null("To_yuheng_sewer_alchemy_room") as Area2D):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_alchemy_room)


func _on_to_yuheng_sewer_final_room_body_entered(body: Node2D) -> void:
	if MapTransitionGuard.can_transition(body, get_node_or_null("To_yuheng_sewer_final_room") as Area2D):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_final_room)


func _on_to_yuheng_sewer_music_room_body_entered(body: Node2D) -> void:
	if MapTransitionGuard.can_transition(body, get_node_or_null("To_yuheng_sewer_music_room") as Area2D):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_music_room)
