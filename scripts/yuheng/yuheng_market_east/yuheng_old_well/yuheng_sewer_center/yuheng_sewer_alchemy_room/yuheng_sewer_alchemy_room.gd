extends Node2D

const EnemyDB = preload("res://scripts/db/EnemyDB.gd")

@onready var yuheng_sewer_center: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_center.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "yuheng_sewer"
@export var map_display_name: String = "玉衡鎮下水道調香室"

const SEWER_ZONE_ID := "yuheng_sewer"
const ALCHEMY_ROOM_SCENE_PATH := "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_alchemy_room/yuheng_sewer_alchemy_room.tscn"
const BATTLE_SCENE_PATH := "res://scenes/battle_scene.tscn"
const BITTER_YUMEI_ID := "bitterness_tone_phantom"
const ALCHEMY_BATTLE_KEY := "yuheng_sewer_alchemy_bitter_yumei"
const META_ALCHEMY_BATTLE_PENDING := "pending_yuheng_sewer_alchemy_bitter_battle"
const FLAG_BITTER_YUMEI_DEFEATED := "sewer_alchemy_bitter_yumei_defeated"
const FLAG_ALCHEMY_SOLVED := "sewer_alchemy_solved"
const FLAG_FAILURE_RETURN_PENDING := "sewer_alchemy_failure_return_pending"
const PHASE_HERBS_CONFIRMED := "herbs_confirmed"
const PHASE_PROCESSING := "processing"
const PHASE_READY_TO_IGNITE := "ready_to_ignite"
const PHASE_RETRY_NEEDED := "retry_needed"
const SEWER_ALCHEMY_ENCOUNTER_CONFIG := {
	"encounter_region_id": "yuheng_sewer",
	"encounter_profile_id": "yuheng_sewer_pressure_v1",
	"distance_threshold": 240.0,
	"chance": 0.30,
	"cooldown_distance": 280.0,
	"intro_key": "yuheng_sewer_alchemy_random"
}
const SEWER_ALCHEMY_ENCOUNTER_TABLE := [
	{"w": 10, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 6, "enemies": ["yumei_sewer_bat", "yumei_sewer_bat"]},
	{"w": 8, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 6, "enemies": ["yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 14, "enemies": ["fidgety_sewer_fish", "fidgety_sewer_fish"]},
	{"w": 12, "enemies": ["fidgety_sewer_fish", "yumei_sewer_rat"]},
	{"w": 8, "enemies": ["fidgety_sewer_fish", "yumei_sewer_bat"]},
	{"w": 6, "enemies": ["fidgety_sewer_fish", "fidgety_sewer_fish", "yumei_sewer_rat"]},
	{"w": 6, "enemies": ["turbid_tone_phantom", "yumei_sewer_rat"]},
	{"w": 7, "enemies": ["turbid_tone_phantom", "fidgety_sewer_fish"]},
	{"w": 7, "enemies": ["bitterness_tone_phantom", "yumei_sewer_rat"]},
	{"w": 8, "enemies": ["bitterness_tone_phantom", "fidgety_sewer_fish"]},
	{"w": 2, "enemies": ["bitterness_tone_phantom", "yumei_sewer_bat"]}
]

var selected_herbs: Array[String] = []
var processing_methods: Array[String] = []
var herbs_confirmed := false
var alchemy_phase := ""
var _failure_closeout_pending := false
var _owns_menu_lock := false


func _ready():
	_restore_alchemy_puzzle_state()
	_refresh_sewer_puzzle_note()
	var battle_return := _resolve_alchemy_battle_return()
	var returned_from_alchemy_battle := bool(battle_return.get("returned", false))
	_failure_closeout_pending = bool(battle_return.get("failure_closeout", false))
	if not returned_from_alchemy_battle \
	and bool(GlobalState.get_flag(FLAG_FAILURE_RETURN_PENDING)):
		push_warning("[調香室] 發現缺少固定戰鬥返回結果的失敗收尾狀態；已保留配方並清除過期 pending。")
		GlobalState.set_flag(FLAG_FAILURE_RETURN_PENDING, false)
	var player := _get_player()
	if _failure_closeout_pending:
		_owns_menu_lock = not bool(GlobalState.get_meta("menu_locked", false))
		GlobalState.set_meta("menu_locked", true)
		_set_alchemy_interactions_locked(true)
	if (returned_from_alchemy_battle or _failure_closeout_pending) and player:
		player.set("can_move", false)
		player.set("velocity", Vector2.ZERO)
		if player.has_method("set_encounter_paused"):
			player.call("set_encounter_paused", true)
	_set_entry_idle_direction()
	overlay.modulate.a = 1.5
	var tween_in = overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished

	if _failure_closeout_pending:
		await _play_failure_battle_return_closeout()
	elif returned_from_alchemy_battle and player:
		player.visible = true
		player.set("can_move", true)
		if player.has_method("set_encounter_paused"):
			player.call("set_encounter_paused", false)
	show_map_name()


func start_alchemy_bitter_yumei_battle(player: Node) -> bool:
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root == null or player == null:
		push_warning("[調香室] 固定戰鬥啟動失敗：找不到 GameRoot 或 LiuYu。")
		return false
	var player_party: Array = TeamData.get_active_party()
	if player_party.is_empty():
		push_warning("[調香室] 固定戰鬥啟動失敗：隊伍為空。")
		return false
	var enemy := EnemyDB.make_enemy(BITTER_YUMEI_ID)
	if enemy.is_empty():
		push_warning("[調香室] EnemyDB 找不到：%s" % BITTER_YUMEI_ID)
		return false
	enemy["ui_index"] = 0

	var context := {
		"player_party": player_party,
		"enemy_party": [enemy],
		"ruleset": {"id": "default"},
		"regen_policy": {"id": "round_end_mp_regen_default"},
		"tone": {"intro_key": ALCHEMY_BATTLE_KEY},
		"battle_tag": ALCHEMY_BATTLE_KEY,
		"zone_id": SEWER_ZONE_ID,
		"map_id": ALCHEMY_ROOM_SCENE_PATH,
		"scene_name": String(name),
		"battle_bgm_path": "res://assets/BGM/battle_1.ogg",
	}
	GlobalState.set_meta("return_map_path", ALCHEMY_ROOM_SCENE_PATH)
	GlobalState.set_meta("return_player_pos", player.global_position)
	GlobalState.set_flag(FLAG_FAILURE_RETURN_PENDING, true)
	GlobalState.set_meta(META_ALCHEMY_BATTLE_PENDING, true)
	GlobalState.set_meta("pending_battle_context", context)
	if game_root.has_method("pause_world_bgm_for_battle"):
		game_root.call("pause_world_bgm_for_battle")
	if player.has_method("set_encounter_paused"):
		player.call("set_encounter_paused", true)
	if player.has_method("lock_for_battle"):
		player.call("lock_for_battle")
	else:
		player.set("can_move", false)
		player.set("velocity", Vector2.ZERO)
	if player.has_method("_play_encounter_transition"):
		await player.call("_play_encounter_transition", {})
	player.visible = false
	game_root.change_map_to(BATTLE_SCENE_PATH)
	return true


func _resolve_alchemy_battle_return() -> Dictionary:
	if not bool(GlobalState.get_meta(META_ALCHEMY_BATTLE_PENDING, false)):
		return {"returned": false, "failure_closeout": false}
	var result_meta = GlobalState.get_meta("pending_battle_result", "")
	var result := ""
	if typeof(result_meta) == TYPE_DICTIONARY:
		result = String((result_meta as Dictionary).get("result", ""))
	else:
		result = String(result_meta)
	if result == "victory":
		GlobalState.set_flag(FLAG_BITTER_YUMEI_DEFEATED, true)
	var play_failure_closeout := result == "victory" \
		and bool(GlobalState.get_flag(FLAG_FAILURE_RETURN_PENDING))
	GlobalState.remove_meta(META_ALCHEMY_BATTLE_PENDING)
	GlobalState.remove_meta("pending_battle_result")
	return {"returned": true, "failure_closeout": play_failure_closeout}


func get_selected_alchemy_herbs() -> Array[String]:
	return selected_herbs.duplicate()


func set_selected_alchemy_herbs(value: Array[String]) -> void:
	selected_herbs = value.duplicate()
	processing_methods.clear()
	herbs_confirmed = selected_herbs.size() == 3
	alchemy_phase = PHASE_HERBS_CONFIRMED if herbs_confirmed else PHASE_RETRY_NEEDED
	_persist_alchemy_puzzle_state()


func get_alchemy_processing_methods() -> Array[String]:
	return processing_methods.duplicate()


func set_alchemy_processing_methods(value: Array[String]) -> void:
	processing_methods = value.duplicate()
	if not herbs_confirmed or selected_herbs.size() != 3:
		processing_methods.clear()
		alchemy_phase = PHASE_RETRY_NEEDED
	elif processing_methods.is_empty():
		alchemy_phase = PHASE_HERBS_CONFIRMED
	elif processing_methods.size() < selected_herbs.size():
		alchemy_phase = PHASE_PROCESSING
	else:
		alchemy_phase = PHASE_READY_TO_IGNITE
	_persist_alchemy_puzzle_state()


func clear_alchemy_formula(retry_needed := false) -> void:
	selected_herbs.clear()
	processing_methods.clear()
	herbs_confirmed = false
	alchemy_phase = PHASE_RETRY_NEEDED if retry_needed else ""
	_persist_alchemy_puzzle_state()


func prepare_battle_return_actor(player: Node) -> void:
	if not _failure_closeout_pending or player == null:
		return
	player.set("can_move", false)
	player.set("velocity", Vector2.ZERO)
	if player.has_method("set_encounter_paused"):
		player.call("set_encounter_paused", true)


func _restore_alchemy_puzzle_state() -> void:
	selected_herbs.clear()
	processing_methods.clear()
	herbs_confirmed = false
	alchemy_phase = ""
	if bool(GlobalState.get_flag(FLAG_ALCHEMY_SOLVED)):
		GlobalState.clear_alchemy_puzzle_state()
		return
	var state := GlobalState.get_alchemy_puzzle_state()
	var herbs_value = state.get("selected_herbs", [])
	var methods_value = state.get("processing_methods", [])
	if herbs_value is Array:
		for herb in herbs_value:
			selected_herbs.append(String(herb))
	if methods_value is Array:
		for method in methods_value:
			processing_methods.append(String(method))
	herbs_confirmed = bool(state.get("herbs_confirmed", false))
	alchemy_phase = String(state.get("phase", ""))
	if herbs_confirmed and selected_herbs.size() != 3:
		push_warning("[調香室] 已確認取藥狀態損壞，已保留殘方進度並重置配方。")
		clear_alchemy_formula(true)
		_refresh_sewer_puzzle_note()
		return
	if not herbs_confirmed and (not selected_herbs.is_empty() or not processing_methods.is_empty()):
		push_warning("[調香室] 發現未確認的殘留配方資料，已安全重置。")
		clear_alchemy_formula(true)
		_refresh_sewer_puzzle_note()
		return
	if processing_methods.size() > selected_herbs.size():
		push_warning("[調香室] 藥材處理資料超出已選藥材數量，已退回取藥階段。")
		clear_alchemy_formula(true)
		_refresh_sewer_puzzle_note()


func _persist_alchemy_puzzle_state() -> void:
	GlobalState.set_alchemy_puzzle_state({
		"selected_herbs": selected_herbs.duplicate(),
		"processing_methods": processing_methods.duplicate(),
		"herbs_confirmed": herbs_confirmed,
		"phase": alchemy_phase,
	})


func _play_failure_battle_return_closeout() -> void:
	var player := _get_player()
	if player:
		player.visible = true
	var table := get_node_or_null("alchemy_table")
	if table and table.has_method("play_failure_battle_return_closeout"):
		await table.call("play_failure_battle_return_closeout")
	else:
		push_warning("[調香室] 找不到調香台戰後收尾入口，已安全清除錯誤配方。")
	clear_alchemy_formula(true)
	GlobalState.set_flag(FLAG_FAILURE_RETURN_PENDING, false)
	_failure_closeout_pending = false
	_refresh_sewer_puzzle_note()
	_set_alchemy_interactions_locked(false)
	if _owns_menu_lock and GlobalState.has_meta("menu_locked"):
		GlobalState.remove_meta("menu_locked")
	_owns_menu_lock = false
	if player:
		player.set("can_move", true)
		if player.has_method("set_encounter_paused"):
			player.call("set_encounter_paused", false)


func _set_alchemy_interactions_locked(value: bool) -> void:
	for node_name in ["medicine_cabinet", "alchemy_table", "alchemy_recipe"]:
		var target := get_node_or_null(node_name)
		if target:
			target.set("interaction_locked", value)


func _refresh_sewer_puzzle_note() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager and quest_manager.has_method("refresh_sewer_puzzle_note"):
		quest_manager.call("refresh_sewer_puzzle_note")


func _get_player() -> Node:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player == null:
		player = get_node_or_null("/root/Player")
	return player


func _set_entry_idle_direction() -> void:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player == null:
		player = get_node_or_null("/root/Player")
	if player == null or not player.has_method("play_idle_direction"):
		return

	player.call("play_idle_direction", "left_down")
	if player.has_method("restore_idle_control"):
		player.call("restore_idle_control")

func get_map_display_name() -> String:
	return map_display_name

func get_encounter_zone_config(zone_id: String) -> Dictionary:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_ALCHEMY_ENCOUNTER_CONFIG.duplicate(true)
	return {}

func get_encounter_table(zone_id: String) -> Array:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_ALCHEMY_ENCOUNTER_TABLE.duplicate(true)
	return []

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

func _on_to_yuheng_sewer_center_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_alchemy_room"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_center)
