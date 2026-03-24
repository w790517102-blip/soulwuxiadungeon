extends Node

const INNER_FORCES := {
	"qingfeng_jue": {
		"id": "qingfeng_jue",
		"prefix": "清風",
		"type": "訣",
		"boost_weapon": "刀",
		"element": "快",
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
		"description": "流塵訣，劍勢講究快、準、穩，氣如細塵隨風入隙，先手壓制最見神髓。",
		"available": ["liuyu"],
	},
	"wuji_zhenjing": {
		"id": "wuji_zhenjing",
		"prefix": "無極",
		"type": "真經",
		"boost_weapon": "劍",
		"element": "遲",
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
		"element": "剛",
		"description": "赤陽真經，出自弦心門烈火脈，專為琴音殺伐而生。內息如火走弦，聲聲皆可焚心。",
		"available": ["lieshao", "honghuiyin"],
	},
	"po_jun_zhenjing": {
		"id": "po_jun_zhenjing",
		"prefix": "破軍",
		"type": "真經",
		"boost_weapon": "刀",
		"element": "快",
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
