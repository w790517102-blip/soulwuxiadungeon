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
var is_waiting_for_player = false
var round_roster: Array = []
var acted_this_round: Dictionary = {}
var round_end_emitted = false

# 外部資料來源（從 BattleController 注入）
var player_party: Array = []
var enemy_party: Array = []

# 自訂比較：快 > 遲 > 柔 > 剛（若未設定 speed，預設 0）
func _compare_speed(a: Dictionary, b: Dictionary) -> bool:
	return a.get("speed", 0) > b.get("speed", 0)

# === 記憶阿達雷勒現象 ===
var round_in_progress = false

# 初始化並開始第一回合
func start_battle(players: Array, enemies: Array) -> void:
	player_party = players
	enemy_party = enemies
	round_count = 1
	call_deferred("start_new_round")

# 產生新一輪行動順序
func start_new_round() -> void:
	if _is_battle_ending():
		return
	if round_in_progress:
		return  # 避免重複啟動

	round_in_progress = true
	round_end_emitted = false
	_build_round_roster()
	emit_signal("round_started", round_count)

	turn_queue.clear()
	turn_queue += player_party + enemy_party
	turn_queue = turn_queue.filter(func(a): return _is_actor_alive(a))
	turn_queue.sort_custom(Callable(self, "_compare_speed"))
	current_index = 0

	call_deferred("next_turn")

# 執行下一位角色行動
func next_turn() -> void:
	if _is_battle_ending():
		return
	if is_waiting_for_player:
		print("🛑 尚未完成玩家回合，禁止進入下一角色")
		return

	if current_index >= turn_queue.size():
		print("⚠️ [TURN] 回合索引超界，檢查回合結束")
		_try_end_round()
		return

	active_actor = turn_queue[current_index]

	# ✅ 若是玩家角色，啟用回合鎖
	if active_actor in player_party:
		is_waiting_for_player = true

	print("【NEXT TURN】%s" % active_actor.name)
	emit_signal("turn_started", active_actor)

# 當角色完成行動時呼叫此方法
func end_turn() -> void:
	if _is_battle_ending():
		return
	if round_in_progress == false:
		print("⛔ 嘗試結束非進行中回合，略過")
		return

	if is_waiting_for_player:
		print("🔓 玩家回合結束：%s" % active_actor.name)
	else:
		print("🔚 敵方回合結束：%s" % active_actor.name)

	is_waiting_for_player = false
	current_index += 1

	_mark_actor_acted(active_actor)
	_try_end_round()
	if round_in_progress:
		call_deferred("next_turn")

# ✅ 用於外部檢查是否輪到我方角色
func is_player_turn() -> bool:
	return active_actor in player_party

# ✅ 用於外部查詢目前行動角色
func get_current_actor() -> Dictionary:
	return active_actor

func _actor_key(actor: Dictionary) -> String:
	var id = str(actor.get("id", ""))
	if id != "":
		return id
	return str(actor.get("name", ""))

func _is_actor_alive(actor: Dictionary) -> bool:
	if typeof(actor) != TYPE_DICTIONARY:
		return false
	if bool(actor.get("is_dead", false)) or bool(actor.get("dead", false)):
		return false
	if actor.has("alive") and not bool(actor.get("alive", true)):
		return false
	return int(actor.get("hp", 0)) > 0

func _build_round_roster() -> void:
	round_roster.clear()
	acted_this_round.clear()
	for actor in (player_party + enemy_party):
		if _is_actor_alive(actor):
			var key = _actor_key(actor)
			if key != "":
				round_roster.append(key)

func _mark_actor_acted(actor: Dictionary) -> void:
	var key = _actor_key(actor)
	if key == "":
		return
	if round_roster.has(key):
		acted_this_round[key] = true

func _prune_roster() -> void:
	var remaining = []
	for actor in (player_party + enemy_party):
		var key = _actor_key(actor)
		if key == "":
			continue
		if not round_roster.has(key):
			continue
		if _is_actor_alive(actor):
			remaining.append(key)
		else:
			acted_this_round[key] = true
	round_roster = remaining

func _is_round_complete() -> bool:
	for key in round_roster:
		if not acted_this_round.get(key, false):
			return false
	return true

func _try_end_round() -> void:
	if _is_battle_ending():
		return
	if round_end_emitted:
		return
	_prune_roster()
	if not _is_round_complete():
		return
	round_end_emitted = true
	round_in_progress = false
	emit_signal("round_ended", round_count)
	round_count += 1
	call_deferred("start_new_round")

func _is_battle_ending() -> bool:
	var controller = get_parent()
	if controller == null:
		return false
	if bool(controller.get("battle_finished")):
		return true
	if bool(controller.get("_ending")):
		return true
	return false
