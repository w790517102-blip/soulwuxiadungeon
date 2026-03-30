extends Node

const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
var _skill_db: Node = SkillDBScript.new()

enum SkillCouplingTier {
	NORMAL,
	WEAPON_BOOST,
	EXCLUSIVE,
	ULTIMATE
}

const SKILL_COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const SKILL_COLOR_WEAPON_BOOST := Color(1.00, 0.62, 0.20) # 橘
const SKILL_COLOR_EXCLUSIVE := Color(1.00, 0.62, 0.20) # 橘（專屬）
const SKILL_COLOR_ULTIMATE := Color(1.00, 0.22, 0.22) # 紅（奧義）

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

func resolve_runtime_skill(skill: Dictionary, inner_force: Dictionary, actor: Dictionary = {}) -> Dictionary:
	var runtime_skill: Dictionary = skill.duplicate(true)
	var chain = runtime_skill.get("legendary_chain", {})
	if typeof(chain) != TYPE_DICTIONARY:
		return runtime_skill
	var chain_map: Dictionary = chain
	var required_force_id := String(chain_map.get("inner_force_id", ""))
	var current_force_id := String(inner_force.get("id", ""))
	if required_force_id == "" or current_force_id != required_force_id:
		return runtime_skill

	if _is_actor_fully_unequipped(actor):
		runtime_skill["name"] = String(chain_map.get("ultimate_name", runtime_skill.get("name", "")))
		runtime_skill["target_scope"] = "enemy_all_per_target_random_hits"
		runtime_skill["target_side"] = "enemy"
		runtime_skill["coupling_tier"] = SkillCouplingTier.ULTIMATE
		return runtime_skill

	runtime_skill["name"] = String(chain_map.get("exclusive_name", runtime_skill.get("name", "")))
	runtime_skill["target_scope"] = "enemy_all_shared_random_hits"
	runtime_skill["target_side"] = "enemy"
	runtime_skill["coupling_tier"] = SkillCouplingTier.EXCLUSIVE
	return runtime_skill

func resolve_skill_name(skill: Dictionary, inner_force: Dictionary) -> String:
	if skill.has("coupling_tier"):
		return String(skill.get("name", ""))
	if inner_force and inner_force.has("prefix") and inner_force.has("boost_weapon") and skill.has("weapon_type"):
		if inner_force["boost_weapon"] == skill["weapon_type"]:
			return "%s%s" % [inner_force["prefix"], String(skill.get("name", ""))]
	return String(skill.get("name", ""))

func resolve_skill_coupling_tier(skill: Dictionary, inner_force: Dictionary) -> SkillCouplingTier:
	if skill.has("coupling_tier"):
		return int(skill.get("coupling_tier", SkillCouplingTier.NORMAL))

	if inner_force.is_empty():
		return SkillCouplingTier.NORMAL

	if _is_exclusive_combo(skill, inner_force):
		return SkillCouplingTier.EXCLUSIVE

	if _is_weapon_boosted(skill, inner_force):
		return SkillCouplingTier.WEAPON_BOOST

	return SkillCouplingTier.NORMAL

func get_skill_color(skill: Dictionary, inner_force: Dictionary) -> Color:
	match resolve_skill_coupling_tier(skill, inner_force):
		SkillCouplingTier.ULTIMATE:
			return SKILL_COLOR_ULTIMATE
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
	if skill.has("coupling_tier") and int(skill.get("coupling_tier", SkillCouplingTier.NORMAL)) == SkillCouplingTier.EXCLUSIVE:
		return true
	var skill_id := String(skill.get("id", ""))
	if skill_id == "":
		return false
	var exclusive_ids_raw = inner_force.get("exclusive_skill_ids", [])
	if typeof(exclusive_ids_raw) != TYPE_ARRAY:
		return false
	var exclusive_ids: Array = exclusive_ids_raw
	return exclusive_ids.has(skill_id)

func _is_actor_fully_unequipped(actor: Dictionary) -> bool:
	if actor.is_empty():
		return false
	var actor_id := String(actor.get("id", ""))
	if actor_id == "":
		return false
	var equip_slots := ["weapon_1", "weapon_2", "armor_head", "armor_body", "armor_hands", "armor_feet", "accessory_1", "accessory_2"]
	if typeof(InventorySync) == TYPE_NIL or not InventorySync.has_method("get_equipped"):
		return false
	var equipped: Dictionary = InventorySync.get_equipped(actor_id)
	for slot in equip_slots:
		if String(equipped.get(slot, "")) != "":
			return false
	return true
