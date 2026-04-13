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
	"med_smoke_sand": {"name": "迷煙砂", "desc": "朝敵面揚出細砂，使命中下降15（3回合）。", "type": "consumable", "use_scope": "battle", "use_action": "consume", "effect": "blind", "amount": 15, "turns": 3, "target_scope": "enemy_single"},
	"med_binding_resin": {"name": "纏步膠", "desc": "黏住敵人下盤，使閃避下降20（2回合）。", "type": "consumable", "use_scope": "battle", "use_action": "consume", "effect": "root", "amount": 20, "turns": 2, "target_scope": "enemy_single"},
	"med_focus_powder": {"name": "凝神散", "desc": "穩定心神，使命中上升10（3回合）。", "type": "consumable", "use_scope": "battle", "use_action": "consume", "effect": "focus", "amount": 10, "turns": 3, "target_scope": "ally_single"},
	"med_heartguard_small": {"name": "小護心丹", "desc": "前期保命丹藥。", "type": "consumable", "use_scope": "none", "use_action": "none"},

	"food_walnut": {"name": "胡桃", "desc": "來自西域美味且營養的堅果，然而堅硬的外表使得在食用之前必須先付出一番心力。", "type": "consumable", "use_scope": "any", "use_action": "consume", "effect": "walnut", "target_scope": "ally_single", "require_stat": "str", "require_min": 31, "hp_restore": 30, "mp_restore": 10},
	"misc_walnut_cracker": {"name": "胡桃鉗", "desc": "破殼工具。只要持有就能輕鬆開胡桃。", "type": "tool", "use_scope": "none", "use_action": "none"},
	"tool_zhuge_crossbow": {"name": "諸葛連弩", "desc": "機巧連弩，可連射箭矢；本體可重複使用。", "type": "consumable", "use_scope": "battle", "use_action": "consume", "effect": "zhuge_crossbow", "target_scope": "enemy_single", "power": 18, "ammo_item_id": "ammo_arrow", "no_consume": true},
	"ammo_arrow": {"name": "箭矢", "desc": "連弩使用的消耗箭矢。", "type": "material", "use_scope": "none", "use_action": "none"},
	"misc_smoke_pellet": {"name": "煙霧丸", "desc": "投擲後煙霧四散，可趁隙脫離戰場。", "type": "consumable", "use_scope": "battle", "use_action": "consume", "effect": "escape_battle", "target_scope": "self"},
	"book_poem_a_int": {"name": "詩歌A", "desc": "閱讀後文思共鳴，智慧永久 +5。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "perm_stat", "stat_key": "int", "amount": 5, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"book_poem_b_luck": {"name": "詩歌B", "desc": "閱讀後靈感流轉，幸運永久 +5。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "perm_stat", "stat_key": "luck", "amount": 5, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"book_debug_str_10": {"name": "秘笈·力量", "desc": "測試秘笈，研讀後力量永久 +10。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "perm_stat", "stat_key": "str", "amount": 10, "target_scope": "ally_single", "price": 1, "base_price": 1, "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"book_debug_agi_10": {"name": "秘笈·敏捷", "desc": "測試秘笈，研讀後敏捷永久 +10。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "perm_stat", "stat_key": "agi", "amount": 10, "target_scope": "ally_single", "price": 1, "base_price": 1, "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"book_essay_c_pen_up": {"name": "散文C", "desc": "下一場戰鬥筆系武功傷害 +20%。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "apply_battle_buff", "buff_key": "pen_damage_up", "buff_value": 0.2, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"book_essay_d_pen_resist": {"name": "散文D", "desc": "下一場戰鬥受到筆系武功傷害 -10%。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "apply_battle_buff", "buff_key": "pen_damage_resist", "buff_value": 0.1, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"tea_refresh_agi": {"name": "清爽茶", "desc": "茶香清透，敏捷永久 +5。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "perm_stat", "stat_key": "agi", "amount": 5, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"tea_rich_con": {"name": "渾厚茶", "desc": "茶韻渾厚，體能永久 +5。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "perm_stat", "stat_key": "con", "amount": 5, "target_scope": "ally_single", "can_sell": false, "stock_once": true, "restock_rule": "never"},
	"tea_tasting_mp": {"name": "品茗茶", "desc": "依智慧回復內力（5 + INT，範圍 5~30）。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "mp_heal_by_stat", "stat_key": "int", "base_amount": 5, "scale": 1, "min_amount": 5, "max_amount": 30, "target_scope": "ally_single"},
	"tea_snack_hp": {"name": "精緻茶點", "desc": "依敏捷回復生命（10 + AGI*2，範圍 10~80）。", "type": "consumable", "use_scope": "world", "use_action": "consume", "effect": "heal_by_stat", "stat_key": "agi", "base_amount": 10, "scale": 2, "min_amount": 10, "max_amount": 80, "target_scope": "ally_single"},
	"mat_herb_bundle": {"name": "藥材包", "desc": "常見藥材材料包。", "type": "material", "use_scope": "none", "use_action": "none"},
	"wep_wood_sword": {"name": "木劍", "desc": "入門木劍。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_1", "weapon_type": "劍", "stats": {"atk": 1}},
	"wep_short_blade": {"name": "短刀", "desc": "短柄單刀。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_2", "weapon_type": "刀", "stats": {"atk": 2}},
	"wep_qingfeng_sword": {"name": "青鋒劍", "desc": "均衡劍器。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_1", "weapon_type": "劍", "stats": {"atk": 3}},
	"wep_bamboo_staff": {"name": "竹槍", "desc": "竹製長槍。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "weapon_1", "weapon_type": "槍", "stats": {"atk": 2}},
	"arm_cloth": {"name": "布衣", "desc": "輕便布衣，基本護身衣著。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_body", "stats": {"def": 1}},
	"acc_bracer": {"name": "護腕", "desc": "厚實護腕，能穩定手勢與招架。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_hands", "stats": {"def": 5, "accuracy": 5}},
	"arm_straw_sandals": {"name": "草履", "desc": "結實草履。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_feet", "stats": {"speed": 1}},
	"acc_boss_sighting_ring": {"name": "老闆的校準戒", "desc": "鐵匠老闆拿來校正試招的戒指，特別適合測試命中。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "accessory_1", "can_sell": false, "stats": {"accuracy": 60}},
	"arm_boss_running_shoes": {"name": "老闆的跑鞋", "desc": "鐵匠老闆私藏的跑鞋，穿上後腳步輕快，特別適合測試閃避。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_feet", "can_sell": false, "stats": {"speed": 3, "evasion": 60}},
	"arm_boss_crit_gloves": {"name": "老闆必殺拳套", "desc": "QA 驗證專用拳套，特化暴擊測試。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_hands", "can_sell": false, "stats": {"crit_rate_bonus": 0.8}},
	"arm_thin_leather": {"name": "輕薄皮甲", "desc": "輕薄的皮製甲冑，比起一般衣物更為結實。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_body", "stats": {"def": 10, "max_hp": 10}},
	"arm_leather_cloth": {"name": "皮衣", "desc": "動物的皮毛製成的厚實大衣。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_body", "stats": {"def": 5, "max_hp": 3}},
	"cloth_gloves": {"name": "布手套", "desc": "柔軟布製手套，提供基礎保護。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_hands", "stats": {"def": 1}},
	"leather_gloves": {"name": "皮手套", "desc": "耐磨皮革手套，強化手部防護。", "type": "equipment", "use_scope": "world", "use_action": "equip", "equip_slot": "armor_hands", "stats": {"def": 3}},
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
	"med_smoke_sand": 20,
	"med_binding_resin": 24,
	"med_focus_powder": 22,
	"med_heartguard_small": 45,
	"food_walnut": 6,
	"misc_walnut_cracker": 40,
	"tool_zhuge_crossbow": 120,
	"ammo_arrow": 1,
	"misc_smoke_pellet": 30,
	"book_poem_a_int": 88,
	"book_poem_b_luck": 88,
	"book_debug_str_10": 1,
	"book_debug_agi_10": 1,
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
	"acc_boss_sighting_ring": 1,
	"arm_boss_running_shoes": 1,
	"arm_boss_crit_gloves": 1,
	"arm_thin_leather": 80,
	"arm_leather_cloth": 50,
	"cloth_gloves": 5,
	"leather_gloves": 10,
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

static func _ensure_equipment_desc_has_effects(item_def: Dictionary) -> void:
	if str(item_def.get("type", "")) != "equipment":
		return
	var stats_raw = item_def.get("stats", {})
	if typeof(stats_raw) != TYPE_DICTIONARY:
		return
	var stats: Dictionary = stats_raw
	var effect_parts: Array[String] = []
	var ordered_keys := ["atk", "def", "max_hp", "max_mp", "speed", "accuracy", "evasion", "crit_rate_bonus"]
	for stat_key in ordered_keys:
		if not stats.has(stat_key):
			continue
		var part := _equipment_stat_desc_part(stat_key, stats.get(stat_key))
		if part != "":
			effect_parts.append(part)
	if effect_parts.is_empty():
		return
	var effect_line := "效果：" + "，".join(effect_parts) + "。"
	var desc := str(item_def.get("desc", "")).strip_edges()
	if desc == "":
		item_def["desc"] = effect_line
		return
	if desc.find("效果：") != -1:
		return
	item_def["desc"] = "%s %s" % [desc, effect_line]

static func _equipment_stat_desc_part(stat_key: String, value) -> String:
	match stat_key:
		"atk":
			return "攻擊%+d" % int(value)
		"def":
			return "防禦%+d" % int(value)
		"max_hp":
			return "最大生命值%+d" % int(value)
		"max_mp":
			return "最大內力%+d" % int(value)
		"speed":
			return "速度%+d" % int(value)
		"accuracy":
			return "命中%+d" % int(value)
		"evasion":
			return "閃避%+d" % int(value)
		"crit_rate_bonus":
			return "暴擊率%+.1f%%" % (float(value) * 100.0)
		_:
			return ""

static func get_effect_display_text(item_def: Dictionary) -> String:
	if item_def.is_empty():
		return "（無）"
	if str(item_def.get("type", "")) == "equipment":
		var stats_raw = item_def.get("stats", {})
		if typeof(stats_raw) != TYPE_DICTIONARY:
			return "（無）"
		var stats: Dictionary = stats_raw
		var effect_parts: Array[String] = []
		var ordered_keys := ["atk", "def", "max_hp", "max_mp", "speed", "accuracy", "evasion", "crit_rate_bonus"]
		for stat_key in ordered_keys:
			if not stats.has(stat_key):
				continue
			var part := _equipment_stat_desc_part(stat_key, stats.get(stat_key))
			if part != "":
				effect_parts.append(part)
		return "、".join(effect_parts) if not effect_parts.is_empty() else "（無）"
	var effect_key := String(item_def.get("effect", ""))
	match effect_key:
		"heal":
			return "回復 %d 點氣血" % int(item_def.get("amount", 0))
		"mp_heal":
			return "回復 %d 點內力" % int(item_def.get("amount", 0))
		"cure_status":
			var status_id := String(item_def.get("status_id", ""))
			if status_id == "poison":
				return "解除中毒"
			if status_id == "stun":
				return "解除暈眩"
			if status_id == "confuse":
				return "解除混亂"
			return "解除狀態：%s" % status_id
		"perm_stat":
			return "%s 永久 %+d" % [String(item_def.get("stat_key", "能力")), int(item_def.get("amount", 0))]
		_:
			return "效果代號：%s" % effect_key if effect_key != "" else "（無）"

static func make_item(id: String) -> Dictionary:
	var data: Dictionary = get_def(id)
	if data.is_empty():
		return {}
	var item := data.duplicate(true)
	item["id"] = id
	return item
