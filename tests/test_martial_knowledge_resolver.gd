extends SceneTree

const TeamDataManagerScript = preload("res://scripts/battlescripts/TeamDataManager.gd")
const CharacterSkillScript = preload("res://scripts/battlescripts/CharacterSkill.gd")
const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
const InnerForceDBScript = preload("res://scripts/battlescripts/InnerForceDB.gd")

const SHARED_SKILL_ID := "skill_badaozhan"
const NON_SHAREABLE_SKILL_ID := "skill_duanshuizhan"
const COMPANION_INSIGHT_SKILL_ID := "skill_luobichengshi"
const LIESHAO_KNIFE_INSIGHT_SKILL_ID := "skill_liedaoposhi"
const LIESHAO_QIN_INSIGHT_SKILL_ID := "skill_luanyinsuiqin"
const EXCLUSIVE_SKILL_ID := "skill_qihui_talisman"
const LIMITED_GROUP_SKILL_ID := "skill_huagu_mianzhang"
const MANUAL_FORCE_ID := "ling_feng_jue"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_other_actor_personal_skill_does_not_share()
	_test_liuyu_personal_skill_shares_with_level_gate()
	_test_non_shareable_skill_stays_personal_to_liuyu()
	_test_shumian_skill_becomes_liuyu_personal_insight()
	_test_lieshao_insight_thresholds_and_growth_events()
	_test_multi_level_growth_collapses_and_reports_both_insights()
	_test_weapon_aptitudes_gate_knowledge_before_equipment()
	_test_level_acquisition_routes_are_distinct()
	_test_multiple_non_level_routes_are_preserved()
	_test_exclusive_skill_rejects_invalid_knowledge_source()
	_test_multi_actor_eligibility_blocks_every_knowledge_route()
	_test_manual_knowledge_is_global_but_still_eligible_and_level_gated()
	_test_future_actor_resolves_previously_acquired_manual()
	_test_effective_knowledge_does_not_pollute_personal_known()
	_test_weapon_filter_remains_runtime_only()
	_test_inner_force_manual_is_global_without_polluting_personal_known()
	_test_manual_knowledge_survives_team_state_export_import()
	_test_legacy_save_without_manual_fields_defaults_to_empty()
	_test_legacy_skill_metadata_defaults_are_backward_compatible()

	if _failures.is_empty():
		print("PASS: martial knowledge resolver regression")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_other_actor_personal_skill_does_not_share() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_personal_skills(team, "liuyu", [])
	_set_personal_skills(team, "lieshao", [SHARED_SKILL_ID])
	_set_personal_skills(team, "shumian", [])

	_expect(resolver.actor_has_effective_skill("lieshao", SHARED_SKILL_ID), "personal owner can use own non-exclusive skill")
	_expect(not resolver.actor_has_effective_skill("liuyu", SHARED_SKILL_ID), "another actor's personal skill is not a direct knowledge source")
	_free_context(context)


func _test_liuyu_personal_skill_shares_with_level_gate() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_skill_required_level(SHARED_SKILL_ID, 30)
	_set_personal_skills(team, "liuyu", [SHARED_SKILL_ID])
	_set_personal_skills(team, "lieshao", [])
	_set_actor_level(team, "lieshao", 29)

	_expect(not resolver.actor_has_effective_skill("lieshao", SHARED_SKILL_ID), "LiuYu shared skill waits for target level")
	_set_actor_level(team, "lieshao", 30)
	_expect(resolver.actor_has_effective_skill("lieshao", SHARED_SKILL_ID), "LiuYu non-exclusive personal skill shares after target reaches level")
	_expect(not team.get_known_skill_ids("lieshao").has(SHARED_SKILL_ID), "shared skill does not pollute Lieshao personal knowledge")
	_clear_skill_required_level(SHARED_SKILL_ID)
	_free_context(context)


func _test_non_shareable_skill_stays_personal_to_liuyu() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_personal_skills(team, "liuyu", [NON_SHAREABLE_SKILL_ID])
	_set_personal_skills(team, "lieshao", [])
	_expect(resolver.actor_has_effective_skill("liuyu", NON_SHAREABLE_SKILL_ID), "non-shareable skill remains usable by its personal owner")
	_expect(not resolver.actor_has_effective_skill("lieshao", NON_SHAREABLE_SKILL_ID), "Duanshuizhan does not propagate through LiuYu sharing")
	_free_context(context)


func _test_shumian_skill_becomes_liuyu_personal_insight() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_personal_skills(team, "liuyu", [])
	_set_personal_skills(team, "shumian", [COMPANION_INSIGHT_SKILL_ID])
	team.unlock_roster("shumian")
	team.refresh_liuyu_companion_insights()
	_expect(team.get_known_skill_ids("liuyu").has(COMPANION_INSIGHT_SKILL_ID), "Shumian's Luobichengshi is permanently learned by LiuYu")
	_expect(resolver.actor_has_effective_skill("liuyu", COMPANION_INSIGHT_SKILL_ID), "LiuYu can resolve the learned pen skill")
	_expect(not resolver.actor_has_effective_skill("lieshao", COMPANION_INSIGHT_SKILL_ID), "Lieshao cannot receive a pen skill without pen aptitude")
	_free_context(context)


func _test_lieshao_insight_thresholds_and_growth_events() -> void:
	var context := _make_context()
	var team = context.team
	_set_personal_skills(team, "liuyu", [])
	_set_personal_skills(team, "lieshao", [LIESHAO_KNIFE_INSIGHT_SKILL_ID, LIESHAO_QIN_INSIGHT_SKILL_ID])
	team.unlock_roster("lieshao")
	team.current_team_ids = ["liuyu"]
	_set_actor_level(team, "liuyu", 7)
	var liuyu: Dictionary = team.get_character_by_id("liuyu")
	liuyu["exp"] = 0
	team.all_characters["liuyu"] = liuyu
	team.refresh_liuyu_companion_insights()
	_expect(not team.knows_skill("liuyu", LIESHAO_KNIFE_INSIGHT_SKILL_ID), "LiuYu Lv7 has not learned Lieshao's knife insight")
	_expect(not team.knows_skill("liuyu", LIESHAO_QIN_INSIGHT_SKILL_ID), "LiuYu Lv7 has not learned Lieshao's qin insight")

	var level_eight: Dictionary = team.add_exp_to_active_party_with_growth(50)
	_expect((level_eight.get("skills_learned", []) as Array).is_empty(), "Lv8 creates no companion insight event")
	var level_nine: Dictionary = team.add_exp_to_active_party_with_growth(50)
	_expect(_growth_has_skill(level_nine, "liuyu", LIESHAO_KNIFE_INSIGHT_SKILL_ID), "Lv9 reports Liedaoposhi as newly learned")
	_expect(not _growth_has_skill(level_nine, "liuyu", LIESHAO_QIN_INSIGHT_SKILL_ID), "Lv9 does not learn Luanyinsuiqin early")
	var level_ten: Dictionary = team.add_exp_to_active_party_with_growth(50)
	_expect((level_ten.get("skills_learned", []) as Array).is_empty(), "Lv10 does not report an already learned skill again")
	var level_eleven: Dictionary = team.add_exp_to_active_party_with_growth(50)
	_expect(_growth_has_skill(level_eleven, "liuyu", LIESHAO_QIN_INSIGHT_SKILL_ID), "Lv11 reports Luanyinsuiqin as newly learned")
	_expect(team.knows_skill("liuyu", LIESHAO_KNIFE_INSIGHT_SKILL_ID), "Liedaoposhi persists in LiuYu Personal Known")
	_expect(team.knows_skill("liuyu", LIESHAO_QIN_INSIGHT_SKILL_ID), "Luanyinsuiqin persists in LiuYu Personal Known")
	_free_context(context)


func _test_multi_level_growth_collapses_and_reports_both_insights() -> void:
	var context := _make_context()
	var team = context.team
	_set_personal_skills(team, "liuyu", [])
	_set_personal_skills(team, "lieshao", [LIESHAO_KNIFE_INSIGHT_SKILL_ID, LIESHAO_QIN_INSIGHT_SKILL_ID])
	team.unlock_roster("lieshao")
	team.current_team_ids = ["liuyu"]
	_set_actor_level(team, "liuyu", 7)
	var liuyu: Dictionary = team.get_character_by_id("liuyu")
	liuyu["exp"] = 0
	team.all_characters["liuyu"] = liuyu
	var growth: Dictionary = team.add_exp_to_active_party_with_growth(200)
	var level_ups: Array = growth.get("level_ups", [])
	_expect(level_ups.size() == 1, "Lv7 to Lv11 is collapsed into one level-up record")
	if level_ups.size() == 1:
		_expect(int((level_ups[0] as Dictionary).get("old_level", 0)) == 7, "collapsed growth keeps old level 7")
		_expect(int((level_ups[0] as Dictionary).get("new_level", 0)) == 11, "collapsed growth keeps final level 11")
	_expect(_growth_has_skill(growth, "liuyu", LIESHAO_KNIFE_INSIGHT_SKILL_ID), "multi-level growth reports Liedaoposhi")
	_expect(_growth_has_skill(growth, "liuyu", LIESHAO_QIN_INSIGHT_SKILL_ID), "multi-level growth reports Luanyinsuiqin")
	_free_context(context)


func _test_weapon_aptitudes_gate_knowledge_before_equipment() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_personal_skills(team, "liuyu", [SHARED_SKILL_ID, COMPANION_INSIGHT_SKILL_ID])
	_set_personal_skills(team, "lieshao", [])
	_set_personal_skills(team, "shumian", [])
	_expect(resolver.actor_has_effective_skill("lieshao", SHARED_SKILL_ID), "Lieshao accepts LiuYu's knife knowledge")
	_expect(not resolver.actor_has_effective_skill("lieshao", COMPANION_INSIGHT_SKILL_ID), "Lieshao rejects pen knowledge before equipment checks")
	_expect(not resolver.actor_has_effective_skill("shumian", SHARED_SKILL_ID), "Shumian rejects knife knowledge before equipment checks")
	_expect(team.has_weapon_aptitude("liuyu", "筆"), "LiuYu has all-family pen aptitude")
	_expect(not team.has_weapon_aptitude("shumian", "刀"), "Shumian has no knife aptitude")
	_expect(not team.has_weapon_aptitude("lieshao", "筆"), "Lieshao has no pen aptitude")
	_free_context(context)


func _test_level_acquisition_routes_are_distinct() -> void:
	var context := _make_context()
	var team = context.team
	var family_raw: Dictionary = SkillDBScript.SKILLS[SHARED_SKILL_ID]
	var growth_raw: Dictionary = SkillDBScript.SKILLS["skill_huanbu_zhang"]
	family_raw["acquisition_routes"] = [{"type": "weapon_family_level", "weapon_type": "刀", "required_level": 10}]
	growth_raw["acquisition_routes"] = [{"type": "actor_growth", "actor_id": "lieshao", "required_level": 12}]
	_set_personal_skills(team, "lieshao", [])
	_set_personal_skills(team, "shumian", [])
	_set_actor_level(team, "lieshao", 12)
	_set_actor_level(team, "shumian", 99)
	team.refresh_natural_skill_learning("lieshao")
	team.refresh_natural_skill_learning("shumian")
	_expect(team.get_known_skill_ids("lieshao").has(SHARED_SKILL_ID), "weapon-family level route teaches an apt knife actor")
	_expect(team.get_known_skill_ids("lieshao").has("skill_huanbu_zhang"), "actor-growth route teaches only its named actor")
	_expect(not team.get_known_skill_ids("shumian").has(SHARED_SKILL_ID), "weapon-family route rejects a high-level actor without aptitude")
	_expect(not team.get_known_skill_ids("shumian").has("skill_huanbu_zhang"), "actor-growth route does not become family-wide")
	family_raw.erase("acquisition_routes")
	growth_raw.erase("acquisition_routes")
	_free_context(context)


func _test_multiple_non_level_routes_are_preserved() -> void:
	var raw: Dictionary = SkillDBScript.SKILLS[NON_SHAREABLE_SKILL_ID]
	raw["acquisition_routes"] = [
		{"type": "quest_event", "event_id": "test_event"},
		{"type": "manual", "item_id": "test_manual"},
	]
	var db = SkillDBScript.new()
	var routes: Array = db.get_acquisition_routes(NON_SHAREABLE_SKILL_ID)
	_expect(routes.size() == 2, "one skill preserves independent quest and manual acquisition routes")
	_expect(String((routes[0] as Dictionary).get("type", "")) == "quest_event", "quest route keeps its formal type")
	_expect(String((routes[1] as Dictionary).get("type", "")) == "manual", "manual route keeps its formal type")
	db.free()
	raw.erase("acquisition_routes")


func _test_exclusive_skill_rejects_invalid_knowledge_source() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_personal_skills(team, "liuyu", [EXCLUSIVE_SKILL_ID])
	_set_personal_skills(team, "shumian", [])

	_expect(not resolver.actor_has_effective_skill("liuyu", EXCLUSIVE_SKILL_ID), "exclusive skill rejects ineligible LiuYu even if legacy data says known")
	_expect(not resolver.actor_has_effective_skill("shumian", EXCLUSIVE_SKILL_ID), "invalid LiuYu exclusive knowledge is not a shared source")
	_expect(not resolver.actor_has_effective_skill("lieshao", EXCLUSIVE_SKILL_ID), "exclusive skill rejects other actors")
	_free_context(context)


func _test_multi_actor_eligibility_blocks_every_knowledge_route() -> void:
	var raw: Dictionary = SkillDBScript.SKILLS[LIMITED_GROUP_SKILL_ID]
	var original: Dictionary = raw.duplicate(true)
	raw["available"] = {"mode": "include", "actor_ids": ["liuyu", "lieshao"]}
	raw["shareable"] = true
	raw["required_level"] = 1
	raw["acquisition_routes"] = []
	raw["companion_insight"] = {"enabled": false}

	# Personal knowledge and LiuYu sharing both remain behind eligibility.
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_personal_skills(team, "liuyu", [LIMITED_GROUP_SKILL_ID])
	_set_personal_skills(team, "lieshao", [])
	_set_personal_skills(team, "shumian", [])
	_expect(not team.learn_skill("shumian", LIMITED_GROUP_SKILL_ID), "Personal learn entry rejects an actor outside the allowed list")
	# Even malformed legacy Personal Known data remains blocked by the
	# authoritative effective-skill eligibility gate.
	_set_personal_skills(team, "shumian", [LIMITED_GROUP_SKILL_ID])
	_expect(resolver.actor_has_effective_skill("liuyu", LIMITED_GROUP_SKILL_ID), "allowed LiuYu accepts restricted personal knowledge")
	_expect(resolver.actor_has_effective_skill("lieshao", LIMITED_GROUP_SKILL_ID), "allowed Lieshao accepts restricted LiuYu sharing")
	_expect(not resolver.actor_has_effective_skill("shumian", LIMITED_GROUP_SKILL_ID), "disallowed same-family actor rejects personal and shared knowledge")
	var db = SkillDBScript.new()
	_expect(not db.is_exclusive_skill(LIMITED_GROUP_SKILL_ID), "multi-actor restriction is not misclassified as single-owner exclusive")
	db.free()
	_free_context(context)

	# Global manual knowledge does not bypass the actor list.
	context = _make_context()
	team = context.team
	resolver = context.resolver
	_set_personal_skills(team, "liuyu", [])
	_set_personal_skills(team, "lieshao", [])
	_set_personal_skills(team, "shumian", [])
	team.acquire_skill_manual(LIMITED_GROUP_SKILL_ID)
	_expect(resolver.actor_has_effective_skill("lieshao", LIMITED_GROUP_SKILL_ID), "allowed actor resolves restricted manual knowledge")
	_expect(not resolver.actor_has_effective_skill("shumian", LIMITED_GROUP_SKILL_ID), "manual knowledge cannot bypass actor eligibility")
	_free_context(context)

	# Weapon-family growth checks eligibility before aptitude and route level.
	raw["acquisition_routes"] = [{
		"type": "weapon_family_level",
		"weapon_type": "掌",
		"required_level": 1,
	}]
	context = _make_context()
	team = context.team
	_set_personal_skills(team, "lieshao", [])
	_set_personal_skills(team, "shumian", [])
	team.refresh_natural_skill_learning("lieshao")
	team.refresh_natural_skill_learning("shumian")
	_expect(team.knows_skill("lieshao", LIMITED_GROUP_SKILL_ID), "allowed apt actor learns restricted weapon-family growth")
	_expect(not team.knows_skill("shumian", LIMITED_GROUP_SKILL_ID), "disallowed apt actor rejects weapon-family growth")
	_free_context(context)

	# Companion Insight may teach allowed LiuYu, but cannot make an excluded
	# actor resolve the resulting shared knowledge.
	raw["acquisition_routes"] = []
	raw["companion_insight"] = {"enabled": true, "required_level": 1}
	context = _make_context()
	team = context.team
	resolver = context.resolver
	_set_personal_skills(team, "liuyu", [])
	_set_personal_skills(team, "lieshao", [LIMITED_GROUP_SKILL_ID])
	team.unlock_roster("lieshao")
	_set_personal_skills(team, "shumian", [])
	team.refresh_liuyu_companion_insights()
	_expect(team.knows_skill("liuyu", LIMITED_GROUP_SKILL_ID), "allowed LiuYu acquires restricted Companion Insight")
	_expect(not resolver.actor_has_effective_skill("shumian", LIMITED_GROUP_SKILL_ID), "excluded actor rejects restricted knowledge after LiuYu learns it")
	_free_context(context)

	raw.clear()
	raw.merge(original, true)


func _test_manual_knowledge_is_global_but_still_eligible_and_level_gated() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_skill_required_level(SHARED_SKILL_ID, 30)
	_set_personal_skills(team, "liuyu", [])
	_set_personal_skills(team, "shumian", [])
	_set_actor_level(team, "lieshao", 29)
	_expect(team.acquire_skill_manual(SHARED_SKILL_ID), "first skill manual acquisition succeeds")
	_expect(not team.acquire_skill_manual(SHARED_SKILL_ID), "duplicate skill manual does not stack")

	_expect(not resolver.actor_has_effective_skill("lieshao", SHARED_SKILL_ID), "eligible actor below required level cannot use manual knowledge")
	_set_actor_level(team, "lieshao", 30)
	_expect(resolver.actor_has_effective_skill("lieshao", SHARED_SKILL_ID), "eligible actor at required level uses manual knowledge")
	team.acquire_skill_manual(EXCLUSIVE_SKILL_ID)
	_expect(resolver.actor_has_effective_skill("shumian", EXCLUSIVE_SKILL_ID), "exclusive manual unlocks its eligible actor")
	_expect(not resolver.actor_has_effective_skill("liuyu", EXCLUSIVE_SKILL_ID), "manual knowledge cannot bypass actor eligibility")
	_expect(not resolver.actor_has_effective_skill("lieshao", EXCLUSIVE_SKILL_ID), "exclusive manual remains unavailable to other actors")
	_clear_skill_required_level(SHARED_SKILL_ID)
	_free_context(context)


func _test_future_actor_resolves_previously_acquired_manual() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_skill_required_level(SHARED_SKILL_ID, 30)
	team.acquire_skill_manual(SHARED_SKILL_ID)
	var future_actor := {"id": "future_actor", "level": 30, "weapon_1": "刀", "weapon_2": "", "weapon_aptitudes": ["刀", "通用"]}
	_expect(resolver.actor_has_effective_skill("future_actor", SHARED_SKILL_ID, future_actor), "future eligible actor resolves an already acquired manual")
	_clear_skill_required_level(SHARED_SKILL_ID)
	_free_context(context)


func _test_effective_knowledge_does_not_pollute_personal_known() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_personal_skills(team, "liuyu", [SHARED_SKILL_ID])
	_set_personal_skills(team, "lieshao", [])
	_expect(resolver.actor_has_effective_skill("lieshao", SHARED_SKILL_ID), "shared knowledge resolves effectively")
	_expect(not team.get_known_skill_ids("lieshao").has(SHARED_SKILL_ID), "shared knowledge is not appended to personal known")
	_free_context(context)


func _test_weapon_filter_remains_runtime_only() -> void:
	var context := _make_context()
	var team = context.team
	var resolver = context.resolver
	_set_personal_skills(team, "liuyu", [SHARED_SKILL_ID])
	_set_personal_skills(team, "lieshao", [])
	var actor: Dictionary = team.get_character_by_id("lieshao")
	actor["weapon_1"] = "琴"
	actor["weapon_2"] = ""
	var knowledge_list: Array = resolver.get_effective_skills_for_actor("lieshao", actor, false)
	var runtime_list: Array = resolver.get_effective_skills_for_actor("lieshao", actor, true)
	_expect(_contains_skill(knowledge_list, SHARED_SKILL_ID), "effective knowledge exists before weapon filtering")
	_expect(not _contains_skill(runtime_list, SHARED_SKILL_ID), "wrong weapon still hides skill at runtime")
	actor["weapon_2"] = "刀"
	runtime_list = resolver.get_effective_skills_for_actor("lieshao", actor, true)
	_expect(_contains_skill(runtime_list, SHARED_SKILL_ID), "secondary knife keeps dual-weapon compatibility")
	_set_personal_skills(team, "liuyu", [COMPANION_INSIGHT_SKILL_ID, "skill_zhengxinquan"])
	var liuyu: Dictionary = team.get_character_by_id("liuyu")
	liuyu["weapon_1"] = "劍"
	liuyu["weapon_2"] = "筆"
	var liuyu_runtime: Array = resolver.get_effective_skills_for_actor("liuyu", liuyu, true)
	_expect(_contains_skill(liuyu_runtime, COMPANION_INSIGHT_SKILL_ID), "secondary pen enables LiuYu's learned pen skill")
	_expect(_contains_skill(liuyu_runtime, "skill_zhengxinquan"), "ordinary fist skill does not require a free hand")
	_free_context(context)


func _test_inner_force_manual_is_global_without_polluting_personal_known() -> void:
	var context := _make_context()
	var team = context.team
	var raw: Dictionary = InnerForceDBScript.INNER_FORCES[MANUAL_FORCE_ID]
	raw["required_level"] = 20
	_set_actor_level(team, "liuyu", 19)
	_expect(team.acquire_inner_force_manual(MANUAL_FORCE_ID), "first inner-force manual acquisition succeeds")
	_expect(not team.acquire_inner_force_manual(MANUAL_FORCE_ID), "duplicate inner-force manual does not stack")
	_expect(not team.actor_has_effective_inner_force("liuyu", MANUAL_FORCE_ID), "inner-force manual respects actor level")
	_set_actor_level(team, "liuyu", 20)
	_expect(team.actor_has_effective_inner_force("liuyu", MANUAL_FORCE_ID), "eligible actor resolves inner-force manual")
	_expect(team.actor_has_effective_inner_force("future_actor", MANUAL_FORCE_ID, {"id": "future_actor", "level": 20}), "future actor resolves previously acquired inner-force manual")
	_expect(not (team.get_character_by_id("liuyu").get("known_inner_force_ids", []) as Array).has(MANUAL_FORCE_ID), "inner-force manual does not pollute personal known")
	raw.erase("required_level")
	_free_context(context)


func _test_manual_knowledge_survives_team_state_export_import() -> void:
	var context := _make_context()
	var team = context.team
	team.acquire_skill_manual(SHARED_SKILL_ID)
	team.acquire_inner_force_manual(MANUAL_FORCE_ID)
	var saved: Dictionary = team.export_team_state()
	var loaded = TeamDataManagerScript.new()
	loaded.import_team_state(saved)
	_expect(loaded.has_skill_manual_knowledge(SHARED_SKILL_ID), "skill manual survives export/import")
	_expect(loaded.has_inner_force_manual_knowledge(MANUAL_FORCE_ID), "inner-force manual survives export/import")
	loaded.free()
	_free_context(context)


func _test_legacy_save_without_manual_fields_defaults_to_empty() -> void:
	var context := _make_context()
	var team = context.team
	team.acquire_skill_manual(SHARED_SKILL_ID)
	team.acquire_inner_force_manual(MANUAL_FORCE_ID)
	var legacy_state: Dictionary = team.export_team_state()
	legacy_state.erase("acquired_skill_manual_ids")
	legacy_state.erase("acquired_inner_force_manual_ids")
	team.import_team_state(legacy_state)
	_expect(team.get_acquired_skill_manual_ids().is_empty(), "legacy save defaults skill manuals to empty")
	_expect(team.get_acquired_inner_force_manual_ids().is_empty(), "legacy save defaults inner-force manuals to empty")
	_free_context(context)


func _test_legacy_skill_metadata_defaults_are_backward_compatible() -> void:
	var db = SkillDBScript.new()
	_expect(db.is_available_for_actor(SHARED_SKILL_ID, "liuyu"), "legacy available=all remains eligible")
	_expect(db.is_available_for_actor(EXCLUSIVE_SKILL_ID, "shumian"), "legacy include scope keeps eligible actor")
	_expect(not db.is_available_for_actor(EXCLUSIVE_SKILL_ID, "liuyu"), "legacy include scope keeps ineligible actor blocked")
	_expect(db.is_available_for_actor(LIMITED_GROUP_SKILL_ID, "lieshao"), "multi-actor include scope keeps listed actor eligible")
	_expect(not db.is_available_for_actor(LIMITED_GROUP_SKILL_ID, "shumian"), "multi-actor include scope keeps unlisted actor blocked")
	_expect(db.get_required_level(SHARED_SKILL_ID) == 1, "missing required_level defaults to one")
	db.free()


func _make_context() -> Dictionary:
	var team = TeamDataManagerScript.new()
	team._ready()
	var resolver = CharacterSkillScript.new()
	resolver.knowledge_provider = team
	return {"team": team, "resolver": resolver}


func _free_context(context: Dictionary) -> void:
	(context.resolver as Node).free()
	(context.team as Node).free()


func _set_personal_skills(team, actor_id: String, skill_ids: Array) -> void:
	team.known_skill_ids_by_actor[actor_id] = skill_ids.duplicate()


func _set_actor_level(team, actor_id: String, level: int) -> void:
	var actor: Dictionary = team.get_character_by_id(actor_id)
	actor["level"] = level
	team.all_characters[actor_id] = actor


func _set_skill_required_level(skill_id: String, level: int) -> void:
	var raw: Dictionary = SkillDBScript.SKILLS[skill_id]
	raw["required_level"] = level


func _clear_skill_required_level(skill_id: String) -> void:
	var raw: Dictionary = SkillDBScript.SKILLS[skill_id]
	raw.erase("required_level")


func _contains_skill(skills: Array, skill_id: String) -> bool:
	for skill_any in skills:
		if typeof(skill_any) == TYPE_DICTIONARY and String((skill_any as Dictionary).get("id", "")) == skill_id:
			return true
	return false


func _growth_has_skill(growth: Dictionary, actor_id: String, skill_id: String) -> bool:
	var events = growth.get("skills_learned", [])
	if typeof(events) != TYPE_ARRAY:
		return false
	for event_any in events:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_any
		if String(event.get("actor_id", "")) == actor_id and String(event.get("skill_id", "")) == skill_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
