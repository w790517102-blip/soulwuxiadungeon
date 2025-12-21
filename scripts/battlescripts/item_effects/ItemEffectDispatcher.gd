extends Node
class_name ItemEffectDispatcher

func apply(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var effect: String = item.get("effect", "")

	match effect:
		"heal", "heal_hp":
			_handle_heal_hp(controller, user, item, target)
		"mp_heal":
			_handle_mp_heal(controller, user, item, target)
		"buff_speed":
			_handle_buff_speed(controller, user, item, target)
		"debuff_speed":
			_handle_debuff_speed(controller, user, item, target)
		"haste_talisman":
			_handle_haste_talisman(controller, user, item, target)
		"fire_talisman":
			_handle_fire_talisman(controller, user, item, target)
		"bomb_single":
			_handle_bomb_single(controller, user, item, target)
		"bomb_aoe":
			_handle_bomb_aoe(controller, user, item, target)
		_:
			_handle_unimplemented(controller, user, item)


func _handle_heal_hp(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var amount: int = int(item.get("amount", 0))
	if amount <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return

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
			var extra_hp := controller.tone_map.get_tone_text("item_use", "heal", user_id)
			if extra_hp != "":
				controller._log(extra_hp)

		var amount_str := "[color=#80ff80]%d[/color]" % restored

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


func _handle_mp_heal(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var amount_mp: int = int(item.get("amount", 0))
	if amount_mp <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return

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
			var extra_mp := controller.tone_map.get_tone_text("item_use", "mp_heal", user_id)
			if extra_mp != "":
				controller._log(extra_mp)

		var amount_mp_str := "[color=#80ffe0]%d[/color]" % restored_mp

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


func _handle_buff_speed(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var amount_spd: int = int(item.get("amount", 0))
	if amount_spd <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")
	var target_id: String = target.get("id", "")

	var before_spd: int = target.get("speed", 0)
	var after_spd: int = before_spd + amount_spd
	target["speed"] = after_spd

	if controller.tone_map != null:
		var use_line := controller.tone_map.get_tone_text("item_use", "buff_speed", user_id)
		if use_line != "":
			controller._log(use_line)

		var suffer_line := controller.tone_map.get_tone_text("item_suffer", "buff_speed", target_id)
		if suffer_line != "":
			controller._log(suffer_line)

	var amount_spd_str := "[color=#ffd000]%d[/color]" % amount_spd
	controller._log("%s 對 %s 使用了 %s，%s 的速度提升了 %s 點。" % [
		user_name,
		target_name,
		item_name,
		target_name,
		amount_spd_str
	])


func _handle_debuff_speed(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var amount_speed: int = int(item.get("amount", 0))
	if amount_speed <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")
	var target_id: String = target.get("id", "")

	if controller.tone_map != null:
		var use_line := controller.tone_map.get_tone_text("item_use", "debuff_speed", user_id)
		if use_line != "":
			controller._log(use_line)

	var before_spd: int = 0
	if target.has("speed"):
		before_spd = int(target.get("speed", 0))
	elif target.has("spd"):
		before_spd = int(target.get("spd", 0))

	var after_spd: int = max(before_spd - amount_speed, 0)
	var reduced: int = before_spd - after_spd

	if target.has("speed"):
		target["speed"] = after_spd
	elif target.has("spd"):
		target["spd"] = after_spd

	if controller.tone_map != null:
		var suffer_line := controller.tone_map.get_tone_text("item_suffer", "debuff_speed", target_id)
		if suffer_line != "":
			controller._log(suffer_line)

	if reduced > 0:
		var amount_str := "[color=#ffcc66]%d[/color]" % reduced
		var line3 := "%s 對 %s 使用了 %s，%s 的速度降低了 %s 點。" % [
				user_name,
				target_name,
				item_name,
				target_name,
				amount_str
		]
		controller._log(line3)
	else:
		var line_no_effect2 := "%s 使出 %s 想絆住 %s 的腳步，但對方氣勢如虹，幾乎沒被拖慢。" % [
				user_name,
				item_name,
				target_name
		]
		controller._log(line_no_effect2)


func _handle_haste_talisman(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")

	var is_ally: bool = target in controller.player_party

	if is_ally:
		var amount_haste: int = int(item.get("amount", 0))
		if amount_haste <= 0:
			controller._log("WARN: haste_talisman missing amount: %s" % str(item.get("id", "")))
			return

		var amount_haste_str := "[color=#ffd000]%d[/color]" % amount_haste
		target["speed"] = int(target.get("speed", 0)) + amount_haste

		if controller.tone_map != null:
			var use_line := controller.tone_map.get_tone_text("item_use", "haste_talisman", user_id)
			if use_line != "":
				controller._log(use_line)

		controller._log("%s 身上貼上%s，腳下似有風生，速度提升了 %s 點。" % [
				target_name,
				item_name,
				amount_haste_str
		])
	else:
		var enemy_element := str(item.get("enemy_element", ""))
		if enemy_element == "":
			controller._log("WARN: haste_talisman missing enemy_element: %s" % str(item.get("id", "")))
			return

		target["element"] = enemy_element

		if controller.tone_map != null:
			var use_line2 := controller.tone_map.get_tone_text("item_use", "haste_talisman", user_id)
			if use_line2 != "":
				controller._log(use_line2)

		controller._log("%s 被%s貼中，氣脈驟然加速，屬性轉為「%s」。" % [
				target_name,
				item_name,
				enemy_element
		])


func _handle_fire_talisman(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")
	var user_id: String = user.get("id", "")
	var target_id: String = target.get("id", "")

	if target in controller.player_party:
		var amount_atk: int = int(item.get("amount", 0))
		if amount_atk <= 0:
			controller._log("WARN: item missing amount: %s" % item.get("id", ""))
			return

		var amount_atk_str := "[color=#ff8080]%d[/color]" % amount_atk

		target["atk"] = target.get("atk", 0) + amount_atk

		if controller.tone_map != null:
			var use_line := controller.tone_map.get_tone_text("item_use", "fire_talisman_ally", user_id)
			if use_line != "":
				controller._log(use_line)

			var suffer_line := controller.tone_map.get_tone_text("item_suffer", "fire_talisman_ally", target_id)
			if suffer_line != "":
				controller._log(suffer_line)

		controller._log("%s 身上貼上%s，攻擊力提升 %s。" % [
				target_name,
				item_name,
				amount_atk_str
		])
	elif target in controller.enemy_party:
		var enemy_damage := int(item.get("enemy_damage", 0))
		if enemy_damage <= 0:
			controller._log("WARN: item missing enemy_damage: %s" % item.get("id", ""))
			return

		if controller.tone_map != null:
			var use_line := controller.tone_map.get_tone_text("item_use", "fire_talisman_enemy", user_id)
			if use_line != "":
				controller._log(use_line)

		var dmg_item := item.duplicate()
		dmg_item["amount"] = enemy_damage

		controller._apply_bomb_damage_to_target(user, dmg_item, target, "fire_talisman_enemy")


func _handle_bomb_single(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var bomb_amount := int(item.get("amount", 0))
	if bomb_amount <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return
	item["amount"] = bomb_amount

	var user_name: String = user.get("name", "???")
	var target_name: String = target.get("name", "???")
	var item_name: String = item.get("name", "???")

	if target.is_empty():
		controller._log("%s 丟出了 %s。" % [user_name, item_name])
	else:
		controller._log("%s 對 %s 丟出了 %s。" % [user_name, target_name, item_name])

	controller._apply_bomb_single(user, item, target)


func _handle_bomb_aoe(controller, user: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var bomb_amount_aoe := int(item.get("amount", 0))
	if bomb_amount_aoe <= 0:
		controller._log("WARN: item missing amount: %s" % item.get("id", ""))
		return
	item["amount"] = bomb_amount_aoe

	var user_name: String = user.get("name", "???")
	var item_name: String = item.get("name", "???")

	controller._log("%s 拋出了 %s，準備在敵陣中引爆。" % [user_name, item_name])
	controller._apply_bomb_aoe(user, item)


func _handle_unimplemented(controller, user: Dictionary, item: Dictionary) -> void:
	var user_name: String = user.get("name", "???")
	var item_name: String = item.get("name", "???")
	var effect: String = item.get("effect", "")

	controller._log("%s 使用了 %s，但目前尚未實作 effect：%s。" % [
		user_name,
		item_name,
		effect
	])
