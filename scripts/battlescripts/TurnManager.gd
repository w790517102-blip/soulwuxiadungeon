# TurnManager.gd
# ✅ 管理語破江沽的回合制角色輪替與回合階段流程

extends Node

signal turn_started(actor: Dictionary)
signal turn_ended(actor: Dictionary)
signal round_started(round_number: int)
signal round_ended(round_number: int)

# 回合資料
var round_count: int = 1
var turn_queue: Array = []
var current_index: int = 0
var active_actor: Dictionary = {}
var is_waiting_for_player := false

# 外部資料來源（從 BattleController 注入）
var player_party: Array = []
var enemy_party: Array = []

# 自訂比較：快 > 遲 > 柔 > 剛（若未設定 speed，預設 0）
func _compare_speed(a: Dictionary, b: Dictionary) -> bool:
	return a.get("speed", 0) > b.get("speed", 0)

# === 記憶阿達雷勒現象 ===
var round_in_progress := false

# 初始化並開始第一回合
func start_battle(players: Array, enemies: Array) -> void:
	player_party = players
	enemy_party = enemies
	round_count = 1
	call_deferred("start_new_round")

# 產生新一輪行動順序
func start_new_round() -> void:
	if round_in_progress:
		return  # 避免重複啟動

	round_in_progress = true
	emit_signal("round_started", round_count)

	turn_queue.clear()
	turn_queue += player_party + enemy_party
	turn_queue = turn_queue.filter(func(a): return a.get("hp", 1) > 0)
	turn_queue.sort_custom(Callable(self, "_compare_speed"))
	current_index = 0

	call_deferred("next_turn")

# 執行下一位角色行動
func next_turn() -> void:
	if is_waiting_for_player:
		print("🛑 尚未完成玩家回合，禁止進入下一角色")
		return

	if current_index >= turn_queue.size():
		print("⚠️ [TURN] 回合索引超界，結束 round")
		emit_signal("round_ended", round_count)
		round_count += 1
		round_in_progress = false
		call_deferred("start_new_round")
		return

	active_actor = turn_queue[current_index]

	# ✅ 若是玩家角色，啟用回合鎖
	if active_actor in player_party:
		is_waiting_for_player = true

	print("【NEXT TURN】%s" % active_actor.name)
	emit_signal("turn_started", active_actor)

# 當角色完成行動時呼叫此方法
func end_turn() -> void:
	if round_in_progress == false:
		print("⛔ 嘗試結束非進行中回合，略過")
		return

	if is_waiting_for_player:
		print("🔓 玩家回合結束：%s" % active_actor.name)
	else:
		print("🔚 敵方回合結束：%s" % active_actor.name)

	is_waiting_for_player = false
	current_index += 1

	if current_index >= turn_queue.size():
		print("⚠️ [TURN] 回合索引超界，結束 round")
		round_in_progress = false
		emit_signal("round_ended", round_count)
		round_count += 1
		call_deferred("start_new_round")
	else:
		call_deferred("next_turn")

# ✅ 用於外部檢查是否輪到我方角色
func is_player_turn() -> bool:
	return active_actor in player_party

# ✅ 用於外部查詢目前行動角色
func get_current_actor() -> Dictionary:
	return active_actor
