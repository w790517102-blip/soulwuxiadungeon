extends Node
class_name ItemDB

const ITEM_DEFS := {

	"med_bandage": {"name": "繃帶", "desc": "常見止血繃帶。回復20點HP。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "heal", "amount": 20, "target_scope": "ally_single"},
	"med_stopbleed_herb": {"name": "止血草", "desc": "簡易止血草藥。回復75點HP。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "heal", "amount": 75, "target_scope": "ally_single"},
	"med_jinchuang_small": {"name": "金創藥·小", "desc": "小份量金創藥。全體回復50點HP。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "heal", "amount": 50, "target_scope": "ally_all"},
	"med_antidote_powder": {"name": "解毒散", "desc": "常見解毒粉。解除中毒。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "cure_status", "status_id": "poison", "target_scope": "ally_single"},
	"med_awaken_tonic": {"name": "醒神湯", "desc": "提神藥湯。解除暈眩。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "cure_status", "status_id": "stun", "target_scope": "ally_single"},
	"med_calm_pill": {"name": "清心丸", "desc": "安神定心。解除混亂。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "cure_status", "status_id": "confuse", "target_scope": "ally_single"},
	"med_qi_restore_small": {"name": "回氣散·小", "desc": "小量回氣。全體回復10點內力。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "mp_heal", "amount": 10, "target_scope": "ally_all"},
	"med_warm_wine": {"name": "暖身酒", "desc": "溫身散寒。若有緩速則解除，否則速度+10、命中-5（3回合）。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "warm_wine", "target_scope": "ally_single", "turns": 3},
	"med_heartguard_small": {"name": "小護心丹", "desc": "前期保命丹藥。", "type": "consumable", "use_scope": "none", "use_action": "none"},

	"food_walnut": {"name": "胡桃", "desc": "來自西域美味且營養的堅果，然而堅硬的外表使得在食用之前必須先付出一番心力。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "walnut", "target_scope": "self", "require_stat": "str", "require_min": 31, "hp_restore": 30, "mp_restore": 10},
	"tool_zhuge_crossbow": {"name": "諸葛連弩", "desc": "機巧連弩，可連射箭矢；本體可重複使用。", "type": "consumable", "use_scope": "battle", "use_action": "consume", "effect": "zhuge_crossbow", "target_scope": "enemy_single", "power": 18, "ammo_item_id": "ammo_arrow", "no_consume": true},
	"ammo_arrow": {"name": "箭矢", "desc": "連弩使用的消耗箭矢。", "type": "material", "use_scope": "none", "use_action": "none"},
	"misc_smoke_pellet": {"name": "煙霧丸", "desc": "投擲後煙霧四散，可趁隙脫離戰場。", "type": "consumable", "use_scope": "battle", "use_action": "consume", "effect": "escape_battle", "target_scope": "self"},
	"book_poem_a_int": {"name": "詩歌A", "desc": "閱讀後文思共鳴，智慧永久 +5。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "perm_stat", "stat_key": "int", "amount": 5, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"book_poem_b_luck": {"name": "詩歌B", "desc": "閱讀後靈感流轉，幸運永久 +5。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "perm_stat", "stat_key": "luck", "amount": 5, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"book_essay_c_pen_up": {"name": "散文C", "desc": "下一場戰鬥筆系武功傷害 +20%。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "apply_battle_buff", "buff_key": "pen_damage_up", "buff_value": 0.2, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"book_essay_d_pen_resist": {"name": "散文D", "desc": "下一場戰鬥受到筆系武功傷害 -10%。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "apply_battle_buff", "buff_key": "pen_damage_resist", "buff_value": 0.1, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"tea_refresh_agi": {"name": "清爽茶", "desc": "茶香清透，敏捷永久 +5。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "perm_stat", "stat_key": "agi", "amount": 5, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"tea_rich_con": {"name": "渾厚茶", "desc": "茶韻渾厚，體能永久 +5。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "perm_stat", "stat_key": "con", "amount": 5, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"tea_tasting_mp": {"name": "品茗茶", "desc": "依智慧回復內力（5 + INT，範圍 5~30）。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "mp_heal_by_stat", "stat_key": "int", "base_amount": 5, "scale": 1, "min_amount": 5, "max_amount": 30, "target_scope": "ally_single"},
	"tea_snack_hp": {"name": "精緻茶點", "desc": "依敏捷回復生命（10 + AGI*2，範圍 10~80）。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "heal_by_stat", "stat_key": "agi", "base_amount": 10, "scale": 2, "min_amount": 10, "max_amount": 80, "target_scope": "ally_single"},
	"mat_herb_bundle": {"name": "藥材包", "desc": "常見藥材材料包。", "type": "material", "use_scope": "none", "use_action": "none"},
	"wep_wood_sword": {"name": "木劍", "desc": "入門木劍。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_1", "weapon_type": "劍", "stats": {"atk": 1}},
	"wep_short_blade": {"name": "短刀", "desc": "短柄單刀。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_2", "weapon_type": "刀", "stats": {"atk": 2}},
	"wep_qingfeng_sword": {"name": "青鋒劍", "desc": "均衡劍器。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_1", "weapon_type": "劍", "stats": {"atk": 3}},
	"wep_bamboo_staff": {"name": "竹槍", "desc": "竹製長槍。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_1", "weapon_type": "槍", "stats": {"atk": 2}},
	"arm_cloth": {"name": "布衣", "desc": "輕便布衣。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_body", "stats": {"def": 1}},
	"acc_bracer": {"name": "護腕", "desc": "簡易護腕。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_hands", "stats": {"def": 1}},
	"arm_straw_sandals": {"name": "草履", "desc": "結實草履。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_feet", "stats": {"speed": 1}},
	"arm_thin_leather": {"name": "皮甲·薄", "desc": "輕薄皮甲。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_body", "stats": {"def": 2, "max_hp": 5}},
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
		"equip_slot": "armor_body",
		"stats": {"def": 2, "max_hp": 10},
	},
	"jade_pendant": {
		"name": "玉佩",
		"desc": "溫潤玉佩，傳說可護身。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "accessory_1",
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

const BASE_PRICES := {
	"med_bandage": 12,
	"med_stopbleed_herb": 8,
	"med_jinchuang_small": 18,
	"med_antidote_powder": 15,
	"med_awaken_tonic": 18,
	"med_calm_pill": 22,
	"med_qi_restore_small": 20,
	"med_warm_wine": 25,
	"med_heartguard_small": 45,
	"food_walnut": 6,
	"tool_zhuge_crossbow": 120,
	"ammo_arrow": 1,
	"misc_smoke_pellet": 30,
	"book_poem_a_int": 88,
	"book_poem_b_luck": 88,
	"book_essay_c_pen_up": 72,
	"book_essay_d_pen_resist": 72,
	"tea_refresh_agi": 70,
	"tea_rich_con": 70,
	"tea_tasting_mp": 16,
	"tea_snack_hp": 22,
	"mat_herb_bundle": 10,
	"wep_wood_sword": 25,
	"wep_short_blade": 45,
	"wep_qingfeng_sword": 60,
	"wep_bamboo_staff": 55,
	"arm_cloth": 35,
	"acc_bracer": 25,
	"arm_straw_sandals": 28,
	"arm_thin_leather": 80,
	"misc_tinderbox": 15,
	"misc_hemp_twine": 10,
	"misc_small_rope": 18,
	"misc_sachet": 20,
	"misc_empty_bottle": 8,
	"food_dried_rations": 12,
	"misc_paper_ink": 10,
	"mat_herb_pouch": 14,
	"throw_stone_pack": 12,
	"misc_little_box": 16,
	"iron_sword": 40,
	"bronze_sword": 55,
	"ink_brush": 48,
	"yaoqin": 58,
	"short_dao": 36,
	"cloth_armor": 35,
	"jade_pendant": 42,
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
	out["equip_slot"] = _normalize_equip_slot(str(out.get("equip_slot", "")))
	if not out.has("weapon_type"):
		out["weapon_type"] = ""
	if not out.has("stats"):
		out["stats"] = {}
	if not out.has("base_price"):
		out["base_price"] = int(BASE_PRICES.get(id, 0))
	if not out.has("price"):
		out["price"] = int(out.get("base_price", 0))
	if not out.has("can_sell"):
		out["can_sell"] = str(out.get("type", "consumable")) != "quest" and int(out.get("base_price", 0)) > 0
	return out

static func _normalize_equip_slot(slot: String) -> String:
	match slot:
		"armor":
			return "armor_body"
		"accessory":
			return "accessory_1"
		_:
			return slot

static func make_item(id: String) -> Dictionary:
	var data: Dictionary = get_def(id)
	if data.is_empty():
		return {}
	var item := data.duplicate(true)
	item["id"] = id
	return item
