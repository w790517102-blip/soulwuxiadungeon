extends Node

const SKILLS := {
	"skill_lianjuejian": {
		"id": "skill_lianjuejian",
		"name": "連訣劍",
		"category": "單體攻擊",
		"description": "迅速揮劍三次，連擊破敵。",
		"weapon_type": "劍",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.1}],
		"available": {"mode": "all"},
	},
	"skill_badaozhan": {
		"id": "skill_badaozhan",
		"name": "霸刀斬",
		"category": "單體攻擊",
		"description": "霸氣一斬，重擊敵人。",
		"weapon_type": "刀",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.2}],
		"available": {"mode": "all"},
	},
	"skill_mujian_saoye": {
		"id": "skill_mujian_saoye",
		"name": "木劍掃葉",
		"category": "單體攻擊",
		"description": "以木劍練武時，悟得之招式。",
		"weapon_type": "劍",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.8}],
		"available": {"mode": "all"},
	},
	"skill_qiliaozhang": {
		"id": "skill_qiliaozhang",
		"name": "氣療掌",
		"category": "單體恢復",
		"description": "掌勁回流經脈，穩住傷勢。",
		"weapon_type": "掌",
		"menu_usable": true,
		"mp_cost": 5,
		"target_scope": "single",
		"target_side": "ally",
		"effects": [{"type": "heal_hp", "amount": 40}],
		"available": {"mode": "all"},
	},
	"skill_xianglong18": {
		"id": "skill_xianglong18",
		"name": "翔龍十八掌",
		"category": "全體攻擊",
		"description": "真氣自丹田騰起如龍，一掌落下，氣浪層層外推。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "enemy_all",
		"target_side": "enemy",
		"require_free_hand": true,
		"effects": [{"type": "damage", "power": 1.0}],
		"available": {"mode": "include", "actor_ids": ["liuyu"]},
	},
	"skill_bisaoyanxia": {
		"id": "skill_bisaoyanxia",
		"name": "筆掃煙霞",
		"category": "全體攻擊",
		"description": "以筆破風，掃出詩意煙霞，傷敵於無形。",
		"weapon_type": "筆",
		"menu_usable": false,
		"mp_cost": 10,
		"target_scope": "enemy_all",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.1}],
		"available": {"mode": "all"},
	},
	"skill_luobichengshi": {
		"id": "skill_luobichengshi",
		"name": "落筆成詩",
		"category": "單體攻擊",
		"description": "一筆揮就，一詩成陣，敵人心神動搖。",
		"weapon_type": "筆",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.3}],
		"available": {"mode": "all"},
	},
	"skill_zhengxinquan": {
		"id": "skill_zhengxinquan",
		"name": "正心拳",
		"category": "單體攻擊",
		"description": "扎穩馬步，屏除雜念，用堅定的信念揮出一拳。",
		"weapon_type": "拳",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.3}],
		"available": {"mode": "all"},
	},
	"skill_buff_speed_test": {
		"id": "skill_buff_speed_test",
		"name": "提氣輕身",
		"category": "單體增益",
		"description": "運氣提身，腳下如風。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 5,
		"target_scope": "single",
		"target_side": "ally",
		"effects": [{"type": "buff_speed", "amount": 3, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_debuff_speed_test": {
		"id": "skill_debuff_speed_test",
		"name": "凝滯封脈",
		"category": "單體減益",
		"description": "封住敵人經脈，使其身形遲鈍。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 5,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "debuff_speed", "amount": 3, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_force_element_test": {
		"id": "skill_force_element_test",
		"name": "轉性訣",
		"category": "屬性變化",
		"description": "以真氣扭轉敵人體內屬性流向。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 8,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "force_element", "element": "柔", "turns": 2}],
		"available": {"mode": "all"},
	},
	"skill_mobishuxin": {
		"id": "skill_mobishuxin",
		"name": "墨筆舒心",
		"category": "全體恢復",
		"description": "筆墨舒心，氣息回流，眾人心神微定。",
		"weapon_type": "筆",
		"menu_usable": true,
		"mp_cost": 0,
		"target_scope": "ally_all",
		"target_side": "ally",
		"effects": [{"type": "heal_hp", "amount": 18}],
		"available": {"mode": "all"},
	},
	"skill_liedaoposhi": {
		"id": "skill_liedaoposhi",
		"name": "烈刀破勢",
		"category": "單體攻擊",
		"description": "猛然橫刀劈斷氣勢，強行突破敵陣。",
		"weapon_type": "刀",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.2}],
		"available": {"mode": "all"},
	},
	"skill_luanyinsuiqin": {
		"id": "skill_luanyinsuiqin",
		"name": "亂音碎琴",
		"category": "單體攻擊",
		"description": "激昂琴音化為利刃，震懾敵人心魄。",
		"weapon_type": "琴",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.1}],
		"available": {"mode": "all"},
	},
	"skill_huagu_mianzhang": {
		"id": "skill_huagu_mianzhang",
		"name": "化骨綿掌",
		"category": "單體攻擊",
		"description": "掌勁入骨，綿裡藏勁，並強行將敵之屬性轉為柔。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 12,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [
			{"type": "damage", "power": 0.95},
			{"type": "force_element", "element": "柔", "turns": 3}
		],
		"available": {"mode": "include", "actor_ids": ["lieshao", "honghuiyin"]},
	},
	"skill_huanbu_zhang": {
		"id": "skill_huanbu_zhang",
		"name": "緩步掌",
		"category": "單體攻擊",
		"description": "掌風黏滯如泥，令敵身法遲緩。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 10,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [
			{"type": "damage", "power": 0.90},
			{"type": "debuff_speed", "amount": 5, "turns": 2}
		],
		"available": {"mode": "all"},
	},
	"skill_liumai_shenjian": {
		"id": "skill_liumai_shenjian",
		"name": "六脈神劍",
		"category": "單體攻擊",
		"description": "劍氣化脈，疾如驟雨，出手更快。",
		"weapon_type": "劍",
		"menu_usable": false,
		"mp_cost": 18,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [
			{"type": "damage", "power": 1.15},
			{"type": "buff_speed", "amount": 6, "turns": 2, "target": "self"}
		],
		"available": {"mode": "all"},
	},
	"skill_bagua_gunfa": {
		"id": "skill_bagua_gunfa",
		"name": "八卦棍法",
		"category": "單體攻擊",
		"description": "棍走八卦，纏步鎖身，令敵動作遲滯。",
		"weapon_type": "棍",
		"menu_usable": false,
		"mp_cost": 12,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [
			{"type": "damage", "power": 1.00},
			{"type": "debuff_speed", "amount": 4, "turns": 2}
		],
		"available": {"mode": "all"},
	},
	"skill_enemy_zhishui_yinzhang": {
		"id": "skill_enemy_zhishui_yinzhang",
		"name": "滯水陰掌",
		"category": "單體攻擊",
		"description": "語魅以濕掌勾魂，令敵意識遲滯。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.1}],
		"available": {"mode": "include", "actor_ids": ["enemy1"]},
	},
	"skill_enemy_panshi_gangquan": {
		"id": "skill_enemy_panshi_gangquan",
		"name": "磐石剛拳",
		"category": "單體攻擊",
		"description": "語魅以磐石般的硬拳痛擊對手。",
		"weapon_type": "拳",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.1}],
		"available": {"mode": "include", "actor_ids": ["enemy2"]},
	},
}

const LEGACY_NAME_TO_ID := {
	"連訣劍": "skill_lianjuejian",
	"霸刀斬": "skill_badaozhan",
	"木劍掃葉": "skill_mujian_saoye",
	"氣療掌": "skill_qiliaozhang",
	"翔龍十八掌": "skill_xianglong18",
	"筆掃煙霞": "skill_bisaoyanxia",
	"落筆成詩": "skill_luobichengshi",
	"正心拳": "skill_zhengxinquan",
	"提氣輕身": "skill_buff_speed_test",
	"凝滯封脈": "skill_debuff_speed_test",
	"轉性訣": "skill_force_element_test",
	"墨筆舒心": "skill_mobishuxin",
	"烈刀破勢": "skill_liedaoposhi",
	"亂音碎琴": "skill_luanyinsuiqin",
	"化骨綿掌": "skill_huagu_mianzhang",
	"緩步掌": "skill_huanbu_zhang",
	"六脈神劍": "skill_liumai_shenjian",
	"八卦棍法": "skill_bagua_gunfa",
	"滯水陰掌": "skill_enemy_zhishui_yinzhang",
	"磐石剛拳": "skill_enemy_panshi_gangquan",
}

const DEFAULT_SKILL_IDS_BY_ACTOR := {
	"liuyu": ["skill_lianjuejian", "skill_badaozhan", "skill_mujian_saoye", "skill_qiliaozhang", "skill_xianglong18"],
	"shumian": ["skill_bisaoyanxia", "skill_luobichengshi", "skill_zhengxinquan", "skill_buff_speed_test", "skill_debuff_speed_test", "skill_force_element_test", "skill_mobishuxin"],
	"lieshao": ["skill_liedaoposhi", "skill_luanyinsuiqin", "skill_huagu_mianzhang", "skill_huanbu_zhang", "skill_liumai_shenjian", "skill_bagua_gunfa"],
	"enemy1": ["skill_enemy_zhishui_yinzhang"],
	"enemy2": ["skill_enemy_panshi_gangquan"],
}

func get_skill(skill_id: String) -> Dictionary:
	if not SKILLS.has(skill_id):
		return {}
	return _normalize_skill((SKILLS[skill_id] as Dictionary).duplicate(true))

func get_all_skills() -> Array:
	var out: Array = []
	for skill_id in SKILLS.keys():
		out.append(get_skill(String(skill_id)))
	return out

func get_default_skill_ids(actor_id: String) -> Array:
	if not DEFAULT_SKILL_IDS_BY_ACTOR.has(actor_id):
		return []
	return (DEFAULT_SKILL_IDS_BY_ACTOR[actor_id] as Array).duplicate()

func get_skills_for_actor(actor_id: String, actor = null, known_skill_ids: Array = []) -> Array:
	var ids: Array = known_skill_ids if not known_skill_ids.is_empty() else get_default_skill_ids(actor_id)
	var out: Array = []
	for raw_id in ids:
		var skill_id := coerce_skill_id(raw_id)
		if skill_id == "":
			continue
		if not is_available_for_actor(skill_id, actor_id):
			continue
		var skill := get_skill(skill_id)
		if skill.is_empty():
			continue
		if actor != null and not is_weapon_compatible(skill, actor):
			continue
		out.append(skill)
	return out

func is_available_for_actor(skill_id: String, actor_id: String) -> bool:
	var skill := get_skill(skill_id)
	if skill.is_empty():
		return false
	var available = skill.get("available", {"mode": "all"})
	if typeof(available) != TYPE_DICTIONARY:
		return true
	var mode := String((available as Dictionary).get("mode", "all"))
	if mode == "all":
		return true
	if mode == "include":
		var actor_ids = (available as Dictionary).get("actor_ids", [])
		return typeof(actor_ids) == TYPE_ARRAY and (actor_ids as Array).has(actor_id)
	return true

func is_weapon_compatible(skill: Dictionary, actor) -> bool:
	if skill.is_empty():
		return false
	var weapon_type := String(skill.get("weapon_type", "通用"))
	if weapon_type == "" or weapon_type == "通用":
		return true

	var w1 := String(_actor_get(actor, "weapon_1", ""))
	var w2 := String(_actor_get(actor, "weapon_2", ""))
	var equipped: Array = []
	if w1 != "":
		equipped.append(w1)
	if w2 != "":
		equipped.append(w2)
	if equipped.is_empty():
		equipped.append("拳")
		equipped.append("掌")
		equipped.append("空手")

	if bool(skill.get("require_free_hand", false)) and w1 != "" and w2 != "":
		return false
	if weapon_type == "空手":
		return w1 == "" and w2 == ""
	return equipped.has(weapon_type)

func coerce_skill_id(value) -> String:
	if typeof(value) == TYPE_STRING:
		var as_id := String(value)
		if SKILLS.has(as_id):
			return as_id
		if LEGACY_NAME_TO_ID.has(as_id):
			return String(LEGACY_NAME_TO_ID[as_id])
		push_warning("[SkillDB] Unknown skill string: %s" % as_id)
		return ""

	if typeof(value) == TYPE_DICTIONARY:
		var dict := value as Dictionary
		var id := String(dict.get("id", ""))
		if id != "" and SKILLS.has(id):
			return id
		var name := String(dict.get("name", ""))
		if name != "" and LEGACY_NAME_TO_ID.has(name):
			return String(LEGACY_NAME_TO_ID[name])
		push_warning("[SkillDB] Cannot coerce skill dictionary: %s" % [dict])
		return ""

	push_warning("[SkillDB] Unsupported skill id value type: %s" % typeof(value))
	return ""

func _normalize_skill(skill: Dictionary) -> Dictionary:
	if skill.is_empty():
		return {}
	if not skill.has("description"):
		skill["description"] = String(skill.get("desc", ""))
	if not skill.has("desc"):
		skill["desc"] = String(skill.get("description", ""))
	if not skill.has("menu_usable"):
		skill["menu_usable"] = false
	if not skill.has("mp_cost"):
		skill["mp_cost"] = 0
	if not skill.has("target_scope"):
		skill["target_scope"] = "single"
	if not skill.has("target_side"):
		skill["target_side"] = "enemy"
	if not skill.has("effects"):
		skill["effects"] = _legacy_effect_to_effects(skill)
	if not skill.has("available"):
		skill["available"] = {"mode": "all"}

	if skill.has("effect") and skill.has("heal_amount"):
		var effect := String(skill.get("effect", ""))
		if effect == "heal_hp":
			skill["effects"] = [{"type": "heal_hp", "amount": int(skill.get("heal_amount", 0))}]

	return skill

func _legacy_effect_to_effects(skill: Dictionary) -> Array:
	if skill.has("power"):
		return [{"type": "damage", "power": float(skill.get("power", 1.0))}]
	var legacy_effect := String(skill.get("effect", ""))
	match legacy_effect:
		"heal_hp":
			return [{"type": "heal_hp", "amount": int(skill.get("heal_amount", 0))}]
		"buff_speed":
			return [{"type": "buff_speed", "amount": int(skill.get("amount", 0)), "turns": int(skill.get("turns", 0))}]
		"debuff_speed":
			return [{"type": "debuff_speed", "amount": int(skill.get("amount", 0)), "turns": int(skill.get("turns", 0))}]
		"force_element":
			return [{"type": "force_element", "element": String(skill.get("element", "")), "turns": int(skill.get("turns", 0))}]
		_:
			return []

func _actor_get(actor, key: String, default_value):
	if actor == null:
		return default_value
	if typeof(actor) == TYPE_DICTIONARY:
		return (actor as Dictionary).get(key, default_value)
	if actor is Object:
		var value = actor.get(key)
		if value == null:
			return default_value
		return value
	return default_value
