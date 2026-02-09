extends Node

const SLOT_COUNT = 3
const SAVE_FOLDER = "user://save/"
const SAVE_PREFIX = "slot_"
const SAVE_EXT = ".save"
const SAVE_VERSION = 1

func _ensure_save_dir() -> void:
	# 確保 user://save/ 存在（避免 DirAccess.open 失敗）
	DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)

func _as_dict(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}

func _safe_count(value) -> int:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).size()
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).size()
	return 0

	_ensure_save_dir()
	var save_dir = DirAccess.open(SAVE_FOLDER)

	var player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D

	# current_scene 多半是 GameRoot（不是地圖），這裡留作 fallback
	var current_scene = get_tree().current_scene
	var scene_path = ""
		if typeof(scene_file_path) == TYPE_STRING and String(scene_file_path) != "":
			scene_path = String(current_scene.call("get_scene_file_path"))

	# ✅ 真正用來還原地圖的來源：GameRoot.current_map_path
	var game_root = get_node_or_null("/root/GameRoot")
		map_path = String(game_root.get("current_map_path"))
	var save_data = {
		# GlobalState

	var path = _slot_path(slot_index)
	var temp = _slot_temp_path(slot_index)
	var bak = _slot_backup_path(slot_index)
	var f = FileAccess.open(temp, FileAccess.WRITE)
		var err_rename_old = save_dir.rename(path.get_file(), bak.get_file())
	var err_rename_tmp = save_dir.rename(temp.get_file(), path.get_file())

	if not _valid_slot(slot_index):
		push_error("Invalid save slot index.")
		return
	var path = _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		print("No save found in slot %d" % slot_index)
		return

	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to open file for reading: %s" % path)
		return
	var v = f.get_var()
	f.close()

	if typeof(v) != TYPE_DICTIONARY:
		print("[SaveManager] load slot=", slot_index, " invalid root type=", typeof(v))
		return

	var data = v as Dictionary

	# --- 套用資料（提供預設，避免老存檔缺欄位報錯） ---
	var version = int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("Save version (%d) is newer than game version (%d)." % [version, SAVE_VERSION])

	# Managers
	SideQuestManager.load_all(_as_dict(data.get("side_quests", {})))

	# GlobalState
	GlobalState.triggered_flags = _as_dict(data.get("flags", {}))
	GlobalState.relationship = _as_dict(data.get("relationships", {}))
	GlobalState.ethics = int(data.get("ethics", 0))
	GlobalState.grudge = int(data.get("grudge", 0))
	GlobalState.affection = int(data.get("affection", 0))
	GlobalState.last_facing_direction = data.get("last_facing_direction", Vector2(1, 1).normalized())

	# Scene snapshot
	var map_path = String(data.get("current_map_path", ""))
	var scene_path = String(data.get("current_scene_path", ""))

	var game_root = get_node_or_null("/root/GameRoot")
	var player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D

	# ✅ 優先用 map_path 還原（因為 current_scene_path 多半只會是 GameRoot）
	if game_root and game_root.has_method("change_map_to") and map_path != "":
		game_root.change_map_to(map_path)
		await get_tree().process_frame
		player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	elif game_root and game_root.has_method("change_map_to") and scene_path != "":
		game_root.change_map_to(scene_path)
		await get_tree().process_frame
		player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	elif scene_path != "" and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		await get_tree().process_frame
		player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D

	# Player snapshot（放在切換場景之後，以便正確取得玩家節點）
	if player:
		player.global_position = data.get("player_position", player.global_position)

	print("Loaded from slot %d" % slot_index)
	if not _valid_slot(slot_index):
		return {}

	var path = _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {"_status": "empty"}

	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"_status": "empty"}

	var bytes = FileAccess.get_file_as_bytes(path).size()
	var v = f.get_var()
	f.close()

	if typeof(v) != TYPE_DICTIONARY:
			"_status": "invalid",
			"bytes": bytes,
			"root_type": typeof(v),
	var data = v as Dictionary
	return {
		"_status": "ok",
		"timestamp": data.get("timestamp", 0),
		"ethics": data.get("ethics", 0),
		"grudge": data.get("grudge", 0),
		"affection": data.get("affection", 0),
		"flags_count": _safe_count(data.get("flags")),
		"quests_count": _safe_count(data.get("side_quests")),
		"current_scene_path": data.get("current_scene_path", ""),
		"current_map_path": data.get("current_map_path", ""),
	}
						await get_tree().process_frame
						player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
				elif scene_path != "" and ResourceLoader.exists(scene_path):
						get_tree().change_scene_to_file(scene_path)
						await get_tree().process_frame
						player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
						push_warning("GameRoot 缺少 change_map_to，無法切換到保存場景：%s" % scene_path)
				push_error("Invalid save slot index.")
				return

		var path: String = _slot_path(slot_index)
		if not FileAccess.file_exists(path):
				print("No save found in slot %d" % slot_index)
				return

		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
				push_error("Failed to open file for reading: %s" % path)
				return
		var v = f.get_var()
		if typeof(v) != TYPE_DICTIONARY:
				f.close()
				print("[SaveManager] load slot=", slot_index, " invalid root type=", typeof(v))
				return
		var data: Dictionary = v as Dictionary
		f.close()

		# --- 套用資料（提供預設，避免老存檔缺欄位報錯） ---
		var version: int = int(data.get("version", 0))
		if version > SAVE_VERSION:
				push_warning("Save version (%d) is newer than game version (%d)." % [version, SAVE_VERSION])

		# Managers
		SideQuestManager.load_all(_as_dict(data.get("side_quests", {})))

		# GlobalState
		GlobalState.triggered_flags = _as_dict(data.get("flags", {}))
		GlobalState.relationship = _as_dict(data.get("relationships", {}))
		GlobalState.ethics = int(data.get("ethics", 0))
		GlobalState.grudge = int(data.get("grudge", 0))
		GlobalState.affection = int(data.get("affection", 0))
		GlobalState.last_facing_direction = data.get("last_facing_direction", Vector2(1, 1).normalized())

		# Scene snapshot（如果你有自己的場景管理器，這邊可以交給它處理）
		var scene_path: String = data.get("current_scene_path", "")
		var map_id: String = data.get("current_map_id", "")
		var player: Node2D = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
		if scene_path != "" or map_id != "":
				var game_root = get_node_or_null("/root/GameRoot")
				if game_root and game_root.has_method("change_map_to"):
						var target_path = ""
						if map_id != "" and ResourceLoader.exists(map_id):
								target_path = map_id
						elif scene_path != "":
								target_path = scene_path
						if target_path != "":
								await game_root.change_map_to(target_path)
								player = _resolve_player()
				else:
						if scene_path != "" and ResourceLoader.exists(scene_path):
								get_tree().change_scene_to_file(scene_path)
								await get_tree().process_frame
								player = _resolve_player()
						else:
								push_warning("GameRoot 缺少 change_map_to，無法切換到保存場景：%s" % scene_path)

		# Player snapshot（放在切換場景之後，以便正確取得玩家節點）
		if player:
				player.global_position = data.get("player_position", player.global_position)

		print("Loaded from slot %d" % slot_index)

# 讀取存檔的摘要（例如做選單顯示）
func get_slot_summary(slot_index: int) -> Dictionary:
	if not _valid_slot(slot_index):
		return {}
	var path: String = _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {"_status": "empty"}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"_status": "empty"}
	var bytes = FileAccess.get_file_as_bytes(path).size()
	print("[SaveManager] slot=", slot_index, " bytes=", bytes)
	var v = f.get_var()
	print("[SaveManager] slot=", slot_index, " path=", path, " type=", typeof(v))
	if typeof(v) == TYPE_DICTIONARY:
		var keys = (v as Dictionary).keys()
		print("[SaveManager] slot=", slot_index, " keys=", keys)
		var flags_value = (v as Dictionary).get("flags")
		var quests_value = (v as Dictionary).get("side_quests")
		print("[SaveManager] slot=", slot_index, " flags_type=", typeof(flags_value))
		print("[SaveManager] slot=", slot_index, " side_quests_type=", typeof(quests_value))
	if typeof(v) == TYPE_STRING:
		var preview = String(v)
		if preview.length() > 80:
			preview = preview.substr(0, 80)
		print("[SaveManager] slot=", slot_index, " string_preview=", preview)
	elif typeof(v) == TYPE_ARRAY:
		print("[SaveManager] slot=", slot_index, " array_size=", (v as Array).size())
	elif v == null:
		print("[SaveManager] slot=", slot_index, " null")
	if typeof(v) != TYPE_DICTIONARY:
		f.close()
		return {
			"_status": "invalid",
			"bytes": bytes,
			"root_type": typeof(v),
		}
	var data: Dictionary = v as Dictionary
	f.close()
	var flags_value = data.get("flags")
	var quests_value = data.get("side_quests")
	return {
		"_status": "ok",
		"timestamp": data.get("timestamp", 0),
		"ethics": data.get("ethics", 0),
		"grudge": data.get("grudge", 0),
		"affection": data.get("affection", 0),
		"flags_count": _safe_count(flags_value),
		"quests_count": _safe_count(quests_value),
		"current_scene_path": data.get("current_scene_path", ""),
	}

# 小幫手：確認事件是否觸發過（範例）
func has_triggered_market_melody_event() -> bool:
	return GlobalState.get_flag("event_yuheng_market_melody")

func mark_market_melody_event_triggered() -> void:
	GlobalState.set_flag("event_yuheng_market_melody", true)
