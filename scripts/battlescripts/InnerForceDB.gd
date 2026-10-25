extends Node

const MartialSynergyScript = preload("res://scripts/battlescripts/MartialSynergy.gd")

const ELEMENT_FINAL_STAT_MULTIPLIERS := {
	"快": {"speed": 1.15, "def": 0.90},
	"柔": {"evasion": 1.15, "crit_rate": 0.90},
	"遲": {"accuracy": 1.15, "evasion": 0.90},
	"剛": {"def": 1.15, "speed": 0.90},
}

const ELEMENT_ADVANTAGE_TARGETS := {
	"快": "遲",
	"遲": "柔",
	"柔": "剛",
	"剛": "快",
}

const ELEMENT_ADVANTAGE_MULTIPLIER := 1.5


static func resolve_element_final_stat(element: String, stat_name: String, raw_value: float) -> float:
	var element_rules = ELEMENT_FINAL_STAT_MULTIPLIERS.get(element, {})
	if typeof(element_rules) != TYPE_DICTIONARY:
		return raw_value
	var rules: Dictionary = element_rules
	if not rules.has(stat_name):
		return raw_value
	var resolved := raw_value * float(rules.get(stat_name, 1.0))
	if stat_name == "crit_rate":
		return clampf(resolved, 0.0, 0.95)
	return float(round(resolved))


static func resolve_element_advantage_multiplier(attacker_element: String, defender_element: String) -> float:
	var advantaged_element := String(ELEMENT_ADVANTAGE_TARGETS.get(attacker_element, ""))
	if advantaged_element != "" and advantaged_element == defender_element:
		return ELEMENT_ADVANTAGE_MULTIPLIER
	return 1.0


## 清渠護印（清渠共印的防護）：同一份防護有兩個來源——白書眠正在運行《清渠共印》（內功被動），以及《清渠澄心落筆》施放後
## 留在隊員身上的「清渠護印」狀態（3 回合）。兩者是同一類防護，合併時只算一次：遲屬性防禦取較大值、語魅傷害倍率取較小值，
## 不會 +30 或 ×0.81。其他來源的防禦／減傷（def_up、臨符、石破心法等）不受影響，照舊各自疊加。
const WARD_STATUS_ID := "qingqu_ward"


## The ward protection an actor has right now, from both sources merged without double counting:
## {"def_vs_element": {attacker_element: flat defense}, "damage_mult_vs_family": {enemy family: final damage multiplier}}.
static func resolve_ward_protection(actor: Dictionary) -> Dictionary:
	var def_vs_element: Dictionary = {}
	var damage_mult_vs_family: Dictionary = {}
	var sources: Array = []
	var force = actor.get("inner_force", {})
	if typeof(force) == TYPE_DICTIONARY:
		sources.append(force)
	var effects = actor.get("status_effects", {})
	if typeof(effects) == TYPE_DICTIONARY and (effects as Dictionary).has(WARD_STATUS_ID):
		var record = (effects as Dictionary)[WARD_STATUS_ID]
		if typeof(record) == TYPE_DICTIONARY and typeof((record as Dictionary).get("payload", {})) == TYPE_DICTIONARY:
			sources.append((record as Dictionary).get("payload", {}))
	for source_any in sources:
		var source: Dictionary = source_any
		var def_map = source.get("ward_def_vs_element", {})
		if typeof(def_map) == TYPE_DICTIONARY:
			for element in (def_map as Dictionary).keys():
				var value := float((def_map as Dictionary)[element])
				def_vs_element[String(element)] = maxf(float(def_vs_element.get(String(element), 0.0)), value)
		var mult_map = source.get("ward_damage_mult_vs_family", {})
		if typeof(mult_map) == TYPE_DICTIONARY:
			for family in (mult_map as Dictionary).keys():
				var mult := float((mult_map as Dictionary)[family])
				damage_mult_vs_family[String(family)] = minf(float(damage_mult_vs_family.get(String(family), 1.0)), mult)
	return {"def_vs_element": def_vs_element, "damage_mult_vs_family": damage_mult_vs_family}


## The payload a 清渠護印 status carries: the very numbers of the inner force that defines it (one place to tune).
static func ward_payload_from_force(force_id: String) -> Dictionary:
	var force: Dictionary = (INNER_FORCES.get(force_id, {}) as Dictionary)
	return {
		"ward_def_vs_element": (force.get("ward_def_vs_element", {}) as Dictionary).duplicate(true),
		"ward_damage_mult_vs_family": (force.get("ward_damage_mult_vs_family", {}) as Dictionary).duplicate(true),
	}


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

## 內功 × 武術的「武器加成」：內功的 boost_weapon 與招式的 weapon_type 相同就成立（戰鬥的 coupling 詞綴與數值加成都看同一條件）。
## 成立回 {text_long, text_short}，不成立回 {}。數字全部從內功資料讀；資料裡的特殊敘述用 weapon_boost_note / weapon_boost_note_short 補。
static func weapon_boost_texts(force: Dictionary, skill_weapon_type: String) -> Dictionary:
	var weapon := skill_weapon_type.strip_edges()
	if force.is_empty() or weapon == "" or weapon == "通用":
		return {}
	if String(force.get("boost_weapon", "")) != weapon:
		return {}
	var force_name := "%s%s" % [String(force.get("prefix", "")), String(force.get("type", ""))]
	var long_parts: Array[String] = []
	var short_parts: Array[String] = []
	var accuracy := int(force.get("weapon_accuracy_flat_bonus", 0))
	if accuracy != 0:
		long_parts.append("命中 %+d" % accuracy)
		short_parts.append("命中%+d" % accuracy)
	var damage_pct := float(force.get("boost_damage_pct", 0.0))
	if damage_pct > 0.0:
		long_parts.append("傷害 +%d%%" % int(round(damage_pct * 100.0)))
		short_parts.append("傷害+%d%%" % int(round(damage_pct * 100.0)))
	var by_weapon = force.get("skill_mp_cost_multiplier_by_weapon", {})
	if typeof(by_weapon) == TYPE_DICTIONARY and (by_weapon as Dictionary).has(weapon):
		var mul := float((by_weapon as Dictionary)[weapon])
		if mul < 1.0:
			long_parts.append("MP 消耗降低 %d%%" % int(round((1.0 - mul) * 100.0)))
			short_parts.append("MP-%d%%" % int(round((1.0 - mul) * 100.0)))
		elif mul > 1.0:
			long_parts.append("MP 消耗增加 %d%%" % int(round((mul - 1.0) * 100.0)))
			short_parts.append("MP+%d%%" % int(round((mul - 1.0) * 100.0)))
	var note_long := String(force.get("weapon_boost_note", ""))
	var note_short := String(force.get("weapon_boost_note_short", ""))
	var text_long := ""
	var text_short := ""
	if long_parts.is_empty() and note_long == "":
		text_long = "%s強化%s系招式。" % [force_name, weapon]
		text_short = "%s：強化%s招。" % [force_name, weapon]
	else:
		var gap := " " if not long_parts.is_empty() and String(long_parts[0]).begins_with("MP") else ""
		text_long = "%s下，%s系招式%s%s" % [force_name, weapon, gap, "、".join(long_parts)]
		if note_long != "":
			text_long += ("；" if not long_parts.is_empty() else "") + note_long
		text_long += "。"
		text_short = "%s：%s招%s" % [force_name, weapon, "、".join(short_parts)]
		if note_short != "":
			text_short += ("，" if not short_parts.is_empty() else "") + note_short
		text_short += "。"
	return {"text_long": text_long, "text_short": text_short}


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
		"element": "遲",
		"str_flat_bonus": 6,
		"boost_damage_pct": 0.12,
		"description": "伏潮訣，真氣沉厚如潛潮伏岩，平時不顯，出刀時一波壓一波，專破對手氣勢。",
		"special_effect_desc": "刀類技能命中已破防的敵人時，有機率使其陷入暈眩。\n暈眩機率受智慧與幸運影響。",
		"weapon_boost_note": "對已破防敵人出刀時，有機率追加暈眩",
		"weapon_boost_note_short": "打破防目標可追暈",
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
		"boost_damage_pct": 0.20,
		"weapon_accuracy_flat_bonus": 10,
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
		"weapon_boost_note": "至少空一手時傷害 +10%，雙手皆空時命中 +10",
		"weapon_boost_note_short": "空手拳勢增幅",
		"fist_accuracy_flat_if_both_hands_free": 10,
		"crit_rate_bonus_if_naked": 0.10,
		"damage_reduction_pct_if_naked": 0.10,
		"description": "石破心法，講究捨物存真，氣勁沉於骨血之中。外物越少，拳意越純，方可觸及天驚之境。",
		"extra_effect_desc": "至少空一手時拳系傷害 +10%、雙手皆空時拳系命中 +10、全身無裝備時暴擊率 +10% 並減少所受傷害 10%",
		"extra_effect_summary": "空手拳勢增幅，裸裝暴擊與減傷",
		"available": ["liuyu"],
	}, 
	"chenchao_jue": {
		"id": "chenchao_jue",
		"prefix": "沉潮",
		"type": "訣",
		"element": "遲",
		"boost_weapon": "槍",
		"description": "沉氣如潮伏於深處，不迎其鋒，不逐其退。先定身勢，再循敵勢尋隙而發。",
		"available": "all",
		"required_weapon_aptitude": "槍",
		"str_flat_bonus": 3,
		"con_flat_bonus": 2,
		"accuracy_flat_bonus": 4,
		"max_mp_flat_bonus": 6,
		"skill_mp_cost_multiplier_by_weapon": {"槍": 0.90},
	},
	"qingqu_gongyin": {
		"id": "qingqu_gongyin",
		"prefix": "清渠",
		"type": "共印",
		"element": "遲",
		"description": "清渠共印，是書眠回到舊水道、把自己貼下的符一張張看完之後才悟出的內功。不再把一切獨自壓在心底，而是讓水路有口可流，守住自己，也替身邊的人留一條出路。",
		"extra_effect_desc": "運行時：受到遲屬性攻擊，防禦 +15；受到語魅造成的傷害，最終傷害 ×0.9。\n與「澄心落筆」相合：清渠澄心落筆。",
		"extra_effect_summary": "遲屬性防禦、語魅減傷",
		"ward_def_vs_element": {"遲": 15},
		"ward_damage_mult_vs_family": {"yumei": 0.9},
		"available": ["shumian"],
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
		"weapon_boost_note": "當自身 HP 低於 50% 時，劍系招式暴擊率 +10%",
		"weapon_boost_note_short": "低血(HP<50%)時劍招暴擊+10%",
		"description": "天殘訣，逆行血氣、以殘換勢。行功時筋骨如烈火焚身，代價沉重，卻能逼出破局一斬。",
		"extra_effect_desc": "劍系招式傷害 +10%、自身 HP 低於 50% 時劍系招式暴擊率 +10%、可將「地缺劍」轉為紫色絕技「天殘．地缺劍」",
		"extra_effect_summary": "劍勢增傷、低血劍招暴擊提升、解鎖地缺劍絕技分支",
		"available": ["liuyu"],
	},
}

func get_force(force_id: String) -> Dictionary:
	if not INNER_FORCES.has(force_id):
		return {}
	var force: Dictionary = (INNER_FORCES[force_id] as Dictionary).duplicate(true)
	# which skills a force makes exclusive comes from the standard synergies (MartialSynergy), not from a second list
	var synergy_ids: Array = MartialSynergyScript.exclusive_skill_ids(force_id)
	if not synergy_ids.is_empty():
		force["exclusive_skill_ids"] = synergy_ids
	if not force.has("available"):
		force["available"] = "all"
	if not force.has("required_level"):
		force["required_level"] = 1
	return force

func get_all_forces() -> Array:
	var out: Array = []
	for force_id in INNER_FORCES.keys():
		out.append(get_force(String(force_id)))
	return out

func is_available_to_actor(force_id: String, actor_id: String, actor_override: Dictionary = {}) -> bool:
	var force := get_force(force_id)
	if force.is_empty():
		return false
	var available = force.get("available", "all")
	var available_to_actor := false
	if typeof(available) == TYPE_STRING:
		available_to_actor = String(available) == "all" or String(available) == actor_id
	elif typeof(available) == TYPE_ARRAY:
		available_to_actor = (available as Array).has(actor_id)
	elif typeof(available) == TYPE_DICTIONARY:
		var scope: Dictionary = available
		var mode := String(scope.get("mode", "all"))
		var actor_ids = scope.get("actor_ids", [])
		available_to_actor = mode == "all" or (mode == "include" and typeof(actor_ids) == TYPE_ARRAY and (actor_ids as Array).has(actor_id))
	if not available_to_actor:
		return false
	var required_weapon := String(force.get("required_weapon_aptitude", ""))
	if required_weapon == "":
		return true
	if typeof(actor_override) == TYPE_DICTIONARY and not actor_override.is_empty():
		var aptitudes = actor_override.get("weapon_aptitudes", [])
		return typeof(aptitudes) == TYPE_ARRAY and (aptitudes as Array).has(required_weapon)
	# Callers that only have an actor id can still use the legacy availability
	# contract; the authoritative TeamData entry points pass the normalized actor
	# dictionary above.  Keeping this script free of an autoload reference also
	# preserves standalone DB/test loading.
	return false

func get_required_level(force_id: String) -> int:
	var force := get_force(force_id)
	if force.is_empty():
		return 1
	return max(1, int(force.get("required_level", 1)))

func is_level_eligible(force_id: String, actor_level: int) -> bool:
	return actor_level >= get_required_level(force_id)

func get_forces_for_actor(actor_id: String, ids: Array, actor_override: Dictionary = {}) -> Array:
	var out: Array = []
	for force_id in ids:
		var id := String(force_id)
		if id == "":
			continue
		if not is_available_to_actor(id, actor_id, actor_override):
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
