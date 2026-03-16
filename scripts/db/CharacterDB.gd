extends Node
class_name CharacterDB

const DB := {
	"liuyu": {
		"display_name": "劉語塵",
		"portrait_path": "res://assets/sprites/Liu_Yu/LiuYu_battle.png",
		"job": "俠客",
		"subclass": "劍修",
		"base_stats": {"str": 5, "agi": 5, "int": 5, "con": 5, "luck": 5},
	},
	"shumian": {
		"display_name": "書眠",
		"portrait_path": "res://assets/sprites/NPC/Yuheng/Su_Mien_battle.png",
		"job": "詩人",
		"subclass": "符咒師",
		"base_stats": {"str": 5, "agi": 5, "int": 5, "con": 5, "luck": 5},
	},
	"su_mien": {
		"display_name": "書眠",
		"portrait_path": "res://assets/sprites/NPC/Yuheng/Su_Mien_battle.png",
		"job": "詩人",
		"subclass": "符咒師",
		"base_stats": {"str": 5, "agi": 5, "int": 5, "con": 5, "luck": 5},
	},
	"lieshao": {
		"display_name": "列肖",
		"portrait_path": "res://assets/sprites/NPC/LieFong/LieShao_battle.png",
		"job": "樂師",
		"subclass": "琴手",
		"base_stats": {"str": 5, "agi": 5, "int": 5, "con": 5, "luck": 5},
	},
}

static func get_base_stats(actor_id: String) -> Dictionary:
	var entry = DB.get(actor_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var stats = entry.get("base_stats", {})
	if typeof(stats) != TYPE_DICTIONARY:
		return {}
	return (stats as Dictionary).duplicate(true)

static func get_portrait_path(actor_id: String) -> String:
	var entry = DB.get(actor_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	return String((entry as Dictionary).get("portrait_path", ""))

static func get_display_name(actor_id: String) -> String:
	var entry = DB.get(actor_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	return String((entry as Dictionary).get("display_name", ""))

static func ensure_actor_stats(actor_id: String, actor_dict: Dictionary) -> Dictionary:
	var out: Dictionary = actor_dict
	if actor_id == "":
		actor_id = String(out.get("id", ""))
	if actor_id == "":
		return out

	var base_stats = get_base_stats(actor_id)
	if base_stats.is_empty():
		base_stats = {"str": 5, "agi": 5, "int": 5, "con": 5, "luck": 5}

	for stat_key in ["str", "agi", "int", "con", "luck"]:
		if not out.has(stat_key):
			out[stat_key] = int(base_stats.get(stat_key, 5))
		else:
			out[stat_key] = int(out.get(stat_key, base_stats.get(stat_key, 5)))

	if not out.has("battle_modifiers") or typeof(out.get("battle_modifiers", {})) != TYPE_DICTIONARY:
		out["battle_modifiers"] = {}

	var display_name = get_display_name(actor_id)
	if String(out.get("name", "")) == "" and display_name != "":
		out["name"] = display_name

	var portrait = get_portrait_path(actor_id)
	if String(out.get("portrait_path", "")) == "" and portrait != "":
		out["portrait_path"] = portrait

	var entry = DB.get(actor_id, {})
	if typeof(entry) == TYPE_DICTIONARY:
		var entry_dict: Dictionary = entry
		if String(out.get("job", "")) == "":
			out["job"] = String(entry_dict.get("job", ""))
		if String(out.get("subclass", "")) == "":
			out["subclass"] = String(entry_dict.get("subclass", ""))

	return out
