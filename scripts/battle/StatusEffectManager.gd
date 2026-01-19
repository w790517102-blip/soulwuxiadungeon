extends Node
class_name StatusEffectManager


func apply_effect(target: Dictionary, effect_id: String, payload: Dictionary, turns: int, refresh := true) -> bool:
	if target.is_empty():
		return false
	if turns <= 0:
		return false

	if not target.has("base_speed"):
		target["base_speed"] = int(target.get("speed", 0))
		# TODO: 裝備 / 升級導致的永久速度變化，之後應同步更新 base_speed 或改為動態計算。

	if not target.has("status_effects") or typeof(target["status_effects"]) != TYPE_DICTIONARY:
		target["status_effects"] = {}

	var effects: Dictionary = target["status_effects"]
	var has_existing := effects.has(effect_id)

	if has_existing and not refresh:
		return false

	var payload_copy := payload.duplicate(true)

	match effect_id:
		"speed_buff":
			var delta := int(payload_copy.get("speed_delta", 0))
			if delta <= 0:
				return false

			if has_existing:
				var data = effects[effect_id]
				data["payload"] = {"speed_delta": delta}
				data["turns_left"] = turns
				effects[effect_id] = data
			else:
				effects[effect_id] = {
					"payload": {"speed_delta": delta},
					"turns_left": turns,
				}
			_recalc_speed(target)
			return true
		"speed_debuff":
			var slow_delta := int(payload_copy.get("slow_delta", 0))
			if slow_delta <= 0:
				return false

			if has_existing:
				var data2 = effects[effect_id]
				data2["payload"] = {"slow_delta": slow_delta}
				data2["turns_left"] = turns
				effects[effect_id] = data2
			else:
				effects[effect_id] = {
					"payload": {"slow_delta": slow_delta},
					"turns_left": turns,
				}
			_recalc_speed(target)
			return true
		"force_element":
			var new_element := str(payload_copy.get("element", ""))
			if new_element == "":
				return false

			if has_existing:
				remove_effect(target, effect_id)
				effects = target.get("status_effects", {})
				target["status_effects"] = effects

			var prev_element = target.get("element", "")
			target["element"] = new_element

			effects[effect_id] = {
				"payload": {"element": new_element},
				"prev_element": prev_element,
				"turns_left": turns,
			}
			return true
		_:
			return false


func tick_end_of_turn(actors: Array) -> void:
	for actor in actors:
		if typeof(actor) != TYPE_DICTIONARY:
			continue
		if not actor.has("status_effects") or typeof(actor["status_effects"]) != TYPE_DICTIONARY:
			continue

		var effects: Dictionary = actor["status_effects"]
		var to_remove: Array = []

		for effect_id in effects.keys():
			var effect_data: Dictionary = effects[effect_id]
			var turns_left := int(effect_data.get("turns_left", 0)) - 1
			effect_data["turns_left"] = turns_left
			effects[effect_id] = effect_data
			if turns_left <= 0:
				to_remove.append(effect_id)

		for eid in to_remove:
			remove_effect(actor, eid)


func remove_effect(target: Dictionary, effect_id: String) -> void:
	if target.is_empty():
		return

	if not target.has("status_effects") or typeof(target["status_effects"]) != TYPE_DICTIONARY:
		return

	var effects: Dictionary = target["status_effects"]
	if not effects.has(effect_id):
		return

	var effect_data: Dictionary = effects[effect_id]

	match effect_id:
		"speed_buff", "speed_debuff":
			effects.erase(effect_id)
			_recalc_speed(target)
			return
		"force_element":
			if effect_data.has("prev_element"):
				target["element"] = effect_data.get("prev_element", target.get("element", ""))

	effects.erase(effect_id)


func _recalc_speed(target: Dictionary) -> void:
	var base := int(target.get("base_speed", target.get("speed", 0)))
	var effects = target.get("status_effects", {})
	var buff := 0
	var debuff := 0

	if typeof(effects) == TYPE_DICTIONARY:
		if effects.has("speed_buff"):
			buff = int(effects["speed_buff"].get("payload", {}).get("speed_delta", 0))
		if effects.has("speed_debuff"):
			debuff = int(effects["speed_debuff"].get("payload", {}).get("slow_delta", 0))

	target["speed"] = max(base + buff - debuff, 0)
