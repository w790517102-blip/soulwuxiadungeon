	match effect:
		# === 神速符 ===
		"haste_talisman":
			var amount_haste: int = int(item.get("amount", 0))
			var amount_haste_str := "[color=#ffd000]%d[/color]" % amount_haste
			var is_ally: bool = target in player_party

			if tone_map != null:
				var use_line := tone_map.get_tone_text("item_use", "haste_talisman", user_id)
				if use_line != "":
					_log(use_line)

			if is_ally:
				target["speed"] = target.get("speed", 0) + amount_haste
				_log("%s 身上貼上%s，腳下似有風生，速度提升了 %s 點。" % [
					target_name, item_name, amount_haste_str
				])
			else:
				target["element"] = "快"
				_log("%s 被%s貼中，氣脈驟然加速，屬性轉為「快」。" % [
					target_name, item_name
				])

		# === 烈火符：我方 atk+ / 敵方固定傷害 ===
		"fire_talisman":
			var amount_atk: int = int(item.get("amount", 15))
			var amount_atk_str := "[color=#ff8080]%d[/color]" % amount_atk

			if target in player_party:
				target["atk"] = target.get("atk", 0) + amount_atk

				if tone_map != null:
					var use_line := tone_map.get_tone_text("item_use", "fire_talisman_ally", user_id)
					if use_line != "":
						_log(use_line)

					var suffer_line := tone_map.get_tone_text("item_suffer", "fire_talisman_ally", target_id)
					if suffer_line != "":
						_log(suffer_line)

				_log("%s 身上貼上%s，攻擊力提升 %s。" % [
					target_name, item_name, amount_atk_str
				])

			elif target in enemy_party:
				if tone_map != null:
					var use_line2 := tone_map.get_tone_text("item_use", "fire_talisman_enemy", user_id)
					if use_line2 != "":
						_log(use_line2)

				# ✅ 不改你的整套傷害系統：直接走你現有的「固定傷害套用」 helper
				var dmg_item := item.duplicate()
				dmg_item["amount"] = int(item.get("enemy_damage", 30))
				_apply_bomb_damage_to_target(user, dmg_item, target, "fire_talisman_enemy")

		# === 霹靂彈：單體固定傷害 ===
		"bomb_single":
			if target.is_empty():
				_log("%s 丟出了 %s。" % [user_name, item_name])
			else:
				_log("%s 對 %s 丟出了 %s。" % [user_name, target_name, item_name])

			_apply_bomb_single(user, item, target)

		# === 轟雷霹靂彈：敵方全體固定傷害 ===
		"bomb_aoe":
			_log("%s 拋出了 %s，準備在敵陣中引爆。" % [user_name, item_name])
			_apply_bomb_aoe(user, item)

		_:
			_log("%s 使用了 %s，但目前尚未實作 effect：%s。" % [
				user_name, item_name, effect
			])
