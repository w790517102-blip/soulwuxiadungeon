extends Node
class_name ItemDB

const ITEM_DEFS := {

	"med_bandage": {"name": "繃帶", "desc": "常見止血繃帶。", "type": "consumable", "use_scope": "none", "use_action": "none"},
	"med_stopbleed_herb": {"name": "止血草", "desc": "簡易止血草藥。", "type": "consumable", "use_scope": "none", "use_action": "none"},
	"med_jinchuang_small": {"name": "金創藥·小", "desc": "小份量金創藥。", "type": "consumable", "use_scope": "none", "use_action": "none"},
	"med_antidote_powder": {"name": "解毒散", "desc": "常見解毒粉。", "type": "consumable", "use_scope": "none", "use_action": "none"},
	"med_awaken_tonic": {"name": "醒神湯", "desc": "提神藥湯。", "type": "consumable", "use_scope": "none", "use_action": "none"},
	"med_calm_pill": {"name": "清心丸", "desc": "安神定心。", "type": "consumable", "use_scope": "none", "use_action": "none"},
	"med_qi_restore_small": {"name": "回氣散·小", "desc": "小量回氣。", "type": "consumable", "use_scope": "none", "use_action": "none"},
	"med_warm_wine": {"name": "暖身酒", "desc": "溫身散寒。", "type": "consumable", "use_scope": "none", "use_action": "none"},
	"med_heartguard_small": {"name": "小護心丹", "desc": "前期保命丹藥。", "type": "consumable", "use_scope": "none", "use_action": "none"},
	"mat_herb_bundle": {"name": "藥材包", "desc": "常見藥材材料包。", "type": "material", "use_scope": "none", "use_action": "none"},
	"wep_wood_sword": {"name": "木劍", "desc": "入門木劍。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_1", "weapon_type": "劍", "stats": {"atk": 1}},
	"wep_short_blade": {"name": "短刀", "desc": "短柄單刀。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_2", "weapon_type": "刀", "stats": {"atk": 2}},
	"wep_qingfeng_sword": {"name": "青鋒劍", "desc": "均衡劍器。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_1", "weapon_type": "劍", "stats": {"atk": 3}},
	"wep_bamboo_staff": {"name": "竹槍", "desc": "竹製長槍。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_1", "weapon_type": "槍", "stats": {"atk": 2}},
	"arm_cloth": {"name": "布衣", "desc": "輕便布衣。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor", "stats": {"def": 1}},
	"acc_bracer": {"name": "護腕", "desc": "簡易護腕。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "accessory", "stats": {"def": 1}},
	"arm_straw_sandals": {"name": "草履", "desc": "結實草履。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor", "stats": {"speed": 1}},
	"arm_thin_leather": {"name": "皮甲·薄", "desc": "輕薄皮甲。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor", "stats": {"def": 2, "max_hp": 5}},
	"misc_tinderbox": {"name": "火折子", "desc": "可點火的雜貨。", "type": "misc", "use_scope": "none", "use_action": "none"},
	"misc_hemp_twine": {"name": "麻線", "desc": "耐用麻線。", "type": "material", "use_scope": "none", "use_action": "none"},
	"misc_small_rope": {"name": "麻繩", "desc": "簡易麻繩。", "type": "material", "use_scope": "none", "use_action": "none"},
	"misc_sachet": {"name": "香包", "desc": "留香小包。", "type": "misc", "use_scope": "none", "use_action": "none"},
	"misc_empty_bottle": {"name": "空瓶", "desc": "可盛裝液體。", "type": "material", "use_scope": "none", "use_action": "none"},
	"food_dried_rations": {"name": "乾糧", "desc": "行路補給。", "type": "food", "use_scope": "none", "use_action": "none"},
	"misc_paper_ink": {"name": "紙筆／信封", "desc": "文書雜貨。", "type": "misc", "use_scope": "none", "use_action": "none"},
	"mat_herb_pouch": {"name": "草藥包", "desc": "常見草藥材料。", "type": "material", "use_scope": "none", "use_action": "none"},
	"throw_stone_pack": {"name": "飛石包", "desc": "可投擲的小石包。", "type": "consumable", "use_scope": "battle", "use_action": "consume", "effect": "bomb_single", "amount": 6, "target_scope": "enemy_single"},
	"misc_little_box": {"name": "小木盒", "desc": "可收納小物。", "type": "misc", "use_scope": "none", "use_action": "none"},
	"herb": {
		"name": "藥草",
		"desc": "回復50點HP的藥草。",
		"type": "consumable",
		"use_scope": "any",
		"use_action": "consume",
		"effect": "heal",
		"amount": 50,
		"target_scope": "ally_single",
	},
	"elixir_qi": {
		"name": "回氣丹",
		"desc": "回復15點內力。",
		"type": "consumable",
		"use_scope": "any",
		"use_action": "consume",
		"effect": "mp_heal",
		"amount": 15,
		"target_scope": "ally_single",
	},
	"light_step_powder": {
		"name": "輕身散",
		"desc": "暫時提升使用者的身法速度。",
		"type": "consumable",
		"use_scope": "any",
		"use_action": "consume",
		"effect": "buff_speed",
		"amount": 5,
		"target_scope": "ally_single",
	},
	"chicken_spike": {
		"name": "雞爪釘",
		"desc": "拋向敵人足下，可拖慢對方腳步。",
		"type": "consumable",
		"use_scope": "battle",
		"use_action": "consume",
		"effect": "debuff_speed",
		"amount": 5,
		"target_scope": "enemy_single",
	},
	"haste_talisman": {
		"name": "神速符",
		"desc": "貼在己方可加速，貼在敵方可改變其屬性為「快」。",
		"type": "consumable",
		"use_scope": "battle",
		"use_action": "consume",
		"effect": "haste_talisman",
		"amount": 8,
		"target_scope": "all_single",
		"effects": [],
	},
	"item_pili_single": {
		"name": "霹靂彈",
		"desc": "單體爆裂道具，對單一敵人造成固定傷害。",
		"type": "consumable",
		"use_scope": "battle",
		"use_action": "consume",
		"effect": "bomb_single",
		"amount": 20,
		"target_scope": "enemy_single",
	},
	"item_pili_aoe": {
		"name": "轟雷霹靂彈",
		"desc": "對敵方全體造成爆裂傷害。",
		"type": "consumable",
		"use_scope": "battle",
		"use_action": "consume",
		"effect": "bomb_aoe",
		"amount": 15,
		"target_scope": "enemy_all",
	},
	"item_fire_talisman": {
		"name": "烈火符",
		"desc": "點燃烈焰之符，可對敵人造成火焰傷害。",
		"type": "consumable",
		"use_scope": "battle",
		"use_action": "consume",
		"effect": "fire_talisman",
		"amount": 15,
		"enemy_damage": 30,
		"target_scope": "all_single",
	},
	"iron_sword": {
		"name": "鐵劍",
		"desc": "尋常鐵劍，易得但仍可防身。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "weapon_1",
		"weapon_type": "劍",
		"stats": {"atk": 3},
	},
	"bronze_sword": {
		"name": "青銅劍",
		"desc": "青銅打造的長劍，勝在輕便。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "weapon_1",
		"weapon_type": "劍",
		"stats": {"atk": 4, "speed": 1},
	},
	"ink_brush": {
		"name": "墨筆",
		"desc": "書家墨筆，筆走龍蛇亦可為武。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "weapon_1",
		"weapon_type": "筆",
	},
	"yaoqin": {
		"name": "瑤琴",
		"desc": "清音瑤琴，弦動可裂金石。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "weapon_1",
		"weapon_type": "琴",
	},
	"short_dao": {
		"name": "短刀",
		"desc": "刀身短小，利於副手運用。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "weapon_2",
		"weapon_type": "刀",
	},
	"cloth_armor": {
		"name": "布衣",
		"desc": "粗布縫製的衣物，可略增防護。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "armor",
		"stats": {"def": 2, "max_hp": 10},
	},
	"jade_pendant": {
		"name": "玉佩",
		"desc": "溫潤玉佩，傳說可護身。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "accessory",
		"stats": {"max_mp": 15, "def": 1},
	},
	"quest_letter": {
		"name": "密函",
		"desc": "重要的任務物品，切勿遺失。",
		"type": "quest",
		"use_scope": "none",
		"use_action": "none",
	},
}

static func get_def(id: String) -> Dictionary:
	if not ITEM_DEFS.has(id):
		push_warning("Item def not found: %s" % id)
		return {}
	var data: Dictionary = ITEM_DEFS[id]
	var out := data.duplicate(true)
	out["id"] = id
	if not out.has("desc"):
		out["desc"] = ""
	if not out.has("type"):
		out["type"] = "consumable"
	if not out.has("use_scope"):
		out["use_scope"] = "none"
	if not out.has("use_action"):
		out["use_action"] = "none"
	if not out.has("equip_slot"):
		out["equip_slot"] = ""
	if not out.has("weapon_type"):
		out["weapon_type"] = ""
	if not out.has("stats"):
		out["stats"] = {}
	return out

static func make_item(id: String) -> Dictionary:
	var data: Dictionary = get_def(id)
	if data.is_empty():
		return {}
	var item := data.duplicate(true)
	item["id"] = id
	return item
