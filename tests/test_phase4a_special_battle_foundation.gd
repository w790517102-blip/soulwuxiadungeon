extends SceneTree

const TeamDataManagerScript = preload("res://scripts/battlescripts/TeamDataManager.gd")
const StalactiteCaveScript = preload("res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_final_room/yuheng_stalactite_cave/yuheng_stalactite_cave.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_special_party_overlay_does_not_mutate_normal_party()
	_test_stalactite_context_declares_phase4a_boundaries()
	_test_special_reward_recipients_write_canonical_growth()
	_test_battle_resources_use_canonical_actor_state()
	_test_temporary_companion_insight_is_explicit()
	_test_save_slot_team_state_isolation()

	if _failures.is_empty():
		print("PASS: Phase 4A special battle foundation")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_special_party_overlay_does_not_mutate_normal_party() -> void:
	var team = _make_team()
	var normal_party_ids: Array = team.current_team_ids.duplicate()
	var overlay: Array = team.get_party_for_actor_ids(["liuyu", "shumian"])
	_expect(_actor_ids(overlay) == ["liuyu", "shumian"], "special overlay resolves LiuYu and canonical Shumian")
	_expect(team.current_team_ids == normal_party_ids, "special overlay does not mutate current_team_ids")
	_expect(not team.is_roster_unlocked("shumian"), "temporary special-battle Shumian remains roster locked")
	_expect(not team.get_reserve_actor_ids().has("shumian"), "temporary Shumian remains hidden from reserve")
	team.free()


func _test_stalactite_context_declares_phase4a_boundaries() -> void:
	var cave = StalactiteCaveScript.new()
	var config: Dictionary = cave.get_fish_boss_battle_config()
	_expect(String(config.get("enemy_id", "")) == "molin_yanjiang", "stalactite battle uses the canonical Molin Yanjiang EnemyDB id")
	var enemy_party: Array = config.get("enemy_party", [])
	_expect(enemy_party.size() == 1, "stalactite Phase 1 battle contains exactly one enemy")
	if enemy_party.size() == 1:
		_expect(String((enemy_party[0] as Dictionary).get("id", "")) == "molin_yanjiang", "stalactite enemy party is built from the canonical Molin Yanjiang card")
	_expect(config.get("party_actor_ids_override", []) == ["liuyu", "shumian"], "stalactite battle declares the exact special party overlay")
	_expect((config.get("player_party", []) as Array).size() == 2, "stalactite battle resolves both canonical special-party actors")
	_expect(config.get("reward_recipient_actor_ids", []) == ["liuyu", "shumian"], "stalactite battle declares exact reward recipients")
	_expect(config.get("post_battle_companion_insight_source_actor_ids", []) == ["shumian"], "stalactite battle declares the deferred temporary insight source")
	_expect(not config.has("guest_assist"), "Phase 4A config does not activate the Phase 4B guest hook")
	_expect(not config.has("phase_two"), "Phase 4A config does not implement the boss phase transition")
	cave.free()


func _test_special_reward_recipients_write_canonical_growth() -> void:
	var team = _make_team()
	var normal_party_ids: Array = team.current_team_ids.duplicate()
	var liuyu_before := int(team.get_character_by_id("liuyu").get("level", 1))
	var shumian_before := int(team.get_character_by_id("shumian").get("level", 1))
	var growth: Dictionary = team.add_exp_to_actor_ids_with_growth(
		50,
		["liuyu", "shumian"],
		[]
	)
	_expect(int(team.get_character_by_id("liuyu").get("level", 1)) == liuyu_before + 1, "LiuYu receives special-battle EXP")
	_expect(int(team.get_character_by_id("shumian").get("level", 1)) == shumian_before + 1, "roster-locked Shumian receives canonical EXP")
	_expect((growth.get("level_ups", []) as Array).size() == 2, "special reward produces both structured level-up events")
	_expect(team.current_team_ids == normal_party_ids, "reward cleanup does not change normal party composition")
	_expect(not team.is_roster_unlocked("shumian"), "reward eligibility does not imply roster unlock")
	team.free()


func _test_battle_resources_use_canonical_actor_state() -> void:
	var team = _make_team()
	var overlay: Array = team.get_party_for_actor_ids(["liuyu", "shumian"])
	var shumian: Dictionary = overlay[1]
	shumian["hp"] = 37
	shumian["mp"] = 12
	_expect(int(team.get_character_by_id("shumian").get("hp", 0)) == 37, "special battle HP remains on canonical Shumian")
	_expect(int(team.get_character_by_id("shumian").get("mp", 0)) == 12, "special battle MP remains on canonical Shumian")
	team.free()


func _test_temporary_companion_insight_is_explicit() -> void:
	var team = _make_team()
	team.get_party_for_actor_ids(["liuyu", "shumian"])
	team.refresh_liuyu_companion_insights()
	_expect(not team.knows_skill("liuyu", "skill_luobichengshi"), "pre-battle temporary party does not trigger Companion Insight")
	var growth: Dictionary = team.add_exp_to_actor_ids_with_growth(0, [], ["shumian"])
	var learned: Array = growth.get("skills_learned", [])
	_expect(team.knows_skill("liuyu", "skill_luobichengshi"), "explicit true-victory source can grant Companion Insight")
	_expect(not learned.is_empty(), "temporary Companion Insight emits a structured skills_learned event")
	if not learned.is_empty():
		_expect(String((learned[0] as Dictionary).get("source", "")) == "companion_insight", "temporary insight event keeps the formal source type")
	team.free()


func _test_save_slot_team_state_isolation() -> void:
	var save_a_team = _make_team()
	var save_a_actor: Dictionary = save_a_team.get_character_by_id("shumian")
	save_a_actor["level"] = 22
	save_a_actor["exp"] = 31
	var save_a: Dictionary = save_a_team.export_team_state()

	var save_b_team = _make_team()
	var save_b: Dictionary = save_b_team.export_team_state()

	var loaded = _make_team()
	loaded.import_team_state(save_a)
	_expect(int(loaded.get_character_by_id("shumian").get("level", 0)) == 22, "slot A restores its Shumian progression")
	loaded.import_team_state(save_b)
	_expect(int(loaded.get_character_by_id("shumian").get("level", 0)) == 6, "loading slot B does not retain slot A Shumian progression")
	loaded.import_team_state({})
	_expect(int(loaded.get_character_by_id("shumian").get("level", 0)) == 6, "empty/new-game team payload resets to the initial canonical card")

	loaded.free()
	save_b_team.free()
	save_a_team.free()


func _actor_ids(party: Array) -> Array:
	var out: Array = []
	for actor_any in party:
		if typeof(actor_any) == TYPE_DICTIONARY:
			out.append(String((actor_any as Dictionary).get("id", "")))
	return out


func _make_team():
	var team = TeamDataManagerScript.new()
	team._ready()
	return team


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
