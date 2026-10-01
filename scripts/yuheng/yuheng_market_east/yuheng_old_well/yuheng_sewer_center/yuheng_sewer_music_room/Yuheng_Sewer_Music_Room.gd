extends Node2D
class_name YuhengSewerMusicRoom

@onready var yuheng_sewer_center: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_center.tscn"
@export var music_manager_path: NodePath
@export var final_room_flag := "sewer_music_solved"
@export var music_tag := "yuheng_sewer"
@export var map_display_name: String = "玉衡鎮下水道調音室"
@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")

const SEWER_ZONE_ID := "yuheng_sewer"
const SEWER_MUSIC_ENCOUNTER_CONFIG := {
	"encounter_region_id": "yuheng_sewer",
	"encounter_profile_id": "yuheng_sewer_pressure_v1",
	"distance_threshold": 240.0,
	"chance": 0.30,
	"cooldown_distance": 280.0,
	"intro_key": "yuheng_sewer_music_random"
}
const SEWER_MUSIC_ENCOUNTER_TABLE := [
	{"w": 10, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 14, "enemies": ["yumei_sewer_bat", "yumei_sewer_bat"]},
	{"w": 6, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 8, "enemies": ["yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 7, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 7, "enemies": ["yumei_sewer_rat", "yumei_sewer_bat", "yumei_sewer_bat"]},
	{"w": 6, "enemies": ["turbid_tone_phantom", "yumei_sewer_rat"]},
	{"w": 4, "enemies": ["turbid_tone_phantom", "yumei_sewer_bat"]},
	{"w": 10, "enemies": ["broken_string_tone_phantom", "yumei_sewer_rat"]},
	{"w": 9, "enemies": ["broken_string_tone_phantom", "yumei_sewer_bat"]},
	{"w": 4, "enemies": ["broken_string_tone_phantom", "yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 3, "enemies": ["broken_string_tone_phantom", "yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 7, "enemies": ["echo_tone_phantom"]},
	{"w": 3, "enemies": ["echo_tone_phantom", "yumei_sewer_rat"]},
	{"w": 2, "enemies": ["echo_tone_phantom", "broken_string_tone_phantom"]}
]

var music_manager: MusicRoomManager


func _ready() -> void:
	_set_player_movable(false)
	await _play_entry_fade()
	show_map_name()

	music_manager = _resolve_music_manager()

	if music_manager:
		if not music_manager.music_puzzle_solved.is_connected(_on_music_puzzle_solved):
			music_manager.music_puzzle_solved.connect(_on_music_puzzle_solved)
	else:
		push_warning("YuhengSewerMusicRoom 找不到 MusicRoomManager")

	# 地名 UI 繼續依原時長播放；BlackOverlay 淡出並完成同步初始化後立即交還控制。
	# Manager 或其他互動節點缺失時也必須完成進場交接，不能把常駐玩家留在鎖定狀態。
	_set_player_movable(true)


func _play_entry_fade() -> void:
	if overlay == null:
		push_warning("YuhengSewerMusicRoom 找不到 BlackOverlay，略過淡出並繼續進場。")
		return

	overlay.visible = true
	overlay.modulate.a = 1.0
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween.finished
	overlay.visible = false


func show_map_name() -> void:
	var map_popup := get_node_or_null("CanvasLayer/MapNamePopup") as Label
	if map_popup == null:
		push_warning("YuhengSewerMusicRoom 找不到 CanvasLayer/MapNamePopup，略過地名顯示。")
		return

	map_popup.text = map_display_name
	map_popup.visible = true
	map_popup.modulate.a = 1.0
	await get_tree().create_timer(2.0).timeout

	var tween := map_popup.create_tween()
	tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
	await tween.finished
	map_popup.visible = false


func _set_player_movable(value: bool) -> void:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player == null:
		player = get_node_or_null("/root/Player")
	if player == null:
		return

	player.set("can_move", value)
	if not value and player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO

func get_encounter_zone_config(zone_id: String) -> Dictionary:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_MUSIC_ENCOUNTER_CONFIG.duplicate(true)
	return {}

func get_encounter_table(zone_id: String) -> Array:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_MUSIC_ENCOUNTER_TABLE.duplicate(true)
	return []


func _on_music_puzzle_solved() -> void:
	print("舊水道調音室機關已解除。")

	# MusicRoomManager 已經寫入 sewer_music_solved；終端房載入時會直接
	# 從 GlobalState 重建琴徽印狀態，不需要跨場景尋找或更新節點。
	# 若相容場景明確指定另一枚旗標，才在本房間同步該旗標。
	if final_room_flag != "sewer_music_solved":
		_set_flag(final_room_flag, true)


func force_complete_music_puzzle() -> void:
	# Debug 用：需要時可從 Godot console 或測試事件呼叫。
	_set_flag("sewer_music_solved", true)
	_set_flag(final_room_flag, true)


func _resolve_music_manager() -> MusicRoomManager:
	if music_manager_path != NodePath():
		var node := get_node_or_null(music_manager_path)
		if node is MusicRoomManager:
			return node

	var direct := get_node_or_null("MusicRoomManager")
	if direct is MusicRoomManager:
		return direct

	for child in get_children():
		if child is MusicRoomManager:
			return child

	return null


func _set_flag(flag_name: String, value) -> void:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state == null:
		global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state == null:
		push_warning("找不到 GlobalState，無法寫入：" + flag_name)
		return

	if global_state.has_method("set_flag"):
		global_state.set_flag(flag_name, value)
	else:
		global_state.set(flag_name, value)


func _on_to_yuheng_sewer_center_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_music_room"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_center)
