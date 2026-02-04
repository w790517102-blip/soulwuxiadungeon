extends Node
class_name ItemDB

const ITEM_DEFS := {
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
		"equip_slot": "weapon",
	},
	"bronze_sword": {
		"name": "青銅劍",
		"desc": "青銅打造的長劍，勝在輕便。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "weapon",
	},
	"cloth_armor": {
		"name": "布衣",
		"desc": "粗布縫製的衣物，可略增防護。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "armor",
	},
	"jade_pendant": {
		"name": "玉佩",
		"desc": "溫潤玉佩，傳說可護身。",
		"type": "equipment",
		"use_scope": "world",
		"use_action": "equip",
		"equip_slot": "accessory",
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
	return out

static func make_item(id: String) -> Dictionary:
	var data: Dictionary = get_def(id)
	if data.is_empty():
		return {}
	var item := data.duplicate(true)
	item["id"] = id
	return item
