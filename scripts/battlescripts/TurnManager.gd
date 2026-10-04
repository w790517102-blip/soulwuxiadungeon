# TurnManager.gd
# ✅ 管理語破江沽的回合制角色輪替與回合階段流程

extends Node

const InnerForceDB = preload("res://scripts/battlescripts/InnerForceDB.gd")

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
## A scripted guest (e.g. 左飲): it has a place in the turn order and a turn of its own, but no
## player action; the controller plays its scripted move when the turn comes. Empty when none.
var guest_actor: Dictionary = {}
## Stage entities that take part in the turn order (a 臨符 card...): one proxy dictionary each
## ({is_stage_entity, entity_id, faction, speed, hp, ...}). They sort by speed like anyone and each
## activation is their turn.
var queue_entities: Array = []

# 每輪依角色當下的最終加權速度排序（若未設定 speed，預設 0）
func _compare_speed(a: Dictionary, b: Dictionary) -> bool:
	var a_speed := int(InnerForceDB.resolve_element_final_stat(
		String(a.get("element", "")),
		"speed",
		float(a.get("speed", 0))
	))
	var b_speed := int(InnerForceDB.resolve_element_final_stat(
		String(b.get("element", "")),
		"speed",
		float(b.get("speed", 0))
	))
	if a_speed != b_speed:
		return a_speed > b_speed
	return int(a.get("battle_order_index", 9999)) < int(b.get("battle_order_index", 9999))

# === 記憶阿達雷勒現象 ===
var round_in_progress = false

# 初始化並開始第一回合
func start_battle(players: Array, enemies: Array, guest: Dictionary = {}) -> void:
	guest_actor = guest
	player_party = players
	enemy_party = enemies
	_assign_battle_order_indices()
	round_count = 1
	call_deferred("start_new_round")

func _assign_battle_order_indices() -> void:
	var order_index := 0
	for actor in get_all_actors():
		if typeof(actor) != TYPE_DICTIONARY:
			continue
		if not actor.has("battle_order_index"):
			actor["battle_order_index"] = order_index
		order_index += 1

# 產生新一輪行動順序
func start_new_round() -> void:
	if _is_battle_ending():
		return
	if round_in_progress:
		return  # 避免重複啟動

	round_in_progress = true
	round_end_emitted = false
	_clear_left_stamps()
	_build_round_roster()
	emit_signal("round_started", round_count)

	turn_queue.clear()
	turn_queue += get_all_actors()
	turn_queue = turn_queue.filter(func(a): return _is_actor_alive(a) and not _is_card(a))
	turn_queue.sort_custom(Callable(self, "_compare_speed"))
	_queue_cards_by_position()
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
	var battle_uid := str(actor.get("battle_uid", ""))
	if battle_uid != "":
		return battle_uid
	var id := str(actor.get("id", ""))
	if bool(actor.get("is_enemy", false)):
		var ui_index := int(actor.get("ui_index", -1))
		if ui_index >= 0:
			return "%s#%d" % [id if id != "" else "enemy", ui_index]
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
	for actor in get_all_actors():
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
	for actor in get_all_actors():
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
	var controller := get_parent()
	if controller != null and controller.has_method("run_round_end_encounter_actions"):
		await controller.call("run_round_end_encounter_actions", round_count)
	if _is_battle_ending():
		return
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



## Everyone who takes a turn: the party, the enemies, the scripted guest and the queued stage entities.
func get_all_actors() -> Array:
	var everyone: Array = player_party + enemy_party
	if not guest_actor.is_empty():
		everyone.append(guest_actor)
	everyone += queue_entities
	return everyone


## Puts a stage entity (a card) in the turn order. A card obeys POSITION, never speed: it is drawn at the far
## left of its camp's row (everything that stood there is pushed one place right), or, with `beside_actor`,
## directly to the left of that actor. It keeps its place in the row (characters only trade places among
## themselves by speed); its own turn (activation) comes when every character to its right has acted. A card
## drawn in the middle of a round has no turn in that round. `proxy` is {is_stage_entity, entity_id,
## faction, name}.
func add_queue_actor(proxy: Dictionary, beside_actor: Dictionary = {}) -> void:
	if queue_entities.has(proxy):
		return
	proxy["is_stage_entity"] = true
	proxy["hp"] = 1
	proxy["max_hp"] = 1
	if not proxy.has("battle_order_index"):
		proxy["battle_order_index"] = 1000 + queue_entities.size()
	var enemy_side: bool = is_enemy_side(proxy)
	var slot: int = 0
	if not beside_actor.is_empty():
		var row: Array = get_display_row(is_enemy_side(beside_actor))
		var owner_index: int = row.find(beside_actor)
		if owner_index >= 0:
			slot = row.size() - 1 - owner_index   # his place counted from the left: the card takes it
	_shift_cards_from(enemy_side, slot, 1)
	proxy["slot_left"] = slot
	queue_entities.append(proxy)


## Takes a stage entity out of the turn order (it expired or was destroyed). The cards that stood to its
## right close up with everything else.
func remove_queue_actor(proxy: Dictionary) -> void:
	if not queue_entities.has(proxy):
		return
	var slot: int = int(proxy.get("slot_left", 0))
	var enemy_side: bool = is_enemy_side(proxy)
	queue_entities.erase(proxy)
	_shift_cards_from(enemy_side, slot + 1, -1)
	proxy["hp"] = 0
	var key := _actor_key(proxy)
	round_roster.erase(key)
	acted_this_round.erase(key)
	var queue_index: int = turn_queue.find(proxy)
	if queue_index >= 0:
		turn_queue.remove_at(queue_index)
		if queue_index < current_index:
			current_index -= 1


func find_queue_actor(entity_id: String) -> Dictionary:
	for proxy: Dictionary in queue_entities:
		if String(proxy.get("entity_id", "")) == entity_id:
			return proxy
	return {}


## Cards of one camp whose place counted from the left is `from_slot` or more move `delta` places.
func _shift_cards_from(enemy_side: bool, from_slot: int, delta: int) -> void:
	for card: Dictionary in queue_entities:
		if is_enemy_side(card) == enemy_side and int(card.get("slot_left", 0)) >= from_slot:
			card["slot_left"] = maxi(int(card.get("slot_left", 0)) + delta, 0)


func _is_card(entry: Dictionary) -> bool:
	return bool(entry.get("is_stage_entity", false))


## The characters (never cards), next to act first: whoever is still to act this round, then everyone who
## has acted, sorted the way the next round will sort them.
func _character_order() -> Array:
	var queue: Array = turn_queue
	var index: int = clampi(current_index, 0, queue.size())
	var alive_all: Array = []
	for actor: Dictionary in get_all_actors():
		if _is_actor_alive(actor) and not _is_card(actor):
			alive_all.append(actor)
	var remaining: Array = []
	for actor: Dictionary in queue.slice(index):
		if alive_all.has(actor):
			remaining.append(actor)
	var acted: Array = []
	for actor: Dictionary in alive_all:
		if not remaining.has(actor):
			acted.append(actor)
	acted.sort_custom(Callable(self, "_compare_acted"))
	return remaining + acted


## One camp's row: its characters (speed decides only their order among themselves) with its cards standing
## in their own places counted from the left.
func get_display_row(enemy_side: bool) -> Array:
	var characters: Array = _character_order().filter(func(entry: Dictionary) -> bool: return is_enemy_side(entry) == enemy_side)
	var cards: Array = queue_entities.filter(func(card: Dictionary) -> bool: return is_enemy_side(card) == enemy_side and _is_actor_alive(card))
	return _merge_cards(characters, cards)


## `characters` run from the right end (index 0) to the left; each card takes its place counted from the left
## end (0 = far left); the characters fill the places that are left, keeping their order.
func _merge_cards(characters: Array, cards: Array) -> Array:
	if cards.is_empty():
		return characters
	var total: int = characters.size() + cards.size()
	var sorted_cards: Array = cards.duplicate()
	sorted_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("slot_left", 0)) != int(b.get("slot_left", 0)):
			return int(a.get("slot_left", 0)) < int(b.get("slot_left", 0))
		return int(a.get("battle_order_index", 0)) < int(b.get("battle_order_index", 0)))
	var row: Array = []
	row.resize(total)
	for card: Dictionary in sorted_cards:
		var place: int = clampi(int(card.get("slot_left", 0)), 0, total - 1)
		while row[total - 1 - place] != null:
			place = (place + 1) % total
		row[total - 1 - place] = card
	var next_character: int = 0
	for index: int in range(total):
		if row[index] == null:
			row[index] = characters[next_character]
			next_character += 1
	return row


## Both camps' rows in one list (each camp keeps its own order). Camp rows are this list filtered by side.
func get_display_order() -> Array:
	var rows: Dictionary = {false: get_display_row(false), true: get_display_row(true)}
	var cursor: Dictionary = {false: 0, true: 0}
	var result: Array = []
	for entry: Dictionary in _character_order():
		var side: bool = is_enemy_side(entry)
		var row: Array = rows[side]
		if cursor[side] < row.size():
			result.append(row[cursor[side]])
			cursor[side] += 1
	for side: bool in [false, true]:
		var row: Array = rows[side]
		while cursor[side] < row.size():
			result.append(row[cursor[side]])
			cursor[side] += 1
	return result


func is_enemy_side(entry: Dictionary) -> bool:
	if bool(entry.get("is_stage_entity", false)):
		return String(entry.get("faction", "player")) == "enemy"
	return enemy_party.has(entry) or bool(entry.get("is_enemy", false))


## At the start of a round each card gets its turn in the queue: right after the last character of its camp
## standing to its right (before everyone if there is none). A card drawn mid-round is not in the queue.
func _queue_cards_by_position() -> void:
	for enemy_side: bool in [false, true]:
		var row: Array = get_display_row(enemy_side)
		var anchor: Dictionary = {}
		var placed_after: Dictionary = {}
		for entry: Dictionary in row:
			if not _is_card(entry):
				anchor = entry
				continue
			if not _is_actor_alive(entry):
				continue
			var anchor_key: String = _actor_key(anchor) if not anchor.is_empty() else "<front>"
			var base: int = turn_queue.find(anchor) + 1 if not anchor.is_empty() else 0
			var offset: int = int(placed_after.get(anchor_key, 0))
			placed_after[anchor_key] = offset + 1
			turn_queue.insert(clampi(base + offset, 0, turn_queue.size()), entry)


# --- Explicit placements at the far left of a camp's row ----------------------------------------
# A character that ends up at the far left (the actor after 鞘劍連擊) stands after everyone who has acted,
# and a card sent there takes place 0 of its camp; whatever stood at the far left is one place in. Stamps
# last for the round; the next round sorts the characters by speed as usual (cards keep their places).

var _left_stamp: int = 0


## Puts `entry` at the far left of its camp's row. A character that still had a turn to come uses it up.
func send_to_far_left(entry: Dictionary) -> void:
	var enemy_side: bool = is_enemy_side(entry)
	if _is_card(entry):
		var old_slot: int = int(entry.get("slot_left", 0))
		for card: Dictionary in queue_entities:
			if card != entry and is_enemy_side(card) == enemy_side and int(card.get("slot_left", 0)) < old_slot:
				card["slot_left"] = int(card.get("slot_left", 0)) + 1
		entry["slot_left"] = 0
		return
	var index: int = turn_queue.find(entry)
	if index > current_index:
		turn_queue.remove_at(index)
	var key := _actor_key(entry)
	if key != "" and round_roster.has(key):
		acted_this_round[key] = true
	_left_stamp += 1
	entry["left_stamp"] = _left_stamp
	_shift_cards_from(enemy_side, 0, 1)


func _clear_left_stamps() -> void:
	_left_stamp = 0
	for actor: Dictionary in get_all_actors():
		actor.erase("left_stamp")


## Ordering of the characters that have acted: by speed (as the next round will sort them), except that
## characters sent to the far left stand after all the others, in the order they were sent.
func _compare_acted(a: Dictionary, b: Dictionary) -> bool:
	var stamp_a: int = int(a.get("left_stamp", 0))
	var stamp_b: int = int(b.get("left_stamp", 0))
	if (stamp_a > 0) != (stamp_b > 0):
		return stamp_b > 0
	if stamp_a > 0:
		return stamp_a < stamp_b
	return _compare_speed(a, b)
