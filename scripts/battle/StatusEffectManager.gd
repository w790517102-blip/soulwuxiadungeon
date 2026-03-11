extends Node
class_name StatusEffectManager

const DEFAULT_SLOW_DELTA := 10

func has_effect(target: Dictionary, effect_id: String) -> bool:
	if target.is_empty() or effect_id == "":
		return false
	if not target.has("status_effects") or typeof(target["status_effects"]) != TYPE_DICTIONARY:
		return false
	return (target["status_effects"] as Dictionary).has(effect_id)


func apply_effect(target: Dictionary, effect_id: String, payload: Dictionary, turns: int, refresh := true) -> bool:
	if target.is_empty() or turns <= 0:
		return false

	_ensure_base_stats(target)

	if not target.has("status_effects") or typeof(target["status_effects"]) != TYPE_DICTIONARY:
		target["status_effects"] = {}

	var effects: Dictionary = target["status_effects"]
	var has_existing = effects.has(effect_id)
	if has_existing and not refresh:
		return false

	var payload_copy = payload.duplicate(true)
	var effect_payload = payload_copy.duplicate(true)

	match effect_id:
		"speed_buff":
			var delta = int(effect_payload.get("speed_delta", 0))
			if delta <= 0:
				return false
			effect_payload = {"speed_delta": delta}
		"speed_debuff":
			var slow_delta = int(effect_payload.get("slow_delta", 0))
			if slow_delta <= 0:
				return false
			effect_payload = {"slow_delta": slow_delta}
		"force_element":
			var new_element = str(effect_payload.get("element", ""))
			if new_element == "":
				return false
			if has_existing:
				remove_effect(target, effect_id)
				effects = target.get("status_effects", {})
				target["status_effects"] = effects
			effects[effect_id] = {
				"payload": {"element": new_element},
				"prev_element": target.get("element", ""),
				"turns_left": turns,
			}
			target["element"] = new_element
			return true
		"poison", "stun", "confuse":
			pass
		"slow":
			if int(effect_payload.get("slow_delta", 0)) <= 0:
				effect_payload["slow_delta"] = DEFAULT_SLOW_DELTA
		"warm_wine_buff":
			if int(effect_payload.get("speed_delta", 0)) == 0:
				effect_payload["speed_delta"] = 10
			if int(effect_payload.get("accuracy_delta", 0)) == 0:
				effect_payload["accuracy_delta"] = -5
		"weaken":
			if int(effect_payload.get("atk_delta", 0)) == 0:
				effect_payload["atk_delta"] = -10
		"break_def":
			if int(effect_payload.get("def_delta", 0)) == 0:
				effect_payload["def_delta"] = -10
		"weak":
			if int(effect_payload.get("max_hp_delta", 0)) == 0:
				effect_payload["max_hp_delta"] = -30
		"seal_mp":
			if int(effect_payload.get("max_mp_delta", 0)) == 0:
				effect_payload["max_mp_delta"] = -15
		"blind":
			if int(effect_payload.get("accuracy_delta", 0)) == 0:
				effect_payload["accuracy_delta"] = -15
		"root":
			if int(effect_payload.get("evasion_delta", 0)) == 0:
				effect_payload["evasion_delta"] = -20
		_:
			return false

	effects[effect_id] = {
		"payload": effect_payload,
		"turns_left": turns,
	}

	_recalc_speed(target)
	_recalc_accuracy(target)
	_recalc_evasion(target)
	_recalc_atk(target)
	_recalc_def(target)
	_recalc_max_hp(target)
	_recalc_max_mp(target)
	return true


func tick_end_of_turn(actors: Array) -> Array:
	var events: Array = []
	for actor in actors:
		if typeof(actor) != TYPE_DICTIONARY:
			continue
		if not actor.has("status_effects") or typeof(actor["status_effects"]) != TYPE_DICTIONARY:
			continue

		var effects: Dictionary = actor["status_effects"]
		var to_remove: Array = []

		for effect_id in effects.keys():
			if effect_id == "poison" and int(actor.get("hp", 0)) > 0:
				var max_hp = int(actor.get("max_hp", actor.get("base_max_hp", 0)))
				var tick_damage = max(10, int(floor(float(max_hp) * 0.05)))
				var before_hp = int(actor.get("hp", 0))
				var after_hp = max(0, before_hp - tick_damage)
				actor["hp"] = after_hp
				if after_hp <= 0:
					actor["is_dead"] = true
				events.append({
					"type": "poison_tick",
					"actor": actor,
					"damage": before_hp - after_hp,
				})

			var effect_data: Dictionary = effects[effect_id]
			var turns_left = int(effect_data.get("turns_left", 0)) - 1
			effect_data["turns_left"] = turns_left
			effects[effect_id] = effect_data
			if turns_left <= 0:
				to_remove.append(effect_id)

		for eid in to_remove:
			remove_effect(actor, eid)

	return events


func remove_effect(target: Dictionary, effect_id: String) -> void:
	if target.is_empty():
		return
	if not target.has("status_effects") or typeof(target["status_effects"]) != TYPE_DICTIONARY:
		return

	var effects: Dictionary = target["status_effects"]
	if not effects.has(effect_id):
		return

	var effect_data: Dictionary = effects[effect_id]
	if effect_id == "force_element" and effect_data.has("prev_element"):
		target["element"] = effect_data.get("prev_element", target.get("element", ""))

	effects.erase(effect_id)

	_recalc_speed(target)
	_recalc_accuracy(target)
	_recalc_evasion(target)
	_recalc_atk(target)
	_recalc_def(target)
	_recalc_max_hp(target)
	_recalc_max_mp(target)


func describe_effect(effect_id: String, actor: Dictionary, effect_record: Dictionary = {}) -> String:
	var turns_left = int(effect_record.get("turns_left", 0))
	var payload: Dictionary = effect_record.get("payload", {}) if typeof(effect_record.get("payload", {})) == TYPE_DICTIONARY else {}
	var actor_name = String(actor.get("name", "???"))
	match effect_id:
		"poison":
			var max_hp = int(actor.get("max_hp", actor.get("base_max_hp", actor.get("hp", 0))))
			var tick = max(10, int(floor(float(max_hp) * 0.05)))
			return "%s 中了「毒」，每回合約損失 %d 生命（剩 %d 回合）。" % [actor_name, tick, turns_left]
		"stun":
			return "%s 陷入「暈眩」，將無法行動（剩 %d 回合）。" % [actor_name, turns_left]
		"confuse":
			return "%s 神智混亂，單體行動可能誤擊敵我（剩 %d 回合）。" % [actor_name, turns_left]
		"weaken":
			return "%s 攻擊力下降 %d（剩 %d 回合）。" % [actor_name, abs(int(payload.get("atk_delta", -10))), turns_left]
		"break_def":
			return "%s 防禦力下降 %d（剩 %d 回合）。" % [actor_name, abs(int(payload.get("def_delta", -10))), turns_left]
		"weak":
			return "%s 最大生命下降 %d（剩 %d 回合）。" % [actor_name, abs(int(payload.get("max_hp_delta", -30))), turns_left]
		"seal_mp":
			return "%s 最大內力下降 %d（剩 %d 回合）。" % [actor_name, abs(int(payload.get("max_mp_delta", -15))), turns_left]
		"blind":
			return "%s 命中下降 %d（剩 %d 回合）。" % [actor_name, abs(int(payload.get("accuracy_delta", -15))), turns_left]
		"root":
			return "%s 閃避下降 %d（剩 %d 回合）。" % [actor_name, abs(int(payload.get("evasion_delta", -20))), turns_left]
		"speed_buff":
			return "%s 速度上升 %d（剩 %d 回合）。" % [actor_name, int(payload.get("speed_delta", 0)), turns_left]
		"speed_debuff", "slow":
			return "%s 速度下降 %d（剩 %d 回合）。" % [actor_name, int(payload.get("slow_delta", 0)), turns_left]
		"force_element":
			return "%s 屬性轉為「%s」（剩 %d 回合）。" % [actor_name, String(payload.get("element", "?")), turns_left]
		_:
			return "%s 附加了 %s（剩 %d 回合）。" % [actor_name, effect_id, turns_left]


func _ensure_base_stats(target: Dictionary) -> void:
	if not target.has("base_speed"):
		target["base_speed"] = int(target.get("speed", 0))
	if not target.has("base_accuracy"):
		target["base_accuracy"] = int(target.get("accuracy", 100))
	if not target.has("base_evasion"):
		target["base_evasion"] = int(target.get("evasion", 0))
	if not target.has("base_atk"):
		target["base_atk"] = int(target.get("atk", 0))
	if not target.has("base_def"):
		target["base_def"] = int(target.get("def", 0))
	if not target.has("base_max_hp"):
		target["base_max_hp"] = int(target.get("max_hp", target.get("hp", 0)))
	if not target.has("base_max_mp"):
		target["base_max_mp"] = int(target.get("max_mp", target.get("mp", 0)))


func _recalc_speed(target: Dictionary) -> void:
	_ensure_base_stats(target)
	var base = int(target.get("base_speed", target.get("speed", 0)))
	var effects = target.get("status_effects", {})
	var buff = 0
	var debuff = 0

	if typeof(effects) == TYPE_DICTIONARY:
		if effects.has("speed_buff"):
			buff += int(effects["speed_buff"].get("payload", {}).get("speed_delta", 0))
		if effects.has("speed_debuff"):
			debuff += int(effects["speed_debuff"].get("payload", {}).get("slow_delta", 0))
		if effects.has("slow"):
			debuff += int(effects["slow"].get("payload", {}).get("slow_delta", 0))
		if effects.has("warm_wine_buff"):
			buff += int(effects["warm_wine_buff"].get("payload", {}).get("speed_delta", 0))

	target["speed"] = max(base + buff - debuff, 0)


func _recalc_accuracy(target: Dictionary) -> void:
	_ensure_base_stats(target)
	var base = int(target.get("base_accuracy", target.get("accuracy", 100)))
	var effects = target.get("status_effects", {})
	var delta = 0
	if typeof(effects) == TYPE_DICTIONARY:
		if effects.has("warm_wine_buff"):
			delta += int(effects["warm_wine_buff"].get("payload", {}).get("accuracy_delta", 0))
		if effects.has("blind"):
			delta += int(effects["blind"].get("payload", {}).get("accuracy_delta", 0))
	target["accuracy"] = base + delta
	target["accuracy_mod"] = delta


func _recalc_evasion(target: Dictionary) -> void:
	_ensure_base_stats(target)
	var base = int(target.get("base_evasion", target.get("evasion", 0)))
	var effects = target.get("status_effects", {})
	var delta = 0
	if typeof(effects) == TYPE_DICTIONARY and effects.has("root"):
		delta += int(effects["root"].get("payload", {}).get("evasion_delta", 0))
	target["evasion"] = base + delta
	target["evasion_mod"] = delta


func _recalc_atk(target: Dictionary) -> void:
	_ensure_base_stats(target)
	var base = int(target.get("base_atk", target.get("atk", 0)))
	var effects = target.get("status_effects", {})
	var delta = 0
	if typeof(effects) == TYPE_DICTIONARY and effects.has("weaken"):
		delta += int(effects["weaken"].get("payload", {}).get("atk_delta", 0))
	target["atk"] = max(0, base + delta)
	target["atk_mod"] = delta


func _recalc_def(target: Dictionary) -> void:
	_ensure_base_stats(target)
	var base = int(target.get("base_def", target.get("def", 0)))
	var effects = target.get("status_effects", {})
	var delta = 0
	if typeof(effects) == TYPE_DICTIONARY and effects.has("break_def"):
		delta += int(effects["break_def"].get("payload", {}).get("def_delta", 0))
	target["def"] = max(0, base + delta)
	target["def_mod"] = delta


func _recalc_max_hp(target: Dictionary) -> void:
	_ensure_base_stats(target)
	var base = int(target.get("base_max_hp", target.get("max_hp", target.get("hp", 0))))
	var effects = target.get("status_effects", {})
	var delta = 0
	if typeof(effects) == TYPE_DICTIONARY and effects.has("weak"):
		delta += int(effects["weak"].get("payload", {}).get("max_hp_delta", 0))
	var new_max = max(1, base + delta)
	target["max_hp"] = new_max
	if int(target.get("hp", 0)) > new_max:
		target["hp"] = new_max
	target["max_hp_mod"] = delta


func _recalc_max_mp(target: Dictionary) -> void:
	_ensure_base_stats(target)
	var base = int(target.get("base_max_mp", target.get("max_mp", target.get("mp", 0))))
	var effects = target.get("status_effects", {})
	var delta = 0
	if typeof(effects) == TYPE_DICTIONARY and effects.has("seal_mp"):
		delta += int(effects["seal_mp"].get("payload", {}).get("max_mp_delta", 0))
	var new_max = max(0, base + delta)
	target["max_mp"] = new_max
	if int(target.get("mp", 0)) > new_max:
		target["mp"] = new_max
	target["max_mp_mod"] = delta
