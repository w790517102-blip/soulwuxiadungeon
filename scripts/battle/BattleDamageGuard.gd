extends RefCounted


static func resolve_hp_damage(source: Dictionary, target: Dictionary, requested_damage: int) -> Dictionary:
	var resolved_damage := maxi(requested_damage, 0)
	if resolved_damage <= 0:
		return {"damage": 0, "blocked": false, "effect_id": "", "log": ""}
	if bool(source.get("is_enemy", false)):
		return {"damage": resolved_damage, "blocked": false, "effect_id": "", "log": ""}
	var effects = target.get("status_effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		return {"damage": resolved_damage, "blocked": false, "effect_id": "", "log": ""}
	for effect_id in (effects as Dictionary).keys():
		var effect_record = (effects as Dictionary).get(effect_id, {})
		if typeof(effect_record) != TYPE_DICTIONARY:
			continue
		var payload = (effect_record as Dictionary).get("payload", {})
		if typeof(payload) != TYPE_DICTIONARY or not bool((payload as Dictionary).get("player_hp_damage_immunity", false)):
			continue
		return {
			"damage": 0,
			"blocked": true,
			"effect_id": String(effect_id),
			"log": String((payload as Dictionary).get(
				"blocked_log",
				"紫黑色語魅驟然翻湧，將攻勢硬生生隔絕在墨鱗魘將身外！"
			)),
		}
	return {"damage": resolved_damage, "blocked": false, "effect_id": "", "log": ""}
