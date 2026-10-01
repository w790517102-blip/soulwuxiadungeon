extends Node
class_name EnemyAI

const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
var _skill_db := SkillDBScript.new()
var _runtime_state: Dictionary = {}
## Set by the controller. Stage entities (cover, decoys...) may add weight to a target.
var stage_entities = null

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
	var committed_action := _get_locked_intent_action(enemy, alive_players, state)
	if not committed_action.is_empty():
		return committed_action
	var switch_action := _get_pending_attribute_switch_action(enemy, state)
	if not switch_action.is_empty():
		return switch_action

	var profile := String(enemy.get("ai_profile", "default"))
	var skills_mode := String(enemy.get("skills_mode", "weighted"))
	var skill_entries := _build_enemy_skill_entries(enemy, fallback_skill_list)
	if skill_entries.is_empty():
		return _fallback_basic_attack(alive_players)

	if skills_mode == "cycle":
		return _cycle_pick_action(enemy, alive_players, skill_entries, state)

	return _weighted_pick_action(enemy, alive_players, skill_entries, state, profile)

func _cycle_pick_action(enemy: Dictionary, alive_players: Array, entries: Array, state: Dictionary) -> Dictionary:
	var total := entries.size()
	if total <= 0:
		return _fallback_basic_attack(alive_players)
	var rotation_index := int(state.get("rotation_index", 0))
	rotation_index = posmod(rotation_index, total)
	for offset in range(total):
		var idx := (rotation_index + offset) % total
		var entry = entries[idx]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var packaged := _package_candidate(enemy, entry, alive_players, state)
		if packaged.is_empty():
			continue
		state["rotation_index"] = (idx + 1) % total
		_apply_cooldown(state, packaged.get("entry", {}))
		return {
			"skill": packaged.get("skill", {}),
			"target": packaged.get("target", {})
		}
	return _fallback_basic_attack(alive_players)

func _weighted_pick_action(enemy: Dictionary, alive_players: Array, entries: Array, state: Dictionary, profile: String) -> Dictionary:
	var candidates: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var packaged := _package_candidate(enemy, entry, alive_players, state)
		if packaged.is_empty():
			continue
		var weight := _profile_adjusted_weight(profile, packaged.get("entry", {}))
		if weight <= 0:
			continue
		packaged["weight"] = weight
		candidates.append(packaged)

	if candidates.is_empty():
		return _fallback_basic_attack(alive_players)

	var picked := _weighted_pick(candidates)
	if picked.is_empty():
		return _fallback_basic_attack(alive_players)
	_apply_cooldown(state, picked.get("entry", {}))
	return {
		"skill": picked.get("skill", {}),
		"target": picked.get("target", {})
	}

func _package_candidate(enemy: Dictionary, entry: Dictionary, alive_players: Array, state: Dictionary) -> Dictionary:
	if not _is_skill_entry_usable(enemy, entry, alive_players, state):
		return {}
	var skill_id := String(entry.get("skill_id", ""))
	var skill := _skill_db.get_skill(skill_id)
	if skill.is_empty():
		return {}
	var target := _choose_target_for_entry(enemy, entry, alive_players)
	if target.is_empty():
		return {}
	return {
		"entry": entry,
		"skill": skill,
		"target": target
	}

func _apply_cooldown(state: Dictionary, entry: Dictionary) -> void:
	var picked_id := String(entry.get("skill_id", ""))
	var cd_turns := int(entry.get("cd_turns", 0))
	if cd_turns > 0 and picked_id != "":
		state["cooldowns"][picked_id] = cd_turns


func complete_action(enemy: Dictionary, used_skill_id: String, allow_new_intent: bool = true) -> Dictionary:
	var state := _ensure_enemy_state(enemy)
	var pending_switch: Dictionary = state.get("pending_attribute_switch", {})
	if not pending_switch.is_empty() \
			and String(pending_switch.get("skill_id", "")) == used_skill_id:
		state["pending_attribute_switch"] = {}
		state["same_element_action_count"] = 0
		return {}
	var locked_intent := String(state.get("locked_intent", ""))
	if locked_intent != "" and locked_intent == used_skill_id:
		var config := _committed_intent_config(enemy)
		_apply_cooldown(state, {
			"skill_id": used_skill_id,
			"cd_turns": int(config.get("cooldown_turns", 0)),
		})
		state["locked_intent"] = ""
		state["eligible_fail_count"] = 0
		state["same_element_action_count"] = int(state.get("same_element_action_count", 0)) + 1
		return {}
	if String(state.get("locked_intent", "")) != "":
		return {}
	if not (state.get("pending_attribute_switch", {}) as Dictionary).is_empty():
		return {}
	state["same_element_action_count"] = int(state.get("same_element_action_count", 0)) + 1
	if not allow_new_intent:
		return {}
	return _arbitrate_special_intent(enemy, state)


func cancel_locked_intent(enemy: Dictionary) -> void:
	var state := _ensure_enemy_state(enemy)
	state["locked_intent"] = ""


func get_runtime_state(enemy: Dictionary) -> Dictionary:
	return _ensure_enemy_state(enemy).duplicate(true)


func _get_locked_intent_action(enemy: Dictionary, alive_players: Array, state: Dictionary) -> Dictionary:
	var skill_id := String(state.get("locked_intent", ""))
	if skill_id == "":
		return {}
	var skill := _skill_db.get_skill(skill_id)
	if skill.is_empty():
		push_warning("Enemy committed intent skill not found: %s" % skill_id)
		state["locked_intent"] = ""
		return {}
	var target := _choose_target_for_entry(enemy, {
		"target": String(skill.get("target_scope", "enemy_single")),
	}, alive_players)
	return {
		"skill": skill,
		"target": target,
		"committed_intent": true,
	}


func _get_pending_attribute_switch_action(enemy: Dictionary, state: Dictionary) -> Dictionary:
	var pending: Dictionary = state.get("pending_attribute_switch", {})
	if pending.is_empty():
		return {}
	var skill_id := String(pending.get("skill_id", ""))
	var skill := _skill_db.get_skill(skill_id)
	if skill.is_empty():
		push_warning("Enemy attribute switch skill not found: %s" % skill_id)
		state["pending_attribute_switch"] = {}
		return {}
	return {
		"skill": skill,
		"target": enemy,
		"pending_attribute_switch": true,
	}


func _arbitrate_special_intent(enemy: Dictionary, state: Dictionary) -> Dictionary:
	if _has_pending_special_intent(state):
		return {}
	var ultimate_result := _roll_committed_intent(enemy, state)
	if not ultimate_result.is_empty():
		return ultimate_result
	return _roll_attribute_switch_intent(enemy, state)


func _roll_committed_intent(enemy: Dictionary, state: Dictionary, roll_override: float = -1.0) -> Dictionary:
	var config := _committed_intent_config(enemy)
	if not _is_committed_intent_eligible(enemy, state, config):
		return {}
	var resolved := _resolve_intent_probability(enemy, state, config)
	var weight := float(resolved.get("weight", 0.0))
	var weight_pool := float(resolved.get("weight_pool", 0.0))
	if weight <= 0.0 or weight_pool <= 0.0:
		return {}
	var roll := roll_override if roll_override >= 0.0 else randf() * weight_pool
	if roll >= weight:
		state["eligible_fail_count"] = int(state.get("eligible_fail_count", 0)) + 1
		return {}
	var skill_id := String(config.get("skill_id", ""))
	state["locked_intent"] = skill_id
	state["eligible_fail_count"] = 0
	return {
		"locked_intent": skill_id,
		"tone_event": String(config.get("tone_event", "")),
	}


func _committed_intent_config(enemy: Dictionary) -> Dictionary:
	var raw = enemy.get("committed_intent", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _is_committed_intent_eligible(enemy: Dictionary, state: Dictionary, config: Dictionary) -> bool:
	if config.is_empty() or not bool(config.get("enabled", false)):
		return false
	if _has_pending_special_intent(state):
		return false
	if int(enemy.get("hp", 0)) <= 0:
		return false
	var skill_id := String(config.get("skill_id", ""))
	if skill_id == "" or _skill_db.get_skill(skill_id).is_empty():
		return false
	var cooldowns: Dictionary = state.get("cooldowns", {})
	return int(cooldowns.get(skill_id, 0)) <= 0


func _roll_attribute_switch_intent(
		enemy: Dictionary,
		state: Dictionary,
		roll_override: float = -1.0
	) -> Dictionary:
	var config := _attribute_switch_intent_config(enemy)
	if not _is_attribute_switch_eligible(enemy, state, config):
		return {}
	var chance := _resolve_attribute_switch_probability(enemy, state, config)
	if chance <= 0.0:
		return {}
	var roll := roll_override if roll_override >= 0.0 else randf()
	if roll >= chance:
		return {}
	var switches: Dictionary = config.get("switches_by_element", {})
	var current_element := String(enemy.get("element", ""))
	var pending: Dictionary = (switches.get(current_element, {}) as Dictionary).duplicate(true)
	state["pending_attribute_switch"] = pending
	return {
		"pending_attribute_switch": pending.duplicate(true),
		"switch_chance": chance,
	}


func _attribute_switch_intent_config(enemy: Dictionary) -> Dictionary:
	var raw = enemy.get("attribute_switch_intent", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _is_attribute_switch_eligible(enemy: Dictionary, state: Dictionary, config: Dictionary) -> bool:
	if config.is_empty() or not bool(config.get("enabled", false)):
		return false
	if _has_pending_special_intent(state) or int(enemy.get("hp", 0)) <= 0:
		return false
	var action_count := int(state.get("same_element_action_count", 0))
	if action_count <= int(config.get("minimum_dwell_actions", 0)):
		return false
	var switches = config.get("switches_by_element", {})
	if typeof(switches) != TYPE_DICTIONARY:
		return false
	var switch_data = (switches as Dictionary).get(String(enemy.get("element", "")), {})
	if typeof(switch_data) != TYPE_DICTIONARY:
		return false
	var skill_id := String((switch_data as Dictionary).get("skill_id", ""))
	return skill_id != "" and not _skill_db.get_skill(skill_id).is_empty()


func _resolve_attribute_switch_probability(enemy: Dictionary, state: Dictionary, config: Dictionary) -> float:
	var chance := float(config.get("base_chance", 0.0))
	var action_count := int(state.get("same_element_action_count", 0))
	var curve = config.get("chance_curve", [])
	if typeof(curve) == TYPE_ARRAY:
		for raw_step in curve:
			if typeof(raw_step) != TYPE_DICTIONARY:
				continue
			var step: Dictionary = raw_step
			if action_count >= int(step.get("action_count", 0)):
				chance = float(step.get("chance", chance))
	var modifiers = config.get("modifiers", [])
	if typeof(modifiers) == TYPE_ARRAY:
		for raw_modifier in modifiers:
			if typeof(raw_modifier) != TYPE_DICTIONARY:
				continue
			var modifier: Dictionary = raw_modifier
			if not _intent_modifier_matches(enemy, state, modifier):
				continue
			chance += float(modifier.get("chance_add", 0.0))
			chance *= float(modifier.get("chance_multiplier", 1.0))
	return clampf(chance, 0.0, 1.0)


func _has_pending_special_intent(state: Dictionary) -> bool:
	if String(state.get("locked_intent", "")) != "":
		return true
	var pending = state.get("pending_attribute_switch", {})
	return typeof(pending) == TYPE_DICTIONARY and not (pending as Dictionary).is_empty()


func _resolve_intent_probability(enemy: Dictionary, state: Dictionary, config: Dictionary) -> Dictionary:
	var weight := float(config.get("intent_weight", 0.0))
	var weight_pool := float(config.get("weight_pool", 0.0))
	var raw_modifiers = config.get("modifiers", [])
	if typeof(raw_modifiers) == TYPE_ARRAY:
		for raw_modifier in raw_modifiers:
			if typeof(raw_modifier) != TYPE_DICTIONARY:
				continue
			var modifier: Dictionary = raw_modifier
			if not _intent_modifier_matches(enemy, state, modifier):
				continue
			weight += float(modifier.get("weight_add", 0.0))
			weight *= float(modifier.get("weight_multiplier", 1.0))
			weight_pool += float(modifier.get("pool_add", 0.0))
	var pity_raw = config.get("pity", {})
	if typeof(pity_raw) == TYPE_DICTIONARY:
		var pity: Dictionary = pity_raw
		if bool(pity.get("enabled", false)):
			var failures := int(state.get("eligible_fail_count", 0))
			var start_after := int(pity.get("start_after_failures", 0))
			if failures >= start_after:
				weight += float(pity.get("weight_per_failure", 0.0)) * float(failures - start_after + 1)
	return {
		"weight": clampf(weight, 0.0, maxf(weight_pool, 0.0)),
		"weight_pool": maxf(weight_pool, 0.0),
	}


func _intent_modifier_matches(enemy: Dictionary, state: Dictionary, modifier: Dictionary) -> bool:
	var hp := float(enemy.get("hp", 0))
	var max_hp := maxf(1.0, float(enemy.get("max_hp", hp)))
	var hp_pct := hp / max_hp
	if modifier.has("self_hp_pct_lte") and hp_pct > float(modifier.get("self_hp_pct_lte", 1.0)):
		return false
	if modifier.has("self_hp_pct_gte") and hp_pct < float(modifier.get("self_hp_pct_gte", 0.0)):
		return false
	if modifier.has("min_turn") and int(state.get("turn_count", 0)) < int(modifier.get("min_turn", 0)):
		return false
	return true

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

func _enemy_state_key(enemy: Dictionary) -> String:
	var enemy_id := String(enemy.get("id", "unknown"))
	var ui_index := int(enemy.get("ui_index", -1))
	return "%s#%d" % [enemy_id, ui_index]

func _ensure_enemy_state(enemy: Dictionary) -> Dictionary:
	var key := _enemy_state_key(enemy)
	if not _runtime_state.has(key):
		_runtime_state[key] = {
			"turn_count": 0,
			"cooldowns": {},
			"rotation_index": 0,
			"locked_intent": "",
			"eligible_fail_count": 0,
			"pending_attribute_switch": {},
			"same_element_action_count": 0,
		}
	return _runtime_state[key]

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
	if bool(skill.get("committed_intent_only", false)):
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
	var hp = float(enemy.get("hp", 1))
	var max_hp = max(1.0, float(enemy.get("max_hp", hp)))
	var hp_pct = hp / max_hp
	if conditions.has("self_hp_pct_lte") and hp_pct > float(conditions.get("self_hp_pct_lte", 1.0)):
		return false
	if conditions.has("self_hp_pct_gte") and hp_pct < float(conditions.get("self_hp_pct_gte", 0.0)):
		return false
	if conditions.has("min_turn") and int(state.get("turn_count", 0)) < int(conditions.get("min_turn", 1)):
		return false
	if conditions.has("self_element_is") and String(enemy.get("element", "")) != String(conditions.get("self_element_is", "")):
		return false
	if conditions.has("self_element_not") and String(enemy.get("element", "")) == String(conditions.get("self_element_not", "")):
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


# --- Stage entity target priority (not wired into the existing target choice) ----------

## Score of one candidate target (an actor dictionary or a stage entity). With no
## entities this is just `base_score`, so it cannot change today's behaviour.
func target_score(enemy: Dictionary, candidate: Variant, base_score: float = 1.0) -> float:
	if stage_entities == null:
		return base_score
	return stage_entities.modify_target_score(enemy, candidate, base_score)


## Weighted random pick over `candidates` (actors and/or entities) by target_score. A
## future caller would use this where _choose_target_for_entry picks uniformly today.
func pick_weighted_target(enemy: Dictionary, candidates: Array) -> Variant:
	var weights: Array = []
	var total: float = 0.0
	for candidate: Variant in candidates:
		var weight: float = maxf(target_score(enemy, candidate), 0.0)
		weights.append(weight)
		total += weight
	if candidates.is_empty() or total <= 0.0:
		return null
	var roll: float = randf() * total
	for index: int in range(candidates.size()):
		roll -= float(weights[index])
		if roll <= 0.0:
			return candidates[index]
	return candidates[-1]
