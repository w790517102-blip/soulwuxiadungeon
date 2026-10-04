extends SceneTree
## 拔劍持鞘: 劉語塵's scabbard card in the ADB, the HOLDING_SHEATH stance and what it allows, 鞘劍連擊,
## the block, 收鞘於背. Real battle controller. Run:
## --headless --path . --script tests/test_sheath_stance.gd

const StageAdjacencyKey = preload("res://scripts/battlescripts/StageAdjacency.gd")

var SkillDBScript: Script
var _failures: Array[String] = []
var _assertions: int = 0
var battle: Node
var controller: Node
var manager: Node
var real_executor: Node
var rules


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _names(row: Array) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in row:
		parts.append(String(entry.get("name", "?")))
	parts.reverse()
	return "".join(parts)   # drawn left to right


func _skill(id: String) -> Dictionary:
	return rules.get_skill(id)


func _liuyu() -> Dictionary:
	return {"id": "liuyu", "name": "劉", "hp": 100000, "max_hp": 100000, "mp": 50, "max_mp": 50, "speed": 10, "atk": 20, "def": 5, "weapon_1": "劍", "weapon_2": ""}


func _enemy() -> Dictionary:
	return {"id": "foe", "name": "敵", "hp": 100000, "max_hp": 100000, "mp": 0, "speed": 7, "atk": 20, "def": 3, "is_enemy": true, "battle_uid": "foe#0", "accuracy": 100000, "crit_rate": 0.0}


## A fresh battle with `party` and one enemy; the round is under way.
func _setup(party: Array) -> void:
	if battle != null:
		battle.queue_free()
		await process_frame
	var state: Node = root.get_node("GlobalState")
	state.remove_meta("pending_battle_context")
	battle = (load("res://scenes/battle_scene.tscn") as PackedScene).instantiate()
	battle.presentation_mode = 2
	root.add_child(battle)
	await process_frame
	await process_frame
	controller = battle.get_node("BattleController")
	controller.battle_ui = null
	controller.action_log_ui = null
	real_executor = controller.skill_executor
	var enemy: Dictionary = _enemy()
	controller.player_party = party
	controller.enemy_party = [enemy]
	manager = controller.turn_manager
	manager.player_party = party
	manager.enemy_party = [enemy]
	manager.queue_entities.clear()
	manager.round_in_progress = true
	manager.round_roster = []
	for actor: Dictionary in party + [enemy]:
		manager.round_roster.append(manager._actor_key(actor))
	manager.acted_this_round = {}
	manager.turn_queue = (party + [enemy]).duplicate()
	manager.turn_queue.sort_custom(Callable(manager, "_compare_speed"))
	manager.current_index = 0


func _run() -> void:
	SkillDBScript = load("res://scripts/db/SkillDB.gd")
	rules = SkillDBScript.new()
	_check_data()
	await _check_cast_and_turn()
	await _check_legality()
	await _check_combo()
	await _check_block()
	await _check_stow()
	if battle != null:
		battle.queue_free()
	if _failures.is_empty():
		print("PASS: ", _assertions, " assertions; sheath stance")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check_data() -> void:
	for id: String in ["skill_bajian_chishao", "skill_shaojian_lianji", "skill_shouqiao_beibei"]:
		var skill: Dictionary = _skill(id)
		_expect(not skill.is_empty(), "%s exists" % id)
		_expect(skill.available.actor_ids == ["liuyu"] and not bool(skill.shareable) and int(skill.required_level) == 1, "%s: 劉語塵 only, learned at level 1, not shareable" % id)
		_expect(rules.is_available_for_actor(id, "liuyu") and not rules.is_available_for_actor(id, "shumian"), "%s is not available to anyone else" % id)
	_expect(_skill("skill_bajian_chishao").weapon_type == "劍" and _skill("skill_bajian_chishao").has("stage_entity"), "拔劍持鞘 is a sword skill that makes a card, not an attack")
	var config: Dictionary = _skill("skill_bajian_chishao").stage_entity
	_expect(config.entity_type == "sheath_card" and int(config.turn_speed) == 0 and bool(config.joins_turn_order), "the card has a turn (speed 0), not 'no turn'")


func _check_cast_and_turn() -> void:
	# A. one character: the card appears at the far left
	var liuyu: Dictionary = _liuyu()
	await _setup([liuyu])
	var cast: Dictionary = _skill("skill_bajian_chishao")
	await controller.execute_action(liuyu, cast, liuyu)
	var registry = controller.stage_entities
	var entities: Array = registry.get_stage_entities()
	_expect(entities.size() == 1 and entities[0].entity_type == "sheath_card", "A: a 持鞘 card is on the stage")
	_expect(String(liuyu.get("stance", "")) == "HOLDING_SHEATH", "A: 劉語塵 is in the HOLDING_SHEATH stance")
	var row: Array = manager.get_display_row(false)
	_expect(_names(row) == "持鞘劉", "A: the card is at the far left: " + _names(row))
	_expect(bool(liuyu.get("acted_this_turn", false)), "the skill ends 劉語塵's turn like any action")
	# once is enough
	var count_before: int = registry.get_stage_entities().size()
	await controller.execute_action(liuyu, cast, liuyu)
	_expect(registry.get_stage_entities().size() == count_before, "a second 拔劍持鞘 is refused while the card stands")
	_expect(not rules.is_stance_compatible(cast, liuyu), "...and the skill is not offered in the stance")
	# B. the card's own turn: no player action, goes to the far left, ends
	var proxy: Dictionary = manager.find_queue_actor(String(entities[0].entity_id))
	_expect(not proxy.is_empty() and int(proxy.speed) == 0, "B: it has its own entry in the turn order, speed 0")
	manager.current_index = manager.turn_queue.find(proxy)
	manager.active_actor = proxy
	await controller._run_stage_entity_turn(proxy)
	_expect(int(proxy.get("left_stamp", 0)) > 0, "B: on its turn it sends itself to the far left (automatically)")
	_expect(not manager.is_waiting_for_player, "B: nobody is asked for a command on its turn")


func _check_legality() -> void:
	var liuyu: Dictionary = _liuyu()
	liuyu["weapon_2"] = "棍"
	await _setup([liuyu])
	var sword: Dictionary = _skill("skill_lianjuejian")
	var palm: Dictionary = _skill("skill_xianglong18")
	var staff: Dictionary = {"id": "staff_test", "weapon_type": "棍", "name": "棍"}
	var general: Dictionary = _skill("skill_hawkeye_focus")
	var combo: Dictionary = _skill("skill_shaojian_lianji")
	var stow: Dictionary = _skill("skill_shouqiao_beibei")
	var cast: Dictionary = _skill("skill_bajian_chishao")
	_expect(rules.is_weapon_compatible(sword, liuyu) and rules.is_weapon_compatible(staff, liuyu) and rules.is_weapon_compatible(cast, liuyu), "without the stance: sword, equipped staff and 拔劍持鞘 are legal")
	_expect(not rules.is_weapon_compatible(combo, liuyu) and not rules.is_weapon_compatible(stow, liuyu), "without the stance: the stance's own skills are not offered")
	liuyu["stance"] = "HOLDING_SHEATH"
	_expect(rules.is_weapon_compatible(sword, liuyu), "C: sword skills stay legal while holding the sheath")
	_expect(rules.is_weapon_compatible(general, liuyu), "C: general skills stay legal")
	_expect(not rules.is_weapon_compatible(palm, liuyu), "C: 翔龍十八掌 (empty hands) is forbidden")
	_expect(not rules.is_weapon_compatible(staff, liuyu), "C: another equipped weapon's skills are forbidden")
	_expect(rules.is_weapon_compatible(combo, liuyu) and rules.is_weapon_compatible(stow, liuyu), "C: 鞘劍連擊 and 收鞘於背 are offered")
	_expect(not rules.is_weapon_compatible(cast, liuyu), "C: 拔劍持鞘 itself is not offered again")
	# the hard rule in the controller
	liuyu["mp"] = 50
	await controller.execute_action(liuyu, palm, _enemy())
	_expect(int(liuyu.mp) == 50 and not bool(liuyu.get("acted_this_turn", false)), "C: a forbidden skill cannot be used: no MP spent, no action used")
	# the skill list the menu builds
	var ids: Array = rules.get_default_skill_ids("liuyu")
	var offered: Array = rules.get_skills_for_actor("liuyu", liuyu, ids, false).map(func(skill: Dictionary) -> String: return String(skill.id))
	_expect(offered.has("skill_lianjuejian") and offered.has("skill_hawkeye_focus") and offered.has("skill_shaojian_lianji") and offered.has("skill_shouqiao_beibei"), "C: the menu offers sword, general and stance skills")
	_expect(not offered.has("skill_xianglong18") and not offered.has("skill_bajian_chishao"), "C: the menu hides the palm skill and the cast")


func _stub_executor() -> Node:
	var stub_script := GDScript.new()
	var lines: PackedStringArray = [
		"extends Node",
		"var calls: Array = []",
		"var block_provider: Callable = Callable()",
		"var adjacency_provider: Callable = Callable()",
		"signal hit_blocked(target, attacker, skill_name)",
		"func execute(user, target, skill_data, inner_force):",
		"\tvar power: float = float(skill_data.get('power', 0.0))",
		"\tcalls.append({'power': power, 'name': String(skill_data.get('name', ''))})",
		"\ttarget['hp'] = int(target.get('hp', 0)) - int(10.0 * power)",
		"\treturn {'hit': true, 'damage': int(10.0 * power), 'crit': false, 'log': [], 'target_down': false, 'dodged': false}",
	]
	stub_script.source_code = "\n".join(lines) + "\n"
	stub_script.reload()
	var stub := Node.new()
	stub.set_script(stub_script)
	return stub


func _check_combo() -> void:
	var combo: Dictionary = _skill("skill_shaojian_lianji")
	var cast: Dictionary = _skill("skill_bajian_chishao")
	for scenario: String in ["single", "multi"]:
		var liuyu: Dictionary = _liuyu()
		var party: Array = [liuyu]
		var shumian: Dictionary = {"id": "shumian", "name": "白", "hp": 80, "max_hp": 80, "mp": 40, "speed": 15, "atk": 10, "def": 4}
		var zuoyin: Dictionary = {"id": "zuoyin", "name": "左", "hp": 80, "max_hp": 80, "mp": 40, "speed": 5, "atk": 10, "def": 4}
		if scenario == "multi":
			party = [shumian, liuyu, zuoyin]
		await _setup(party)
		if scenario == "multi":
			manager.current_index = 1   # 白 has acted; it is 劉's turn
		await controller.execute_action(liuyu, cast, liuyu)
		liuyu["acted_this_turn"] = false
		var sheath_entity: Object = controller.find_stance_entity(liuyu)
		var sheath_proxy: Dictionary = manager.find_queue_actor(String(sheath_entity.entity_id))
		var stub: Node = _stub_executor()
		controller.add_child(stub)
		controller.skill_executor = stub
		var enemy: Dictionary = controller.enemy_party[0]
		var hp_before: int = int(enemy.hp)
		await controller.execute_action(liuyu, combo, enemy)
		controller.skill_executor = real_executor
		_expect(stub.calls.size() == 2, "D (%s): two strikes in all" % scenario)
		if stub.calls.size() == 2:
			_expect(is_equal_approx(float(stub.calls[0].power), 1.0), "D (%s): 劉語塵 strikes at 1.0x" % scenario)
			_expect(is_equal_approx(float(stub.calls[1].power), 0.5), "D (%s): the card strikes at 0.5x" % scenario)
		_expect(int(enemy.hp) == hp_before - 15, "D (%s): both strikes land on the same target" % scenario)
		_expect(int(sheath_proxy.get("left_stamp", 0)) > 0 and int(liuyu.get("left_stamp", 0)) > int(sheath_proxy.get("left_stamp", 0)), "D (%s): the card went to the far left FIRST, then 劉語塵" % scenario)
		_expect(bool(liuyu.get("acted_this_turn", false)), "D (%s): only then does his turn end" % scenario)
		# his turn ends: the order moves on
		manager.active_actor = liuyu
		manager.end_turn()
		await process_frame
		var row: Array = manager.get_display_row(false)
		if scenario == "single":
			_expect(_names(row) == "劉持鞘", "E: single party: [劉][持] - the card ends up to his right, at the right end: " + _names(row))
		else:
			_expect(_names(row) == "劉持鞘白左", "F: with a team the card is only pushed along the real order: " + _names(row))
			_expect(StageAdjacencyKey.key_of(row[0]) != "ent:%s" % String(sheath_entity.entity_id), "F: not thrown to the right end")
		controller.remove_child(stub)
		stub.free()


func _check_block() -> void:
	# G / H / I / J
	var liuyu: Dictionary = _liuyu()
	var shumian: Dictionary = {"id": "shumian", "name": "白", "hp": 100000, "max_hp": 100000, "mp": 40, "speed": 15, "atk": 10, "def": 4}
	await _setup([liuyu, shumian])
	var enemy: Dictionary = controller.enemy_party[0]
	var cast: Dictionary = _skill("skill_bajian_chishao")
	manager.current_index = 1   # 白 acted; 劉's turn
	await controller.execute_action(liuyu, cast, liuyu)
	var attack: Dictionary = {"id": "basic_attack", "name": "普通攻擊", "power": 1.0, "target_scope": "enemy_single"}
	# J: the card is not at the right end (劉 is next to act): never blocks
	var row: Array = manager.get_display_row(false)
	_expect(StageAdjacencyKey.key_of(row[0]) == "liuyu", "J: 劉 is at the right end while it is his own turn")
	var blocks_j: int = 0
	for trial: int in range(300):
		if controller._sheath_blocks_hit(liuyu, enemy):
			blocks_j += 1
	_expect(blocks_j == 0, "J: with the card not at the right end nothing is ever blocked")
	# the card at the right end: everyone else has acted, it is next
	var proxy: Dictionary = manager.queue_entities[0]
	manager.turn_queue = [proxy]
	manager.current_index = 0
	row = manager.get_display_row(false)
	_expect(StageAdjacencyKey.key_of(row[0]) == "ent:%s" % String(controller.find_stance_entity(liuyu).entity_id), "G: the card stands at the right end")
	seed(5)
	var blocked_single: int = 0
	for trial: int in range(600):
		if controller._sheath_blocks_hit(liuyu, enemy):
			blocked_single += 1
	_expect(blocked_single > 240 and blocked_single < 360, "G: about half of the hits are blocked (%d / 600)" % blocked_single)
	_expect(not controller._sheath_blocks_hit(shumian, enemy), "I: a hit meant for anyone else is never blocked")
	_expect(not controller._sheath_blocks_hit(liuyu, liuyu), "only enemy blows are blocked")
	# through the real executor: each Hit rolls on its own
	var blocked_logged: bool = false
	var mixed: bool = false
	var counts: Array[int] = [0, 0, 0, 0]
	for trial: int in range(300):
		var copy: Dictionary = liuyu.duplicate(true)
		var strikes: Array = controller._roll_strikes(enemy, copy, attack, {}, 3)
		var blocked: int = 0
		for strike: Dictionary in strikes:
			if bool(strike.get("blocked", false)):
				blocked += 1
				blocked_logged = blocked_logged or String(strike.log[0]).contains("劍鞘")
		counts[blocked] += 1
		if blocked > 0 and blocked < strikes.size():
			mixed = true
	_expect(blocked_logged, "a blocked Hit says so")
	_expect(mixed and counts[1] > 20 and counts[2] > 20, "H: three hits are judged one by one (blocked counts 0/1/2/3: %s)" % str(counts))
	_expect(controller.find_stance_entity(liuyu) != null, "G: blocking does not consume the card")
	# I: an area attack - judged per Hit on 劉 only
	var shumian_blocked: int = 0
	var liuyu_blocked: int = 0
	for trial: int in range(300):
		var r_l: Dictionary = real_executor.execute(enemy, liuyu.duplicate(true), attack, {})
		var r_s: Dictionary = real_executor.execute(enemy, shumian.duplicate(true), attack, {})
		liuyu_blocked += 1 if bool(r_l.get("blocked", false)) else 0
		shumian_blocked += 1 if bool(r_s.get("blocked", false)) else 0
	_expect(shumian_blocked == 0 and liuyu_blocked > 80, "I: in an area attack only the Hit meant for 劉 is judged (his %d blocked, 白's %d)" % [liuyu_blocked, shumian_blocked])


func _check_stow() -> void:
	var liuyu: Dictionary = _liuyu()
	await _setup([liuyu])
	var cast: Dictionary = _skill("skill_bajian_chishao")
	var stow: Dictionary = _skill("skill_shouqiao_beibei")
	await controller.execute_action(liuyu, cast, liuyu)
	liuyu["acted_this_turn"] = false
	var registry = controller.stage_entities
	_expect(registry.get_stage_entities().size() == 1 and String(liuyu.get("stance", "")) == "HOLDING_SHEATH", "K: the card stands and the stance is on")
	await controller.execute_action(liuyu, stow, liuyu)
	_expect(registry.is_empty() and manager.queue_entities.is_empty(), "K: the card is gone from the stage and the order")
	_expect(String(liuyu.get("stance", "")) == "", "K: the stance is lifted (no ghost stance)")
	_expect(bool(liuyu.get("acted_this_turn", false)), "K: the turn ends normally")
	_expect(rules.is_weapon_compatible(_skill("skill_xianglong18"), liuyu) and rules.is_weapon_compatible(cast, liuyu), "K: the normal skill set is back")
	_expect(not rules.is_weapon_compatible(_skill("skill_shaojian_lianji"), liuyu), "K: the stance skills are gone")
	# a destroyed card (not stowed) lifts the stance as well
	liuyu["acted_this_turn"] = false
	await controller.execute_action(liuyu, cast, liuyu)
	registry.destroy_entity(registry.get_stage_entities()[0], {})
	_expect(String(liuyu.get("stance", "")) == "", "a card destroyed any other way lifts the stance too")
