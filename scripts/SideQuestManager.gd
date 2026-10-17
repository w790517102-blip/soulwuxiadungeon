extends Node

# 支線任務容器：quest_id : Dictionary
var side_quests := {}

func _toast(text: String) -> void:
	var toast = get_node_or_null("/root/MessageToast")
	if toast and toast.has_method("push_message"):
		toast.push_message(text)

# 註冊任務：初始化階段與完成狀態
func register_quest(id: String, data: Dictionary) -> void:
	if GlobalState and GlobalState.get("is_loading") == true:
		if not side_quests.has(id) and not data.is_empty():
			side_quests[id] = data.duplicate(true)
		return
	if not side_quests.has(id):
		side_quests[id] = data
		side_quests[id]["stage"] = 0
		side_quests[id]["is_finished"] = false
		print("[支線] 已註冊任務：%s" % id)
		var quest_title = str(side_quests[id].get("title", "")).strip_edges()
		if quest_title != "":
			_toast("已新增支線任務")

# 推進任務階段
func advance_quest(id: String, new_stage: int) -> void:
	if not side_quests.has(id): return
	side_quests[id]["stage"] = new_stage
	print("[支線] 任務 %s 已推進至第 %d 階段" % [id, new_stage])

# 完成任務
func complete_quest(id: String) -> void:
	if side_quests.has(id):
		side_quests[id]["is_finished"] = true
		print("[支線] 任務 %s 已完成" % id)
		_toast("已完成支線任務")

# 取得任務資料
func get_quest(id: String) -> Dictionary:
	return side_quests.get(id, {})

# 錯過：任務沒有完成就永遠關閉（序章限定的支線在離開玉衡鎮時使用）。這不是任務失敗，只是終止狀態。
# 沒接取過的任務也可以直接標記為錯過（此時用 data 建立紀錄，不跳出「已新增支線任務」提示）。
func mark_quest_missed(id: String, data: Dictionary = {}) -> void:
	if not side_quests.has(id):
		if data.is_empty():
			return
		side_quests[id] = data.duplicate(true)
		side_quests[id]["stage"] = 0
		side_quests[id]["is_finished"] = false
	if bool(side_quests[id].get("is_finished", false)):
		return
	if not data.is_empty():
		side_quests[id]["current_objective"] = data.get("current_objective", side_quests[id].get("current_objective", ""))
	side_quests[id]["is_missed"] = true
	print("[支線] 任務 %s 已錯過" % id)

func is_quest_missed(id: String) -> bool:
	return side_quests.has(id) and bool(side_quests[id].get("is_missed", false))

# 檢查是否完成
func is_quest_finished(id: String) -> bool:
	return side_quests.has(id) and side_quests[id]["is_finished"]

# 重置任務
func reset_quest(id: String) -> void:
	if side_quests.has(id):
		side_quests[id]["stage"] = 0
		side_quests[id]["is_finished"] = false

# ✅ 儲存所有支線任務資料
func save_all() -> Dictionary:
	return side_quests.duplicate(true)

# ✅ 載入任務資料（從存檔）
func load_all(saved_data: Dictionary) -> void:
	side_quests = saved_data.duplicate(true)

func reset_all() -> void:
	side_quests.clear()

func notify_objective_updated(_text: String) -> void:
	pass
