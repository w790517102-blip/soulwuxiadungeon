func execute_action(actor: Dictionary, skill_data: Dictionary, target: Dictionary = {}) -> void:
	var effect: String = str(skill_data.get("effect", ""))
	var scope: String  = str(skill_data.get("target_scope", "single"))
	var side: String   = str(skill_data.get("target_side", "enemy"))

	# =========================
	# 0️⃣ 支援 / 補血技能分流（保持剛剛那段）
	# =========================
	if effect == "heal_hp" or effect == "mp_heal" or side == "ally":
		await _execute_support_heal_action(actor, skill_data, target)
		check_battle_status()
		return

	# =========================
	# 1️⃣ AOE：全體敵方（例：翔龍十八掌）
	# =========================
	if scope == "enemy_all" and side == "enemy":
		if enemy_party.is_empty():
			push_warning("❗ execute_action：敵方隊伍為空，AOE 無目標。")
			return

		var inner_force = actor.get("inner_force", {})

		# 🎭 決定顯示用招式名稱（含 prefix）
		var display_skill_name: String = str(skill_data.get("name", "???"))
		if inner_force.has("prefix") and inner_force.has("boost_weapon"):
			var bw: String = str(inner_force.get("boost_weapon", ""))
			var wt: String = str(skill_data.get("weapon_type", ""))
			if bw == wt:
				display_skill_name = "%s%s" % [
					str(inner_force.get("prefix", "")),
					display_skill_name
				]

		var actor_name: String = str(actor.get("name", "???"))

		# 🌊 先打一句「全場級」描述，賦予 AOE 感
		# （這句你之後想改成別的招式專屬語氣也可以在這裡客製）
		_log("%s 使出「%s」，掌風層層拍出，氣浪如驟雨般席捲整個敵陣。" % [
			actor_name,
			display_skill_name
		])

		var any_down := false

		# 逐一對「還活著的敵人」結算（連環多段演出）
		for enemy in enemy_party:
			if typeof(enemy) != TYPE_DICTIONARY:
				continue
			if int(enemy.get("hp", 0)) <= 0:
				continue

			var result = skill_executor.execute(actor, enemy, skill_data, inner_force)

			# 🎬 每個目標各跑一次敘事＋受擊動畫
			await _play_attack_cinematic(actor, enemy, skill_data, result)

			if result.get("target_down", false):
				enemy["hp"] = 0
				enemy["is_dead"] = true
				any_down = true

		# ⭐ 更新敵方 UI
		if any_down and battle_ui:
			battle_ui.update_enemy_panel()

		check_battle_status()
		return

	# =========================
	# 2️⃣ 原本的單體攻擊流程（維持你原本那段）
	# =========================
	if enemy_party.is_empty() and target.is_empty():
		push_warning("❗ execute_action 被呼叫時沒有敵人可以攻擊")
		return

	var actual_target: Dictionary
	if target.is_empty():
		actual_target = enemy_party[0]
	else:
		actual_target = target

	var inner_force_single = actor.get("inner_force", {})
	var result_single = skill_executor.execute(actor, actual_target, skill_data, inner_force_single)

	await _play_attack_cinematic(actor, actual_target, skill_data, result_single)

	if result_single.target_down:
		actual_target["hp"] = 0
		actual_target["is_dead"] = true
		if battle_ui:
			battle_ui.update_enemy_panel()

	check_battle_status()
