# ✅ 通用版 EnemyAI.gd
# 任何敵人都可以吃這套 AI，不綁定特定 id

extends Node
class_name EnemyAI

# 回傳：
# {
#   "skill": Dictionary,  # 要使用的技能資料（或普通攻擊）
#   "target": Dictionary  # 要攻擊 / 作用的目標
# }
func get_action(enemy: Dictionary, player_party: Array, skill_list: Array) -> Dictionary:
	# 先過濾出「還活著」的玩家當目標候選
	var valid_targets: Array = []
	for p in player_party:
		if p.get("hp", 0) > 0:
			valid_targets.append(p)

	if valid_targets.is_empty():
		# 沒有人可以打了，直接放棄這回合
		return {}

	# ✅ 基礎普通攻擊（給「沒有任何技能」的敵人用）
	var basic_skill := {
		"id": "basic_attack",
		"name": "普通攻擊",
		"power": 1.0,
		"target_scope": "enemy_single"
	}

	# === 情況 0：完全沒有技能 → 用普通攻擊 ===
	if skill_list.is_empty():
		print("⚠️ 敵人 %s 沒有技能可用，改用普通攻擊。" % enemy.get("name", "???"))
		var t0: Dictionary = valid_targets[randi() % valid_targets.size()]
		return {
			"skill": basic_skill,
			"target": t0
		}

	# === 情況 1：低血量 → 優先找回復技 ===
	var hp_now: float = float(enemy.get("hp", 100))
	var hp_max: float = float(enemy.get("max_hp", 100))
	if hp_now < 0.2 * hp_max:
		for skill in skill_list:
			if skill.get("effect", "") == "heal":
				# 自己幫自己補血
				return {
					"skill": skill,
					"target": enemy
				}

	# === 情況 2：有高威力技（power >= 1.5） → 砍血最少的人 ===
	var high_power_skills: Array = []
	for s in skill_list:
		if s.get("power", 1.0) >= 1.5:
			high_power_skills.append(s)

	if not high_power_skills.is_empty():
		var high_skill: Dictionary = high_power_skills[0]
		var t1: Dictionary = _get_lowest_hp_target(valid_targets)
		# 安全一下，避免回傳空 Dictionary
		if t1.is_empty():
			t1 = valid_targets[randi() % valid_targets.size()]
		return {
			"skill": high_skill,
			"target": t1
		}

	# === 情況 3：一般情況 → 隨機技能 + 隨機目標 ===
	var random_skill = skill_list[randi() % skill_list.size()]
	var t2: Dictionary = valid_targets[randi() % valid_targets.size()]
	return {
		"skill": random_skill,
		"target": t2
	}


# 🔍 選出血量最低的目標（party 只會塞活著的成員）
func _get_lowest_hp_target(party: Array) -> Dictionary:
	var lowest: Dictionary = {}
	var min_hp: int = 999999

	for member in party:
		var hp: int = member.get("hp", 0)
		if hp > 0 and hp < min_hp:
			min_hp = hp
			lowest = member

	return lowest
