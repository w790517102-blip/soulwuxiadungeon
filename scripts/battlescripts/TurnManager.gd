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
	current_index = 0

	call_deferred("next_turn")

# 執行下一位角色行動
func next_turn() -> void:
	if _is_battle_ending():
		return
	if is_waiting_for_player:
		print("🛑 尚未完成玩家回合，禁止進入下一角色")
		return

	# A card that has reached the frontier of its camp's row takes its own turn first (no command, no speed).
	var frontier_card: Dictionary = pending_frontier_card()
	if not frontier_card.is_empty():
		active_actor = frontier_card
		emit_signal("turn_started", active_actor)
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
	if _is_card(active_actor):
		_card_goes_to_far_left(active_actor)
	else:
		# The row is read while the actor is still in his place: he and his followers go to the far left.
		var leaving: Dictionary = active_actor
		var row_before: Array = get_display_row(is_enemy_side(leaving))
		var moved_by_hand: bool = bool(leaving.get("moved_this_turn", false))
		current_index += 1
		_mark_actor_acted(leaving)
		if moved_by_hand:
			_character_goes_to_far_left(leaving)
		else:
			var group: Array = _group_of(leaving, row_before)
			for entry: Dictionary in group:
				if _is_card(entry):
					acted_this_round[_actor_key(entry)] = true
			_left_stamp += 1
			leaving["left_stamp"] = _left_stamp
			_commit_row(_row_with_group_at_far_left(row_before, group))
			for card: Dictionary in queue_entities:
				card.erase("detached_this_turn")
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
		if _is_actor_alive(actor) and not _is_card(actor):
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
	# A card that has reached the frontier still has its turn to take before the round is over.
	if not pending_frontier_card().is_empty():
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


## Puts a stage entity (a card) on the battlefield line. A card has NO speed: it stands where its spawn rule puts
## it (directly to the left of `beside_actor`, otherwise at the far left) and from then on only moves by the
## movement rules of the line (an acting character takes along the follower cards at his left, a card that has
## reached the frontier resolves and goes to the far left). `proxy` is {is_stage_entity, entity_id, faction,
## name, follow_topology}. A card drawn in the middle of a round has no turn in that round.
func add_queue_actor(proxy: Dictionary, beside_actor: Dictionary = {}) -> void:
	if queue_entities.has(proxy):
		return
	proxy["is_stage_entity"] = true
	proxy["hp"] = 1
	proxy["max_hp"] = 1
	if not proxy.has("battle_order_index"):
		proxy["battle_order_index"] = 1000 + queue_entities.size()
	var side: bool = is_enemy_side(proxy)
	var row: Array = get_display_row(side)
	var at: int = row.find(beside_actor) if not beside_actor.is_empty() else -1
	if at >= 0:
		row.insert(at + 1, proxy)   # directly to his left
	else:
		row.append(proxy)           # the far left
	queue_entities.append(proxy)
	_commit_row(row)
	if round_in_progress:
		acted_this_round[_actor_key(proxy)] = true


## Takes a stage entity out of the line (it expired or was destroyed). Nothing else is re-assigned.
func remove_queue_actor(proxy: Dictionary) -> void:
	if not queue_entities.has(proxy):
		return
	queue_entities.erase(proxy)
	proxy["hp"] = 0
	var key := _actor_key(proxy)
	round_roster.erase(key)
	acted_this_round.erase(key)


func find_queue_actor(entity_id: String) -> Dictionary:
	for proxy: Dictionary in queue_entities:
		if String(proxy.get("entity_id", "")) == entity_id:
			return proxy
	return {}


func has_acted(entry: Dictionary) -> bool:
	return bool(acted_this_round.get(_actor_key(entry), false))


func _is_card(entry: Dictionary) -> bool:
	return bool(entry.get("is_stage_entity", false))


## The characters (never cards), next to act first: whoever is still to act this round, then everyone who
## has acted in the order they went back to the far left.
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


## One camp's row, index 0 = the frontier (the right end). Characters are ordered by speed among
## themselves; each card stands in its physical place: after as many characters as stood to its right when
## it was last placed (a character that has died no longer counts), so a character changing speed only trades
## places with other characters and the cards stay where they are.
func get_display_row(enemy_side: bool) -> Array:
	var characters: Array = _character_order().filter(func(entry: Dictionary) -> bool: return is_enemy_side(entry) == enemy_side)
	var cards: Array = queue_entities.filter(func(card: Dictionary) -> bool: return is_enemy_side(card) == enemy_side and _is_actor_alive(card))
	return _merge_cards(characters, cards)


func _merge_cards(characters: Array, cards: Array) -> Array:
	if cards.is_empty():
		return characters
	var alive_keys: Dictionary = {}
	for entry: Dictionary in characters:
		alive_keys[_actor_key(entry)] = true
	var placed: Array = []
	for card: Dictionary in cards:
		var gap: int = 0
		for key: String in card.get("right_keys", []):
			if alive_keys.has(key):
				gap += 1
		placed.append({"card": card, "gap": mini(gap, characters.size()), "rank": float(card.get("rank", 0.0))})
	placed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.gap != b.gap:
			return a.gap < b.gap
		return a.rank < b.rank)
	var row: Array = []
	var next_card: int = 0
	for emitted: int in range(characters.size() + 1):
		while next_card < placed.size() and int(placed[next_card].gap) <= emitted:
			row.append(placed[next_card].card)
			next_card += 1
		if emitted < characters.size():
			row.append(characters[emitted])
	return row


## Remembers the physical places of the cards of `row` (one camp): for each card, which characters stand to its
## right, and its rank among the cards.
func _commit_row(row: Array) -> void:
	var keys: Array = []
	var rank: float = 0.0
	for entry: Dictionary in row:
		if _is_card(entry):
			entry["right_keys"] = keys.duplicate()
			entry["rank"] = rank
			rank += 1.0
		else:
			keys.append(_actor_key(entry))


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


## A card standing at the frontier (index 0) of a camp's row that has not had its turn this round, or {}.
func pending_frontier_card() -> Dictionary:
	for side: bool in [false, true]:
		var row: Array = get_display_row(side)
		if not row.is_empty() and _is_card(row[0]) and not has_acted(row[0]):
			return row[0]
	return {}


# --- Movement on the line ---------------------------------------------------------------------------
# The line is rearranged only by explicit moves: a character who ends his turn goes to the far left TOGETHER with
# the follower cards (follow_topology) directly at his left (the hen takes her chicks); a card that has had its
# turn at the frontier goes to the far left alone; send_to_far_left moves exactly one entry. A change of
# speed never moves a card, and a death does not hand a card to anyone else.

var _left_stamp: int = 0


## `row` with the entries of `group` taken out and put at the far left in their own order.
func _row_with_group_at_far_left(row: Array, group: Array) -> Array:
	var moved: Array = row.filter(func(entry: Dictionary) -> bool: return not group.has(entry))
	return moved + group


## The acting `actor` and the follower cards directly to his left (up to the next character or non-follower).
func _group_of(actor: Dictionary, row: Array) -> Array:
	var group: Array = [actor]
	var at: int = row.find(actor)
	if at < 0:
		return group
	var next_index: int = at + 1
	while next_index < row.size():
		var entry: Dictionary = row[next_index]
		if not _is_card(entry) or not bool(entry.get("follow_topology", false)) or bool(entry.get("detached_this_turn", false)):
			break
		group.append(entry)
		next_index += 1
	return group


## A character's turn is over: he and his followers go to the far left (unless he already went by himself).
func _character_goes_to_far_left(actor: Dictionary) -> void:
	var side: bool = is_enemy_side(actor)
	if bool(actor.get("moved_this_turn", false)):
		actor.erase("moved_this_turn")
	else:
		var row: Array = get_display_row(side)
		var group: Array = _group_of(actor, row)
		for entry: Dictionary in group:
			if _is_card(entry):
				acted_this_round[_actor_key(entry)] = true
		_left_stamp += 1
		actor["left_stamp"] = _left_stamp
		_commit_row(_row_with_group_at_far_left(row, group))
	for card: Dictionary in queue_entities:
		card.erase("detached_this_turn")


## A card has had its turn at the frontier: it goes to the far left and waits for the next round.
func _card_goes_to_far_left(card: Dictionary) -> void:
	acted_this_round[_actor_key(card)] = true
	var row: Array = get_display_row(is_enemy_side(card))
	_commit_row(_row_with_group_at_far_left(row, [card]))


## Puts exactly `entry` at the far left of its camp's row (no followers). A character that still had a turn to
## come uses it up; the entry is not moved again when the turn ends.
func send_to_far_left(entry: Dictionary) -> void:
	var side: bool = is_enemy_side(entry)
	var row: Array = get_display_row(side)
	if _is_card(entry):
		entry["detached_this_turn"] = true
		_commit_row(_row_with_group_at_far_left(row, [entry]))
		return
	var index: int = turn_queue.find(entry)
	if index > current_index:
		turn_queue.remove_at(index)
	var key := _actor_key(entry)
	if key != "" and round_roster.has(key):
		acted_this_round[key] = true
	_left_stamp += 1
	entry["left_stamp"] = _left_stamp
	entry["moved_this_turn"] = true
	_commit_row(_row_with_group_at_far_left(row, [entry]))


func _clear_left_stamps() -> void:
	_left_stamp = 0
	for actor: Dictionary in get_all_actors():
		actor.erase("left_stamp")


## Ordering of the characters that have acted: stamped ones (they went to the far left, in that order) stand
## after the others, who stand by speed (as the next round will sort them).
func _compare_acted(a: Dictionary, b: Dictionary) -> bool:
	var stamp_a: int = int(a.get("left_stamp", 0))
	var stamp_b: int = int(b.get("left_stamp", 0))
	if (stamp_a > 0) != (stamp_b > 0):
		return stamp_b > 0
	if stamp_a > 0:
		return stamp_a < stamp_b
	return _compare_speed(a, b)


## A speed changed in the middle of a round: the characters still to act trade places among themselves by
## their new speed. Cards stay where they physically stand (the row is only re-read, nothing is moved).
func resort_remaining_characters() -> void:
	# The character acting right now keeps his turn; only those after him are re-sorted.
	var index: int = clampi(current_index, 0, turn_queue.size())
	if index < turn_queue.size() and turn_queue[index] == active_actor:
		index += 1
	var remaining: Array = turn_queue.slice(index)
	remaining.sort_custom(Callable(self, "_compare_speed"))
	turn_queue = turn_queue.slice(0, index) + remaining
