extends Node

static func _compute_runtime_effects(force: Dictionary, actor: Dictionary = {}) -> Dictionary:
	if force.is_empty():
		return {}
	var result := {
		"str": int(force.get("str_flat_bonus", 0)),
		"con": int(force.get("con_flat_bonus", 0)),
		"agi": int(force.get("agi_flat_bonus", 0)),
		"int": int(force.get("int_flat_bonus", 0)),
		"luck": int(force.get("luck_flat_bonus", 0)),
		"accuracy": int(force.get("accuracy_flat_bonus", 0)),
		"def": int(force.get("def_flat_bonus", 0)),
		"max_mp": int(force.get("max_mp_flat_bonus", 0)),
		"weapon_accuracy_flat_bonus": int(force.get("weapon_accuracy_flat_bonus", 0)),
		"weapon_damage_pct_bonus": float(force.get("boost_damage_pct", 0.0)),
		"boost_weapon": String(force.get("boost_weapon", "")),
		"skill_mp_mul": float(force.get("skill_mp_cost_multiplier", 1.0)),
		"skill_mp_mul_by_weapon": force.get("skill_mp_cost_multiplier_by_weapon", {}),
		"fast_resist": 0.0,
	}
	var actor_con := int(actor.get("con", 0)) if typeof(actor) == TYPE_DICTIONARY else 0
	var actor_int := int(actor.get("int", 0)) if typeof(actor) == TYPE_DICTIONARY else 0
	var actor_str := int(actor.get("str", 0)) if typeof(actor) == TYPE_DICTIONARY else 0
	var def_from_con := float(force.get("def_from_con_ratio", 0.0))
	if def_from_con != 0.0:
		result["def"] = int(result.get("def", 0)) + int(floor(float(actor_con) * def_from_con))
	var mp_from_int := float(force.get("max_mp_from_int_ratio", 0.0))
	if mp_from_int != 0.0:
		result["max_mp"] = int(result.get("max_mp", 0)) + int(floor(float(actor_int) * mp_from_int))
	var resist_base := float(force.get("damage_reduction_vs_fast_base", 0.0))
	var resist_from_str := float(force.get("damage_reduction_vs_fast_from_str", 0.0))
	var resist_cap := float(force.get("damage_reduction_vs_fast_cap", 0.8))
	result["fast_resist"] = clampf(resist_base + float(actor_str) * resist_from_str, 0.0, max(0.0, resist_cap))
	return result

static func get_runtime_effects(force: Dictionary, actor: Dictionary = {}) -> Dictionary:
	return _compute_runtime_effects(force, actor)

static func get_effect_description_line(force: Dictionary, actor: Dictionary = {}) -> String:
	if force.is_empty():
		return ""
	var effects := _compute_runtime_effects(force, actor)
	var parts: Array[String] = []
	var str_bonus := int(effects.get("str", 0))
	if str_bonus != 0:
		parts.append("力量 %+d" % str_bonus)
	var con_bonus := int(effects.get("con", 0))
	if con_bonus != 0:
		parts.append("體能 %+d" % con_bonus)
	var agi_bonus := int(effects.get("agi", 0))
	if agi_bonus != 0:
		parts.append("敏捷 %+d" % agi_bonus)
	var int_bonus := int(effects.get("int", 0))
	if int_bonus != 0:
		parts.append("智慧 %+d" % int_bonus)
	var luck_bonus := int(effects.get("luck", 0))
	if luck_bonus != 0:
		parts.append("幸運 %+d" % luck_bonus)
	var accuracy_bonus := int(effects.get("accuracy", 0))
	if accuracy_bonus != 0:
		parts.append("命中 %+d" % accuracy_bonus)
	var def_bonus := int(effects.get("def", 0))
	if def_bonus != 0:
		parts.append("防禦 %+d" % def_bonus)
	var max_mp_bonus := int(effects.get("max_mp", 0))
	if max_mp_bonus != 0:
		parts.append("最大 MP %+d" % max_mp_bonus)
	var boost_weapon := String(effects.get("boost_weapon", ""))
	var weapon_acc_bonus := int(effects.get("weapon_accuracy_flat_bonus", 0))
	if boost_weapon != "" and weapon_acc_bonus != 0:
		parts.append("%s系招式命中 %+d" % [boost_weapon, weapon_acc_bonus])
	var weapon_damage_pct := float(effects.get("weapon_damage_pct_bonus", 0.0))
	if boost_weapon != "" and weapon_damage_pct > 0.0:
		parts.append("%s系招式傷害 +%d%%" % [boost_weapon, int(round(weapon_damage_pct * 100.0))])
	var by_weapon = effects.get("skill_mp_mul_by_weapon", {})
	if typeof(by_weapon) == TYPE_DICTIONARY:
		var map: Dictionary = by_weapon
		for weapon_type in map.keys():
			var mul := float(map.get(weapon_type, 1.0))
			if is_equal_approx(mul, 1.0):
				continue
			parts.append("%s系招式 MP 消耗 %.2f 倍" % [String(weapon_type), mul])
	var generic_mul := float(effects.get("skill_mp_mul", 1.0))
	if not is_equal_approx(generic_mul, 1.0):
		parts.append("招式 MP 消耗 %.2f 倍" % generic_mul)
	var fast_resist := float(effects.get("fast_resist", 0.0))
	if fast_resist > 0.0:
		parts.append("受到快屬性傷害降低 %d%%" % int(round(fast_resist * 100.0)))
	var extra_desc := String(force.get("extra_effect_desc", ""))
	if extra_desc != "":
		parts.append(extra_desc)
	if parts.is_empty():
		return "目前無可量化數值加成"
	return "、".join(parts)

static func get_effect_summary_line(force: Dictionary, actor: Dictionary = {}) -> String:
	if force.is_empty():
		return ""
	var effects := _compute_runtime_effects(force, actor)
	var tokens: Array[String] = []
	if int(effects.get("str", 0)) != 0:
		tokens.append("力量上升")
	if int(effects.get("con", 0)) != 0:
		tokens.append("體能上升")
	if int(effects.get("agi", 0)) != 0:
		tokens.append("敏捷上升")
	if int(effects.get("int", 0)) != 0:
		tokens.append("智慧上升")
	if int(effects.get("luck", 0)) != 0:
		tokens.append("幸運上升")
	if int(effects.get("accuracy", 0)) != 0:
		tokens.append("命中上升")
	if int(effects.get("def", 0)) != 0:
		tokens.append("防禦上升")
	if int(effects.get("max_mp", 0)) != 0:
		tokens.append("最大 MP 提升")
	var boost_weapon := String(effects.get("boost_weapon", ""))
	if boost_weapon != "" and int(effects.get("weapon_accuracy_flat_bonus", 0)) != 0:
		tokens.append("%s系命中上升" % boost_weapon)
	if boost_weapon != "" and float(effects.get("weapon_damage_pct_bonus", 0.0)) > 0.0:
		tokens.append("%s系傷害上升" % boost_weapon)
	var by_weapon = effects.get("skill_mp_mul_by_weapon", {})
	if typeof(by_weapon) == TYPE_DICTIONARY:
		var map: Dictionary = by_weapon
		for weapon_type in map.keys():
			var mul := float(map.get(weapon_type, 1.0))
			if mul < 1.0:
				tokens.append("%s系消耗下降" % String(weapon_type))
			elif mul > 1.0:
				tokens.append("%s系消耗上升" % String(weapon_type))
	if float(effects.get("fast_resist", 0.0)) > 0.0:
		tokens.append("對快屬性減傷")
	var extra_summary := String(force.get("extra_effect_summary", ""))
	if extra_summary != "":
		tokens.append(extra_summary)
	if tokens.is_empty():
		return ""
	return "%s。" % "、".join(tokens)

const INNER_FORCES := {
	"qingfeng_jue": {
		"id": "qingfeng_jue",
		"prefix": "清風",
		"type": "訣",
		"boost_weapon": "刀",
		"element": "柔",
		"description": "清風訣，行功講究一吐一納之間，體內真氣隨呼吸盤旋，如清風拂面，最利刀勢與迅疾身法。",
		"available": "all",
	},
	"liuchen_jue": {
		"id": "liuchen_jue",
		"prefix": "流塵",
		"type": "訣",
		"boost_weapon": "劍",
		"exclusive_skill_ids": ["skill_lianjuejian"],
		"element": "快",
		"agi_flat_bonus": 6,
		"accuracy_flat_bonus": 10,
		"weapon_accuracy_flat_bonus": 10,
		"boost_damage_pct": 0.10,
		"description": "流塵訣，劍勢講究快、準、穩，氣如細塵隨風入隙，先手壓制最見神髓。",
		"available": ["liuyu"],
	},
	"fuchao_jue": {
		"id": "fuchao_jue",
		"prefix": "伏潮",
		"type": "訣",
		"boost_weapon": "刀",
		"exclusive_skill_ids": ["skill_duanshuizhan"],
		"element": "遲",
		"str_flat_bonus": 6,
		"boost_damage_pct": 0.12,
		"description": "伏潮訣，真氣沉厚如潛潮伏岩，平時不顯，出刀時一波壓一波，專破對手氣勢。",
		"special_effect_desc": "刀類技能命中已破防的敵人時，有機率使其陷入暈眩。\n暈眩機率受智慧與幸運影響。",
		"available": ["liuyu", "lieshao"],
	},
	"wuji_zhenjing": {
		"id": "wuji_zhenjing",
		"prefix": "無極",
		"type": "真經",
		"boost_weapon": "劍",
		"element": "剛",
		"def_flat_bonus": 10,
		"def_from_con_ratio": 1.0,
		"damage_reduction_vs_fast_base": 0.10,
		"damage_reduction_vs_fast_from_str": 0.006,
		"damage_reduction_vs_fast_cap": 0.45,
		"description": "無極真經，意守丹田如天地初開，不動則如山，一動則驚人。劍勢緩發卻後勁綿長，專破浮躁之敵。",
		"available": "all",
	},
	"chi_yang_zhenjing": {
		"id": "chi_yang_zhenjing",
		"prefix": "赤陽",
		"type": "真經",
		"boost_weapon": "琴",
		"element": "遲",
		"description": "赤陽真經，出自弦心門烈火脈，專為琴音殺伐而生。內息如火走弦，聲聲皆可焚心。",
		"available": ["lieshao", "honghuiyin"],
	},
	"po_jun_zhenjing": {
		"id": "po_jun_zhenjing",
		"prefix": "破軍",
		"type": "真經",
		"boost_weapon": "刀",
		"element": "剛",
		"description": "破軍真經，逆勢行功，專破堅城厚甲。心法一起，刀意如星墜天江，勢若破軍。",
		"available": ["liuyu", "lieshao"],
	},
	"meng_ying_xinfa": {
		"id": "meng_ying_xinfa",
		"prefix": "夢影",
		"type": "心法",
		"boost_weapon": "筆",
		"element": "柔",
		"max_mp_flat_bonus": 20,
		"max_mp_from_int_ratio": 1.2,
		"skill_mp_cost_multiplier_by_weapon": {"筆": 0.9},
		"description": "夢影心法，講究一念入夢，一念出塵。運轉得法時，書寫如雲煙流動，筆鋒隨心意流轉。",
		"available": ["liuyu", "shumian", "honghuiyin"],
	},
	"ling_feng_jue": {
		"id": "ling_feng_jue",
		"prefix": "靈風",
		"type": "訣",
		"boost_weapon": "拳",
		"element": "快",
		"description": "靈風訣，輕身如燕，出拳若風行林梢。氣機不著痕跡，卻能在掠過之處留下一記暗勁。",
		"available": "all",
	},
	"shipo_xinfa": {
		"id": "shipo_xinfa",
		"prefix": "石破",
		"type": "心法",
		"boost_weapon": "拳",
		"element": "剛",
		"str_flat_bonus": 8,
		"con_flat_bonus": 8,
		"fist_damage_pct_if_free_hand": 0.10,
		"fist_accuracy_flat_if_both_hands_free": 10,
		"crit_rate_bonus_if_naked": 0.10,
		"damage_reduction_pct_if_naked": 0.10,
		"description": "石破心法，講究捨物存真，氣勁沉於骨血之中。外物越少，拳意越純，方可觸及天驚之境。",
		"extra_effect_desc": "至少空一手時拳系傷害 +10%、雙手皆空時拳系命中 +10、全身無裝備時暴擊率 +10% 並減少所受傷害 10%",
		"extra_effect_summary": "空手拳勢增幅，裸裝暴擊與減傷",
		"available": ["liuyu"],
	}, 
	"tiancan_jue": {
		"id": "tiancan_jue",
		"prefix": "天殘",
		"type": "訣",
		"boost_weapon": "劍",
		"element": "遲",
		"str_flat_bonus": 10,
		"con_flat_bonus": 10,
		"boost_damage_pct": 0.10,
		"sword_crit_bonus_low_hp": 0.10,
		"description": "天殘訣，逆行血氣、以殘換勢。行功時筋骨如烈火焚身，代價沉重，卻能逼出破局一斬。",
		"extra_effect_desc": "劍系招式傷害 +10%、自身 HP 低於 50% 時劍系招式暴擊率 +10%、可將「地缺劍」轉為紫色絕技「天殘．地缺劍」",
		"extra_effect_summary": "劍勢增傷、低血劍招暴擊提升、解鎖地缺劍絕技分支",
		"available": ["liuyu"],
	},
}

func get_force(force_id: String) -> Dictionary:
	if not INNER_FORCES.has(force_id):
		return {}
	return (INNER_FORCES[force_id] as Dictionary).duplicate(true)

func is_available_to_actor(force_id: String, actor_id: String) -> bool:
	var force := get_force(force_id)
	if force.is_empty():
		return false
	var available = force.get("available", "all")
	if typeof(available) == TYPE_STRING:
		return String(available) == "all"
	if typeof(available) == TYPE_ARRAY:
		return (available as Array).has(actor_id)
	return false

func get_forces_for_actor(actor_id: String, ids: Array) -> Array:
	var out: Array = []
	for force_id in ids:
		var id := String(force_id)
		if id == "":
			continue
		if not is_available_to_actor(id, actor_id):
			continue
		var force := get_force(id)
		if not force.is_empty():
			out.append(force)
	return out

func resolve_legacy_force_id(force_data: Dictionary) -> String:
	if force_data.is_empty():
		return ""
	var force_id := String(force_data.get("id", ""))
	if force_id != "" and INNER_FORCES.has(force_id):
		return force_id
	var prefix := String(force_data.get("prefix", ""))
	var force_type := String(force_data.get("type", ""))
	for id in INNER_FORCES.keys():
		var force: Dictionary = INNER_FORCES[id]
		if String(force.get("prefix", "")) == prefix and String(force.get("type", "")) == force_type:
			return String(id)
	return ""
