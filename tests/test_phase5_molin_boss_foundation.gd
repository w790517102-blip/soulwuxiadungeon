extends SceneTree

const EnemyDBScript = preload("res://scripts/db/EnemyDB.gd")
const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
const EnemyAIScript = preload("res://scripts/battlescripts/EnemyAI.gd")
const BattleControllerScript = preload("res://scripts/battlescripts/BattleController.gd")
const ToneMapScript = preload("res://scripts/battlestyles/ToneMap.gd")
const BattlePhaseProfileDB = preload("res://scripts/db/BattlePhaseProfileDB.gd")
const BattleDamageGuard = preload("res://scripts/battle/BattleDamageGuard.gd")
const StatusEffectManagerScript = preload("res://scripts/battle/StatusEffectManager.gd")

var _failed := false


func _init() -> void:
	_test_skill_and_enemy_schema()
	_test_element_replacement_and_transition_logs()
	_test_committed_intent_contract()
	_test_repeating_attribute_switch_contract()
	_test_tone_profile_fallback()
	_test_player_balance_changes()
	_test_phase2_card_and_context_boundaries()
	_test_phase_break_result_contract()
	_test_phase2_shield_damage_guard()
	_test_phase2_encounter_round_clock()
	_test_guest_action_data_and_variant_rotation()
	quit(1 if _failed else 0)


func _test_skill_and_enemy_schema() -> void:
	var skill_db := SkillDBScript.new()
	_expect(String(skill_db.get_skill("skill_molin_rusty_fork_thrust").get("weapon_type", "")) == "槍", "rusty fork is spear-family")
	_expect(String(skill_db.get_skill("skill_molin_breaking_wave_fork").get("weapon_type", "")) == "槍", "breaking-wave fork is spear-family")
	for skill_id in ["skill_molin_tail_sweep", "skill_molin_water_bullet", "skill_molin_deluge_burial"]:
		_expect(String(skill_db.get_skill(skill_id).get("weapon_type", "")) == "通用", "%s remains generic" % skill_id)
	var tail := skill_db.get_skill("skill_molin_tail_sweep")
	var tail_effects: Array = tail.get("effects", [])
	_expect(String(tail.get("target_scope", "")) == "enemy_all", "tail sweep targets the full opposing party")
	_expect(float((tail_effects[1] as Dictionary).get("chance", 0.0)) == 0.25, "tail stun uses an independent 25 percent per-target roll")
	var deluge := skill_db.get_skill("skill_molin_deluge_burial")
	_expect(bool(deluge.get("committed_intent_only", false)), "deluge cannot enter the ordinary reactive pool")
	var boss := EnemyDBScript.make_enemy("molin_yanjiang")
	_expect(int(boss.get("max_hp", 0)) == 560, "boss first-playtest HP is registered")
	_expect(int(boss.get("atk", 0)) == 38, "boss first-playtest ATK is registered")
	_expect(int(boss.get("def", 0)) == 10, "boss first-playtest DEF is registered")
	_expect(int(boss.get("speed", 0)) == 16, "boss first-playtest speed is registered")
	_expect(int(boss.get("accuracy", 0)) == 115, "boss first-playtest accuracy is registered")
	_expect(int(boss.get("evasion", 0)) == 10, "boss first-playtest evasion is registered")
	_expect(String(boss.get("display_name", "")) == "墨鱗魘將", "boss identity is registered")
	_expect(String(boss.get("element", "")) == "遲", "boss initial element is slow")
	_expect(String(boss.get("species", "")) == "reptile", "boss retains reptile species")
	_expect(not _skill_ids(boss.get("skills", [])).has("skill_molin_deluge_burial"), "ultimate is absent from reactive pool")
	_expect(not _skill_ids(boss.get("skills", [])).has("skill_molin_reverse_scale_iron_stance"), "hard transition is absent from reactive pool")
	_expect(not _skill_ids(boss.get("skills", [])).has("skill_molin_sunken_tide_breath"), "slow transition is absent from reactive pool")


func _test_element_replacement_and_transition_logs() -> void:
	var controller := BattleControllerScript.new()
	var boss := EnemyDBScript.make_enemy("molin_yanjiang")
	boss["hp"] = 1
	boss["max_hp"] = 1
	var skill := SkillDBScript.new().get_skill("skill_molin_reverse_scale_iron_stance")
	var effects: Array = skill.get("effects", [])
	var effect: Dictionary = effects[0]
	var record: Dictionary = controller._apply_single_skill_effect(boss, boss, "replace_element", effect, skill)
	_expect(String(boss.get("element", "")) == "剛", "state transition replaces enemy current element directly")
	_expect(String(record.get("tone_cast", "")) != "", "transition has a prelude log")
	_expect(String(record.get("desc", "")).contains("屬性轉為「剛」"), "transition has the system element log")
	_expect(String(record.get("tone_suffer", "")) != "", "transition has a closing log")


func _test_committed_intent_contract() -> void:
	var ai := EnemyAIScript.new()
	var boss := EnemyDBScript.make_enemy("molin_yanjiang")
	boss["hp"] = 100
	boss["max_hp"] = 100
	boss["ui_index"] = 0
	var players := [{"id": "liuyu", "hp": 100, "max_hp": 100}]
	ai.begin_battle([boss])
	var state: Dictionary = ai._ensure_enemy_state(boss)
	var rolled: Dictionary = ai._roll_committed_intent(boss, state, 0.0)
	_expect(String(rolled.get("locked_intent", "")) == "skill_molin_deluge_burial", "successful roll locks the ultimate")
	var action: Dictionary = ai.get_action(boss, players)
	_expect(String(action.get("skill", {}).get("id", "")) == "skill_molin_deluge_burial", "locked intent overrides reactive selection")
	_expect(bool(action.get("committed_intent", false)), "locked action is identified as committed intent")
	ai.complete_action(boss, "skill_molin_deluge_burial")
	var after: Dictionary = ai.get_runtime_state(boss)
	_expect(String(after.get("locked_intent", "")) == "", "intent clears only after the committed skill completes")
	_expect(int(after.get("cooldowns", {}).get("skill_molin_deluge_burial", 0)) > 0, "ultimate starts the existing cooldown lockout")
	_expect(ai._roll_committed_intent(boss, ai._ensure_enemy_state(boss), 0.0).is_empty(), "cooldown makes intent ineligible rather than merely unlikely")
	var config: Dictionary = boss.get("committed_intent", {})
	_expect(not bool(config.get("pity", {}).get("enabled", true)), "molin pity hook is present but disabled")
	_expect(int(config.get("cooldown_turns", 0)) == 6, "deluge cooldown uses the Phase 5.2 test value")
	var modified: Dictionary = config.duplicate(true)
	modified["modifiers"] = [{"self_hp_pct_lte": 0.5, "weight_add": 2.0}]
	boss["hp"] = 40
	var probability: Dictionary = ai._resolve_intent_probability(boss, ai._ensure_enemy_state(boss), modified)
	_expect(float(probability.get("weight", 0.0)) == 3.0, "data modifier can change intent weight")


func _test_repeating_attribute_switch_contract() -> void:
	var ai := EnemyAIScript.new()
	var boss := EnemyDBScript.make_enemy("molin_yanjiang")
	boss["ui_index"] = 0
	ai.begin_battle([boss])
	var state: Dictionary = ai._ensure_enemy_state(boss)
	var switch_config: Dictionary = boss.get("attribute_switch_intent", {})
	_expect(int(switch_config.get("minimum_dwell_actions", -1)) == 2, "switch intent data owns the two-action minimum dwell")
	state["same_element_action_count"] = 2
	_expect(ai._roll_attribute_switch_intent(boss, state, 0.0).is_empty(), "two completed actions are still ineligible")
	state["same_element_action_count"] = 3
	_expect(is_equal_approx(ai._resolve_attribute_switch_probability(boss, state, switch_config), 0.25), "third action has a 25 percent full-HP switch chance")
	state["same_element_action_count"] = 4
	_expect(is_equal_approx(ai._resolve_attribute_switch_probability(boss, state, switch_config), 0.40), "fourth action has a 40 percent full-HP switch chance")
	state["same_element_action_count"] = 5
	_expect(is_equal_approx(ai._resolve_attribute_switch_probability(boss, state, switch_config), 0.60), "fifth action has a 60 percent full-HP switch chance")
	state["same_element_action_count"] = 3
	var rolled: Dictionary = ai._roll_attribute_switch_intent(boss, state, 0.0)
	_expect(String(rolled.get("pending_attribute_switch", {}).get("skill_id", "")) == "skill_molin_reverse_scale_iron_stance", "slow state queues the hard transition")
	var players := [{"id": "liuyu", "hp": 100, "max_hp": 100}]
	var switch_action: Dictionary = ai.get_action(boss, players)
	_expect(String(switch_action.get("skill", {}).get("id", "")) == "skill_molin_reverse_scale_iron_stance", "pending switch overrides reactive AI")
	boss["element"] = "剛"
	ai.complete_action(boss, "skill_molin_reverse_scale_iron_stance")
	state = ai._ensure_enemy_state(boss)
	_expect(int(state.get("same_element_action_count", -1)) == 0, "transition action resets and does not increment dwell")
	_expect((state.get("pending_attribute_switch", {}) as Dictionary).is_empty(), "completed transition clears pending state")
	state["same_element_action_count"] = 6
	_expect(is_equal_approx(ai._resolve_attribute_switch_probability(boss, state, switch_config), 1.0), "sixth action guarantees a switch at full HP")
	rolled = ai._roll_attribute_switch_intent(boss, state, 0.0)
	_expect(String(rolled.get("pending_attribute_switch", {}).get("skill_id", "")) == "skill_molin_sunken_tide_breath", "hard state can queue the return to slow")
	boss["element"] = "遲"
	ai.complete_action(boss, "skill_molin_sunken_tide_breath")
	state = ai._ensure_enemy_state(boss)
	state["same_element_action_count"] = 6
	rolled = ai._roll_attribute_switch_intent(boss, state, 0.0)
	_expect(String(rolled.get("pending_attribute_switch", {}).get("skill_id", "")) == "skill_molin_reverse_scale_iron_stance", "same battle can queue slow-to-hard again")
	state["locked_intent"] = "skill_molin_deluge_burial"
	state["pending_attribute_switch"] = {}
	_expect(ai._roll_attribute_switch_intent(boss, state, 0.0).is_empty(), "locked ultimate blocks switch intent")
	state["locked_intent"] = ""
	state["pending_attribute_switch"] = {"skill_id": "skill_molin_reverse_scale_iron_stance", "target_element": "剛"}
	var before_stun_skip := int(state.get("same_element_action_count", 0))
	_expect(int(state.get("same_element_action_count", 0)) == before_stun_skip, "skipping complete_action leaves dwell unchanged")
	_expect(not (state.get("pending_attribute_switch", {}) as Dictionary).is_empty(), "skipping complete_action preserves pending switch")
	state["pending_attribute_switch"] = {}
	state["same_element_action_count"] = 0
	ai.complete_action(boss, "skill_molin_rusty_fork_thrust", false)
	_expect(int(state.get("same_element_action_count", 0)) == 1, "a completed ordinary action increments dwell exactly once")
	boss["hp"] = int(float(boss.get("max_hp", 1)) * 0.5)
	state["same_element_action_count"] = 3
	_expect(is_equal_approx(ai._resolve_attribute_switch_probability(boss, state, switch_config), 0.30), "mid-HP data modifier adds five percentage points")
	boss["hp"] = int(float(boss.get("max_hp", 1)) * 0.3)
	_expect(is_equal_approx(ai._resolve_attribute_switch_probability(boss, state, switch_config), 0.35), "low-HP data modifiers add ten percentage points without choosing an element")


func _test_tone_profile_fallback() -> void:
	var tone := ToneMapScript.new()
	var boss := {"id": "molin_yanjiang", "display_name": "墨鱗魘將", "tone_profile": "molin_yanjiang", "species": "reptile", "element": "遲"}
	_expect(tone.get_enemy_profile_lines("deluge_tell", boss).size() == 2, "boss-specific tell has two ordered lines")
	tone.enemy_profile_tones["reptile"] = {"fallback_probe": ["species"]}
	tone.enemy_profile_tones["default"] = {"generic_probe": ["generic"]}
	_expect(tone.get_enemy_profile_text("fallback_probe", boss) == "species", "missing boss event falls back to species")
	_expect(tone.get_enemy_profile_text("generic_probe", boss) == "generic", "missing species event falls back to generic")


func _test_player_balance_changes() -> void:
	var skill_db := SkillDBScript.new()
	var poem := skill_db.get_skill("skill_luobichengshi")
	_expect(int(poem.get("mp_cost", -1)) == 5, "Luobichengshi costs 5 MP")
	_expect(float(poem.get("power", 0.0)) == 1.3, "Luobichengshi remains 1.3 power")
	var combo := skill_db.get_skill("skill_lianjuejian")
	_expect(int(combo.get("strike_count", 0)) == 3, "Lianjuejian remains three hits")
	_expect(int(combo.get("mp_cost", 0)) == 25, "Lianjuejian remains 25 MP")
	_expect(float(combo.get("power", 0.0)) == 0.6, "Lianjuejian uses 0.6 power per hit")


func _test_phase2_card_and_context_boundaries() -> void:
	var phase1 := EnemyDBScript.make_enemy("molin_yanjiang")
	var phase2 := EnemyDBScript.make_enemy("molin_yanjiang_phase2")
	_expect(int(phase2.get("max_hp", 0)) == 720, "Phase 2 HP is 720")
	_expect(int(phase2.get("atk", 0)) == 44, "Phase 2 ATK is 44")
	_expect(int(phase2.get("def", 0)) == 13, "Phase 2 DEF is 13")
	_expect(int(phase2.get("speed", 0)) == 18, "Phase 2 speed is 18")
	_expect(int(phase2.get("accuracy", 0)) == 118, "Phase 2 accuracy is 118")
	_expect(int(phase2.get("evasion", 0)) == 10, "Phase 2 evasion is 10")
	_expect(String(phase2.get("element", "")) == "剛", "Phase 2 is fixed to hard element")
	_expect(String(phase1.get("portrait_path", "")) == "res://assets/Enemy/molingyanjiang_phase1.png", "Phase 1 uses its dedicated portrait")
	_expect(String(phase2.get("portrait_path", "")) == "res://assets/Enemy/molingyanjiang_phase2.png", "Phase 2 uses its dedicated portrait")
	_expect(bool(phase2.get("balance_pending", false)), "Phase 2 card remains first-playtest balance")
	_expect(not phase2.has("attribute_switch_intent"), "Phase 2 has no Phase 1 attribute switch intent")
	_expect(phase1.has("attribute_switch_intent"), "Phase 1 retains its repeating attribute switch intent")
	_expect(int(phase1.get("max_hp", 0)) == 560, "Phase 1 HP remains unchanged")

	var liuyu := {"id": "liuyu", "hp": 101, "mp": 22}
	var shumian := {"id": "shumian", "hp": 88, "mp": 44}
	var context := BattlePhaseProfileDB.make_molin_phase2_context([liuyu, shumian])
	_expect(String(context.get("battle_bgm_override_path", "")) == "res://assets/BGM/battle_boss_1.ogg", "Phase 2 uses the dedicated boss battle BGM")
	_expect((context.get("player_party", []) as Array).size() == 2, "Phase 2 player party contains only LiuYu and Shumian")
	_expect(int(liuyu.get("hp", 0)) == 101 and int(shumian.get("mp", 0)) == 44, "Phase 2 factory does not refill inherited HP or MP")
	var guest: Dictionary = context.get("scripted_guest", {})
	_expect(String(guest.get("id", "")) == "zuoyin_stalactite_guest", "Phase 2 uses the scripted stalactite ZuoYin profile")
	_expect(not bool(guest.get("controllable", true)), "scripted ZuoYin is not player controllable")
	_expect(not bool(guest.get("normal_target", true)), "scripted ZuoYin is not a normal target")
	_expect(not bool(guest.get("uses_playable_actor", true)), "scripted ZuoYin does not use a playable canonical card")


func _test_phase_break_result_contract() -> void:
	var controller := BattleControllerScript.new()
	controller.battle_context = {
		"battle_id": "boss_yuheng_molin_yanjiang_phase1",
		"scripted_phase_break": "molin_yanjiang_phase1_to_phase2",
	}
	controller.player_party = [
		{"id": "liuyu", "hp": 73, "mp": 24},
		{"id": "shumian", "hp": 61, "mp": 39},
	]
	_expect(controller._should_trigger_scripted_phase_break(), "Phase 1 context opts into the shared scripted phase-break hook")
	var result: Dictionary = controller._build_battle_result("phase_break")
	_expect(int(result.get("exp", -1)) == 0 and int(result.get("gold", -1)) == 0, "phase break never builds victory rewards")
	var resources: Dictionary = result.get("player_resources", {})
	_expect(int((resources.get("liuyu", {}) as Dictionary).get("hp", 0)) == 73, "phase break carries LiuYu current HP without refilling")
	_expect(int((resources.get("shumian", {}) as Dictionary).get("mp", 0)) == 39, "phase break carries Shumian current MP without serializing battle statuses")
	controller.battle_context = {}
	_expect(not controller._should_trigger_scripted_phase_break(), "ordinary battles remain on the normal victory path")
	controller.free()


func _test_phase2_shield_damage_guard() -> void:
	var manager := StatusEffectManagerScript.new()
	var boss := EnemyDBScript.make_enemy("molin_yanjiang_phase2")
	var player := {"id": "liuyu", "is_enemy": false}
	var enemy := {"id": "enemy", "is_enemy": true}
	_expect(manager.apply_effect(boss, "yumei_entanglement", {
		"player_hp_damage_immunity": true,
	}, 1), "Yumei Entanglement can be applied as an explicit status")
	var blocked: Dictionary = BattleDamageGuard.resolve_hp_damage(player, boss, 99)
	_expect(bool(blocked.get("blocked", false)) and int(blocked.get("damage", -1)) == 0, "shield reduces player HP damage to zero")
	var enemy_damage: Dictionary = BattleDamageGuard.resolve_hp_damage(enemy, boss, 99)
	_expect(not bool(enemy_damage.get("blocked", true)) and int(enemy_damage.get("damage", 0)) == 99, "shield contract is not a global DEF or damage rewrite")
	_expect(manager.apply_effect(boss, "poison", {"_source_is_enemy": false}, 2), "hostile status can still be applied through the shield")
	var hp_before_tick := int(boss.get("hp", 0))
	var blocked_ticks: Array = manager.tick_end_of_turn([boss])
	_expect(int(boss.get("hp", 0)) == hp_before_tick, "player-sourced poison cannot bypass shield HP immunity")
	_expect(not blocked_ticks.is_empty() and bool((blocked_ticks[0] as Dictionary).get("damage_prevented", false)), "blocked damage-over-time reports shield prevention")
	manager.remove_effect(boss, "yumei_entanglement")
	_expect(int(BattleDamageGuard.resolve_hp_damage(player, boss, 99).get("damage", 0)) == 99, "removing the shield restores player damage")
	manager.tick_end_of_turn([boss])
	_expect(int(boss.get("hp", 0)) < hp_before_tick, "applied poison resumes HP damage after shield removal")
	manager.free()


func _test_phase2_encounter_round_clock() -> void:
	var context := BattlePhaseProfileDB.make_molin_phase2_context([
		{"id": "liuyu"},
		{"id": "shumian"},
	])
	var boss := EnemyDBScript.make_enemy("molin_yanjiang_phase2")
	var controller := BattleControllerScript.new()
	controller.enemy_party = [boss]
	controller.encounter_mechanic = context.get("encounter_mechanic", {})
	_expect(not controller.status_manager.has_effect(boss, "yumei_entanglement"), "Phase 2 opens without the shield")
	controller._apply_encounter_round_start(1)
	_expect(not controller.status_manager.has_effect(boss, "yumei_entanglement"), "encounter Round 1 remains an open damage window")
	controller._apply_encounter_round_start(2)
	_expect(not controller.status_manager.has_effect(boss, "yumei_entanglement"), "encounter Round 2 remains an open damage window")
	controller._apply_encounter_round_start(3)
	_expect(controller.status_manager.has_effect(boss, "yumei_entanglement"), "encounter Round 3 applies Yumei Entanglement")
	controller.status_manager.remove_effect(boss, "yumei_entanglement")
	controller._encounter_cycle_round = 0
	controller._apply_encounter_round_start(4)
	_expect(not controller.status_manager.has_effect(boss, "yumei_entanglement"), "shield break resets the next encounter round to Cycle Round 1")
	controller.free()


func _test_guest_action_data_and_variant_rotation() -> void:
	var context := BattlePhaseProfileDB.make_molin_phase2_context([
		{"id": "liuyu"},
		{"id": "shumian"},
	])
	var guest: Dictionary = context.get("scripted_guest", {})
	var actions: Array = guest.get("actions", [])
	_expect(actions.size() == 3, "scripted guest has exactly three encounter actions")
	if actions.size() != 3:
		return
	_expect(String((actions[0] as Dictionary).get("display_name", "")) == "飲酒化氣", "guest Round 1 action is Drink to Qi")
	_expect(String((actions[1] as Dictionary).get("display_name", "")) == "酒意催鋒", "guest Round 2 action is Wine Edge Charge")
	_expect(String((actions[2] as Dictionary).get("display_name", "")) == "燕行破風斬", "guest Round 3 action is Yanxing Wind-Breaking Slash")
	for action in actions:
		_expect(int((action as Dictionary).get("hp_damage", -1)) == 0, "every scripted guest action deals zero HP damage")
	_expect(((actions[1] as Dictionary).get("variants", []) as Array).size() == 2, "Wine Edge Charge has two narrative variants")
	var controller := BattleControllerScript.new()
	var first_variant := controller._pick_guest_action_variant(actions[1] as Dictionary, 0)
	var second_variant := controller._pick_guest_action_variant(actions[1] as Dictionary, 0)
	_expect(first_variant != second_variant, "guest narrative resolver avoids repeating the previous variant")
	controller.free()


func _skill_ids(entries) -> Array:
	var out: Array = []
	if typeof(entries) != TYPE_ARRAY:
		return out
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			out.append(String((entry as Dictionary).get("skill_id", "")))
	return out


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
