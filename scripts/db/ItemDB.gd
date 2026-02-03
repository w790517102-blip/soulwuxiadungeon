extends Node
class_name ItemDB

const ITEM_DEFS := {
	"herb": {
		"name": "藥草",
		"desc": "回復50點HP的藥草。",
		"type": "consumable",
		"effect": "heal",
		"amount": 50,
		"target_scope": "ally_single",
	},
	"elixir_qi": {
		"name": "回氣丹",
		"desc": "回復15點內力。",
		"type": "consumable",
		"effect": "mp_heal",
		"amount": 15,
		"target_scope": "ally_single",
	},
	"light_step_powder": {
		"name": "輕身散",
		"desc": "暫時提升使用者的身法速度。",
		"type": "consumable",
		"effect": "buff_speed",
		"amount": 5,
		"target_scope": "ally_single",
	},
	"chicken_spike": {
		"name": "雞爪釘",
		"desc": "拋向敵人足下，可拖慢對方腳步。",
		"type": "consumable",
		"effect": "debuff_speed",
		"amount": 5,
		"target_scope": "enemy_single",
	},
	"haste_talisman": {
		"name": "神速符",
		"desc": "貼在己方可加速，貼在敵方可改變其屬性為「快」。",
		"type": "consumable",
		"effect": "haste_talisman",
		"amount": 8,
		"target_scope": "all_single",
		"effects": [],
	},
	"item_pili_single": {
		"name": "霹靂彈",
		"desc": "單體爆裂道具，對單一敵人造成固定傷害。",
		"type": "consumable",
		"effect": "bomb_single",
		"amount": 20,
		"target_scope": "enemy_single",
	},
	"item_pili_aoe": {
		"name": "轟雷霹靂彈",
		"desc": "對敵方全體造成爆裂傷害。",
		"type": "consumable",
		"effect": "bomb_aoe",
		"amount": 15,
		"target_scope": "enemy_all",
	},
	"item_fire_talisman": {
		"name": "烈火符",
		"desc": "點燃烈焰之符，可對敵人造成火焰傷害。",
		"type": "consumable",
		"effect": "fire_talisman",
		"amount": 15,
		"enemy_damage": 30,
		"target_scope": "all_single",
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
	return out

static func make_item(id: String) -> Dictionary:
	var data: Dictionary = get_def(id)
	if data.is_empty():
		return {}
	var item := data.duplicate(true)
	item["id"] = id
	return item
