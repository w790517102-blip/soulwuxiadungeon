extends Node

const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
var _skill_db: Node = SkillDBScript.new()

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
