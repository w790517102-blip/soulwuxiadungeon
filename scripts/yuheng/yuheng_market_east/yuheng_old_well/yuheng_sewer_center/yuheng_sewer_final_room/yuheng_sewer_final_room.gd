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
@onready var entry_forbidden: CollisionShape2D = get_node_or_null("talisman/Area2D/entry_forbidden")
@onready var entry_barrier: CollisionShape2D = get_node_or_null("talisman/EntryBarrier/CollisionShape2D")
@onready var final_room_intro_trigger: Area2D = get_node_or_null(
	"yuheng_sewer_final_room_event_trigger/yuheng_sewer_final_room_event_trigger"
)
@onready var final_room_intro_path: Path2D = get_node_or_null(
	"yuheng_sewer_final_room_event_trigger/yuheng_sewer_final_room_Path"
)
@onready var final_room_intro_path_follow: PathFollow2D = get_node_or_null(
	"yuheng_sewer_final_room_event_trigger/yuheng_sewer_final_room_Path/PathFollow2D"
)

@export var music_tag := "yuheng_sewer"
@export var map_display_name: String = "玉衡鎮下水道終端房間"
@export var intro_camera_pan_duration: float = 1.2
@export var intro_walk_speed: float = 160.0

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
const F_FINAL_ROOM_INTRO_DONE := "event_yuheng_sewer_final_room_intro_done"
const SEWER_ZONE_ID := "yuheng_sewer"
const SEWER_TERMINAL_ENCOUNTER_CONFIG := {
	"encounter_region_id": "yuheng_sewer",
	"encounter_profile_id": "yuheng_sewer_pressure_v1",
	"distance_threshold": 240.0,
	"chance": 0.30,
	"cooldown_distance": 280.0,
	"intro_key": "yuheng_sewer_terminal_random"
}
const SEWER_TERMINAL_ENCOUNTER_TABLE := [
	{"w": 8, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 6, "enemies": ["yumei_sewer_bat", "yumei_sewer_bat"]},
	{"w": 8, "enemies": ["fidgety_sewer_fish", "fidgety_sewer_fish"]},
	{"w": 6, "enemies": ["yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 6, "enemies": ["turbid_tone_phantom", "fidgety_sewer_fish"]},
	{"w": 8, "enemies": ["bitterness_tone_phantom", "broken_talisman_tone_phantom"]},
	{"w": 8, "enemies": ["bitterness_tone_phantom", "broken_string_tone_phantom"]},
	{"w": 8, "enemies": ["broken_talisman_tone_phantom", "broken_string_tone_phantom"]},
	{"w": 7, "enemies": ["turbid_tone_phantom", "bitterness_tone_phantom"]},
	{"w": 7, "enemies": ["turbid_tone_phantom", "broken_talisman_tone_phantom"]},
	{"w": 6, "enemies": ["turbid_tone_phantom", "broken_string_tone_phantom"]},
	{"w": 6, "enemies": ["fixation_tone_phantom"]},
	{"w": 6, "enemies": ["echo_tone_phantom"]},
	{"w": 3, "enemies": ["fixation_tone_phantom", "yumei_sewer_rat"]},
	{"w": 3, "enemies": ["echo_tone_phantom", "bitterness_tone_phantom"]},
	{"w": 4, "enemies": ["bitterness_tone_phantom", "fixation_tone_phantom"]}
]

var transition_locked := false
var seal_dialog_locked := false
var _waiting_for_dialog := false
var final_room_intro_playing := false
var _intro_menu_was_locked := false
var _intro_map_was_locked := false
var _intro_encounter_was_paused := false
var _intro_idle_override_was_active := false
var _intro_trigger_flow_active := false


func _ready() -> void:
	_apply_totem_and_seal_state()
	_set_final_room_intro_trigger_enabled(
		not bool(_get_flag(F_FINAL_ROOM_INTRO_DONE, false))
		or (_all_puzzles_solved() and not bool(_get_flag(F_FINAL_SEAL_OPENED, false)))
	)
	await _play_entry_fade()
	await show_map_name()

	# Area2D 可能已在進場顯示期間啟動導覽；此時由該流程負責後續封印檢查。
	if _intro_trigger_flow_active:
		return

	# 舊存檔與已看過導覽的存檔維持原本的終端房狀態套用；
	# 首次進房則完全交由壁畫前的事件區域播放導覽與檢查封印。
	if bool(_get_flag(F_FINAL_SEAL_OPENED, false)):
		if not bool(_get_flag(F_FINAL_ROOM_INTRO_DONE, false)):
			_set_flag(F_FINAL_ROOM_INTRO_DONE, true)
		await _refresh_final_room_state()
	elif bool(_get_flag(F_FINAL_ROOM_INTRO_DONE, false)):
		await _refresh_final_room_state()


func get_map_display_name() -> String:
	return map_display_name

func get_encounter_zone_config(zone_id: String) -> Dictionary:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_TERMINAL_ENCOUNTER_CONFIG.duplicate(true)
	return {}

func get_encounter_table(zone_id: String) -> Array:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_TERMINAL_ENCOUNTER_TABLE.duplicate(true)
	return []


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
# 首次進入終端房：鏡頭導覽
# ------------------------------------------------------------
func _on_yuheng_sewer_final_room_event_trigger_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if _intro_trigger_flow_active or final_room_intro_playing \
		or transition_locked or seal_dialog_locked \
		or _is_dialog_active():
		return
	var intro_done := bool(_get_flag(F_FINAL_ROOM_INTRO_DONE, false))
	if intro_done and (not _all_puzzles_solved() or bool(_get_flag(F_FINAL_SEAL_OPENED, false))):
		return

	_intro_trigger_flow_active = true
	final_room_intro_playing = true
	_set_final_room_intro_trigger_enabled(false)
	if intro_done:
		await _run_final_seal_from_trigger(body)
	else:
		await _run_final_room_intro_from_trigger(body)


func _run_final_seal_from_trigger(player: Node2D) -> void:
	await _play_final_seal_open_event(player)
	final_room_intro_playing = false
	_intro_trigger_flow_active = false


func _run_final_room_intro_from_trigger(player: Node2D) -> void:
	var intro_completed: bool = await _play_final_room_intro_if_needed(player)

	# 只有導覽完整完成並寫入一次性旗標後，才接續既有三機關／總封印檢查。
	if intro_completed and bool(_get_flag(F_FINAL_ROOM_INTRO_DONE, false)):
		await _refresh_final_room_state()
	else:
		_set_final_room_intro_trigger_enabled(true)

	final_room_intro_playing = false
	_intro_trigger_flow_active = false


func _play_final_room_intro_if_needed(player: Node2D) -> bool:
	if bool(_get_flag(F_FINAL_ROOM_INTRO_DONE, false)):
		return true

	# 舊存檔若終端封印已經開啟，不再播放「門仍封閉」的錯誤觀察。
	if bool(_get_flag(F_FINAL_SEAL_OPENED, false)):
		_set_flag(F_FINAL_ROOM_INTRO_DONE, true)
		return true

	if not is_instance_valid(player):
		push_warning("[終端房導覽] 找不到劉語塵，安全略過本次導覽。")
		return false

	var game_root: Node = get_node_or_null("/root/GameRoot")
	var camera: Camera2D = null
	if game_root:
		camera = game_root.get_node_or_null("MainCamera") as Camera2D

	_begin_final_room_intro_lock(player, game_root)
	await _walk_player_to_final_room_intro_position(player)
	if not is_instance_valid(player):
		push_warning("[終端房導覽] 自動走位期間找不到劉語塵，已解除本次演出鎖。")
		_end_final_room_intro_lock(player, game_root)
		return false
	_set_player_intro_idle_up(player)

	var camera_override_started := false
	if camera and camera.has_method("begin_story_override"):
		camera_override_started = bool(camera.call("begin_story_override"))
	if not camera_override_started:
		push_warning("[終端房導覽] 活動 Camera 或 Boundary 尚未就緒，改以原取景安全播放獨白。")

	await _show_dialog([
		"這下水道峰迴路轉，沒想到在如此深處，竟藏著這般壯闊的密室。"
	])

	if camera_override_started:
		var top_target: Vector2 = camera.call(
			"get_story_top_position",
			camera.global_position + Vector2(180.0, 0.0)
		)
		await _move_intro_camera(camera, top_target)

	await _show_dialog([
		"這是……琴、符，還有藥草的圖案。"
	])

	if camera_override_started:
		var right_target: Vector2 = camera.call("get_story_right_position", camera.global_position)
		await _move_intro_camera(camera, right_target)

	await _show_dialog([
		"……門後有一股清涼的氣息滲來。",
		"想必那裡，便是離開下水道的出口。",
		"只是門上符繩交錯，封得極嚴。",
		"依我的直覺，破解此陣的關鍵，多半就在那三枚徽印上。",
		"……",
		"眼下也沒有其他出口。既然無路可繞，便逐一查清楚吧。"
	])

	var camera_returned := not camera_override_started
	if camera_override_started and is_instance_valid(camera):
		var follow_target: Vector2 = camera.call("get_follow_position")
		camera_returned = await _move_intro_camera(camera, follow_target)
		camera.call("end_story_override", not camera_returned)

	if camera_override_started and not camera_returned:
		push_warning("[終端房導覽] Camera 返回途中失效，已要求鏡頭安全貼回角色。")

	_set_flag(F_FINAL_ROOM_INTRO_DONE, true)
	_refresh_sewer_puzzle_note()
	_end_final_room_intro_lock(player, game_root)
	return true


func _walk_player_to_final_room_intro_position(player: Node2D) -> bool:
	if not is_instance_valid(player):
		return false
	if final_room_intro_path == null or final_room_intro_path_follow == null:
		push_warning("[終端房導覽] 找不到既有 Path2D／PathFollow2D，保留玩家現位並繼續導覽。")
		return false
	if final_room_intro_path.curve == null:
		push_warning("[終端房導覽] 導覽 Path2D 缺少 Curve2D，保留玩家現位並繼續導覽。")
		return false

	var curve_length: float = final_room_intro_path.curve.get_baked_length()
	if curve_length <= 0.0:
		push_warning("[終端房導覽] 導覽 Path2D 長度為零，保留玩家現位並繼續導覽。")
		return false

	final_room_intro_path_follow.progress = 0.0
	var path_start: Vector2 = final_room_intro_path_follow.global_position
	await _walk_player_to_point(player, path_start)
	if not is_instance_valid(player):
		return false

	var previous_position: Vector2 = player.global_position
	while final_room_intro_path_follow.progress < curve_length and is_instance_valid(player):
		await get_tree().process_frame
		var delta: float = get_process_delta_time()
		final_room_intro_path_follow.progress = minf(
			final_room_intro_path_follow.progress + maxf(intro_walk_speed, 1.0) * delta,
			curve_length
		)
		player.global_position = final_room_intro_path_follow.global_position
		var move_direction: Vector2 = player.global_position - previous_position
		if move_direction.length_squared() > 0.01:
			_play_player_intro_walk(player, move_direction.normalized())
		previous_position = player.global_position

	if not is_instance_valid(player):
		return false
	final_room_intro_path_follow.progress = curve_length
	player.global_position = final_room_intro_path_follow.global_position
	_clear_player_intro_motion(player)
	return true


func _walk_player_to_point(player: Node2D, target_position: Vector2) -> void:
	while is_instance_valid(player) and player.global_position.distance_to(target_position) > 1.0:
		await get_tree().process_frame
		var move_direction: Vector2 = target_position - player.global_position
		var delta: float = get_process_delta_time()
		var step_length: float = minf(maxf(intro_walk_speed, 1.0) * delta, move_direction.length())
		_play_player_intro_walk(player, move_direction.normalized())
		player.global_position += move_direction.normalized() * step_length
	if is_instance_valid(player):
		player.global_position = target_position


func _play_player_intro_walk(player: Node2D, move_direction: Vector2) -> void:
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = move_direction * maxf(intro_walk_speed, 1.0)
	player.set("direction", move_direction)
	player.set("last_direction", move_direction)
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	if player.has_method("get_anim_name"):
		var animation_name := StringName(player.call("get_anim_name", move_direction, "walk"))
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(animation_name):
			sprite.play(animation_name)


func _clear_player_intro_motion(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	player.set("direction", Vector2.ZERO)


func _set_player_intro_idle_up(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	_clear_player_intro_motion(player)
	if player.has_method("play_idle_direction"):
		player.call("play_idle_direction", "up")


func _set_final_room_intro_trigger_enabled(enabled: bool) -> void:
	if final_room_intro_trigger:
		final_room_intro_trigger.set_deferred("monitoring", enabled)


func _is_dialog_active() -> bool:
	var dialog_manager := _get_dialog_manager()
	return dialog_manager != null and bool(dialog_manager.get("dialog_active"))


func _refresh_sewer_puzzle_note() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager == null or not quest_manager.has_method("get_main_quest_state"):
		push_warning("[終端房導覽] 找不到 QuestManager，無法更新主線 Note。")
		return
	var main_state: Dictionary = quest_manager.call("get_main_quest_state")
	if String(main_state.get("id", "")) != "main_001":
		return
	if int(main_state.get("stage", 0)) != QuestManager.STAGE_YH_SEWER_MECHANISMS:
		return
	if quest_manager.has_method("refresh_sewer_puzzle_note"):
		quest_manager.call("refresh_sewer_puzzle_note")


func _move_intro_camera(camera: Camera2D, target_position: Vector2) -> bool:
	if not is_instance_valid(camera):
		return false

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", target_position, maxf(intro_camera_pan_duration, 0.01))
	await tween.finished
	return is_instance_valid(camera)


func _begin_final_room_intro_lock(player: Node2D, game_root: Node) -> void:
	var global_state := _get_global_state()
	_intro_menu_was_locked = bool(global_state.get_meta("menu_locked", false)) if global_state else false
	if global_state:
		global_state.set_meta("menu_locked", true)

	var system_menu := get_node_or_null("/root/SystemMenu")
	if system_menu and system_menu.has_method("close_menu_if_open"):
		system_menu.call("close_menu_if_open")

	_intro_map_was_locked = bool(game_root.call("is_map_transition_locked")) if game_root and game_root.has_method("is_map_transition_locked") else false
	if game_root and game_root.has_method("lock_map_transitions"):
		game_root.call("lock_map_transitions", "final_room_intro")

	_intro_encounter_was_paused = bool(player.get("_encounter_paused"))
	if player.has_method("set_encounter_paused"):
		player.call("set_encounter_paused", true)
	_intro_idle_override_was_active = bool(player.get("override_idle_animation"))
	player.set("override_idle_animation", true)
	_set_player_movable(false)
	_clear_player_intro_motion(player)


func _end_final_room_intro_lock(player: Node2D, game_root: Node) -> void:
	if is_instance_valid(player):
		if player.has_method("set_encounter_paused"):
			player.call("set_encounter_paused", _intro_encounter_was_paused)
		_set_player_intro_idle_up(player)
		if not _intro_idle_override_was_active and player.has_method("restore_idle_control"):
			player.call("restore_idle_control")
		_set_player_movable(true)

	var global_state := _get_global_state()
	if global_state:
		global_state.set_meta("menu_locked", _intro_menu_was_locked)

	if game_root and not _intro_map_was_locked and game_root.has_method("unlock_map_transitions"):
		game_root.call("unlock_map_transitions", "final_room_intro")

# ------------------------------------------------------------
# 終端房狀態
# ------------------------------------------------------------
func _refresh_final_room_state() -> void:
	_apply_totem_and_seal_state()
	_set_final_room_intro_trigger_enabled(
		_all_puzzles_solved() and not bool(_get_flag(F_FINAL_SEAL_OPENED, false))
	)


func _apply_totem_and_seal_state(final_opened_override: bool = false) -> void:
	var alchemy_done: bool = bool(_get_flag(F_ALCHEMY_SOLVED, false))
	var music_done: bool = bool(_get_flag(F_MUSIC_SOLVED, false))
	var talisman_done: bool = bool(_get_flag(F_TALISMAN_SOLVED, false))
	var final_opened: bool = final_opened_override or bool(_get_flag(F_FINAL_SEAL_OPENED, false))

	_set_totem_lit(qin_totem, music_done)
	_set_totem_lit(herb_totem, alchemy_done)
	_set_totem_lit(talisman_totem, talisman_done)
	_set_final_gate_open(final_opened)


func _set_final_gate_open(is_open: bool) -> void:
	if final_seal:
		final_seal.visible = not is_open
		if not is_open:
			final_seal.modulate.a = 1.0

	if entry_forbidden:
		entry_forbidden.set_deferred("disabled", is_open)
	if entry_barrier:
		entry_barrier.set_deferred("disabled", is_open)


func _set_totem_lit(node: CanvasItem, lit: bool) -> void:
	if node == null:
		return

	node.visible = lit
	node.modulate.a = 1.0 if lit else 0.0


func _all_puzzles_solved() -> bool:
	return bool(_get_flag(F_ALCHEMY_SOLVED, false)) \
		and bool(_get_flag(F_MUSIC_SOLVED, false)) \
		and bool(_get_flag(F_TALISMAN_SOLVED, false))


func _play_final_seal_open_event(player: Node2D = null) -> void:
	if bool(_get_flag(F_FINAL_SEAL_OPENED, false)):
		return
	if player == null:
		player = _get_player()
	var game_root: Node = get_node_or_null("/root/GameRoot")
	var camera: Camera2D = null
	if game_root:
		camera = game_root.get_node_or_null("MainCamera") as Camera2D
	if player:
		_begin_final_room_intro_lock(player, game_root)
		await _walk_player_to_final_room_intro_position(player)
		_set_player_intro_idle_up(player)

	var camera_override_started := false
	if camera and camera.has_method("begin_story_override"):
		camera_override_started = bool(camera.call("begin_story_override"))

	# 確保鏡頭上移時，三枚徽印已經全部呈現完成狀態。
	_set_totem_lit(qin_totem, true)
	_set_totem_lit(herb_totem, true)
	_set_totem_lit(talisman_totem, true)
	if camera_override_started:
		var top_target: Vector2 = camera.call(
			"get_story_top_position",
			camera.global_position + Vector2(180.0, 0.0)
		)
		await _move_intro_camera(camera, top_target)

	await _show_dialog([
		"終端房內，三枚徽印同時亮起。",
		"琴音歸正，藥香流開，符光補封。",
	])

	if camera_override_started:
		var right_target: Vector2 = camera.call("get_story_right_position", camera.global_position)
		await _move_intro_camera(camera, right_target)

	await _show_dialog([
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

	await _fade_out_final_seal()
	_set_flag(F_FINAL_SEAL_OPENED, true)
	_refresh_sewer_puzzle_note()
	_set_final_gate_open(true)
	_set_final_room_intro_trigger_enabled(false)

	if camera_override_started and is_instance_valid(camera):
		var follow_target: Vector2 = camera.call("get_follow_position")
		var camera_returned: bool = await _move_intro_camera(camera, follow_target)
		camera.call("end_story_override", not camera_returned)
	if player:
		_end_final_room_intro_lock(player, game_root)


func _fade_out_final_seal() -> void:
	if final_seal == null:
		return

	final_seal.visible = true
	final_seal.modulate.a = 1.0

	var tween := final_seal.create_tween()
	tween.tween_property(final_seal, "modulate:a", 0.0, 0.8)
	await tween.finished


# ------------------------------------------------------------
# 轉場：回中央區
# ------------------------------------------------------------
func _on_to_yuheng_sewer_center_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if final_room_intro_playing:
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
func _on_entry_forbidden_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if final_room_intro_playing:
		return
	if transition_locked or seal_dialog_locked:
		return
	if _get_flag(F_FINAL_SEAL_OPENED, false):
		return

	if not _all_puzzles_solved():
		await _show_sealed_message()


func _on_to_yuheng_stalactite_cave_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if final_room_intro_playing:
		return

	if transition_locked or seal_dialog_locked:
		return

	if not _get_flag(F_FINAL_SEAL_OPENED, false):
		if not _all_puzzles_solved():
			await _show_sealed_message()
			return
		# 三機關完成後仍須由既有壁畫 Trigger 播放正式解封鏡頭；
		# 不可在出口碰撞上繞過 Path2D 與 Camera 演出直接開門。
		_set_final_room_intro_trigger_enabled(true)
		return

	# 轉場本身仍以終端封印完成旗標為最後防線，不只依賴碰撞形狀。
	if not _get_flag(F_FINAL_SEAL_OPENED, false):
		return

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
	var player: Node2D = _get_player()
	if player:
		player.set("can_move", value)


func _get_player() -> Node2D:
	var player := get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	if player == null:
		player = get_node_or_null("/root/Player") as Node2D
	return player


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
