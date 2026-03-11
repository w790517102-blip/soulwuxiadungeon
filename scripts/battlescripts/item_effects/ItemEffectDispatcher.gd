extends Node
class_name ItemEffectDispatcher

func apply(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	var effect: String = item.get("effect", "")

	match effect:
		"heal", "heal_hp":
			return _handle_heal_hp(controller, user, item, target)
		"mp_heal":
			return _handle_mp_heal(controller, user, item, target)
		"perm_stat":
			return _handle_perm_stat(controller, user, item, target)
		"heal_by_stat":
			return _handle_heal_by_stat(controller, user, item, target)
		"mp_heal_by_stat":
			return _handle_mp_heal_by_stat(controller, user, item, target)
		"apply_battle_buff":
			return _handle_apply_battle_buff(controller, user, item, target)
		"walnut":
			return _handle_walnut(controller, user, item, target)
		"zhuge_crossbow":
			return _handle_zhuge_crossbow(controller, user, item, target)
		"buff_speed":
			return _handle_buff_speed(controller, user, item, target)
		"debuff_speed":
			return _handle_debuff_speed(controller, user, item, target)
		"haste_talisman":
			return _handle_haste_talisman(controller, user, item, target)
		"fire_talisman":
			return _handle_fire_talisman(controller, user, item, target)
		"bomb_single":
			return _handle_bomb_single(controller, user, item, target)
		"bomb_aoe":
			return _handle_bomb_aoe(controller, user, item, target)
		"cure_status":
			return _handle_cure_status(controller, user, item, target)
		"warm_wine":
			return _handle_warm_wine(controller, user, item, target)
		"escape_battle":
			return _handle_escape_battle(controller, user, item)
		_:
			return _handle_unimplemented(controller, user, item)


func _handle_heal_hp(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	var amount: int = int(item.get("amount", 0))
	if amount <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return false

	if str(item.get("target_scope", "ally_single")) == "ally_all":
		return _handle_heal_hp_all(controller, user, item, amount)

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")

	var before_hp: int = target.get("hp", 0)
	var max_hp: int = target.get("max_hp", before_hp)
	var after_hp: int = min(before_hp + amount, max_hp)

	var restored: int = after_hp - before_hp
	target["hp"] = after_hp

	if restored <= 0:
		var line_no_effect: String
		if user_name == target_name:
			line_no_effect = "%s 看了看 %s，還是吞了下去——反正都帶在身上了，只是這一回似乎派不上用場。" % [
				user_name,
				item_name
			]
		else:
			line_no_effect = "%s 好心替 %s 用上 %s，結果傷勢早已無礙，藥力幾乎只是圖個心安。" % [
				user_name,
				target_name,
				item_name
			]
		controller._log(line_no_effect)
	else:
		if controller.tone_map != null:
			var extra_hp = controller.tone_map.get_tone_text("item_use", "heal", user_id)
			if extra_hp != "":
				controller._log(extra_hp)

		var amount_str = "[color=#80ff80]%d[/color]" % restored

		var line: String
		if user_name == target_name:
			line = "%s 使用了 %s，恢復了 %s 點生命。" % [
				user_name,
				item_name,
				amount_str
			]
		else:
			line = "%s 對 %s 使用了 %s，恢復了 %s 點生命。" % [
				user_name,
				target_name,
				item_name,
				amount_str
			]

		controller._log(line)

		if controller.battle_ui and controller.battle_ui.has_method("play_heal_react"):
			controller.battle_ui.play_heal_react(target)
	return true


func _handle_mp_heal(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	var amount_mp: int = int(item.get("amount", 0))
	if amount_mp <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return false

	if str(item.get("target_scope", "ally_single")) == "ally_all":
		return _handle_mp_heal_all(controller, user, item, amount_mp)

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")

	var before_mp: int = target.get("mp", 0)
	var max_mp: int = target.get("max_mp", before_mp)
	var after_mp: int = min(before_mp + amount_mp, max_mp)

	var restored_mp: int = after_mp - before_mp
	target["mp"] = after_mp

	if restored_mp <= 0:
		var line_no_mp: String
		if user_name == target_name:
			line_no_mp = "%s 把 %s 送入口中，卻發現真氣早已充沛，藥力無處可去。" % [
				user_name,
				item_name
			]
		else:
			line_no_mp = "%s 對 %s 使用了 %s，但對方的內力早已飽和，頂多算潤潤嗓子。" % [
				user_name,
				target_name,
				item_name
			]
		controller._log(line_no_mp)
	else:
		if controller.tone_map != null:
			var extra_mp = controller.tone_map.get_tone_text("item_use", "mp_heal", user_id)
			if extra_mp != "":
				controller._log(extra_mp)

		var amount_mp_str = "[color=#80ffe0]%d[/color]" % restored_mp

		var line2: String
		if user_name == target_name:
			line2 = "%s 使用了 %s，恢復了 %s 點內力。" % [
				user_name,
				item_name,
				amount_mp_str
			]
		else:
			line2 = "%s 對 %s 使用了 %s，恢復了 %s 點內力。" % [
				user_name,
				target_name,
				item_name,
				amount_mp_str
			]

		controller._log(line2)

		if controller.battle_ui and controller.battle_ui.has_method("play_heal_react"):
			controller.battle_ui.play_heal_react(target)
	return true


func _handle_heal_hp_all(controller, user: Dictionary, item: Dictionary, amount: int) -> bool:
	var user_name: String = user.get("name", "???")
	var item_name: String = item.get("name", "???")
	var has_restore = false
	for ally in controller.player_party:
		if typeof(ally) != TYPE_DICTIONARY:
			continue
		if int(ally.get("hp", 0)) <= 0:
			continue
		var before_hp: int = int(ally.get("hp", 0))
		var max_hp: int = int(ally.get("max_hp", before_hp))
		var after_hp: int = min(before_hp + amount, max_hp)
		ally["hp"] = after_hp
		if after_hp > before_hp:
			has_restore = true
			if controller.battle_ui and controller.battle_ui.has_method("play_heal_react"):
				controller.battle_ui.play_heal_react(ally)

	if has_restore:
		controller._log("%s 使用了 %s，全隊恢復了生命。" % [user_name, item_name])
	else:
		controller._log("%s 使用了 %s，但全隊傷勢已平，藥力無從發揮。" % [user_name, item_name])
	return true


func _handle_mp_heal_all(controller, user: Dictionary, item: Dictionary, amount_mp: int) -> bool:
	var user_name: String = user.get("name", "???")
	var item_name: String = item.get("name", "???")
	var has_restore = false
	for ally in controller.player_party:
		if typeof(ally) != TYPE_DICTIONARY:
			continue
		if int(ally.get("hp", 0)) <= 0:
			continue
		var before_mp: int = int(ally.get("mp", 0))
		var max_mp: int = int(ally.get("max_mp", before_mp))
		var after_mp: int = min(before_mp + amount_mp, max_mp)
		ally["mp"] = after_mp
		if after_mp > before_mp:
			has_restore = true
			if controller.battle_ui and controller.battle_ui.has_method("play_heal_react"):
				controller.battle_ui.play_heal_react(ally)

	if has_restore:
		controller._log("%s 使用了 %s，全隊恢復了內力。" % [user_name, item_name])
	else:
		controller._log("%s 使用了 %s，但全隊真氣充盈，藥力幾乎白白散去。" % [user_name, item_name])
	return true


func _handle_buff_speed(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	var amount_spd: int = int(item.get("amount", 0))
	if amount_spd <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return false

	var turns = int(item.get("turns", 3))
	if turns <= 0:
		controller._log("WARN: buff_speed missing turns: %s" % item.get("id", ""))
		return false

	var before_spd = int(target.get("speed", 0))
	var ok = controller.status_manager.apply_effect(target, "speed_buff", {"speed_delta": amount_spd}, turns)
	if not ok:
		return false
	var after_spd = int(target.get("speed", before_spd))
	var added = after_spd - before_spd

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")
	var target_id: String = target.get("id", "")

	if controller.tone_map != null:
		var use_line = controller.tone_map.get_tone_text("item_use", "buff_speed", user_id)
		if use_line != "":
			controller._log(use_line)

		var suffer_line = controller.tone_map.get_tone_text("item_suffer", "buff_speed", target_id)
		if suffer_line != "":
			controller._log(suffer_line)

	var amount_spd_str = "[color=#ffd000]%d[/color]" % added
	controller._log("%s 對 %s 使用了 %s，%s 的速度提升了 %s 點。" % [
		user_name,
		target_name,
		item_name,
		target_name,
		amount_spd_str
	])
	return true


func _handle_debuff_speed(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	var amount_speed: int = int(item.get("amount", 0))
	if amount_speed <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return false

	var turns = int(item.get("turns", 3))
	if turns <= 0:
		controller._log("WARN: debuff_speed missing turns: %s" % item.get("id", ""))
		return false

	var before_spd = int(target.get("speed", 0))
	var ok = controller.status_manager.apply_effect(target, "speed_debuff", {"slow_delta": amount_speed}, turns)
	if not ok:
		return false
	var after_spd = int(target.get("speed", before_spd))
	var reduced = before_spd - after_spd

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")
	var target_id: String = target.get("id", "")

	if controller.tone_map != null:
		var use_line = controller.tone_map.get_tone_text("item_use", "debuff_speed", user_id)
		if use_line != "":
			controller._log(use_line)

	if controller.tone_map != null:
		var suffer_line = controller.tone_map.get_tone_text("item_suffer", "debuff_speed", target_id)
		if suffer_line != "":
			controller._log(suffer_line)

	if reduced > 0:
		var amount_str = "[color=#ffcc66]%d[/color]" % reduced
		var line3 = "%s 對 %s 使用了 %s，%s 的速度降低了 %s 點。" % [
				user_name,
				target_name,
				item_name,
				target_name,
				amount_str
		]
		controller._log(line3)
	else:
		var line_no_effect2 = "%s 使出 %s 想絆住 %s 的腳步，但對方氣勢如虹，幾乎沒被拖慢。" % [
				user_name,
				item_name,
				target_name
		]
		controller._log(line_no_effect2)
	return true


func _handle_escape_battle(controller, user: Dictionary, item: Dictionary) -> bool:
	if controller == null or not controller.has_method("request_escape_from_item"):
		return false

	var user_name: String = user.get("name", "???")
	var item_name: String = item.get("name", "???")
	controller._log("%s 猛地擲出 %s，濃煙翻湧，眾人趁亂抽身撤離。" % [user_name, item_name])
	controller.request_escape_from_item(user, item)
	return true


func _resolve_actor_stat(actor: Dictionary, stat_key: String) -> int:
	var key = String(stat_key).to_lower()
	return int(actor.get(key, 0))


func _calc_scaled_amount(item: Dictionary, actor: Dictionary) -> int:
	var base_amount = int(item.get("base_amount", item.get("amount", 0)))
	var scale = float(item.get("scale", 1.0))
	var stat_key = String(item.get("stat_key", ""))
	var stat_value = _resolve_actor_stat(actor, stat_key)
	var raw_amount = int(round(base_amount + stat_value * scale))
	var min_amount = int(item.get("min_amount", raw_amount))
	var max_amount = int(item.get("max_amount", raw_amount))
	if max_amount < min_amount:
		max_amount = min_amount
	return clamp(raw_amount, min_amount, max_amount)


func _handle_perm_stat(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var actor_id = String(target.get("id", ""))
	var stat_key = String(item.get("stat_key", "")).to_lower()
	var amount = int(item.get("amount", 0))
	if actor_id == "" or stat_key == "" or amount == 0:
		return false
	if controller == null or controller.team_data_manager == null:
		return false
	if not controller.team_data_manager.has_method("add_perm_stat"):
		return false
	if not bool(controller.team_data_manager.add_perm_stat(actor_id, stat_key, amount)):
		return false
	target[stat_key] = int(target.get(stat_key, 0)) + amount
	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	controller._log("%s 對 %s 使用了 %s，%s 永久提升 %s 點。" % [user_name, target_name, item_name, stat_key.to_upper(), amount])
	return true


func _handle_heal_by_stat(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var amount = _calc_scaled_amount(item, target)
	if amount <= 0:
		return false
	var temp_item = item.duplicate(true)
	temp_item["amount"] = amount
	return _handle_heal_hp(controller, user, temp_item, target)


func _handle_mp_heal_by_stat(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var amount = _calc_scaled_amount(item, target)
	if amount <= 0:
		return false
	var temp_item = item.duplicate(true)
	temp_item["amount"] = amount
	return _handle_mp_heal(controller, user, temp_item, target)


func _handle_apply_battle_buff(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		return false
	if controller == null or controller.team_data_manager == null:
		return false
	var actor_id = String(target.get("id", ""))
	var buff_key = String(item.get("buff_key", ""))
	var buff_value = float(item.get("buff_value", 0.0))
	if actor_id == "" or buff_key == "" or buff_value == 0.0:
		return false
	if not controller.team_data_manager.has_method("add_next_battle_modifier"):
		return false
	if not bool(controller.team_data_manager.add_next_battle_modifier(actor_id, buff_key, buff_value)):
		return false
	var mods: Dictionary = target.get("battle_modifiers", {})
	if typeof(mods) != TYPE_DICTIONARY:
		mods = {}
	mods[buff_key] = float(mods.get(buff_key, 0.0)) + buff_value
	target["battle_modifiers"] = mods
	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	controller._log("%s 對 %s 使用了 %s，下一場戰鬥將獲得 %s 效果。" % [user_name, target_name, item_name, buff_key])
	return true


func _status_display_name(status_id: String) -> String:
	match status_id:
		"poison":
			return "中毒"
		"stun":
			return "暈眩"
		"slow":
			return "緩速"
		"confuse":
			return "混亂"
		_:
			return status_id


func _handle_cure_status(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		return false
	if controller == null or controller.status_manager == null:
		return false

	var status_id = str(item.get("status_id", ""))
	if status_id == "":
		controller._log("WARN: cure_status missing status_id: %s" % str(item.get("id", "")))
		return false

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var status_name = _status_display_name(status_id)

	var had_effect = false
	if controller.status_manager.has_method("has_effect"):
		had_effect = bool(controller.status_manager.has_effect(target, status_id))

	controller.status_manager.remove_effect(target, status_id)

	if had_effect:
		controller._log("%s 對 %s 使用了 %s，解除了「%s」。" % [user_name, target_name, item_name, status_name])
	else:
		controller._log("%s 對 %s 使用了 %s，但對方並未處於「%s」。" % [user_name, target_name, item_name, status_name])
	return true


func _handle_warm_wine(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		return false
	if controller == null or controller.status_manager == null:
		return false

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var status_manager = controller.status_manager

	var has_slow = false
	if status_manager.has_method("has_effect"):
		has_slow = bool(status_manager.has_effect(target, "slow"))

	if has_slow:
		status_manager.remove_effect(target, "slow")
		controller._log("%s 對 %s 使用了 %s，酒力驅寒，解除了「緩速」。" % [user_name, target_name, item_name])
		return true

	var turns = int(item.get("turns", 3))
	if turns <= 0:
		turns = 3
	var ok = status_manager.apply_effect(target, "warm_wine_buff", {
		"speed_delta": 10,
		"accuracy_delta": -5,
	}, turns)
	if not ok:
		return false

	controller._log("%s 對 %s 使用了 %s，身法提升 10、命中修正 -5（%d 回合）。" % [
		user_name,
		target_name,
		item_name,
		turns
	])
	return true


func _handle_walnut(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		target = user
	var user_name: String = user.get("name", "???")
	var stat_key = String(item.get("require_stat", "str")).to_lower()
	var require_min = int(item.get("require_min", 31))
	var stat_val = int(target.get(stat_key, 0))
	var cracker_count = int(InventorySync.get_item_by_id("misc_walnut_cracker").get("count", 0))
	var has_cracker = cracker_count > 0
	if stat_val < require_min and not has_cracker:
		controller._log("%s 面紅耳赤的捏著胡桃，但即使雙手通紅，胡桃仍然無動於衷。" % [user_name])
		return false

	var hp_restore = int(item.get("hp_restore", 30))
	var mp_restore = int(item.get("mp_restore", 10))
	var before_hp = int(target.get("hp", 0))
	var before_mp = int(target.get("mp", 0))
	var max_hp = int(target.get("max_hp", before_hp))
	var max_mp = int(target.get("max_mp", before_mp))
	target["hp"] = min(before_hp + hp_restore, max_hp)
	target["mp"] = min(before_mp + mp_restore, max_mp)
	controller._log("%s 雙指一掐，胡桃殼應聲破裂，隨即將掌中那充滿香氣的果仁塞入口中，陶醉地咀嚼著。" % [user_name])
	return true


func _handle_zhuge_crossbow(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var power = int(item.get("power", 18))
	var agi_total = int(user.get("agi", 0))
	var hits_raw = clamp(int(floor(float(agi_total) / 20.0)) + 1, 1, 5)
	var ammo_id = String(item.get("ammo_item_id", "ammo_arrow"))
	var ammo_item = InventorySync.get_item_by_id(ammo_id)
	var arrow_count = int(ammo_item.get("count", 0))
	if arrow_count <= 0:
		controller._log("箭矢已耗盡！")
		return false
	var hits = min(hits_raw, arrow_count)
	if arrow_count < hits_raw:
		controller._log("箭矢不足，只射出 %d 發！" % hits)
	InventorySync.consume_item(ammo_id, hits)
	var total_damage = 0
	for _i in range(hits):
		if int(target.get("hp", 0)) <= 0:
			break
		var before_hp = int(target.get("hp", 0))
		var dealt = min(power, before_hp)
		target["hp"] = max(0, before_hp - power)
		total_damage += dealt
	controller._log("%s 催動諸葛連弩，連射 %d 發！" % [user_name, hits])
	controller._log("對 %s 造成總計 [color=#ffd447]%d[/color] 傷害。" % [target_name, total_damage])
	if int(target.get("hp", 0)) <= 0:
		target["is_dead"] = true
		controller._log("%s 倒下了，已無力再戰。" % target_name)
	return false


func _handle_haste_talisman(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")

	var is_ally: bool = target in controller.player_party
	var turns = int(item.get("turns", 3))
	if turns <= 0:
		controller._log("WARN: haste_talisman missing turns: %s" % str(item.get("id", "")))
		return false

	if is_ally:
		var amount_haste: int = int(item.get("amount", 0))
		if amount_haste <= 0:
			controller._log("WARN: haste_talisman missing amount: %s" % str(item.get("id", "")))
			return false

		var before_speed = int(target.get("speed", 0))
		var ok = controller.status_manager.apply_effect(
			target,
			"speed_buff",
			{"speed_delta": amount_haste},
			turns
		)
		if not ok:
			return false

		var after_speed = int(target.get("speed", before_speed))
		var amount_haste_str = "[color=#ffd000]%d[/color]" % (after_speed - before_speed)

		if controller.tone_map != null:
			var use_line = controller.tone_map.get_tone_text("item_use", "haste_talisman", user_id)
			if use_line != "":
				controller._log(use_line)

		controller._log("%s 身上貼上%s，腳下似有風生，速度提升了 %s 點。" % [
				target_name,
				item_name,
				amount_haste_str
		])
	else:
		var enemy_element = str(item.get("enemy_element", ""))
		if enemy_element == "":
			enemy_element = "快"

		var ok_enemy = controller.status_manager.apply_effect(
			target,
			"force_element",
			{"element": enemy_element},
			turns
		)
		if not ok_enemy:
			return false

		if controller.tone_map != null:
			var use_line2 = controller.tone_map.get_tone_text("item_use", "haste_talisman", user_id)
			if use_line2 != "":
				controller._log(use_line2)

		controller._log("%s 被%s貼中，氣脈驟然加速，屬性轉為「%s」。" % [
				target_name,
				item_name,
				enemy_element
		])
	return true


func _handle_fire_talisman(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")
	var target_id: String = target.get("id", "")

	if target in controller.player_party:
		var amount_atk: int = int(item.get("amount", 0))
		if amount_atk <= 0:
			controller._log("WARN: item missing amount: %s" % item.get("id", ""))
			return false

		var amount_atk_str = "[color=#ff8080]%d[/color]" % amount_atk

		target["atk"] = target.get("atk", 0) + amount_atk

		if controller.tone_map != null:
			var use_line = controller.tone_map.get_tone_text("item_use", "fire_talisman_ally", user_id)
			if use_line != "":
				controller._log(use_line)

			var suffer_line = controller.tone_map.get_tone_text("item_suffer", "fire_talisman_ally", target_id)
			if suffer_line != "":
				controller._log(suffer_line)

		controller._log("%s 身上貼上%s，攻擊力提升 %s。" % [
				target_name,
				item_name,
				amount_atk_str
		])
	elif target in controller.enemy_party:
		var enemy_damage = int(item.get("enemy_damage", 0))
		if enemy_damage <= 0:
			controller._log("WARN: item missing enemy_damage: %s" % item.get("id", ""))
			return false

		if controller.tone_map != null:
			var use_line = controller.tone_map.get_tone_text("item_use", "fire_talisman_enemy", user_id)
			if use_line != "":
				controller._log(use_line)

		var dmg_item = item.duplicate()
		dmg_item["amount"] = enemy_damage

		controller._apply_bomb_damage_to_target(user, dmg_item, target, "fire_talisman_enemy")
	else:
		return false
	return true


func _handle_bomb_single(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	var bomb_amount = int(item.get("amount", 0))
	if bomb_amount <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return false
	item["amount"] = bomb_amount

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")

	if target.is_empty():
		controller._log("%s 丟出了 %s。" % [user_name, item_name])
	else:
		controller._log("%s 對 %s 丟出了 %s。" % [user_name, target_name, item_name])

	controller._apply_bomb_single(user, item, target)
	return true


func _handle_bomb_aoe(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> bool:
	var bomb_amount_aoe = int(item.get("amount", 0))
	if bomb_amount_aoe <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return false
	item["amount"] = bomb_amount_aoe

	var user_name: String = user.get("name", "???")
	var item_name: String = item.get("name", "???")

	controller._log("%s 拋出了 %s，準備在敵陣中引爆。" % [user_name, item_name])
	controller._apply_bomb_aoe(user, item)
	return true


func _handle_unimplemented(controller, user: Dictionary, item: Dictionary) -> bool:
	var user_name: String = user.get("name", "???")
	var item_name: String = item.get("name", "???")
	var effect: String = item.get("effect", "")

	controller._log("%s 使用了 %s，但目前尚未實作 effect：%s。" % [
		user_name,
		item_name,
		effect
	])
	return false
