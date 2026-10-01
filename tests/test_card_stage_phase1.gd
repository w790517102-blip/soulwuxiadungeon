extends SceneTree
## Card Stage phase 1: formation slots, depth, spatial motion, picking, FX depth.
## Run explicitly with --headless --path . --script tests/test_card_stage_phase1.gd.

const Formation := preload("res://scripts/presentation/CardStageFormation.gd")

var _failures: Array[String] = []
var _assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	_check_formation_table()
	_check_rank_assignment()
	await _check_entry_modes()
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	_expect(fixture.prepared, "card stage preview prepares")
	if fixture.prepared:
		await _check_stage(fixture)
	fixture.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: ", _assertions, " assertions; card stage formation, depth, motion, picking and FX")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check_formation_table() -> void:
	for count: int in [1, 2, 3]:
		for enemy: bool in [false, true]:
			var previous: Dictionary = {}
			for rank: int in range(count):
				var slot: Dictionary = Formation.slot(count, rank, enemy, -1.0 if enemy else 1.0)
				var side: float = 1.0 if enemy else -1.0
				_expect(signf(slot.position.x) == side, "slot x stays on its own side (count %d rank %d)" % [count, rank])
				if not previous.is_empty():
					_expect(absf(slot.position.x) > absf(previous.position.x), "later ranks stand farther from the centre line along X")
					_expect(is_equal_approx(slot.position.y, previous.position.y), "a row shares one ground line")
					_expect(slot.position.z <= previous.position.z and previous.position.z - slot.position.z < 0.6, "the row stays at almost one depth; only a small poke for the fastest")
				_expect(not slot.has("role_name") and not slot.has("role"), "slots carry no battle-role semantics")
				previous = slot
	var ally: Dictionary = Formation.slot(3, 0, false, 1.0)
	var enemy_slot: Dictionary = Formation.slot(3, 0, true, -2.0)
	_expect(ally.position.z - enemy_slot.position.z > 2.5, "enemy row is clearly deeper than the party row")
	_expect(is_equal_approx(ally.position.y, enemy_slot.position.y), "both rows share the same height")
	var ally_span: float = absf(Formation.slot(3, 2, false, 1.0).position.x - Formation.slot(3, 0, false, 1.0).position.x)
	_expect(is_equal_approx(ally_span, Formation.ALLY_SPACING * 2.0), "neighbour spacing is the data constant")
	_expect(is_equal_approx(Formation.slot(1, 0, false, 1.0).position.x, -Formation.ALLY_LANE_X), "a lone party card centres in its lane")


func _check_rank_assignment() -> void:
	var actors: Array = [{"id": "a", "speed": 9}, {"id": "b", "speed": 14}, {"id": "c", "speed": 6}]
	_expect(Formation.assign_ranks(actors) == [1, 0, 2], "fastest actor takes the innermost slot")
	_expect(Formation.assign_ranks([{"speed": 5}, {"speed": 5}, {"speed": 5}]) == [0, 1, 2], "equal speed keeps original order")
	_expect(Formation.assign_ranks([{"speed": 1, "is_guest": true}, {"speed": 3}, {"speed": 2}]) == [2, 0, 1], "guests always stand last")
	_expect(Formation.assign_ranks([{"speed": 20}, {"speed": 1, "formation": "inner"}]) == [1, 0], "explicit formation hint overrides speed")
	var before: Array = actors.duplicate(true)
	Formation.assign_ranks(actors)
	_expect(actors == before, "rank assignment does not modify actor dictionaries")


func _check_entry_modes() -> void:
	var state: Node = root.get_node("GlobalState")
	var had_pending: bool = state.has_meta("pending_battle_context")
	var prior: Variant = state.get_meta("pending_battle_context") if had_pending else null
	state.remove_meta("pending_battle_context")
	var scene: PackedScene = load("res://scenes/battle_scene.tscn")
	var expected: Dictionary = {
		0: ["/BattleUI.gd", "/BattleController.gd"],
		1: ["/StageBattleUI.gd", "/StageBattleController.gd"],
		2: ["/CardStageBattleUI.gd", "/StageBattleController.gd"],
	}
	for mode: int in [0, 1, 2]:
		var battle: Node = scene.instantiate()
		battle.presentation_mode = mode
		root.add_child(battle)
		await process_frame
		await process_frame
		var ui_path: String = battle.get_node("BattleUILayer/BattleUI").get_script().resource_path
		var controller_path: String = battle.get_node("BattleController").get_script().resource_path
		_expect(ui_path.ends_with(expected[mode][0]), "mode %d selects %s" % [mode, expected[mode][0]])
		_expect(controller_path.ends_with(expected[mode][1]), "mode %d selects %s" % [mode, expected[mode][1]])
		if mode == 2:
			var stage: Node3D = battle.get_node("BattleUILayer/BattleUI").stage
			_expect(stage.get_script().resource_path.ends_with("/CardStage3D.gd"), "card stage builds CardStage3D")
		if mode == 1:
			var stage_25d: Node3D = battle.get_node("BattleUILayer/BattleUI").stage
			_expect(stage_25d.get_script().resource_path.ends_with("/CombatStage25D.gd"), "STAGE_25D still builds the unchanged CombatStage25D")
		battle.queue_free()
		await process_frame
	# Normal story entry: nothing is requested, so the default must be CARD_STAGE.
	var default_battle: Node = scene.instantiate()
	root.add_child(default_battle)
	await process_frame
	await process_frame
	_expect(default_battle.get_node("BattleUILayer/BattleUI").get_script().resource_path.ends_with("/CardStageBattleUI.gd"), "default presentation is CARD_STAGE")
	_expect(default_battle.active_presentation_name() == "CARD_STAGE", "the active presentation reports CARD_STAGE")
	_expect(default_battle.has_node("PresentationBadgeLayer/PresentationBadge") == OS.is_debug_build(), "debug builds show the presentation badge")
	default_battle.queue_free()
	await process_frame
	# A battle context can still ask for the previous stage explicitly.
	state.set_meta("pending_battle_context", {"presentation_mode": 1})
	var context_battle: Node = scene.instantiate()
	root.add_child(context_battle)
	await process_frame
	_expect(context_battle.active_presentation_name() == "STAGE_25D", "context presentation_mode = 1 selects STAGE_25D")
	context_battle.queue_free()
	await process_frame
	state.remove_meta("pending_battle_context")
	if had_pending:
		state.set_meta("pending_battle_context", prior)


func _actor(base: Dictionary, id: String, speed: int, enemy: bool, index: int) -> Dictionary:
	var actor: Dictionary = base.duplicate(true)
	actor["id"] = id
	actor["name"] = id
	actor["display_name"] = id
	actor["speed"] = speed
	actor["battle_uid"] = "%s#%d" % [id, index]
	if enemy:
		actor["is_enemy"] = true
	return actor


func _check_stage(fixture: Node) -> void:
	var ui: Node = fixture.ui
	var controller: Node = fixture.controller
	var context: Dictionary = fixture.build_preview_context()
	var base_ally: Dictionary = context.player_party[0]
	var base_enemy: Dictionary = context.enemy_party[0]
	var allies: Array = [_actor(base_ally, "ally_mid", 9, false, 0), _actor(base_ally, "ally_fast", 14, false, 1), _actor(base_ally, "ally_slow", 6, false, 2)]
	var enemies: Array = [_actor(base_enemy, "foe_mid", 7, true, 0), _actor(base_enemy, "foe_fast", 16, true, 1), _actor(base_enemy, "foe_slow", 3, true, 2)]
	controller.player_party = allies
	controller.enemy_party = enemies
	controller.ruleset = context.ruleset
	ui.set_teams(allies, enemies)
	var stage: Node3D = ui.stage
	_expect(stage.get_script().resource_path.ends_with("/CardStage3D.gd"), "preview uses the card stage")
	_expect(stage.cards.size() == 6, "3v3 creates six cards")

	# --- Slots and depth -------------------------------------------------------
	var fast: Node3D = stage.card_for(allies[1])
	var mid: Node3D = stage.card_for(allies[0])
	var slow: Node3D = stage.card_for(allies[2])
	_expect(fast.slot_rank == 0 and mid.slot_rank == 1 and slow.slot_rank == 2, "initial speed decides the left-to-right order")
	_expect(absf(fast.home_position.x) < absf(mid.home_position.x) and absf(mid.home_position.x) < absf(slow.home_position.x), "faster party cards stand closer to the centre")
	_expect(fast.home_position.z >= mid.home_position.z and mid.home_position.z >= slow.home_position.z, "faster cards poke slightly toward the camera")
	var party_depths: Array = [fast.home_position.z, mid.home_position.z, slow.home_position.z]
	_expect(party_depths.max() - party_depths.min() < 0.6, "the party stands in one row at nearly one depth")
	_expect(is_equal_approx(fast.home_position.y, mid.home_position.y) and is_equal_approx(mid.home_position.y, slow.home_position.y), "the party shares one ground line")
	var foe_fast: Node3D = stage.card_for(enemies[1])
	_expect(foe_fast.slot_rank == 0 and foe_fast.home_position.x > 0.0, "enemy row is on the right")
	for foe: Dictionary in enemies:
		_expect(stage.card_for(foe).home_position.z < party_depths.min() - 2.0, "every enemy card is clearly deeper than the party row")
	# Upright: the card's long axis is world up, and it is not a billboard.
	_expect(fast.card_size.y / fast.card_size.x > 1.4 and fast.card_size.y / fast.card_size.x < 1.7, "cards are portrait proportioned")
	_expect(is_equal_approx(fast.home_rotation.x, 0.0) and is_equal_approx(fast.home_rotation.z, 0.0), "resting cards have no pitch or roll")
	_expect(fast.global_transform.basis.y.dot(Vector3.UP) > 0.999, "the card's long axis stays along world Y")
	_expect(fast.card_mesh.mesh.size == fast.card_size, "mesh follows the data-driven card size")
	# Current game information is still on the face.
	_expect(fast.hp_label.visible and fast.mp_label.visible and fast.force_label.visible and fast.level_label.visible, "party card keeps HP, MP, inner force and level")
	_expect(foe_fast.hp_label.visible and foe_fast.species_label.visible and foe_fast.element_label.visible and not foe_fast.mp_label.visible, "enemy card keeps HP, species and element")
	_expect(fast.card_viewport.size_2d_override.y > fast.card_viewport.size_2d_override.x, "card face canvas is portrait")
	_expect(is_equal_approx(fast.home_rotation.y, deg_to_rad(28.0)) and is_equal_approx(foe_fast.home_rotation.y, deg_to_rad(-28.0)), "default yaw is the 28 degree preset, mirrored")
	_expect(stage.YAW_PRESETS == [22.0, 28.0, 32.0], "yaw presets are 22 / 28 / 32")
	for preset: int in [0, 2, 1]:
		var applied: float = stage.set_yaw_preset(preset)
		_expect(is_equal_approx(fast.home_rotation.y, deg_to_rad(applied)) and is_equal_approx(foe_fast.home_rotation.y, deg_to_rad(-applied)) and fast.rotation.is_equal_approx(fast.home_rotation), "preset %d seats every card at %d degrees, mirrored" % [preset, int(applied)])
	_expect(stage.cycle_yaw_preset() == 32.0 and stage.cycle_yaw_preset() == 22.0 and stage.cycle_yaw_preset() == 28.0, "yaw cycles 28 -> 32 -> 22 -> 28")
	# Camp depth: the camps are pulled apart, never the cards of one camp.
	_expect(party_depths.min() - foe_fast.home_position.z >= 5.0, "enemy camp is at least 5 world units deeper than the party camp")
	var enemy_depths: Array = []
	for foe_actor: Dictionary in enemies:
		enemy_depths.append(stage.card_for(foe_actor).home_position.z)
	_expect(enemy_depths.max() - enemy_depths.min() < 0.6, "the enemy camp also shares one Z band")
	_expect(stage.background_depth < enemy_depths.min() - 5.0, "the backdrop is well behind the enemy camp")
	# Size difference comes from perspective only; no compensating scale.
	var ally_rect: Rect2 = stage.card_screen_rect(allies[0])
	var foe_rect: Rect2 = stage.card_screen_rect(enemies[0])
	_expect(stage.card_for(enemies[0]).scale == Vector3.ONE and foe_rect.size.y < ally_rect.size.y * 0.85, "farther enemy cards look smaller through perspective, not scale")
	# The middle stays open for sword trails, MISS flights and charges.
	var party_right: float = 0.0
	var enemy_left: float = 99999.0
	for ally_actor: Dictionary in allies:
		party_right = maxf(party_right, stage.card_screen_rect(ally_actor).end.x)
	for foe_actor: Dictionary in enemies:
		enemy_left = minf(enemy_left, stage.card_screen_rect(foe_actor).position.x)
	_expect(enemy_left - party_right >= root.get_visible_rect().size.x * 0.15, "at least 15 percent of the screen width stays open between the camps")
	_expect(fast.scale == Vector3.ONE and slow.scale == Vector3.ONE, "cards keep scale 1; depth comes from perspective")
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for card: Node3D in stage.cards.values():
		var rect: Rect2 = stage.card_screen_rect(_actor_of(card, stage, allies + enemies))
		_expect(viewport_rect.grow(2.0).encloses(rect), "%s stays inside the viewport" % card.name)

	# --- Overlap, picking and hover --------------------------------------------
	var overlap_found := false
	for pair: Array in [[allies[1], allies[0]], [allies[0], allies[2]], [enemies[1], enemies[0]], [enemies[0], enemies[2]]]:
		var near_actor: Dictionary = pair[0]
		var far_actor: Dictionary = pair[1]
		var both: Rect2 = stage.card_screen_rect(near_actor).intersection(stage.card_screen_rect(far_actor))
		if both.size.x <= 4.0 or both.size.y <= 4.0:
			continue
		for step_x: int in range(1, 8):
			for step_y: int in range(1, 8):
				var point: Vector2 = both.position + both.size * Vector2(step_x / 8.0, step_y / 8.0)
				var hit_near: bool = not stage.pick_actor(point, [near_actor]).is_empty()
				var hit_far: bool = not stage.pick_actor(point, [far_actor]).is_empty()
				if hit_near and hit_far:
					overlap_found = true
					var picked: Dictionary = stage.pick_actor(point, [near_actor, far_actor])
					_expect(String(picked.get("battle_uid", "")) == String(near_actor.battle_uid), "overlapping cards pick the nearer one")
					var swapped: Dictionary = stage.pick_actor(point, [far_actor, near_actor])
					_expect(String(swapped.get("battle_uid", "")) == String(near_actor.battle_uid), "pick result does not depend on candidate order")
	_expect(overlap_found, "formation produces at least one genuinely overlapping pair to exercise picking")
	var dead_target: Dictionary = allies[1].duplicate(true)
	dead_target["hp"] = 0
	_expect(stage.pick_actor(stage.card_screen_rect(allies[1]).get_center(), [dead_target]).is_empty(), "defeated cards are not picked unless allowed")

	# --- Target picker uses the same nearest-card rule --------------------------
	ui.target_picker.begin(allies[0], enemies)
	var enemy_center: Vector2 = stage.card_screen_rect(enemies[1]).get_center()
	ui.target_picker._update_pointer(enemy_center)
	_expect(stage.card_for(enemies[1])._target_frame.visible and not stage.card_for(enemies[0])._target_frame.visible, "hover highlights exactly one overlapped card")
	ui.target_picker.close()

	# --- OS bubble --------------------------------------------------------------
	ui._setup_actor_bubble_labels()
	for index: int in range(ui.enemy_slots.size()):
		var box: PanelContainer = ui._actor_bubble_boxes.get(ui._get_bubble_key_for_slot(ui.enemy_slots[index]))
		if box == null or index >= enemies.size():
			continue
		ui._position_bubble_on_portrait(ui.enemy_slots[index], box)
		_expect(viewport_rect.encloses(Rect2(box.global_position, box.size)), "OS bubble %d stays inside the viewport" % index)
		_expect(box.global_position.x + box.size.x <= stage.card_screen_rect(enemies[index]).position.x, "OS bubble %d sits beside its own card" % index)

	# --- Spatial motion ---------------------------------------------------------
	await _check_motion(fast, foe_fast, stage, "attack")
	await _check_motion(foe_fast, fast, stage, "hit")
	await _check_motion(stage.card_for(enemies[0]), fast, stage, "dodge")
	await _check_motion(stage.card_for(enemies[2]), fast, stage, "guard")

	# --- Combat values and FX volume -------------------------------------------
	var before: Array = (allies + enemies).duplicate(true)
	await stage.present_attack(allies[1], enemies[1], {}, {"hit": true, "crit": false})
	_expect(allies + enemies == before, "hit presentation leaves combat dictionaries untouched")
	_expect(not stage.busy and stage.fx_root.get_child_count() == 0, "hit presentation completes and releases its FX")
	for target_index: int in [1, 0, 2]:
		var target: Dictionary = enemies[target_index]
		var destination: Node3D = stage.card_for(target)
		var done: Array = [false]
		_present(stage, allies[1], target, done)
		var endpoint: Vector3 = Vector3.ZERO
		var frames := 0
		while not done[0] and frames < 400:
			await process_frame
			frames += 1
			if stage.fx_root.get_child_count() > 0 and stage.fx_root.get_child(0).last_endpoint != Vector3.ZERO:
				endpoint = stage.fx_root.get_child(0).last_endpoint
		await process_frame
		_expect(endpoint != Vector3.ZERO, "miss ribbon reports a flight endpoint (target %d)" % target_index)
		_expect(endpoint.z < destination.home_position.z - 2.0, "miss ribbon passes behind the target's depth (target %d)" % target_index)
		_expect(endpoint.z > stage.background_depth + 1.0, "miss ribbon dissipates before the backdrop plane (target %d)" % target_index)
		_expect(endpoint.x > destination.home_position.x, "miss ribbon continues through to the far side (target %d)" % target_index)
		_expect(not stage.busy and stage.fx_root.get_child_count() == 0 and allies + enemies == before, "miss completes cleanly (target %d)" % target_index)

	# --- Legacy switch and empty slots ------------------------------------------
	ui.set_stage_enabled(false)
	_expect(not stage.visible and ui.ally_panel.visible, "F8 path restores the legacy panels")
	ui.set_stage_enabled(true)
	ui.set_teams([allies[0]], [enemies[0]])
	_expect(stage.cards.size() == 2, "empty slots are not drawn as cards")
	_expect(stage.card_for(allies[0]).slot_rank == 0, "a lone actor takes the only slot")


func _present(stage: Node3D, attacker: Dictionary, target: Dictionary, done: Array) -> void:
	await stage.present_attack(attacker, target, {}, {"hit": false, "crit": false})
	done[0] = true


func _actor_of(card: Node3D, stage: Node3D, actors: Array) -> Dictionary:
	for actor: Dictionary in actors:
		if stage.card_for(actor) == card:
			return actor
	return {}


func _check_motion(card: Node3D, other: Node3D, stage: Node3D, kind: String) -> void:
	var home: Vector3 = card.home_position
	var peak_z_back: float = 0.0
	var peak_z_forward: float = 0.0
	var peak_distance: float = 0.0
	match kind:
		"attack": card.attack_motion(other.home_position)
		"hit": card.hit_reaction(true)
		"dodge": card.dodge_motion()
		"guard": card.guard_motion()
	var frames := 0
	while card._motion_tween != null and card._motion_tween.is_valid() and card._motion_tween.is_running() and frames < 240:
		await process_frame
		frames += 1
		peak_z_back = minf(peak_z_back, card.position.z - home.z)
		peak_z_forward = maxf(peak_z_forward, card.position.z - home.z)
		peak_distance = maxf(peak_distance, card.position.distance_to(home))
	await process_frame
	_expect(card.position.is_equal_approx(home) and card.rotation.is_equal_approx(card.home_rotation), "%s motion returns the card to its slot" % kind)
	match kind:
		"attack":
			_expect(peak_distance > 2.0 and peak_z_forward >= 0.8, "attack lunges toward the centre and swings out toward the viewer")
		"hit":
			_expect(peak_z_back <= -1.4, "heavy hit knocks the card back into depth")
		"dodge":
			_expect(peak_z_back <= -1.0 and peak_distance > 1.0, "dodge slips sideways and deeper")
		"guard":
			_expect(peak_z_back <= -0.3 and peak_distance < 0.6, "guard braces in place")
