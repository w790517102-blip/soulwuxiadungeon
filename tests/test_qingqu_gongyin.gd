extends SceneTree

# 《清渠共印》（白書眠專屬內功）、《澄心落筆》（武術）與相合《清渠澄心落筆》：
#   資料與專屬資格、有效武術解析、遲屬性防禦與語魅傷害倍率（同源只算一次）、清渠護印狀態的回合與換功、補符獎勵的習得與讀檔補發。
# 執行：godot --headless --path . --script tests/test_qingqu_gongyin.gd

# These scripts reach the autoloads, so they are loaded at runtime (a preload fails to compile under --script).
var InnerForceDBScript: GDScript

var _failures := 0
var _force_db: Node
var _skill_db: Node
var _executor: Node
var _status: Node
var _state: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	InnerForceDBScript = load("res://scripts/battlescripts/InnerForceDB.gd")
	_force_db = InnerForceDBScript.new()
	_skill_db = load("res://scripts/db/SkillDB.gd").new()
	_executor = load("res://scripts/battlescripts/SkillExecutor.gd").new()
	_status = load("res://scripts/battle/StatusEffectManager.gd").new()
	_state = load("res://scripts/yuheng/YinYueManor/YuhengPrologueState.gd")

	_test_data_and_eligibility()
	_test_exclusivity()
	_test_synergy_resolution()
	_test_ward_damage()
	_test_ward_status_lifetime()
	_test_rewards()
	_test_liuyu_resonance()
	_test_sewer_loot()

	if _failures == 0:
		print("PASS test_qingqu_gongyin")
		quit(0)
	else:
		print("FAIL test_qingqu_gongyin failures=%d" % _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)


func _team() -> Node:
	return root.get_node("TeamData")


func _reset_world() -> void:
	root.get_node("GlobalState").flags.clear()
	root.get_node("GlobalState").triggered_flags.clear()
	_team().reset_to_initial_team_state()
	root.get_node("SideQuestManager").reset_all()


# ------------------------------------------------------------
func _test_data_and_eligibility() -> void:
	var force: Dictionary = _force_db.get_force("qingqu_gongyin")
	_expect(not force.is_empty(), "the inner force exists")
	_expect(String(force.get("element", "")) == "遲", "its element is 遲")
	_expect(_force_db.is_available_to_actor("qingqu_gongyin", "shumian"), "available to Shumian")
	_expect(not _force_db.is_available_to_actor("qingqu_gongyin", "liuyu"), "not available to 劉語塵")
	_expect(not _force_db.is_available_to_actor("qingqu_gongyin", "lieshao"), "not available to anyone else")
	_expect(_force_db.get_force("qingqu_gongyin").get("exclusive_skill_ids", []).has("skill_chengxin_luobi"), "the synergy makes 澄心落筆 its exclusive skill")

	var skill: Dictionary = _skill_db.get_skill("skill_chengxin_luobi")
	_expect(not skill.is_empty(), "the skill exists")
	_expect(String(skill.get("weapon_type", "")) == "筆", "it is a 筆 skill")
	_expect(int(skill.get("mp_cost", 0)) == 75, "costs 75 MP")
	_expect(String(skill.get("target_scope", "")) == "single" and String(skill.get("target_side", "")) == "ally", "single ally target")
	var effects: Array = skill.get("effects", [])
	_expect(effects.size() == 1 and String((effects[0] as Dictionary).get("type", "")) == "heal_hp" and int((effects[0] as Dictionary).get("amount", 0)) == 100, "heals 100 HP")
	_expect((skill.get("cleanse_statuses", []) as Array) == ["confuse"], "cleanses 混亂 only (沉默 is not a status of this battle system)")
	_expect(String(skill.get("description", "")).find("沉默") == -1, "the description no longer promises 沉默")
	_expect(_skill_db.is_available_for_actor("skill_chengxin_luobi", "shumian") and _skill_db.is_available_for_actor("skill_chengxin_luobi", "liuyu"), "the skill is not 書眠-only")
	_expect(not _skill_db.is_exclusive_skill("skill_chengxin_luobi"), "not an exclusive skill")
	_expect(not _skill_db.allows_companion_insight("skill_chengxin_luobi"), "not companion-insight enabled")


func _test_exclusivity() -> void:
	_reset_world()
	var team := _team()
	_expect(not team.learn_inner_force("liuyu", "qingqu_gongyin"), "劉語塵 cannot learn the inner force")
	_expect(not team.learn_inner_force("lieshao", "qingqu_gongyin"), "nobody else can learn it either")
	_expect(team.learn_skill("shumian", "skill_chengxin_luobi"), "Shumian learns the skill personally")
	_expect(not team.learn_skill("shumian", "skill_chengxin_luobi"), "learning twice does nothing")
	team.refresh_liuyu_companion_insights()
	_expect(not team.knows_skill("liuyu", "skill_chengxin_luobi"), "劉語塵 does not pick it up through 共鳴")
	_expect(not team.get_acquired_skill_manual_ids().has("skill_chengxin_luobi"), "it is not registered as a global manual")
	var skill_provider: Node = load("res://scripts/battlescripts/CharacterSkill.gd").new()
	_expect(skill_provider.actor_has_effective_skill("shumian", "skill_chengxin_luobi"), "Shumian can use it")
	_expect(not skill_provider.actor_has_effective_skill("liuyu", "skill_chengxin_luobi"), "劉語塵 cannot use Shumian's knowledge")
	_expect(not skill_provider.actor_has_effective_skill("lieshao", "skill_chengxin_luobi"), "teammates do not share it")
	# 儲存、讀檔
	var exported: Dictionary = team.export_team_state()
	team.import_team_state(exported)
	_expect(team.knows_skill("shumian", "skill_chengxin_luobi"), "the skill survives save and load")
	skill_provider.free()


func _test_synergy_resolution() -> void:
	var provider: Node = load("res://scripts/battlescripts/CharacterSkill.gd").new()
	var base: Dictionary = _skill_db.get_skill("skill_chengxin_luobi")
	var qingqu: Dictionary = _force_db.get_force("qingqu_gongyin")
	var mengying: Dictionary = _force_db.get_force("meng_ying_xinfa")

	var paired: Dictionary = provider.resolve_runtime_skill(base, qingqu, {"id": "shumian"})
	_expect(String(paired.get("name", "")) == "清渠澄心落筆", "with 清渠共印 the effective skill is 清渠澄心落筆: %s" % String(paired.get("name", "")))
	_expect(provider.resolve_skill_name(paired, qingqu) == "清渠澄心落筆", "no inner-force prefix is added a second time")
	_expect(paired.get("effects") == base.get("effects") and paired.get("cleanse_statuses") == base.get("cleanse_statuses"), "the base 澄心落筆 effects are all kept")
	# 從已解析的版本再解析一次：仍然從 SkillDB 重建，不會疊兩次
	var again: Dictionary = provider.resolve_runtime_skill(paired, qingqu, {"id": "shumian"})
	_expect(again == paired, "resolving an already resolved clone gives the same skill")

	var plain: Dictionary = provider.resolve_runtime_skill(base, mengying, {"id": "shumian"})
	_expect(String(plain.get("name", "")) == "澄心落筆", "with another inner force it is the ordinary 澄心落筆")
	var rule: Dictionary = load("res://scripts/battlescripts/CharacterSkill.gd").get_pairing_rule("skill_chengxin_luobi", "qingqu_gongyin")
	var team_status: Dictionary = (rule.get("effects", {}) as Dictionary).get("team_status", {})
	_expect(String(team_status.get("effect_id", "")) == "qingqu_ward" and int(team_status.get("turns", 0)) == 3, "the pairing is a 3-turn 清渠護印 for the team")
	_expect(load("res://scripts/battlescripts/CharacterSkill.gd").get_pairing_rule("skill_chengxin_luobi", "meng_ying_xinfa").is_empty(), "no pairing with other inner forces")
	_expect(load("res://scripts/battlescripts/CharacterSkill.gd").get_pairing_rule("skill_luobichengshi", "qingqu_gongyin").is_empty(), "no pairing for other 筆 skills")
	# 其他既有搭配沒被影響
	_expect(String(load("res://scripts/battlescripts/CharacterSkill.gd").get_pairing_rule("skill_lianjuejian", "liuchen_jue").get("display_name", "")) == "流塵連決劍", "existing pairings are untouched")
	provider.free()


# ------------------------------------------------------------
func _target(with_force: bool, with_status: bool) -> Dictionary:
	var target := {"id": "t", "name": "目標", "hp": 100000, "max_hp": 100000, "def": 40, "element": "遲", "str": 0, "luck": 0, "evasion": 0}
	if with_force:
		target["inner_force"] = _force_db.get_force("qingqu_gongyin")
	if with_status:
		_status.apply_effect(target, "qingqu_ward", InnerForceDBScript.ward_payload_from_force("qingqu_gongyin"), 3)
	return target


func _attacker(element: String, family: String) -> Dictionary:
	return {"id": "a", "name": "敵人", "atk": 100, "element": element, "family": family, "luck": 0, "accuracy": 100, "is_enemy": true}


## One strike with every random draw pinned (same seed for every scenario), so only the rule under test differs.
func _hit(attacker: Dictionary, target: Dictionary) -> int:
	for seed_value in range(1, 400):
		seed(seed_value)
		var probe: Dictionary = _executor.execute(_attacker("剛", ""), _target(false, false), {"name": "x", "power": 1.0, "weapon_type": "通用"}, {})
		if bool(probe.get("hit", false)) and not bool(probe.get("crit", false)):
			seed(seed_value)
			var result: Dictionary = _executor.execute(attacker, target, {"name": "x", "power": 1.0, "weapon_type": "通用"}, {})
			_expect(bool(result.get("hit", false)) and not bool(result.get("crit", false)), "the pinned roll is a plain hit")
			return int(result.get("damage", -1))
	return -1


func _test_ward_damage() -> void:
	var base_dmg: int = _hit(_attacker("遲", ""), _target(false, false))
	_expect(base_dmg == 60, "baseline: ATK 100 - DEF 40 = 60 (got %d)" % base_dmg)

	# 遲屬性防禦 +15（內功被動 / 狀態 / 兩者同時 = 一樣只有 +15）
	_expect(_hit(_attacker("遲", ""), _target(true, false)) == 45, "passive: 遲 attack, DEF +15 -> 45")
	_expect(_hit(_attacker("遲", ""), _target(false, true)) == 45, "status only (a teammate): DEF +15 -> 45")
	_expect(_hit(_attacker("遲", ""), _target(true, true)) == 45, "passive + status: still +15, not +30 -> 45")
	# 非遲屬性攻擊：沒有防禦加成
	_expect(_hit(_attacker("剛", ""), _target(true, true)) == 60, "non-遲 attacker, not yumei: no special protection -> 60")

	# 語魅：最終傷害 ×0.9（在 ATK／DEF／屬性防禦之後）；整數化沿用既有（取整數）
	_expect(_hit(_attacker("遲", "yumei"), _target(true, false)) == 40, "yumei 遲 attack: (100-55) x 0.9 = 40.5 -> 40")
	_expect(_hit(_attacker("遲", "yumei"), _target(true, true)) == 40, "passive + status on a yumei hit: x0.9 once, not x0.81 -> 40")
	_expect(_hit(_attacker("剛", "yumei"), _target(true, true)) == 54, "yumei with a non-遲 attack still gets x0.9: 60 x 0.9 = 54")
	_expect(_hit(_attacker("剛", "yumei"), _target(false, true)) == 54, "a teammate with only the status gets x0.9 too")
	_expect(_hit(_attacker("剛", "animal"), _target(true, true)) == 60, "other families are not reduced (the boss is family animal)")

	# 其他防禦來源照舊疊加：def_up +10 與護印同時存在，兩者相加
	var with_def_up := _target(true, false)
	_status.apply_effect(with_def_up, "def_up", {"def_delta": 10}, 3)
	_expect(_hit(_attacker("遲", ""), with_def_up) == 35, "def_up (+10, a different source) still stacks with the ward: 100 - (40+10+15) = 35")

	# 換功：護印狀態留在身上；沒有狀態、也沒有被動就回到原本
	var switched := _target(true, true)
	switched["inner_force"] = _force_db.get_force("meng_ying_xinfa")
	_expect(_hit(_attacker("遲", ""), switched) == 45, "after switching inner force the status keeps protecting")
	var plain := _target(true, false)
	plain["inner_force"] = _force_db.get_force("meng_ying_xinfa")
	_expect(_hit(_attacker("遲", ""), plain) == 60, "passive gone once the inner force is switched (no status)")
	# 原本的石破心法減傷等不受影響
	var shipo := {"id": "s", "hp": 1000, "def": 40, "element": "剛", "inner_force": _force_db.get_force("shipo_xinfa")}
	_expect(InnerForceDBScript.resolve_ward_protection(shipo).def_vs_element.is_empty(), "other inner forces carry no ward")


func _test_ward_status_lifetime() -> void:
	var member := _target(false, false)
	_expect(_status.apply_effect(member, "qingqu_ward", InnerForceDBScript.ward_payload_from_force("qingqu_gongyin"), 3), "the status can be applied")
	_expect(int(member["status_effects"]["qingqu_ward"]["turns_left"]) == 3, "three turns")
	_status.tick_end_of_turn([member])
	_status.tick_end_of_turn([member])
	_expect(_status.has_effect(member, "qingqu_ward") and int(member["status_effects"]["qingqu_ward"]["turns_left"]) == 1, "counts down with the ordinary round counter")
	_status.tick_end_of_turn([member])
	_expect(not _status.has_effect(member, "qingqu_ward"), "gone when the turns run out")
	_expect(InnerForceDBScript.resolve_ward_protection(member).def_vs_element.is_empty(), "no protection after expiry")
	# 重新施放：刷新成滿回合，不是第二份
	var again := _target(false, true)
	_status.tick_end_of_turn([again])
	_status.apply_effect(again, "qingqu_ward", InnerForceDBScript.ward_payload_from_force("qingqu_gongyin"), 3)
	_expect(int(again["status_effects"]["qingqu_ward"]["turns_left"]) == 3 and (again["status_effects"] as Dictionary).size() == 1, "re-casting refreshes, it does not stack a second copy")
	_expect(not _status.apply_effect(_target(false, false), "qingqu_ward", {}, 3), "a status without ward numbers is refused")


# ------------------------------------------------------------
func _known_forces() -> Array:
	var ids: Array = []
	for force in _team().get_known_inner_forces("shumian"):
		ids.append(String((force as Dictionary).get("id", "")))
	return ids


func _test_rewards() -> void:
	_reset_world()
	var team := _team()
	var before_level := int(team.all_characters["shumian"]["level"])
	var before_exp := int(team.all_characters["shumian"]["exp"])
	var before_skills: Array = team.get_known_skill_ids("shumian")

	var first: Dictionary = _state.grant_qudeng_rewards()
	_expect(bool(first["skill_learned_now"]) and bool(first["inner_force_learned_now"]), "first grant learns both")
	_expect(team.knows_skill("shumian", "skill_chengxin_luobi") and _known_forces().has("qingqu_gongyin"), "both are in Shumian's permanent data")
	_expect(not bool(_state.flag(_state.F_QUDENG_REWARD_ERROR)), "no error flag")
	for skill_id in before_skills:
		_expect(team.knows_skill("shumian", String(skill_id)), "existing skill kept: " + String(skill_id))
	var second: Dictionary = _state.grant_qudeng_rewards()
	_expect(not bool(second["skill_learned_now"]) and not bool(second["inner_force_learned_now"]), "granting twice does not learn twice")
	_expect(int(team.get_known_skill_ids("shumian").count("skill_chengxin_luobi")) == 1, "one copy of the skill")
	_expect(int(team.all_characters["shumian"]["level"]) == before_level and int(team.all_characters["shumian"]["exp"]) == before_exp, "level and exp untouched")
	_expect(not team.knows_skill("liuyu", "skill_chengxin_luobi") and not team.get_acquired_skill_manual_ids().has("skill_chengxin_luobi"), "nothing leaks to 劉語塵 or the global manuals")
	# 儲存、讀檔
	team.import_team_state(team.export_team_state())
	_expect(team.knows_skill("shumian", "skill_chengxin_luobi") and _known_forces().has("qingqu_gongyin"), "both survive save and load")
	# 離隊再入隊：個人資料不受影響
	_state.join_shumian()
	team.current_team_ids = ["liuyu"]
	_state.join_shumian()
	_expect(team.knows_skill("shumian", "skill_chengxin_luobi") and _known_forces().has("qingqu_gongyin"), "leaving and rejoining keeps them")

	# 舊存檔補發：支線完成旗標在、武學沒有 → 補發；沒完成 → 不補
	_reset_world()
	_expect(not _state.repair_qudeng_rewards(), "quest not completed: nothing is granted")
	_expect(not team.knows_skill("shumian", "skill_chengxin_luobi"), "still not learned")
	root.get_node("GlobalState").set_flag(_state.F_QD_DONE, true)
	root.get_node("GlobalState").set_flag(_state.F_LEGACY_SKILL_CHENGXIN, true)
	root.get_node("GlobalState").set_flag(_state.F_LEGACY_SKILL_QINGQU, true)
	var level_before := int(team.all_characters["shumian"]["level"])
	_expect(_state.repair_qudeng_rewards(), "completed quest with old flags only: the rewards are granted")
	_expect(team.knows_skill("shumian", "skill_chengxin_luobi") and _known_forces().has("qingqu_gongyin"), "now really learned")
	_expect(int(team.all_characters["shumian"]["level"]) == level_before, "level untouched by the repair")
	_expect(not _state.repair_qudeng_rewards(), "repairing again does nothing")


# ------------------------------------------------------------
# 劉語塵共鳴普通《澄心落筆》（只在「最後一道符」劇情裡習得）
# ------------------------------------------------------------
func _liuyu_forces() -> Array:
	var ids: Array = []
	for force in _team().get_known_inner_forces("liuyu"):
		ids.append(String((force as Dictionary).get("id", "")))
	return ids


func _test_liuyu_resonance() -> void:
	_reset_world()
	var team := _team()
	team.all_characters["liuyu"]["level"] = 1
	team.all_characters["liuyu"]["exp"] = 0

	# 劇情之前：書眠先學會了也不會讓他提早共鳴
	_state.grant_qudeng_rewards(false)
	team.refresh_liuyu_companion_insights()
	team.add_exp_to_actor_ids_with_growth(10, ["liuyu", "shumian"])
	_expect(team.knows_skill("shumian", "skill_chengxin_luobi"), "fixture: Shumian knows it")
	_expect(not team.knows_skill("liuyu", "skill_chengxin_luobi"), "before the scene 劉語塵 has not resonated (no automatic 共鳴)")
	_expect(not bool(_state.flag(_state.F_QUDENG_LIUYU_RESONANCE_DONE)), "no resonance flag yet")

	# 完成劇情：書眠兩項 + 劉語塵一項
	_reset_world()
	team.all_characters["liuyu"]["level"] = 1
	var level_before := int(team.all_characters["shumian"]["level"])
	var exp_before := int(team.all_characters["shumian"]["exp"])
	var result: Dictionary = _state.grant_qudeng_rewards(true)
	_expect(bool(result["skill_learned_now"]) and bool(result["liuyu_learned_now"]) and bool(result["inner_force_learned_now"]), "the scene teaches all three")
	_expect(team.knows_skill("liuyu", "skill_chengxin_luobi"), "劉語塵 (Lv1) knows the ordinary 澄心落筆")
	_expect(team.knows_skill("shumian", "skill_chengxin_luobi") and _known_forces().has("qingqu_gongyin"), "書眠 knows the skill and the inner force")
	_expect(not _liuyu_forces().has("qingqu_gongyin"), "劉語塵 does not get 清渠共印")
	_expect(not team.learn_inner_force("liuyu", "qingqu_gongyin"), "and cannot learn it")
	_expect(not team.get_acquired_skill_manual_ids().has("skill_chengxin_luobi"), "no global manual")
	_expect(bool(_state.flag(_state.F_QUDENG_LIUYU_RESONANCE_DONE)) and not bool(_state.flag(_state.F_QUDENG_REWARD_ERROR)), "the event is recorded, no error")
	_expect(int(team.all_characters["shumian"]["level"]) == level_before and int(team.all_characters["shumian"]["exp"]) == exp_before, "書眠's level and exp untouched")
	_expect(int(team.all_characters["liuyu"]["level"]) == 1, "劉語塵's level untouched")

	# 其他隊友仍依既有資格（列霄沒有筆系資質，用不了）；普通版只有基礎效果
	var provider: Node = load("res://scripts/battlescripts/CharacterSkill.gd").new()
	_expect(provider.actor_has_effective_skill("liuyu", "skill_chengxin_luobi"), "劉語塵 can use it")
	_expect(not provider.actor_has_effective_skill("lieshao", "skill_chengxin_luobi"), "a teammate without the 筆 aptitude still cannot (the existing eligibility holds)")
	var base: Dictionary = _skill_db.get_skill("skill_chengxin_luobi")
	var liu_force: Dictionary = _force_db.get_force("qingfeng_jue")
	var as_liu: Dictionary = provider.resolve_runtime_skill(base, liu_force, {"id": "liuyu"})
	_expect(String(as_liu.get("name", "")) == "澄心落筆" and load("res://scripts/battlescripts/CharacterSkill.gd").get_pairing_rule("skill_chengxin_luobi", String(liu_force.get("id", ""))).is_empty(), "劉語塵 casts the plain version: no team ward")
	provider.free()

	# 重複、存讀檔、離隊
	var again: Dictionary = _state.grant_qudeng_rewards(true)
	_expect(not bool(again["liuyu_learned_now"]) and not bool(again["skill_learned_now"]) and not bool(again["inner_force_learned_now"]), "granting again learns nothing twice")
	_expect(int(team.get_known_skill_ids("liuyu").count("skill_chengxin_luobi")) == 1, "one copy in 劉語塵's list")
	team.import_team_state(team.export_team_state())
	_expect(team.knows_skill("liuyu", "skill_chengxin_luobi") and team.knows_skill("shumian", "skill_chengxin_luobi") and _known_forces().has("qingqu_gongyin"), "all three survive save and load")

	# 舊存檔補發：只補書眠，不替劉語塵補共鳴（他沒看過這場劇情）
	_reset_world()
	root.get_node("GlobalState").set_flag(_state.F_QD_DONE, true)
	_expect(_state.repair_qudeng_rewards(), "the old-save repair still grants 書眠's two")
	_expect(not team.knows_skill("liuyu", "skill_chengxin_luobi"), "but never 劉語塵's resonance")


# ------------------------------------------------------------
# 舊水道搜刮道具真正進背包 + 舊存檔補發
# ------------------------------------------------------------
func _inv() -> Node:
	return root.get_node("InventorySync")


func _test_sewer_loot() -> void:
	_reset_world()
	var inv := _inv()
	var gs := root.get_node("GlobalState")

	# 五種道具的 Item ID 與數量，和兩支腳本的 LOOT_TABLE 一致（沒有走樣）
	var tables := {}
	for path in ["res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_true/yuheng_sewer_true.gd", "res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_true/yuheng_sewer_true_room/yuheng_sewer_true_room.gd"]:
		var script: GDScript = load(path)
		tables.merge(script.get_script_constant_map()["LOOT_TABLE"])
	_expect(tables.size() == 5 and (_state.SEWER_LOOT as Dictionary).size() == 5, "five loot points in total")
	for loot_id in tables.keys():
		var entry: Dictionary = tables[loot_id]
		var mirror: Dictionary = _state.SEWER_LOOT.get(loot_id, {})
		_expect(String(mirror.get("item_id", "")) == String(entry["item_id"]) and int(mirror.get("amount", 0)) == int(entry["amount"]), "repair table matches LOOT_TABLE for " + String(loot_id))

	# 真的進背包：數量增加、存檔讀檔保留
	for loot_id in tables.keys():
		var entry: Dictionary = tables[loot_id]
		var item_id := String(entry["item_id"])
		var before: int = inv.get_item_count(item_id)
		_expect(_state.grant_item(item_id, int(entry["amount"])), "granting works: " + item_id)
		_expect(inv.get_item_count(item_id) == before + int(entry["amount"]), "inventory +%d for %s" % [int(entry["amount"]), item_id])
	var snapshot: Dictionary = inv.export_inventory_state()
	var herb_count: int = inv.get_item_count("herb")
	inv.add_item_stack("herb", 5, false)
	inv.import_inventory_state(snapshot)
	_expect(inv.get_item_count("herb") == herb_count, "inventory survives save and load")

	# 失敗不假裝成功：未知 ID、數量 0 都不改背包
	var count_before: int = (inv.get_items() as Array).size()
	_expect(not _state.grant_item("no_such_item_xyz", 1), "an unknown Item ID is refused")
	_expect(not _state.grant_item("herb", 0), "an amount of 0 is refused")
	_expect((inv.get_items() as Array).size() == count_before and inv.get_item_count("no_such_item_xyz") == 0, "nothing changed after refused grants")

	# 舊存檔補發：領取旗標 + 假記號 → 補發一次，清掉那一個假記號
	gs.set_flag("shumian_qd_loot_loot_qi_box_taken", true)
	gs.set_flag("received_item_elixir_qi", true)
	# 領取旗標在、沒有假記號（新流程拿過的）→ 不補
	gs.set_flag("shumian_qd_loot_loot_haste_scroll_taken", true)
	# 假記號在、領取旗標不在 → 不補
	gs.set_flag("received_item_mat_herb_pouch", true)
	# 與這批無關的其他旗標不能被清掉
	gs.set_flag("received_item_something_else", true)
	var qi_before: int = inv.get_item_count("elixir_qi")
	var haste_before: int = inv.get_item_count("haste_talisman")
	var pouch_before: int = inv.get_item_count("mat_herb_pouch")
	_expect(_state.repair_sewer_loot_items() == 1, "exactly one fake pickup is repaired")
	_expect(inv.get_item_count("elixir_qi") == qi_before + 1, "the missing 回氣丹 is delivered")
	_expect(inv.get_item_count("haste_talisman") == haste_before and inv.get_item_count("mat_herb_pouch") == pouch_before, "nothing else is delivered")
	_expect(not bool(_state.flag("received_item_elixir_qi")), "the repaired fake marker is cleared")
	_expect(bool(_state.flag("received_item_something_else")) and bool(_state.flag("received_item_mat_herb_pouch")), "other markers are left alone")
	_expect(_state.repair_sewer_loot_items() == 0 and inv.get_item_count("elixir_qi") == qi_before + 1, "repairing again does not deliver twice")
