extends Node
class_name EnemyAI

const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
var _skill_db := SkillDBScript.new()
var _runtime_state: Dictionary = {}

func begin_battle(enemies: Array) -> void:
	_runtime_state.clear()
	for enemy in enemies:
		if typeof(enemy) != TYPE_DICTIONARY:
			continue
		_ensure_enemy_state(enemy)

func get_action(enemy: Dictionary, player_party: Array, fallback_skill_list: Array = []) -> Dictionary:
	var alive_players := _alive(player_party)
	if alive_players.is_empty():
		return {}

	var state := _ensure_enemy_state(enemy)
	_tick_enemy_cooldowns(state)

	var profile := String(enemy.get("ai_profile", "default"))
	var skills := _build_enemy_skill_entries(enemy, fallback_skill_list)
	var candidates: Array = []
	for entry in skills:
		if not _is_skill_entry_usable(enemy, entry, alive_players, state):
			continue
		var skill_id := String(entry.get("skill_id", ""))
		var skill := _skill_db.get_skill(skill_id)
		if skill.is_empty():
			continue
		var target := _choose_target_for_entry(enemy, entry, alive_players)
		if target.is_empty():
			continue
		var weight := _profile_adjusted_weight(profile, entry)
		if weight <= 0:
			continue
		candidates.append({"entry": entry, "skill": skill, "target": target, "weight": weight})

	if candidates.is_empty():
		return _fallback_basic_attack(alive_players)

	var picked := _weighted_pick(candidates)
	if picked.is_empty():
		return _fallback_basic_attack(alive_players)

	var picked_entry: Dictionary = picked.get("entry", {})
	var picked_id := String(picked_entry.get("skill_id", ""))
	var cd_turns := int(picked_entry.get("cd_turns", 0))
	if cd_turns > 0 and picked_id != "":
		state["cooldowns"][picked_id] = cd_turns

	return {
		"skill": picked.get("skill", {}),
		"target": picked.get("target", {})
	}

func _fallback_basic_attack(alive_players: Array) -> Dictionary:
	var t0: Dictionary = alive_players[randi() % alive_players.size()]
	return {
		"skill": {
			"id": "basic_attack",
			"name": "普通攻擊",
			"power": 1.0,
			"target_scope": "enemy_single"
		},
		"target": t0
	}

func _build_enemy_skill_entries(enemy: Dictionary, fallback_skill_list: Array) -> Array:
	var entries: Array = []
	var configured = enemy.get("skills", [])
	if typeof(configured) == TYPE_ARRAY and not configured.is_empty():
		for raw in configured:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var entry := (raw as Dictionary).duplicate(true)
			entry["skill_id"] = String(entry.get("skill_id", ""))
			if entry["skill_id"] == "":
				continue
			if not entry.has("weight"):
				entry["weight"] = 10
			if not entry.has("cd_turns"):
				entry["cd_turns"] = 0
			if not entry.has("target"):
				entry["target"] = "enemy_single"
			entries.append(entry)
		return entries

	for skill in fallback_skill_list:
		if typeof(skill) != TYPE_DICTIONARY:
			continue
		var sid := String(skill.get("id", ""))
		if sid == "":
			continue
		entries.append({
			"skill_id": sid,
			"weight": 10,
			"cd_turns": 0,
			"target": String(skill.get("target_scope", "enemy_single")),
			"category": "attack"
		})
	return entries

func _ensure_enemy_state(enemy: Dictionary) -> Dictionary:
	var enemy_id := String(enemy.get("id", "unknown"))
	if not _runtime_state.has(enemy_id):
		_runtime_state[enemy_id] = {
			"turn_count": 0,
			"cooldowns": {}
		}
	return _runtime_state[enemy_id]

func _tick_enemy_cooldowns(state: Dictionary) -> void:
	state["turn_count"] = int(state.get("turn_count", 0)) + 1
	var cds: Dictionary = state.get("cooldowns", {})
	for key in cds.keys():
		var v := int(cds[key])
		if v > 0:
			cds[key] = v - 1

func _is_skill_entry_usable(enemy: Dictionary, entry: Dictionary, alive_players: Array, state: Dictionary) -> bool:
	var sid := String(entry.get("skill_id", ""))
	if sid == "":
		return false
	var skill := _skill_db.get_skill(sid)
	if skill.is_empty():
		return false
	var cooldowns: Dictionary = state.get("cooldowns", {})
	if int(cooldowns.get(sid, 0)) > 0:
		return false
	var mp_cost := int(entry.get("mp_cost", skill.get("mp_cost", 0)))
	if int(enemy.get("mp", 0)) < mp_cost:
		return false
	return _conditions_met(enemy, entry.get("conditions", {}), alive_players, state)

func _conditions_met(enemy: Dictionary, raw_conditions, alive_players: Array, state: Dictionary) -> bool:
	if typeof(raw_conditions) != TYPE_DICTIONARY:
		return true
	var conditions: Dictionary = raw_conditions
	var hp := float(enemy.get("hp", 1))
	var max_hp := max(1.0, float(enemy.get("max_hp", hp)))
	var hp_pct := hp / max_hp
	if conditions.has("self_hp_pct_lte") and hp_pct > float(conditions.get("self_hp_pct_lte", 1.0)):
		return false
	if conditions.has("self_hp_pct_gte") and hp_pct < float(conditions.get("self_hp_pct_gte", 0.0)):
		return false
	if conditions.has("min_turn") and int(state.get("turn_count", 0)) < int(conditions.get("min_turn", 1)):
		return false
	if conditions.has("self_has_status") and not _match_status_set(enemy, conditions.get("self_has_status", []), true):
		return false
	if conditions.has("self_missing_status") and not _match_status_set(enemy, conditions.get("self_missing_status", []), false):
		return false
	if conditions.has("target_has_status"):
		if not _any_target_match_status(alive_players, conditions.get("target_has_status", []), true):
			return false
	if conditions.has("target_missing_status"):
		if not _any_target_match_status(alive_players, conditions.get("target_missing_status", []), false):
			return false
	return true

func _profile_adjusted_weight(profile: String, entry: Dictionary) -> int:
	var weight := int(entry.get("weight", 10))
	var category := String(entry.get("category", "attack"))
	match profile:
		"aggressive":
			if category in ["attack", "debuff"]:
				weight += 8
		"support":
			if category in ["heal", "defend", "utility"]:
				weight += 10
			elif category == "attack":
				weight = max(1, weight - 5)
	return max(weight, 0)

func _choose_target_for_entry(enemy: Dictionary, entry: Dictionary, alive_players: Array) -> Dictionary:
	var target_mode := String(entry.get("target", "enemy_single"))
	var allies := [enemy]
	if target_mode in ["self", "ally_single", "ally_all"]:
		return enemy
	if alive_players.is_empty():
		return {}
	if target_mode == "enemy_single":
		return alive_players[randi() % alive_players.size()]
	return alive_players[randi() % alive_players.size()]

func _weighted_pick(candidates: Array) -> Dictionary:
	var total := 0
	for c in candidates:
		total += int(c.get("weight", 0))
	if total <= 0:
		return {}
	var roll := randi_range(1, total)
	var accum := 0
	for c in candidates:
		accum += int(c.get("weight", 0))
		if roll <= accum:
			return c
	return candidates[-1]

func _alive(party: Array) -> Array:
	var out: Array = []
	for p in party:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		if int(p.get("hp", 0)) <= 0:
			continue
		out.append(p)
	return out

func _extract_effect_types(actor: Dictionary) -> Array:
	var out: Array = []
	var effects = actor.get("status_effects", [])
	if typeof(effects) != TYPE_ARRAY:
		return out
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		out.append(String(e.get("effect_type", "")))
	return out

func _match_status_set(actor: Dictionary, check_set, should_have: bool) -> bool:
	if typeof(check_set) != TYPE_ARRAY:
		return true
	var statuses: Array = _extract_effect_types(actor)
	for raw in check_set:
		var key := String(raw)
		var has_it := statuses.has(key)
		if should_have and not has_it:
			return false
		if not should_have and has_it:
			return false
	return true

func _any_target_match_status(targets: Array, check_set, should_have: bool) -> bool:
	for t in targets:
		if _match_status_set(t, check_set, should_have):
			return true
	return false
