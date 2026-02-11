extends Node

const SLOT_COUNT = 3
const SAVE_FOLDER = "user://save/"
const SAVE_PREFIX = "slot_"
const SAVE_EXT = ".save"
const SAVE_VERSION = 1

func _ensure_save_dir() -> void:
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

func _slot_path(slot_index: int) -> String:
	return "%s%s%02d%s" % [SAVE_FOLDER, SAVE_PREFIX, slot_index, SAVE_EXT]

func _slot_backup_path(slot_index: int) -> String:
	return "%s%s%02d.bak" % [SAVE_FOLDER, SAVE_PREFIX, slot_index]

func _slot_temp_path(slot_index: int) -> String:
	return "%s%s%02d.tmp" % [SAVE_FOLDER, SAVE_PREFIX, slot_index]

func _valid_slot(slot_index: int) -> bool:
	return slot_index >= 1 and slot_index <= SLOT_COUNT

func save_to_slot(slot_index: int) -> void:
	if not _valid_slot(slot_index):
		push_error("Invalid save slot index.")
		return

	_ensure_save_dir()
	var save_dir = DirAccess.open(SAVE_FOLDER)
	if save_dir == null:
		push_error("Failed to open save directory: %s" % SAVE_FOLDER)
		return

	var player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D

	# current_scene 多半是 GameRoot（保留當 fallback）
	var current_scene = get_tree().current_scene
	var scene_path := ""
	if current_scene:
		var scene_file_path = current_scene.get("scene_file_path")
		if typeof(scene_file_path) == TYPE_STRING and String(scene_file_path) != "":
			scene_path = String(scene_file_path)
		elif current_scene.has_method("get_scene_file_path"):
			scene_path = String(current_scene.call("get_scene_file_path"))

	# ✅ 正解：用 GameRoot.current_map_path
	var map_path := ""
	var game_root = get_node_or_null("/root/GameRoot")
	if game_root:
		var map_val = game_root.get("current_map_path")
		if typeof(map_val) == TYPE_STRING:
			map_path = String(map_val)

	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),

		# Managers
		"side_quests": SideQuestManager.save_all(),

		# GlobalState
		"flags": GlobalState.triggered_flags,
		"relationships": GlobalState.relationship,
		"ethics": GlobalState.ethics,
		"grudge": GlobalState.grudge,
		"affection": GlobalState.affection,
		"last_facing_direction": GlobalState.last_facing_direction,

		# Player snapshot
		"player_position": player.global_position if player else Vector2.ZERO,

		# Scene snapshot
		"current_scene_path": scene_path,
		"current_map_path": map_path,
	}

	var path = _slot_path(slot_index)
	var temp = _slot_temp_path(slot_index)
	var bak = _slot_backup_path(slot_index)

	var f = FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open temp save file: %s" % temp)
		return
	f.store_var(save_data)
	f.flush()
	f.close()

	if FileAccess.file_exists(path):
		var err_rename_old = save_dir.rename(path.get_file(), bak.get_file())
		if err_rename_old != OK:
			push_warning("Could not create backup for %s (err %d)" % [path, err_rename_old])

	var err_rename_tmp = save_dir.rename(temp.get_file(), path.get_file())
	if err_rename_tmp != OK:
		push_error("Failed to finalize save file rename (err %d). Temp remains: %s" % [err_rename_tmp, temp])
		return

	print("Saved to slot %d" % slot_index)

func load_from_slot(slot_index: int) -> void:
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

	var version = int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("Save version (%d) is newer than game version (%d)." % [version, SAVE_VERSION])

	# Managers
	SideQuestManager.load_all(_as_dict(data.get("side_quests", {})))

	# GlobalState（硬化 legacy 欄位）
	GlobalState.triggered_flags = _as_dict(data.get("flags", {}))
	GlobalState.relationship = _as_dict(data.get("relationships", {}))
	GlobalState.ethics = int(data.get("ethics", 0))
	GlobalState.grudge = int(data.get("grudge", 0))
	GlobalState.affection = int(data.get("affection", 0))
	GlobalState.last_facing_direction = data.get("last_facing_direction", Vector2(1, 1).normalized())

	var map_path = String(data.get("current_map_path", ""))
	var scene_path = String(data.get("current_scene_path", ""))

	var game_root = get_node_or_null("/root/GameRoot")
	var player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D

	# ✅ 優先 map_path
	if game_root and game_root.has_method("change_map_to") and map_path != "":
		# 如果你的 change_map_to 是 coroutine，這樣寫也 OK（不想 await 也能跑）
		await game_root.change_map_to(map_path)
		await get_tree().process_frame
		player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	elif game_root and game_root.has_method("change_map_to") and scene_path != "":
		await game_root.change_map_to(scene_path)
		await get_tree().process_frame
		player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	elif scene_path != "" and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		await get_tree().process_frame
		player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D

	if player:
		player.global_position = data.get("player_position", player.global_position)

	print("Loaded from slot %d" % slot_index)

func get_slot_summary(slot_index: int) -> Dictionary:
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
		return {
			"_status": "invalid",
			"bytes": bytes,
			"root_type": typeof(v),
		}

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
