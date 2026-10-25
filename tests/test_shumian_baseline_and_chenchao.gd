extends SceneTree
## 白書眠的招式配置以鐘乳石洞 BOSS 戰那張卡（SHUMIAN_INITIAL_SKILL_IDS）為準：舊存檔留下的測試版招式清單會在讀檔與正式入隊時清掉，
## 但之後真正學到的招式（acquired_skill_manual_ids）不受影響，也不是「只能有這幾招」。
## 沉潮訣：力量 +6、體能 +4、最大 MP +10%（不再是固定 +6）。
## Run: --headless --path . --script tests/test_shumian_baseline_and_chenchao.gd

var TeamDataManagerScript: Script
var InnerForceDBScript: Script

const LEGACY_DUMMY := ["skill_bisaoyanxia", "skill_luobichengshi", "skill_zhengxinquan", "skill_buff_speed_test", "skill_qihui_talisman", "skill_jufu_talisman", "skill_linfu_ranfeng", "skill_linfu_guyuan", "skill_linfu_jiying", "skill_linfu_zhuangli", "skill_linfu_humai", "skill_debuff_speed_test", "skill_force_element_test", "skill_smoky_ink_blind", "skill_hawkeye_focus", "skill_mobishuxin", "skill_inkveil_swiftroute"]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Loaded at run time (not preload) so the autoloads TeamDataManager refers to (GlobalState, ...) already exist.
	TeamDataManagerScript = load("res://scripts/battlescripts/TeamDataManager.gd")
	InnerForceDBScript = load("res://scripts/battlescripts/InnerForceDB.gd")
	_test_legacy_list_is_cleaned_on_load()
	_test_later_learned_skill_survives()
	_test_chenchao_numbers()
	if _failures.is_empty():
		print("PASS: shumian baseline and chenchao")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _make_team():
	var team = TeamDataManagerScript.new()
	team._ready()
	return team


func _test_legacy_list_is_cleaned_on_load() -> void:
	var team = _make_team()
	var state: Dictionary = team.export_team_state()
	state["known_skill_ids_by_actor"]["shumian"] = LEGACY_DUMMY.duplicate()
	team.import_team_state(state)
	team.unlock_roster("shumian")
	team.ensure_shumian_story_join_level()
	var known: Array = team.get_known_skill_ids("shumian")
	for skill_id: String in team.SHUMIAN_INITIAL_SKILL_IDS:
		_expect(known.has(skill_id), "initial skill %s is known" % skill_id)
	for skill_id: String in team.SHUMIAN_LEGACY_TEST_SKILL_IDS:
		_expect(not known.has(skill_id), "legacy test skill %s is gone" % skill_id)
	var story: Array = team.get_story_battle_party_for_actor_ids(["shumian"])
	var story_ids: Array = story[0].get("battle_skill_ids", [])
	for skill_id: String in known:
		_expect(story_ids.has(skill_id), "joined card matches the cave card: %s" % skill_id)


func _test_later_learned_skill_survives() -> void:
	var team = _make_team()
	team.unlock_roster("shumian")
	team.acquired_skill_manual_ids.append("skill_linfu_ranfeng")
	team.learn_skill("shumian", "skill_linfu_ranfeng", false)
	team.ensure_shumian_story_join_level()
	var state: Dictionary = team.export_team_state()
	state["acquired_skill_manual_ids"] = ["skill_linfu_ranfeng"]
	team.import_team_state(state)
	_expect(team.get_known_skill_ids("shumian").has("skill_linfu_ranfeng"), "a skill acquired for real is kept")


func _test_chenchao_numbers() -> void:
	var force_db = InnerForceDBScript.new()
	var force: Dictionary = force_db.get_force("chenchao_jue")
	_expect(int(force.get("str_flat_bonus", 0)) == 6, "沉潮訣 STR +6")
	_expect(int(force.get("con_flat_bonus", 0)) == 4, "沉潮訣 CON +4")
	_expect(not force.has("max_mp_flat_bonus"), "沉潮訣 no flat MP bonus any more")
	_expect(is_equal_approx(float(force.get("max_mp_pct_bonus", 0.0)), 0.10), "沉潮訣 max MP +10%")
	var effects: Dictionary = force_db.get_runtime_effects(force, {"int": 5})
	_expect(is_equal_approx(float(effects.get("max_mp_pct", 0.0)), 0.10), "runtime effects carry the MP percent")
	_expect(String(force_db.get_effect_description_line(force, {})).contains("最大 MP +10%"), "description says 最大 MP +10%")
	var team = _make_team()
	var actor: Dictionary = team.get_character_by_id("liuyu").duplicate(true)
	var base_mp := int(actor.get("max_mp", 0))
	team._apply_inner_force_runtime_stats(actor, {})
	var without_force := int(actor.get("max_mp", 0))
	actor = team.get_character_by_id("liuyu").duplicate(true)
	team._apply_inner_force_runtime_stats(actor, force)
	var expected := int(round(float(actor.get("base_max_mp", base_mp)) * (1.0 + float(int(actor.get("int", 0))) * 0.01 + 0.10)))
	_expect(int(actor.get("max_mp", 0)) == expected, "max MP uses the +10%% multiplier (%d vs %d)" % [int(actor.get("max_mp", 0)), expected])
	_expect(int(actor.get("max_mp", 0)) > without_force, "沉潮訣 raises max MP")
	_expect(int(actor.get("str", 0)) == int(actor.get("base_str", 5)) + 6, "applied STR is base + 6")
