extends Node

const SAVE_FOLDER := "user://save/"
const SLOT_COUNT := 3
const SAVE_PREFIX := "slot_"
const SAVE_EXT := ".save"
const SAVE_VERSION := 1

func _ready():
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("save"):
		dir.make_dir("save")

func _safe_count(value: Variant) -> int:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).size()
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).size()
	return 0

func _as_dict(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}

# --- helpers ---
func _slot_path(slot_index: int) -> String:
	return "%s%s%02d%s" % [SAVE_FOLDER, SAVE_PREFIX, slot_index, SAVE_EXT]

func _slot_backup_path(slot_index: int) -> String:
	return "%s%s%02d.bak" % [SAVE_FOLDER, SAVE_PREFIX, slot_index]

func _slot_temp_path(slot_index: int) -> String:
	return "%s%s%02d.tmp" % [SAVE_FOLDER, SAVE_PREFIX, slot_index]

func _valid_slot(slot_index: int) -> bool:
	return slot_index >= 1 and slot_index <= SLOT_COUNT

# --- public API ---
# 儲存遊戲資料（含任務、全域旗標、屬性、主角位置、場景等）
func save_to_slot(slot_index: int) -> void:
	if not _valid_slot(slot_index):
		push_error("Invalid save slot index.")
		return

	var player: Node2D = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	var current_scene: Node = get_tree().current_scene
	var scene_path: String = ""
	if current_scene and current_scene.has_method("get_scene_file_path"):
		scene_path = current_scene.call("get_scene_file_path") as String
	elif current_scene and current_scene.has_meta("_edit_lock_" ):
		# Fallback（有些情形 current_scene.scene_file_path 可直接讀）
		scene_path = current_scene.get("scene_file_path") if current_scene.has("scene_file_path") else ""

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		# Managers
		"side_quests": SideQuestManager.save_all(),
		# GlobalState（完整持久化，避免健忘）
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
	}

	var path: String = _slot_path(slot_index)
	var temp: String = _slot_temp_path(slot_index)
	var bak: String = _slot_backup_path(slot_index)

	# 先寫入 .tmp，成功後再覆蓋正式檔（避免半寫入損毀檔案）
	var f: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open temp save file: %s" % temp)
		return
	f.store_var(save_data)
	f.flush()
	f.close()

	var dir: DirAccess = DirAccess.open(SAVE_FOLDER)
	if FileAccess.file_exists(path):
		# 舊檔改名為 .bak
		var err_rename_old: int = dir.rename(path.get_file(), bak.get_file())
		if err_rename_old != OK:
			push_warning("Could not create backup for %s (err %d)" % [path, err_rename_old])

	# .tmp 改名為正式檔
	var err_rename_tmp: int = dir.rename(temp.get_file(), path.get_file())
	if err_rename_tmp != OK:
		push_error("Failed to finalize save file rename (err %d). Temp remains: %s" % [err_rename_tmp, temp])
		return

	print("Saved to slot %d" % slot_index)

# 載入遊戲資料並套用（包含向下相容）
func load_from_slot(slot_index: int) -> void:
		if not _valid_slot(slot_index):
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
		var v := f.get_var()
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
		var player: Node2D = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
		if scene_path != "":
				var game_root := get_node_or_null("/root/GameRoot")
				if game_root and game_root.has_method("change_map_to"):
						await game_root.change_map_to(scene_path)
						player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
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
	var bytes := FileAccess.get_file_as_bytes(path).size()
	print("[SaveManager] slot=", slot_index, " bytes=", bytes)
	var v := f.get_var()
	print("[SaveManager] slot=", slot_index, " path=", path, " type=", typeof(v))
	if typeof(v) == TYPE_DICTIONARY:
		var keys := (v as Dictionary).keys()
		print("[SaveManager] slot=", slot_index, " keys=", keys)
		var flags_value = (v as Dictionary).get("flags")
		var quests_value = (v as Dictionary).get("side_quests")
		print("[SaveManager] slot=", slot_index, " flags_type=", typeof(flags_value))
		print("[SaveManager] slot=", slot_index, " side_quests_type=", typeof(quests_value))
	if typeof(v) == TYPE_STRING:
		var preview := String(v)
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
