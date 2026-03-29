extends Node

const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
var _skill_db: Node = SkillDBScript.new()

enum SkillCouplingTier {
	NORMAL,
	WEAPON_BOOST,
	EXCLUSIVE
}

const SKILL_COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const SKILL_COLOR_WEAPON_BOOST := Color(0.30, 0.80, 1.00) # 青藍
const SKILL_COLOR_EXCLUSIVE := Color(1.00, 0.72, 0.25) # 金橘

func get_skills(character_id: String) -> Array:
	var actor = null
	if TeamData and TeamData.has_method("get_character_by_id"):
		actor = TeamData.get_character_by_id(character_id)
	var known_ids: Array = []
	if TeamData and TeamData.has_method("get_known_skill_ids"):
		known_ids = TeamData.get_known_skill_ids(character_id)
	return _skill_db.get_skills_for_actor(character_id, actor, known_ids)

func get_skills_by_actor(actor) -> Array:
	if typeof(actor) == TYPE_DICTIONARY:
		return _skill_db.get_skills_for_actor(String(actor.get("id", "")), actor)
	if actor is Object:
		var id_value = actor.get("id")
		if typeof(id_value) == TYPE_STRING and id_value != "":
			return _skill_db.get_skills_for_actor(String(id_value), actor)
	return []

func resolve_skill_name(skill: Dictionary, inner_force: Dictionary) -> String:
	if inner_force and inner_force.has("prefix") and inner_force.has("boost_weapon") and skill.has("weapon_type"):
		if inner_force["boost_weapon"] == skill["weapon_type"]:
			return "%s%s" % [inner_force["prefix"], String(skill.get("name", ""))]
	return String(skill.get("name", ""))

func resolve_skill_coupling_tier(skill: Dictionary, inner_force: Dictionary) -> SkillCouplingTier:
	if inner_force.is_empty():
		return SkillCouplingTier.NORMAL

	if _is_exclusive_combo(skill, inner_force):
		return SkillCouplingTier.EXCLUSIVE

	if _is_weapon_boosted(skill, inner_force):
		return SkillCouplingTier.WEAPON_BOOST

	return SkillCouplingTier.NORMAL

func get_skill_color(skill: Dictionary, inner_force: Dictionary) -> Color:
	match resolve_skill_coupling_tier(skill, inner_force):
		SkillCouplingTier.EXCLUSIVE:
			return SKILL_COLOR_EXCLUSIVE
		SkillCouplingTier.WEAPON_BOOST:
			return SKILL_COLOR_WEAPON_BOOST
		_:
			return SKILL_COLOR_NORMAL

func _is_weapon_boosted(skill: Dictionary, inner_force: Dictionary) -> bool:
	var boost_weapon := String(inner_force.get("boost_weapon", ""))
	var weapon_type := String(skill.get("weapon_type", ""))
	return boost_weapon != "" and weapon_type != "" and weapon_type == boost_weapon

func _is_exclusive_combo(skill: Dictionary, inner_force: Dictionary) -> bool:
	var skill_id := String(skill.get("id", ""))
	if skill_id == "":
		return false
	var exclusive_ids_raw = inner_force.get("exclusive_skill_ids", [])
	if typeof(exclusive_ids_raw) != TYPE_ARRAY:
		return false
	var exclusive_ids: Array = exclusive_ids_raw
	return exclusive_ids.has(skill_id)
