extends Node2D
class_name YuhengSewerMusicRoom

@export var music_manager_path: NodePath
@export var final_room_flag := "sewer_music_solved"

var music_manager: MusicRoomManager


func _ready() -> void:
	music_manager = _resolve_music_manager()

	if music_manager:
		if not music_manager.music_puzzle_solved.is_connected(_on_music_puzzle_solved):
			music_manager.music_puzzle_solved.connect(_on_music_puzzle_solved)
	else:
		push_warning("YuhengSewerMusicRoom 找不到 MusicRoomManager")


func _on_music_puzzle_solved() -> void:
	print("舊水道調音室機關已解除。")

	# 這裡先保留給 Codex 大小姐接後續流程：
	# 1. 更新終端房 seal icon
	# 2. 播放機關動畫或 SFX
	# 3. 更新任務提示
	#
	# MusicRoomManager 已經會寫入 sewer_music_solved。
	# 若你的專案 final room 使用不同 flag，可在這裡另外同步。
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
