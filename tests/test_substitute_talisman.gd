extends SceneTree
## 替身符: the first stage-card skill. Controller-level checks (no animation waits) plus
## the Card Stage row layout. Run: --headless --path . --script tests/test_substitute_talisman.gd

var SkillDBScript: Script
var CharacterSkillScript: Script
const SKILL_ID := "skill_substitute_talisman"

var _failures: Array[String] = []
var _assertions: int = 0
var _completed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _same(first: Variant, second: Variant) -> bool:
	return typeof(first) == typeof(second) and first == second


func _run() -> void:
	# Scripts that reference the project autoloads are loaded only once those exist.
	SkillDBScript = load("res://scripts/db/SkillDB.gd")
	CharacterSkillScript = load("res://scripts/battlescripts/CharacterSkill.gd")
	_check_skill_data()
	await _check_controller_flow()
	await _check_row_layout()
	await _check_other_presentations()
	_completed = true
	_expect(true, "all sections ran")
	if _failures.is_empty():
		print("PASS: ", _assertions, " assertions; substitute talisman")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _new_battle(mode: int) -> Node:
	var state: Node = root.get_node("GlobalState")
	state.remove_meta("pending_battle_context")
	var battle: Node = (load("res://scenes/battle_scene.tscn") as PackedScene).instantiate()
	battle.presentation_mode = mode
	root.add_child(battle)
	await process_frame
	await process_frame
	return battle


func _party() -> Array:
	return [
		{"id": "liuyu", "name": "劉語塵", "hp": 100, "max_hp": 100, "mp": 50, "max_mp": 50, "speed": 9, "atk": 20, "def": 5},
		{"id": "shumian", "name": "書眠", "hp": 80, "max_hp": 80, "mp": 40, "max_mp": 40, "speed": 14, "atk": 10, "def": 4},
	]


func _enemy(id: String = "foe_a", atk: int = 30) -> Dictionary:
	return {"id": id, "name": "語魅", "hp": 60, "max_hp": 60, "mp": 0, "speed": 7, "atk": atk, "def": 3, "is_enemy": true, "battle_uid": id + "#0"}


func _check_skill_data() -> void:
	var skill_db = SkillDBScript.new()
	var skill: Dictionary = skill_db.get_skill(SKILL_ID)
	_expect(not skill.is_empty() and skill.name == "替身符", "the skill exists in the skill database")
	_expect(skill.weapon_type == "筆" and int(skill.mp_cost) == 20 and int(skill.required_level) == 1, "a pen skill, 20 MP, learned at level 1")
	_expect(skill.available.actor_ids == ["shumian"], "only Shumian can use it")
	_expect(skill.has("stage_entity") and skill.stage_entity.entity_type == "substitute_talisman", "it is data-driven: a stage_entity block")
	var config: Dictionary = skill.stage_entity
	_expect(config.targetable and config.damageable and not config.healable and int(config.guard_charges) == 1, "targetable, damageable, not healable, one charge")
	_expect(String(config.advance_policy) == "round_end" and int(config.advance_amount) == 1 and bool(config.expire_at_edge), "advance policy is data, not code")
	var learned = CharacterSkillScript.new()
	var ids: Array = learned.get_effective_skill_ids_for_actor("shumian", {"id": "shumian", "level": 1, "weapon_aptitudes": ["筆"]})
	_expect(ids.has(SKILL_ID), "Shumian knows it at level 1")
	var liu_ids: Array = learned.get_effective_skill_ids_for_actor("liuyu", {"id": "liuyu", "level": 99, "weapon_aptitudes": ["筆", "劍"]})
	_expect(not liu_ids.has(SKILL_ID), "no one else learns it, not even through shared insight")


func _check_controller_flow() -> void:
	var battle: Node = await _new_battle(2)
	var controller: Node = battle.get_node("BattleController")
	var ui: Node = battle.get_node("BattleUILayer/BattleUI")
	controller.battle_ui = null
	# No log panel: the controller must not wait for a player to click through messages.
	controller.action_log_ui = null
	var skill: Dictionary = SkillDBScript.new().get_skill(SKILL_ID)
	var party: Array = _party()
	var enemy: Dictionary = _enemy()
	controller.player_party = party
	controller.enemy_party = [enemy]
	var shumian: Dictionary = party[1]
	var registry = controller.stage_entities
	# --- not enough MP: nothing happens ---
	shumian["mp"] = 19
	await controller.execute_action(shumian, skill, shumian)
	_expect(registry.is_empty() and int(shumian.mp) == 19 and not bool(shumian.get("acted_this_turn", false)), "with 19 MP the skill cannot be cast: no MP spent, no card, no action used")
	# --- cast ---
	shumian["mp"] = 40
	await controller.execute_action(shumian, skill, shumian)
	_expect(int(shumian.mp) == 20, "casting spends exactly 20 MP")
	_expect(bool(shumian.get("acted_this_turn", false)), "casting uses the action")
	var entities: Array = registry.get_stage_entities()
	_expect(entities.size() == 1 and entities[0].entity_type == "substitute_talisman", "a Substitute Talisman is in the Stage Entity Registry")
	var talisman = entities[0]
	_expect(talisman.owner_id == "shumian" and talisman.faction == "player" and talisman.guard_charges == 1, "owned by Shumian, player faction, one charge")
	_expect(talisman.targetable and talisman.damageable and not talisman.healable, "targetable, damageable, not healable")
	_expect(talisman.row == "party" and talisman.row_edge_distance == 0 and talisman.advance_policy == "round_end" and talisman.expire_at_edge, "starts at the left end of the party row")
	_expect(talisman.heal(50).healed == 0 and talisman.guard_charges == 1, "it cannot be healed")
	_expect(party[0].hp == 100 and shumian.hp == 80, "casting costs nobody any HP")
	var no_target: bool = not skill.has("target_side") or String(skill.target_scope) == "self"
	_expect(no_target and skill.has("stage_entity"), "the skill needs no target (the UI skips target selection)")
	# --- enemy AI is drawn to it ---
	var basic: Dictionary = {"id": "basic_attack", "name": "普通攻擊", "power": 1.0, "target_scope": "enemy_single"}
	_expect(controller._priority_stage_entity_for(enemy, basic) == talisman, "a single-target attack is drawn to the talisman")
	_expect(controller._priority_stage_entity_for(enemy, {"id": "x", "target_scope": "enemy_single", "effects": [{"type": "damage", "power": 2.0}]}) == talisman, "a single-target damage skill is drawn to it")
	_expect(controller._priority_stage_entity_for(enemy, {"id": "x", "target_scope": "enemy_all", "effects": [{"type": "damage"}]}) == null, "an area attack is not redirected")
	_expect(controller._priority_stage_entity_for(enemy, {"id": "x", "target_scope": "enemy_single", "effects": [{"type": "stat_debuff"}]}) == null, "a non-damaging skill is not redirected")
	_expect(controller._priority_stage_entity_for(enemy, {"id": "x", "target_scope": "enemy_single", "effects": [{"type": "damage"}], "ignore_stage_entity_priority": true}) == null, "a skill that ignores stage entity priority bypasses it")
	_expect(controller._priority_stage_entity_for(party[0], basic) == null, "our own attacks are not drawn to our talisman")
	var ai = controller.enemy_ai
	_expect(ai != null and ai.target_score(enemy, talisman, 1.0) > 1000.0 and ai.target_score(enemy, party[0], 1.0) == 1.0, "the AI hook scores the talisman far above any character")
	# --- one hit of any size breaks it, nothing carries over ---
	enemy["atk"] = 9999
	var hp_before: Array = [party[0].hp, party[1].hp]
	# The blow has to land first: with a crippled accuracy it can miss, and then the charm stays.
	var normal_accuracy = enemy.get("accuracy", 100)
	enemy["accuracy"] = -100000
	var missed_once := false
	for attempt: int in range(300):
		seed(attempt)
		await controller._perform_enemy_attack_on_entity(enemy, basic, talisman)
		if not registry.is_empty():
			missed_once = true
			break
		# It happened to land: stand a fresh one up and try the next seed.
		shumian["mp"] = 40
		await controller.execute_action(shumian, skill, shumian)
		talisman = registry.get_stage_entities()[0]
	_expect(missed_once and talisman.guard_charges == 1, "a blow drawn to the charm can miss, and then the charm survives intact")
	_expect([party[0].hp, party[1].hp] == hp_before, "a missed blow hurts nobody")
	enemy["accuracy"] = 100000
	for attempt: int in range(300):
		seed(attempt)
		await controller._perform_enemy_attack_on_entity(enemy, basic, talisman)
		if registry.is_empty():
			break
	_expect(registry.is_empty() and talisman.guard_charges == 0, "one landed hit breaks it and it leaves the registry")
	_expect([party[0].hp, party[1].hp] == hp_before, "a huge blow does not spill onto the characters")
	enemy["accuracy"] = normal_accuracy
	enemy["atk"] = 30
	# --- an area blow: every target (characters AND the charm) rolls its own hit ---------------
	await controller.execute_action(shumian, skill, shumian)
	var second = registry.get_stage_entities()[0]
	_expect(registry.get_stage_entities().size() == 1, "a new talisman can be cast again")
	enemy["crit_rate"] = 0.0
	var aoe: Dictionary = {"id": "aoe_test", "name": "橫掃", "target_scope": "enemy_all", "effects": [{"type": "damage", "power": 1.0}], "power": 1.0}
	var start_hp: Array = [party[0].hp, party[1].hp]
	# Reference run WITHOUT the charm, from a fixed random seed.
	registry.unregister_stage_entity(second)
	seed(2024)
	await controller._perform_enemy_aoe_action(enemy, aoe, {})
	var without_charm: Array = [party[0].hp, party[1].hp]
	# Same seed WITH the charm standing: the characters' outcomes must be identical, i.e. the
	# charm neither absorbs the area attack nor changes anyone else's roll.
	party[0].hp = start_hp[0]
	party[1].hp = start_hp[1]
	var third_charm = load("res://scripts/battlescripts/StageEntityFactory.gd").create(skill.stage_entity, "shumian")
	registry.register_stage_entity(third_charm)
	seed(2024)
	await controller._perform_enemy_aoe_action(enemy, aoe, {})
	_expect([party[0].hp, party[1].hp] == without_charm, "a standing charm does not change what an area attack does to the characters")
	_expect((third_charm.guard_charges == 0) == registry.is_empty(), "the charm either took its own hit and broke, or was missed and stays")
	if not registry.is_empty():
		registry.unregister_stage_entity(third_charm)
	party[0].hp = start_hp[0]
	party[1].hp = start_hp[1]
	# --- reaching the right end expires it ---
	shumian["mp"] = 40
	await controller.execute_action(shumian, skill, shumian)
	var third = registry.get_stage_entities()[0]
	controller._advance_stage_entities()
	controller._advance_stage_entities()
	_expect(third.row_edge_distance == 2 and not registry.is_empty(), "it is still valid at the right end (2 positions in, 2 characters)")
	controller._advance_stage_entities()
	_expect(registry.is_empty(), "one more step and it leaves the stage")
	_expect(int(shumian.mp) == 20 or int(shumian.mp) < 20, "an unused talisman refunds nothing")
	var seen: Array[String] = []
	var spy = load("res://scripts/battlescripts/StageEntity.gd").from_dict({"entity_type": "x"})
	_expect(spy.advance_policy == "none", "entities do not advance unless they ask to")
	battle.queue_free()
	await process_frame


func _check_row_layout() -> void:
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	var ui: Node = fixture.ui
	var stage: Node3D = ui.stage
	var controller: Node = fixture.controller
	var registry = controller.stage_entities
	var context: Dictionary = fixture.build_preview_context()
	var base: Dictionary = context.player_party[0]
	var allies: Array = []
	for index: int in range(2):
		var member: Dictionary = base.duplicate(true)
		member["id"] = ["liuyu", "shumian"][index]
		member["name"] = ["劉語塵", "書眠"][index]
		member["speed"] = 9 + index * 5
		member["battle_uid"] = "%s#%d" % [member.id, index]
		allies.append(member)
	var foe: Dictionary = context.enemy_party[0]
	foe["is_enemy"] = true
	foe["battle_uid"] = "foe#0"
	controller.player_party = allies
	controller.enemy_party = [foe]
	var manager: Node = controller.turn_manager
	manager.player_party = allies
	manager.enemy_party = [foe]
	manager.turn_queue = (allies + [foe]).duplicate()
	manager.turn_queue.sort_custom(Callable(manager, "_compare_speed"))
	manager.current_index = 0
	# --- no guest: the talisman is the left-most of the party row ---
	ui.set_teams(allies, [foe])
	controller.battle_ui = null
	var skill: Dictionary = SkillDBScript.new().get_skill(SKILL_ID)
	allies[1]["mp"] = 40
	await controller._execute_stage_entity_skill(allies[1], skill)
	controller.battle_ui = ui
	for frame: int in range(6):
		await process_frame
	var talisman = registry.get_stage_entities()[0]
	var key: String = stage._row_key(talisman)
	var ranks: Dictionary = stage.ranks_from_order(stage.order_keys())
	var party_ranks: Array = []
	for member: Dictionary in allies:
		party_ranks.append(ranks[stage.actor_key(member)])
	_expect(int(ranks[key]) == 2 and party_ranks.max() == 1, "no guest: the talisman is outermost, left of every character")
	_expect(stage.entity_cards.has(talisman.entity_id), "a card for the talisman is on the stage")
	var card: Node3D = stage.entity_cards[talisman.entity_id]
	var ally_cards: Array = []
	for member: Dictionary in allies:
		ally_cards.append(stage.card_for(member))
	_expect(is_equal_approx(card.card_size.x / ally_cards[0].card_size.x, 0.85) and absf(card.card_size.y / ally_cards[0].card_size.y - 0.85) < 0.001, "the talisman card is 85% of a character card")
	_expect(card.home_position.x < ally_cards[0].home_position.x and card.home_position.x < ally_cards[1].home_position.x, "it stands to the left of the characters")
	var nearest_ally_z: float = maxf(ally_cards[0].home_position.z, ally_cards[1].home_position.z)
	_expect(card.home_position.z > nearest_ally_z + 0.5, "the sub card stands clearly nearer the camera than the characters")
	_expect(card.badge_label.text == "×1", "it shows ×1, not an HP bar")
	# The cast waits for the card to land and the characters to make room.
	await stage.settle_entity_arrival()
	_expect(not stage._arrival_in_progress(), "settle_entity_arrival returns only when nothing is still moving")
	_expect(is_equal_approx(card.home_rotation.x, 0.0) and card.global_transform.basis.y.dot(Vector3.UP) > 0.999, "it stands upright in the 3D scene")
	var party_order_before: Array = []
	for member: Dictionary in allies:
		party_order_before.append(ranks[stage.actor_key(member)])
	_expect(ranks[stage.actor_key(allies[1])] < ranks[stage.actor_key(allies[0])] or ranks[stage.actor_key(allies[1])] > ranks[stage.actor_key(allies[0])], "the characters keep their relative order around it")
	# --- advancing one step moves it between the characters ---
	talisman.row_edge_distance = 1
	ranks = stage.ranks_from_order(stage.order_keys())
	_expect(int(ranks[key]) == 1, "after one advance it stands one place in (between the characters)")
	talisman.row_edge_distance = 2
	ranks = stage.ranks_from_order(stage.order_keys())
	_expect(int(ranks[key]) == 0, "at the right end it is next to the exchange zone")
	talisman.row_edge_distance = 0
	# --- picking ---
	for frame: int in range(60):
		await process_frame
	var centre: Vector2 = stage.camera.unproject_position(stage.actor_root.to_global(card.home_position))
	_expect(_same(stage.pick_target(centre, [talisman]), talisman), "the talisman can be picked")
	# --- cleanup: registry, renderer and picking all drop it ---
	var result: Dictionary = talisman.take_damage(5)
	controller._finish_entity_damage(talisman, result, {})
	for frame: int in range(40):
		await process_frame
	_expect(registry.is_empty() and stage.entity_cards.is_empty() and stage._entity_signature() == "", "after it breaks the registry and the renderer are clean")
	_expect(_same(stage.pick_target(centre, [talisman]), {}), "and it can no longer be picked")
	# --- with a guest: the guest keeps the outer end; the talisman is on its right ---
	var guest: Dictionary = {"id": "zuoyin_stalactite_guest", "name": "左飲", "hp": 50, "max_hp": 50, "is_guest": true}
	ui.set_teams(allies, [foe])
	ui.set_guest_presentation(guest)
	await controller._execute_stage_entity_skill(allies[1], skill)
	for frame: int in range(6):
		await process_frame
	var with_guest = registry.get_stage_entities()[0]
	var guest_key: String = stage.actor_key(guest)
	_expect(stage.cards.has(guest_key), "the guest card is on the stage")
	ranks = stage.ranks_from_order(stage.order_keys())
	_expect(int(ranks[stage._row_key(with_guest)]) == 2 and int(ranks[guest_key]) == 3, "with a guest: [guest][talisman][characters...]")
	_expect(stage.cards[guest_key].home_position.x < stage.entity_cards[with_guest.entity_id].home_position.x, "the guest stays left of the talisman")
	ui.set_guest_presentation({})
	fixture.queue_free()
	await process_frame


func _check_other_presentations() -> void:
	for mode: int in [1, 0]:
		var battle: Node = await _new_battle(mode)
		var controller: Node = battle.get_node("BattleController")
		var ui: Node = battle.get_node("BattleUILayer/BattleUI")
		_expect(not ui.has_method("play_stage_entity_cast") or mode == 2, "mode %d has no card-stage cast presentation" % mode)
		var party: Array = _party()
		controller.player_party = party
		controller.enemy_party = [_enemy()]
		party[1]["mp"] = 40
		await controller.execute_action(party[1], SkillDBScript.new().get_skill(SKILL_ID), party[1])
		_expect(controller.stage_entities.get_stage_entities().size() == 1 and int(party[1].mp) == 20, "mode %d: the skill still resolves (logic only)" % mode)
		battle.queue_free()
		await process_frame
