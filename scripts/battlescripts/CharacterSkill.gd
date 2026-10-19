extends Node

const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
var _skill_db: Node = SkillDBScript.new()
var knowledge_provider: Node = null

enum SkillCouplingTier {
	NORMAL,
	WEAPON_BOOST,
	RISK_UPGRADE,
	EXCLUSIVE,
	ULTIMATE
}

const SKILL_COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const SKILL_COLOR_WEAPON_BOOST := Color(0.35, 0.78, 1.00) # 青藍
const SKILL_COLOR_RISK_UPGRADE := Color(0.74, 0.40, 0.96) # 紫（絕技）
const SKILL_COLOR_EXCLUSIVE := Color(1.00, 0.62, 0.20) # 橘（專屬）
const SKILL_COLOR_ULTIMATE := Color(1.00, 0.22, 0.22) # 紅（奧義）

# The inner-force x martial synergy table lives in MartialSynergy.gd (one canonical record per pairing). This class
# applies the runtime part of it; BattleController reads the same rule for strike-count and on-hit effects.
const MartialSynergyScript = preload("res://scripts/battlescripts/MartialSynergy.gd")

func get_skills(character_id: String) -> Array:
	var actor = null
	var provider := _get_knowledge_provider()
	if provider and provider.has_method("get_character_by_id"):
		actor = provider.get_character_by_id(character_id)
	return get_effective_skills_for_actor(character_id, actor, true)

func get_skills_by_actor(actor) -> Array:
	if typeof(actor) == TYPE_DICTIONARY:
		var actor_id := String(actor.get("id", ""))
		return get_effective_skills_for_actor(actor_id, actor, true)
	if actor is Object:
		var id_value = actor.get("id")
		if typeof(id_value) == TYPE_STRING and id_value != "":
			return get_effective_skills_for_actor(String(id_value), actor, true)
	return []

func get_effective_skills_for_actor(actor_id: String, actor = null, apply_weapon_filter: bool = false) -> Array:
	actor_id = _canonicalize_actor_id(actor_id)
	var effective_ids := get_effective_skill_ids_for_actor(actor_id, actor)
	var weapon_actor = actor if apply_weapon_filter else null
	return _skill_db.get_skills_for_actor(actor_id, weapon_actor, effective_ids, false)

func get_effective_skill_ids_for_actor(actor_id: String, actor = null) -> Array:
	actor_id = _canonicalize_actor_id(actor_id)
	var out: Array = []
	var battle_profile_ids = _get_battle_profile_skill_ids(actor)
	if battle_profile_ids != null:
		# A story battle profile is an explicit, finite loadout.  Do not merge
		# later save knowledge, manual knowledge, or LiuYu companion insights into
		# this temporary actor.
		for raw_id in battle_profile_ids:
			var profile_id = _skill_db.coerce_skill_id(raw_id)
			if profile_id == "" or out.has(profile_id):
				continue
			if _is_skill_eligible_for_actor(actor_id, profile_id, actor):
				out.append(profile_id)
		return out
	var candidate_ids: Array = []
	var provider := _get_knowledge_provider()
	if provider and provider.has_method("refresh_liuyu_companion_insights"):
		provider.refresh_liuyu_companion_insights()
	# Keep each actor's established personal-skill order stable; newly effective
	# shared/manual skills follow the canonical SkillDB order.
	if provider and provider.has_method("get_known_skill_ids"):
		for raw_id in provider.get_known_skill_ids(actor_id):
			var personal_id = _skill_db.coerce_skill_id(raw_id)
			if personal_id != "" and not candidate_ids.has(personal_id):
				candidate_ids.append(personal_id)
	for skill_any in _skill_db.get_all_skills():
		if typeof(skill_any) != TYPE_DICTIONARY:
			continue
		var skill_id := String((skill_any as Dictionary).get("id", ""))
		if skill_id != "" and not candidate_ids.has(skill_id):
			candidate_ids.append(skill_id)
	for skill_id in candidate_ids:
		if actor_has_effective_skill(actor_id, String(skill_id), actor):
			out.append(skill_id)
	return out

func actor_has_effective_skill(actor_id: String, skill_id: String, actor = null) -> bool:
	actor_id = _canonicalize_actor_id(actor_id)
	var canonical_id = _skill_db.coerce_skill_id(skill_id)
	if actor_id == "" or canonical_id == "":
		return false
	# Eligibility is authoritative and is checked before every knowledge source.
	if not _skill_db.is_available_for_actor(canonical_id, actor_id):
		return false
	var skill: Dictionary = _skill_db.get_skill(canonical_id)
	if skill.is_empty() or not _actor_has_weapon_aptitude(actor_id, String(skill.get("weapon_type", "")), actor):
		return false
	var actor_level = max(1, int(_actor_get_value(actor, "level", _get_actor_level(actor_id))))
	if not _skill_db.is_level_eligible(canonical_id, actor_level):
		return false
	var battle_profile_ids = _get_battle_profile_skill_ids(actor)
	if battle_profile_ids != null:
		return battle_profile_ids.has(canonical_id)

	var provider := _get_knowledge_provider()
	if provider == null:
		return _skill_db.get_default_skill_ids(actor_id).has(canonical_id)
	if provider.has_method("knows_skill") and bool(provider.knows_skill(actor_id, canonical_id)):
		return true
	if provider.has_method("has_skill_manual_knowledge") and bool(provider.has_skill_manual_knowledge(canonical_id)):
		return true
	if not _skill_db.is_shareable(canonical_id):
		return false
	# Shared knowledge reaches party members only. A wild enemy (id not in the roster) must
	# not borrow LiuYu's skills, or a 獼猴 ends up casting 鷹眼凝 as an attack on its own side.
	if provider.has_method("get_character_by_id") and (provider.get_character_by_id(actor_id) as Dictionary).is_empty():
		return false
	# Only LiuYu's valid personal knowledge may become a shared source.
	# Another actor's personal knowledge never propagates to teammates.
	if not _skill_db.is_available_for_actor(canonical_id, "liuyu"):
		return false
	return provider.has_method("knows_skill") and bool(provider.knows_skill("liuyu", canonical_id))


func _is_skill_eligible_for_actor(actor_id: String, skill_id: String, actor = null) -> bool:
	var skill: Dictionary = _skill_db.get_skill(skill_id)
	if skill.is_empty() or not _skill_db.is_available_for_actor(skill_id, actor_id):
		return false
	if not _actor_has_weapon_aptitude(actor_id, String(skill.get("weapon_type", "")), actor):
		return false
	var actor_level = max(1, int(_actor_get_value(actor, "level", _get_actor_level(actor_id))))
	return _skill_db.is_level_eligible(skill_id, actor_level)


func _get_battle_profile_skill_ids(actor):
	if typeof(actor) != TYPE_DICTIONARY:
		return null
	var raw_ids = (actor as Dictionary).get("battle_skill_ids", null)
	if typeof(raw_ids) != TYPE_ARRAY:
		return null
	return raw_ids as Array

func _actor_has_weapon_aptitude(actor_id: String, weapon_type: String, actor = null) -> bool:
	if weapon_type == "":
		return true
	var actor_aptitudes = _actor_get_value(actor, "weapon_aptitudes", null)
	if typeof(actor_aptitudes) == TYPE_ARRAY:
		return (actor_aptitudes as Array).has(weapon_type)
	var provider := _get_knowledge_provider()
	if provider and provider.has_method("has_weapon_aptitude"):
		return bool(provider.has_weapon_aptitude(actor_id, weapon_type))
	return false

func _get_knowledge_provider() -> Node:
	if knowledge_provider != null:
		return knowledge_provider
	if typeof(TeamData) != TYPE_NIL:
		return TeamData
	return null

func _canonicalize_actor_id(actor_id: String) -> String:
	var provider := _get_knowledge_provider()
	if provider and provider.has_method("canonicalize_actor_id"):
		return String(provider.canonicalize_actor_id(actor_id))
	if actor_id == "su_mien":
		return "shumian"
	return actor_id

func _get_actor_level(actor_id: String) -> int:
	var provider := _get_knowledge_provider()
	if provider and provider.has_method("get_character_by_id"):
		var actor = provider.get_character_by_id(actor_id)
		return max(1, int(_actor_get_value(actor, "level", 1)))
	return 1

func _actor_get_value(actor, key: String, fallback):
	if typeof(actor) == TYPE_DICTIONARY:
		return (actor as Dictionary).get(key, fallback)
	if actor is Object:
		var value = actor.get(key)
		return fallback if value == null else value
	return fallback

func resolve_effective_skill(skill_id: String, actor: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var canonical_id: String = _skill_db.coerce_skill_id(skill_id)
	if canonical_id == "":
		return {}
	var base_skill: Dictionary = _skill_db.get_skill(canonical_id)
	if base_skill.is_empty():
		return {}
	var inner_force = context.get("inner_force", actor.get("inner_force", {}))
	if typeof(inner_force) != TYPE_DICTIONARY:
		inner_force = {}
	return resolve_runtime_skill(base_skill, inner_force, actor)

func resolve_runtime_skill(skill: Dictionary, inner_force: Dictionary, actor: Dictionary = {}) -> Dictionary:
	# Always rebuild from SkillDB when an id is available.  A caller may pass an
	# already-resolved clone (for example from a popup); reusing that clone would
	# apply pairing modifiers a second time.
	var skill_id := String(skill.get("id", ""))
	var canonical_skill: Dictionary = {}
	if skill_id != "":
		canonical_skill = _skill_db.get_skill(_skill_db.coerce_skill_id(skill_id))
	var runtime_skill: Dictionary = canonical_skill if not canonical_skill.is_empty() else skill.duplicate(true)
	var risk_upgrade = runtime_skill.get("risk_upgrade", {})
	if typeof(risk_upgrade) == TYPE_DICTIONARY:
		var risk_map: Dictionary = risk_upgrade
		var required_risk_force_id := String(risk_map.get("inner_force_id", ""))
		var current_force_id := String(inner_force.get("id", ""))
		if required_risk_force_id != "" and current_force_id == required_risk_force_id:
			for key in risk_map.keys():
				var key_str := String(key)
				if key_str == "inner_force_id":
					continue
				runtime_skill[key_str] = risk_map[key]
			runtime_skill["coupling_tier"] = SkillCouplingTier.RISK_UPGRADE

	var chain = runtime_skill.get("legendary_chain", {})
	if typeof(chain) == TYPE_DICTIONARY:
		var chain_map: Dictionary = chain
		var required_force_id := String(chain_map.get("inner_force_id", ""))
		var current_force_id := String(inner_force.get("id", ""))
		if required_force_id != "" and current_force_id == required_force_id:
			if _is_actor_fully_unequipped(actor):
				runtime_skill["name"] = String(chain_map.get("ultimate_name", runtime_skill.get("name", "")))
				runtime_skill["target_scope"] = "enemy_all_per_target_random_hits"
				runtime_skill["target_side"] = "enemy"
				runtime_skill["coupling_tier"] = SkillCouplingTier.ULTIMATE
			else:
				runtime_skill["name"] = String(chain_map.get("exclusive_name", runtime_skill.get("name", "")))
				runtime_skill["target_scope"] = "enemy_all_shared_random_hits"
				runtime_skill["target_side"] = "enemy"
				runtime_skill["coupling_tier"] = SkillCouplingTier.EXCLUSIVE

	_apply_pairing_synergy(runtime_skill, inner_force)
	return runtime_skill

static func get_pairing_rule(skill_id: String, inner_force_id: String) -> Dictionary:
	return MartialSynergyScript.runtime_rule(skill_id, inner_force_id)

func _apply_pairing_synergy(runtime_skill: Dictionary, inner_force: Dictionary) -> void:
	var rule := get_pairing_rule(String(runtime_skill.get("id", "")), String(inner_force.get("id", "")))
	if rule.is_empty():
		return
	var effects = rule.get("effects", {})
	if typeof(effects) == TYPE_DICTIONARY:
		var bonus_scaling = (effects as Dictionary).get("bonus_stat_scaling", {})
		if typeof(bonus_scaling) == TYPE_DICTIONARY and not (bonus_scaling as Dictionary).is_empty():
			var merged_scaling = runtime_skill.get("stat_scaling", {})
			merged_scaling = merged_scaling.duplicate(true) if typeof(merged_scaling) == TYPE_DICTIONARY else {}
			for stat_key in (bonus_scaling as Dictionary).keys():
				var key := String(stat_key)
				merged_scaling[key] = float(merged_scaling.get(key, 0.0)) + float((bonus_scaling as Dictionary).get(stat_key, 0.0))
			runtime_skill["stat_scaling"] = merged_scaling
	var display_name := String(rule.get("display_name", ""))
	if display_name != "":
		runtime_skill["name"] = display_name
		runtime_skill["coupling_tier"] = SkillCouplingTier.EXCLUSIVE

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
		SkillCouplingTier.RISK_UPGRADE:
			return SKILL_COLOR_RISK_UPGRADE
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
	var equip_slots := ["weapon_1", "weapon_2", "armor_head", "armor_body", "armor_hands", "armor_feet", "accessory_1", "mechanism"]
	if typeof(InventorySync) == TYPE_NIL or not InventorySync.has_method("get_equipped"):
		return false
	var equipped: Dictionary = InventorySync.get_equipped(actor_id)
	for slot in equip_slots:
		if String(equipped.get(slot, "")) != "":
			return false
	return true
