extends Node

const SLOT_COUNT = 99
const SLOTS_PER_PAGE = 10
const SAVE_FOLDER = "user://save/"
const SAVE_PREFIX = "slot_"
const SAVE_EXT = ".save"
const SAVE_VERSION = 1
const THUMB_HEIGHT = 270
const FLAG_DABAO_MAP_SHOWN := "yh_side_dabao_map_shown"
const FLAG_DABAO_COIN_HINT := "yh_side_dabao_01_coin_hint"

var cached_world_thumb: Image = null
## 存檔資料夾（預設 SAVE_FOLDER）。測試時改成隔離資料夾，絕不碰正式存檔。
var save_folder: String = SAVE_FOLDER
## 摘要快取：slot_index -> Dictionary。翻頁、選取不再重讀整份存檔；存檔成功後該格會被清掉重讀。
var _summary_cache: Dictionary = {}

func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(save_folder)

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


func _main_quest_display(value) -> String:
	var q = _as_dict(value)
	if q.is_empty():
		return "主線：—"
	var qid = String(q.get("id", ""))
	var stage = int(q.get("stage", 0))
	var desc = String(q.get("description", "")).strip_edges()
	var title = qid if qid != "" else "主線"
	if desc != "":
		return "主線：%s｜第%d步｜%s" % [title, stage, desc]
	return "主線：%s｜第%d步" % [title, stage]

func _slot_path(slot_index: int) -> String:
	return "%s%s%02d%s" % [save_folder, SAVE_PREFIX, slot_index, SAVE_EXT]

func _slot_backup_path(slot_index: int) -> String:
	return "%s%s%02d.bak" % [save_folder, SAVE_PREFIX, slot_index]

func _slot_temp_path(slot_index: int) -> String:
	return "%s%s%02d.tmp" % [save_folder, SAVE_PREFIX, slot_index]

func _valid_slot(slot_index: int) -> bool:
	return slot_index >= 1 and slot_index <= SLOT_COUNT


func _thumb_path(slot_index: int) -> String:
	return "%sthumb_slot_%02d.png" % [save_folder, slot_index]

func _fallback_map_display_name(map_path: String, scene_path: String) -> String:
	var path_for_name: String = map_path if map_path != "" else scene_path
	if path_for_name == "":
		return "未知地點"
	return path_for_name.get_file().get_basename()

func _get_current_map_display_name(map_path: String, scene_path: String) -> String:
	var fallback = _fallback_map_display_name(map_path, scene_path)
	var game_root = get_node_or_null("/root/GameRoot")
	if game_root:
		var current_scene_node = game_root.get_node_or_null("CurrentScene")
		if current_scene_node and current_scene_node.get_child_count() > 0:
			var map_node = current_scene_node.get_child(0)
			if map_node and map_node.has_method("get_map_display_name"):
				var name_v = map_node.call("get_map_display_name")
				if typeof(name_v) == TYPE_STRING and String(name_v).strip_edges() != "":
					return String(name_v).strip_edges()
			if map_node and map_node.get("map_display_name") != null:
				var prop_name = String(map_node.get("map_display_name")).strip_edges()
				if prop_name != "":
					return prop_name
	return fallback

func cache_world_thumbnail() -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	if img == null:
		return
	var src_w = img.get_width()
	var src_h = img.get_height()
	if src_w <= 0 or src_h <= 0:
		return
	# 新存檔的縮圖高度 270（舊存檔的 140 保持原樣、仍可顯示；下次覆寫該格時才換成新尺寸）。
	var target_h = THUMB_HEIGHT
	var target_w = max(1, int(round(float(src_w) * float(target_h) / float(src_h))))
	img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
	cached_world_thumb = img

## 存檔。回傳 true 只代表「檔案真的寫好並改名完成、而且讀得回來」；任何一步失敗都回傳 false（舊檔與縮圖不動）。
func save_to_slot(slot_index: int) -> bool:
	if not _valid_slot(slot_index):
		push_error("Invalid save slot index.")
		return false

	_ensure_save_dir()
	var save_dir = DirAccess.open(save_folder)
	if save_dir == null:
		push_error("Failed to open save directory: %s" % save_folder)
		return false

	var player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D

	# current_scene 多半是 GameRoot（保留當 fallback）
	var current_scene = get_tree().current_scene
	var scene_path = ""
	if current_scene:
		var scene_file_path = current_scene.get("scene_file_path")
		if typeof(scene_file_path) == TYPE_STRING and String(scene_file_path) != "":
			scene_path = String(scene_file_path)
		elif current_scene.has_method("get_scene_file_path"):
			scene_path = String(current_scene.call("get_scene_file_path"))

	# ✅ 正解：用 GameRoot.current_map_path
	var map_path = ""
	var game_root = get_node_or_null("/root/GameRoot")
	if game_root:
		var map_val = game_root.get("current_map_path")
		if typeof(map_val) == TYPE_STRING:
			map_path = String(map_val)

	print("[SaveManager] save slot=", slot_index, " flags_count=", _safe_count(GlobalState.flags), " triggered_flags_count=", _safe_count(GlobalState.triggered_flags))
	var map_display_name = _get_current_map_display_name(map_path, scene_path)
	var thumb_path = _thumb_path(slot_index)
	var main_quest_state: Dictionary = QuestManager.get_main_quest_state() if QuestManager and QuestManager.has_method("get_main_quest_state") else {}

	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		# 主線章節編號：來自正式主線定義（QuestManager.MAIN_QUEST_DEFS），舊存檔沒有這個欄位時由 id 查表還原
		"chapter_number": QuestManager.chapter_number_for_quest(String(main_quest_state.get("id", ""))),

		# Managers
		"side_quests": SideQuestManager.save_all(),
		"main_quest": QuestManager.get_main_quest_state() if QuestManager and QuestManager.has_method("get_main_quest_state") else {},

		# GlobalState
		"flags": GlobalState.flags,
		"triggered_flags": GlobalState.triggered_flags,
		"relationships": GlobalState.relationship,
		"ethics": GlobalState.ethics,
		"grudge": GlobalState.grudge,
		"affection": GlobalState.affection,
		"last_facing_direction": GlobalState.last_facing_direction,
		"shop_runtime_stock": _as_dict(GlobalState.shop_runtime_stock),
		"alchemy_puzzle_state": _as_dict(GlobalState.alchemy_puzzle_state).duplicate(true),
		"team_data": TeamData.export_team_state() if TeamData and TeamData.has_method("export_team_state") else {},
		"inventory_data": InventorySync.export_inventory_state() if InventorySync and InventorySync.has_method("export_inventory_state") else {},

		# Player snapshot
		"player_position": player.global_position if player else Vector2.ZERO,

		# Scene snapshot
		"current_scene_path": scene_path,
		"current_map_path": map_path,
		"map_display_name": map_display_name,
		"thumb_path": thumb_path,
	}

	var path = _slot_path(slot_index)
	var temp = _slot_temp_path(slot_index)
	var bak = _slot_backup_path(slot_index)

	var f = FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open temp save file: %s" % temp)
		return false
	f.store_var(save_data)
	f.flush()
	f.close()

	var had_old := FileAccess.file_exists(path)
	if had_old:
		var err_rename_old = save_dir.rename(path.get_file(), bak.get_file())
		if err_rename_old != OK:
			push_warning("Could not create backup for %s (err %d)" % [path, err_rename_old])
			had_old = false

	var err_rename_tmp = save_dir.rename(temp.get_file(), path.get_file())
	if err_rename_tmp != OK:
		push_error("Failed to finalize save file rename (err %d). Temp remains: %s" % [err_rename_tmp, temp])
		# 舊檔已被改名成 .bak：還原回來，不能讓這格變成「什麼都沒有」
		if had_old and not FileAccess.file_exists(path):
			save_dir.rename(bak.get_file(), path.get_file())
		return false

	# 寫完再驗證一次：讀得回來才算成功
	_summary_cache.erase(slot_index)
	if String(get_slot_summary_cached(slot_index).get("_status", "")) != "ok":
		push_error("Saved file for slot %d could not be read back." % slot_index)
		return false

	# 縮圖在存檔確認成功後才寫入（失敗的存檔不會換掉舊縮圖）
	if cached_world_thumb != null:
		var err_thumb = cached_world_thumb.save_png(thumb_path)
		if err_thumb != OK:
			push_warning("Failed to write thumbnail for slot %d (err %d)" % [slot_index, err_thumb])

	print("Saved to slot %d" % slot_index)
	return true

## 能不能讀這一格：回傳 {"ok": bool, "reason": String}。不改動任何狀態（讀檔前的預檢，失敗就不會進入載入流程）。
func check_slot_loadable(slot_index: int) -> Dictionary:
	if not _valid_slot(slot_index):
		return {"ok": false, "reason": "存檔編號無效"}
	var summary := get_slot_summary_cached(slot_index)
	var status := String(summary.get("_status", "empty"))
	if status == "empty":
		return {"ok": false, "reason": "這一格沒有存檔"}
	if status != "ok":
		return {"ok": false, "reason": "存檔異常"}
	var map_path := String(summary.get("current_map_path", ""))
	var scene_path := String(summary.get("current_scene_path", ""))
	if map_path == "" and scene_path == "":
		return {"ok": false, "reason": "存檔沒有記錄地圖"}
	if map_path != "" and not ResourceLoader.exists(map_path):
		return {"ok": false, "reason": "存檔記錄的地圖已不存在"}
	return {"ok": true, "reason": ""}

## 讀檔。回傳 true = 流程完整跑完；false = 預檢失敗（此時完全沒動遊戲狀態，也不會殘留載入鎖）。
func load_from_slot(slot_index: int) -> bool:
	if not _valid_slot(slot_index):
		push_error("Invalid save slot index.")
		return false

	var path = _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		print("No save found in slot %d" % slot_index)
		return false

	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to open file for reading: %s" % path)
		return false

	var v = f.get_var()
	f.close()

	if typeof(v) != TYPE_DICTIONARY:
		print("[SaveManager] load slot=", slot_index, " invalid root type=", typeof(v))
		return false

	var data = v as Dictionary
	_summary_cache.erase(slot_index)
	if not bool(check_slot_loadable(slot_index).get("ok", false)):
		return false

	# 沒有 GameRoot（例如在編輯器按 F6 單獨測試某張地圖）：先建立 GameRoot 再走完整的還原流程，
	# 不然會落到下面的備用路徑，只載入一個空的 GameRoot（沒有背景的場地），要讀第二次才會正確。
	if get_node_or_null("/root/GameRoot") == null:
		return await load_from_title(slot_index)

	var version = int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("Save version (%d) is newer than game version (%d)." % [version, SAVE_VERSION])

	var menu_ctrl_pre = get_node_or_null("/root/SystemMenu")
	if menu_ctrl_pre and menu_ctrl_pre.has_method("close_menu_if_open"):
		menu_ctrl_pre.call("close_menu_if_open")

	if GlobalState and GlobalState.has_method("begin_load"):
		GlobalState.begin_load()

	# GlobalState（硬化 legacy 欄位）
	print("[SaveManager] load slot=", slot_index, " before flags_count=", _safe_count(GlobalState.flags), " triggered_flags_count=", _safe_count(GlobalState.triggered_flags))
	if GlobalState and GlobalState.has_method("reset_for_load"):
		GlobalState.reset_for_load()
	else:
		GlobalState.flags = {}
		GlobalState.triggered_flags = {}

	var loaded_flags = _as_dict(data.get("flags", {}))
	var loaded_triggered = _as_dict(data.get("triggered_flags", loaded_flags))
	if loaded_flags.is_empty() and not loaded_triggered.is_empty():
		loaded_flags = loaded_triggered.duplicate(true)
	if loaded_triggered.is_empty() and not loaded_flags.is_empty():
		loaded_triggered = loaded_flags.duplicate(true)
	_migrate_legacy_dabao_flags(loaded_flags, loaded_triggered)
	GlobalState.flags = loaded_flags
	GlobalState.triggered_flags = loaded_triggered
	print("[SaveManager] load slot=", slot_index, " imported flags_count=", _safe_count(GlobalState.flags), " triggered_flags_count=", _safe_count(GlobalState.triggered_flags))

	GlobalState.relationship = _as_dict(data.get("relationships", {}))
	GlobalState.ethics = int(data.get("ethics", 0))
	GlobalState.grudge = int(data.get("grudge", 0))
	GlobalState.affection = int(data.get("affection", 0))
	GlobalState.last_facing_direction = data.get("last_facing_direction", Vector2(1, 1).normalized())
	GlobalState.shop_runtime_stock = _as_dict(data.get("shop_runtime_stock", {}))
	GlobalState.alchemy_puzzle_state = _as_dict(data.get("alchemy_puzzle_state", {})).duplicate(true)

	var map_path = String(data.get("current_map_path", ""))
	var scene_path = String(data.get("current_scene_path", ""))
	var saved_player_position: Vector2 = data.get("player_position", Vector2.ZERO)

	var game_root = get_node_or_null("/root/GameRoot")
	var player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	var initial_player_position = player.global_position if player else Vector2.ZERO
	print("[SaveManager] load slot=", slot_index, " begin map_path=", map_path, " scene_path=", scene_path, " initial_player_pos=", initial_player_position, " saved_player_pos=", saved_player_position)
	if game_root and game_root.has_method("lock_map_transitions"):
		game_root.lock_map_transitions("save_load")

	# ✅ 優先 map_path
	if game_root and game_root.has_method("change_map_to") and map_path != "":
		# 如果你的 change_map_to 是 coroutine，這樣寫也 OK（不想 await 也能跑）
		await game_root.change_map_to(map_path)
		await get_tree().process_frame
		player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
		print("[SaveManager] after map load spawn_player_pos=", player.global_position if player else Vector2.ZERO, " target_saved_pos=", saved_player_position)
	elif game_root and game_root.has_method("change_map_to") and scene_path != "":
		await game_root.change_map_to(scene_path)
		await get_tree().process_frame
		player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
		print("[SaveManager] after scene load spawn_player_pos=", player.global_position if player else Vector2.ZERO, " target_saved_pos=", saved_player_position)
	elif scene_path != "" and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		await get_tree().process_frame
		player = get_node_or_null("/root/GameRoot/LiuYu") as Node2D
		print("[SaveManager] after direct scene load spawn_player_pos=", player.global_position if player else Vector2.ZERO, " target_saved_pos=", saved_player_position)

	if player:
		player.global_position = saved_player_position
		await get_tree().process_frame
		await get_tree().physics_frame
		if game_root and game_root.has_method("disarm_overlapping_map_exits"):
			game_root.disarm_overlapping_map_exits(player)
		if player.has_method("refresh_danger_zone_from_position"):
			await player.refresh_danger_zone_from_position(0.7)
		print("[SaveManager] final_player_pos=", player.global_position, " loading=", GlobalState.get("is_loading"))

	# Managers + runtime snapshot（地圖切換完成後再套用，避免 _ready 初始化覆蓋）
	if SideQuestManager and SideQuestManager.has_method("reset_all"):
		SideQuestManager.reset_all()
	if QuestManager and QuestManager.has_method("reset_main_quest"):
		QuestManager.reset_main_quest()

	SideQuestManager.load_all(_as_dict(data.get("side_quests", {})))
	if QuestManager and QuestManager.has_method("load_main_quest"):
		QuestManager.load_main_quest(_as_dict(data.get("main_quest", {})))
	if TeamData and TeamData.has_method("import_team_state"):
		TeamData.import_team_state(_as_dict(data.get("team_data", {})))
	# 舊存檔裡已經正式入隊、卻停在 Lv2 的書眠：補到序章該有的 Lv6（條件與細節見 YuhengPrologueState）
	YuhengPrologueState.repair_shumian_join_level()
	# 舊存檔：補符支線已完成、書眠卻沒有真的學會澄心落筆／清渠共印（舊版只寫旗標）→ 補發（條件與細節見 YuhengPrologueState）
	YuhengPrologueState.repair_qudeng_rewards()
	# 舊存檔：舊水道搜刮只寫了領取旗標與假記號、背包沒有東西 → 補發（條件很窄，見 YuhengPrologueState.repair_sewer_loot_items）
	YuhengPrologueState.repair_sewer_loot_items()
	if InventorySync and InventorySync.has_method("import_inventory_state"):
		InventorySync.import_inventory_state(_as_dict(data.get("inventory_data", {})))

	print("[SaveManager] load slot=", slot_index, " post-import flags_count=", _safe_count(GlobalState.flags), " triggered_flags_count=", _safe_count(GlobalState.triggered_flags))

	if GlobalState and GlobalState.has_method("end_load"):
		GlobalState.end_load()
	if game_root and game_root.has_method("unlock_map_transitions"):
		game_root.unlock_map_transitions("save_load")

	var menu_ctrl = get_node_or_null("/root/SystemMenu")
	if menu_ctrl and menu_ctrl.has_method("close_menu_if_open"):
		menu_ctrl.call("close_menu_if_open")

	print("Loaded from slot %d" % slot_index)
	return true

func _migrate_legacy_dabao_flags(loaded_flags: Dictionary, loaded_triggered: Dictionary) -> void:
	var coin_hint_completed := (
		bool(loaded_flags.get(FLAG_DABAO_COIN_HINT, false))
		or bool(loaded_triggered.get(FLAG_DABAO_COIN_HINT, false))
	)
	if coin_hint_completed:
		if not bool(loaded_flags.get(FLAG_DABAO_MAP_SHOWN, false)):
			loaded_flags[FLAG_DABAO_MAP_SHOWN] = true
		if not bool(loaded_triggered.get(FLAG_DABAO_MAP_SHOWN, false)):
			loaded_triggered[FLAG_DABAO_MAP_SHOWN] = true

## 摘要（有快取）：翻頁、選取不會重讀整份存檔；save_to_slot 成功後該格會清掉快取。
func get_slot_summary_cached(slot_index: int) -> Dictionary:
	if _summary_cache.has(slot_index):
		return _summary_cache[slot_index]
	var summary := get_slot_summary(slot_index)
	if not summary.is_empty():
		_summary_cache[slot_index] = summary
	return summary

func invalidate_summary_cache(slot_index: int = -1) -> void:
	if slot_index < 0:
		_summary_cache.clear()
	else:
		_summary_cache.erase(slot_index)

## 章節數字 → 顯示文字；0 或未知 = 章節未記錄
static func chapter_text(chapter_number: int) -> String:
	var digits := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	if chapter_number >= 1 and chapter_number < digits.size():
		return "第%s章" % digits[chapter_number]
	if chapter_number > 0:
		return "第%d章" % chapter_number
	return "章節未記錄"

func get_slot_summary(slot_index: int) -> Dictionary:
	if not _valid_slot(slot_index):
		return {}

	var path = _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {"_status": "empty"}

	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"_status": "invalid", "reason": "open_failed"}

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
	var map_path: String = String(data.get("current_map_path", ""))
	var scene_path: String = String(data.get("current_scene_path", ""))
	var main_quest: Dictionary = _as_dict(data.get("main_quest", {}))
	# 章節：新存檔直接記錄；舊存檔沒有這欄 → 用主線 id 查正式定義還原；查不到就是 0（章節未記錄）
	# 主角（劉語塵）的等級：來自存檔內的隊伍資料；舊存檔一樣有，缺少就是 0（未記錄）
	var leader_level := int(_as_dict(_as_dict(_as_dict(data.get("team_data", {})).get("all_characters", {})).get("liuyu", {})).get("level", 0))
	# 隊伍陣容：[{id, level}]，順序依存檔的 current_team_ids（主角在前）；名字不存檔，顯示時由 actor_display_name 查
	var party: Array = []
	var team_data: Dictionary = _as_dict(data.get("team_data", {}))
	var all_chars: Dictionary = _as_dict(team_data.get("all_characters", {}))
	var ids = team_data.get("current_team_ids", [])
	if typeof(ids) == TYPE_ARRAY:
		for id_any in ids:
			var id := String(id_any)
			party.append({"id": id, "level": int(_as_dict(all_chars.get(id, {})).get("level", 0))})
	var chapter_number := int(data.get("chapter_number", 0))
	if chapter_number <= 0:
		chapter_number = QuestManager.chapter_number_for_quest(String(main_quest.get("id", "")))
	return {
		"_status": "ok",
		"timestamp": data.get("timestamp", 0),
		"ethics": data.get("ethics", 0),
		"grudge": data.get("grudge", 0),
		"affection": data.get("affection", 0),
		"flags_count": _safe_count(data.get("flags")),
		"quests_count": _safe_count(data.get("side_quests")),
		"current_scene_path": scene_path,
		"current_map_path": map_path,
		"map_display_name": data.get("map_display_name", _fallback_map_display_name(map_path, scene_path)),
		"thumb_path": data.get("thumb_path", ""),
		"main_quest_id": main_quest.get("id", ""),
		"main_quest_stage": int(main_quest.get("stage", 0)),
		"main_quest_description": main_quest.get("description", ""),
		"main_quest_display": _main_quest_display(main_quest),
		"chapter_number": chapter_number,
		"chapter_text": chapter_text(chapter_number),
		"leader_level": leader_level,
		"party": party,
	}


## 主選單讀檔：先預檢（失敗就什麼都不動，標題畫面保留）→ 建立全新的 GameRoot（不播開場）並取代標題畫面
## → 交給 load_from_slot 走和遊戲內讀檔完全相同的正式還原順序 → 成功後把控制權交給玩家。
## 這裡不另寫第二套還原邏輯。
func load_from_title(slot_index: int) -> bool:
	_summary_cache.erase(slot_index)
	if not bool(check_slot_loadable(slot_index).get("ok", false)):
		return false
	if get_node_or_null("/root/GameRoot") != null:
		push_warning("load_from_title: GameRoot already exists; use load_from_slot instead.")
		return false

	var game_root: Node = load("res://scenes/game_root.tscn").instantiate()
	game_root.set("go_to_intro_on_start", false)
	var old_scene := get_tree().current_scene
	get_tree().root.add_child(game_root)
	get_tree().current_scene = game_root
	if old_scene != null:
		old_scene.queue_free()
	await get_tree().process_frame

	var ok: bool = await load_from_slot(slot_index)
	if not ok:
		# 預檢已過、仍失敗的極端情況：GameRoot 是空的，不能把玩家留在空場景
		push_error("load_from_title: load_from_slot failed after GameRoot was created.")
		if GlobalState and GlobalState.has_method("end_load"):
			GlobalState.end_load()
		var gr := get_node_or_null("/root/GameRoot")
		if gr and gr.has_method("unlock_map_transitions"):
			gr.call("unlock_map_transitions", "title_load_failed")
		return false

	# 存檔只會在玩家可以行動時產生，所以讀完直接交還控制權
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player != null:
		player.set("can_move", true)
	return true

## 角色顯示名稱（存檔不記名字）：優先用隊伍資料庫，查不到用內建對照，再不行就用 id
func actor_display_name(actor_id: String) -> String:
	var tm := get_node_or_null("/root/TeamData")
	if tm != null:
		var chars = tm.get("all_characters")
		if typeof(chars) == TYPE_DICTIONARY and (chars as Dictionary).has(actor_id):
			var n := String(_as_dict((chars as Dictionary)[actor_id]).get("name", ""))
			if n != "":
				return n
	return {"liuyu": "劉語塵", "shumian": "書眠", "lieshao": "列霄"}.get(actor_id, actor_id)

## 縮圖檔路徑（給 UI 用；跟隨 save_folder，不再使用存檔裡記的字串路徑）
func thumb_path_for_slot(slot_index: int) -> String:
	return _thumb_path(slot_index)

func slot_count() -> int:
	return SLOT_COUNT

func page_count() -> int:
	return int(ceil(float(SLOT_COUNT) / float(SLOTS_PER_PAGE)))
