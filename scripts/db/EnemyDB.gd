extends Node
class_name EnemyDB

const ENEMY_DEFS := {
	"bamboo_bandit_scout": {
		"id": "bamboo_bandit_scout",
		"display_name": "山賊探子",
		"hp": 60,
		"max_hp": 60,
		"mp": 10,
		"atk": 10,
		"def": 6,
		"speed": 10,
		"element": "遲",
		"exp": 8,
		"gold": {"chance": 0.4, "min": 2, "max": 5},
		"drops": []
	},
	"bamboo_bandit_archer": {
		"id": "bamboo_bandit_archer",
		"display_name": "山賊弓手",
		"hp": 50,
		"max_hp": 50,
		"mp": 15,
		"atk": 11,
		"def": 5,
		"speed": 12,
		"element": "巧",
		"exp": 9,
		"gold": {"chance": 0.45, "min": 2, "max": 6},
		"drops": []
	},
	"bamboo_wild_boar": {
		"id": "bamboo_wild_boar",
		"display_name": "野豬",
		"hp": 90,
		"max_hp": 90,
		"mp": 0,
		"atk": 13,
		"def": 7,
		"speed": 8,
		"element": "剛",
		"exp": 12,
		"gold": {"chance": 0.35, "min": 3, "max": 7},
		"drops": []
	},
	"bamboo_poison_snake": {
		"id": "bamboo_poison_snake",
		"display_name": "毒蛇",
		"hp": 45,
		"max_hp": 45,
		"mp": 0,
		"atk": 12,
		"def": 4,
		"speed": 14,
		"element": "毒",
		"exp": 10,
		"gold": {"chance": 0.3, "min": 1, "max": 4},
		"drops": []
	},
	"bamboo_youmei": {
		"id": "bamboo_youmei",
		"display_name": "語魅",
		"hp": 75,
		"max_hp": 75,
		"mp": 20,
		"atk": 12,
		"def": 7,
		"speed": 9,
		"element": "遲",
		"exp": 14,
		"gold": {"chance": 0.5, "min": 4, "max": 9},
		"drops": []
	},
	"sewer_rat_swarm": {
		"id": "sewer_rat_swarm",
		"display_name": "鼠群",
		"hp": 55,
		"max_hp": 55,
		"mp": 0,
		"atk": 10,
		"def": 5,
		"speed": 13,
		"element": "群",
		"exp": 9,
		"gold": {"chance": 0.35, "min": 2, "max": 5},
		"drops": []
	},
	"sewer_thug": {
		"id": "sewer_thug",
		"display_name": "下水道匪徒",
		"hp": 85,
		"max_hp": 85,
		"mp": 10,
		"atk": 13,
		"def": 7,
		"speed": 10,
		"element": "剛",
		"exp": 13,
		"gold": {"chance": 0.45, "min": 3, "max": 8},
		"drops": []
	},
	"sewer_ooze_slime": {
		"id": "sewer_ooze_slime",
		"display_name": "污泥怪",
		"hp": 110,
		"max_hp": 110,
		"mp": 0,
		"atk": 12,
		"def": 9,
		"speed": 6,
		"element": "濁",
		"exp": 16,
		"gold": {"chance": 0.4, "min": 4, "max": 10},
		"drops": []
	},
	"sewer_drowned_wight": {
		"id": "sewer_drowned_wight",
		"display_name": "溺魂",
		"hp": 120,
		"max_hp": 120,
		"mp": 25,
		"atk": 14,
		"def": 8,
		"speed": 8,
		"element": "陰",
		"exp": 18,
		"gold": {"chance": 0.5, "min": 5, "max": 12},
		"drops": []
	}
}

static func get_def(id: String) -> Dictionary:
	if not ENEMY_DEFS.has(id):
		return {}
	return ENEMY_DEFS[id].duplicate(true)

static func make_enemy(id: String) -> Dictionary:
	var data: Dictionary = ENEMY_DEFS.get(id, {})
	if data.is_empty():
		return {}
	var enemy := data.duplicate(true)
	enemy["id"] = id
	if not enemy.has("name"):
		enemy["name"] = enemy.get("display_name", id)
	if not enemy.has("display_name"):
		enemy["display_name"] = enemy.get("name")
	if enemy.has("hp") and not enemy.has("max_hp"):
		enemy["max_hp"] = enemy["hp"]
	if not enemy.has("exp"):
		enemy["exp"] = 0
	if not enemy.has("gold"):
		enemy["gold"] = {"chance": 0.0, "min": 0, "max": 0}
	if not enemy.has("drops"):
		enemy["drops"] = []
	return enemy
