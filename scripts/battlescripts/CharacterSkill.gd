extends Node

# 基本角色技能資料（後續可改為從 JSON 載入）
func get_skills(character_id: String) -> Array:
	match character_id:
		"liuyu":
			return [
				{
					"name": "連訣劍",
					"weapon_type": "劍",
					"power": 1.1,
					"category":"單體攻擊",
					"desc": "迅速揮劍三次，連擊破敵。"
				},
				{
					"name": "霸刀斬",
					"weapon_type": "刀",
					"power": 1.2,
					"category":"單體攻擊",
					"desc": "霸氣一斬，重擊敵人。"
				},
				{
					"name": "木劍掃葉",
					"weapon_type": "劍",
					"power": 0.8,
					"category":"單體攻擊",
					"desc": "以木劍練武時,悟得之招式。"
				},
				{
					"id": "skill_qiliaozhang",
					"name": "氣療掌",
					"effect": "heal_hp",
					"weapon_type": "掌",
					"category":"單體恢復",
					"heal_amount": 40,          # 自己調數值
					"target_scope": "single",   # ✅ 單體
					"target_side": "ally"
				},
				{
					"id": "skill_xianglong18",
					"name": "翔龍十八掌",
					"weapon_type": "掌",
					"category":"全體攻擊",
					"require_free_hand": true,
					"power": 1.0,
					"target_scope": "enemy_all",  # ⭐ 關鍵：全體敵人
					"target_side": "enemy",
					"desc": "真氣自丹田騰起如龍，一掌落下，氣浪層層外推，席捲對面整片陣線。"
				}

			]
		"shumian":
			return [
				{
					"name": "筆掃煙霞",
					"weapon_type": "筆",
					"power": 1.1,
					"category":"全體攻擊",
					"target_scope": "enemy_all",  # ⭐ 關鍵：全體敵人
					"target_side": "enemy",
					"desc": "以筆破風，掃出詩意煙霞，傷敵於無形。"
				},
				{
					"name": "落筆成詩",
					"weapon_type": "筆",
					"category":"單體攻擊",
					"power": 1.3,
					"desc": "一筆揮就，一詩成陣，敵人心神動搖。"
				},
				{
					"name": "正心拳",
					"weapon_type": "拳",
					"category":"單體攻擊",
					"power": 1.3,
					"desc": "扎穩馬步，屏除雜念，用堅定的信念揮出一拳。"
				},
				{
					"id": "skill_mobishuxin",
					"name": "墨筆舒心",
					"weapon_type": "筆",
					"effect": "heal_hp",
					"category":"全體恢復",
					"desc": "扎穩馬步，屏除雜念，用堅定的信念揮出一拳。",
					"heal_amount": 18,          # ✅ 數值你可以調成「少量」
					"target_scope": "ally_all", # ✅ 全體我方
					"target_side": "ally"
}
			]
		"lieshao":
			return [
				{
					"name": "烈刀破勢",
					"weapon_type": "刀",
					"power": 1.2,
					"category":"單體攻擊",
					"desc": "猛然橫刀劈斷氣勢，強行突破敵陣。"
				},
				{
					"name": "亂音碎琴",
					"weapon_type": "琴",
					"power": 1.1,
					"category":"單體攻擊",
					"desc": "激昂琴音化為利刃，震懾敵人心魄。"
				},
				{
					"id": "skill_huagu_mianzhang",
					"name": "化骨綿掌",
					"mp_cost": 12,
					"weapon_type": "掌",
					"category": "單體攻擊",
					"target_scope": "single",
					"target_side": "enemy",
					"effects": [
						{"type": "damage", "power": 0.95},
						{"type": "force_element", "element": "柔", "turns": 3}
					],
					"desc": "掌勁入骨，綿裡藏勁，並強行將敵之屬性轉為柔。"
				},
				{
					"id": "skill_huanbu_zhang",
					"name": "緩步掌",
					"mp_cost": 10,
					"weapon_type": "掌",
					"category": "單體攻擊",
					"target_scope": "single",
					"target_side": "enemy",
					"effects": [
						{"type": "damage", "power": 0.90},
						{"type": "debuff_speed", "amount": 5, "turns": 2}
					],
					"desc": "掌風黏滯如泥，令敵身法遲緩。"
				},
				{
					"id": "skill_liumai_shenjian",
					"name": "六脈神劍",
					"mp_cost": 18,
					"weapon_type": "劍",
					"category": "單體攻擊",
					"target_scope": "single",
					"target_side": "enemy",
					"effects": [
						{"type": "damage", "power": 1.15},
						{"type": "buff_speed", "amount": 6, "turns": 2, "target": "self"}
					],
					"desc": "劍氣化脈，疾如驟雨，出手更快。"
				},
				{
					"id": "skill_bagua_gunfa",
					"name": "八卦棍法",
					"mp_cost": 12,
					"weapon_type": "棍",
					"category": "單體攻擊",
					"target_scope": "single",
					"target_side": "enemy",
					"effects": [
						{"type": "damage", "power": 1.00},
						{"type": "debuff_speed", "amount": 4, "turns": 2}
					],
					"desc": "棍走八卦，纏步鎖身，令敵動作遲滯。"
				}

			]
		"enemy1":
			return [
				{
					"name": "滯水陰掌",
					"weapon_type": "掌",
					"power": 1.1,
					"desc": "語魅以濕掌勾魂，令敵意識遲滯。"
				}
			]
		"enemy2":
			return [
				{
					"name": "磐石剛拳",
					"weapon_type": "拳",
					"power": 1.1,
					"desc": "語魅以磐石般的硬拳痛擊對手。"
				}
			]
		_:
			return []

# 詞綴邏輯組合器（SkillResolver 功能）
func resolve_skill_name(skill: Dictionary, inner_force: Dictionary) -> String:
	if inner_force and inner_force.has("prefix") and inner_force.has("boost_weapon") and skill.has("weapon_type"):
		if inner_force["boost_weapon"] == skill["weapon_type"]:
			return "%s%s" % [inner_force["prefix"], skill["name"]]
	return skill["name"]
