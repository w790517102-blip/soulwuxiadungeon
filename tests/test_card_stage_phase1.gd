extends SceneTree
## Card Stage phase 1: formation slots, depth, spatial motion, picking, FX depth.
## Run explicitly with --headless --path . --script tests/test_card_stage_phase1.gd.

const Formation := preload("res://scripts/presentation/CardStageFormation.gd")
const CardStageArtScript := preload("res://scripts/presentation/CardStageArt.gd")

var _failures: Array[String] = []
var _assertions: int = 0
var _stage_checks_completed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	_check_formation_table()
	_check_rank_assignment()
	_check_enemy_art_table()
	_check_backgrounds()
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
		_expect(_stage_checks_completed, "the stage checks ran to the end (no silent script abort)")
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
				var slot: Dictionary = Formation.slot(count, rank, enemy)
				_expect((slot.screen_x > 0.5) == enemy, "slot stays on its own half of the screen (count %d rank %d)" % [count, rank])
				if not previous.is_empty():
					var outward: float = slot.screen_x - previous.screen_x
					_expect((outward > 0.0) == enemy and absf(outward) > 0.0, "later ranks stand farther from the centre along X")
					_expect(is_equal_approx(slot.feet, previous.feet) and is_equal_approx(slot.height, previous.height), "a camp shares one ground line and one apparent size")
					_expect(absf(slot.z_stack - previous.z_stack) < 0.3, "ordering offsets inside a camp are tiny")
				_expect(not slot.has("role_name") and not slot.has("role"), "slots carry no battle-role semantics")
				previous = slot
	var ally: Dictionary = Formation.slot(3, 0, false)
	var enemy_slot: Dictionary = Formation.slot(3, 0, true)
	_expect(is_equal_approx(Formation.ALLY_HEIGHT, 0.64) and is_equal_approx(Formation.ENEMY_HEIGHT, 0.37), "camp apparent heights are data constants")
	_expect(Formation.ALLY_HEIGHT > Formation.ENEMY_HEIGHT * 1.5, "the party camp looks clearly taller than the enemy camp")
	_expect(enemy_slot.feet < ally.feet and enemy_slot.feet > 0.5, "enemy feet stand higher on screen on the same ground plane")
	var ally_span: float = absf(Formation.slot(3, 2, false).screen_x - Formation.slot(3, 0, false).screen_x)
	_expect(is_equal_approx(ally_span, Formation.ALLY_SPACING * 2.0), "neighbour spacing is the data constant")
	_expect(is_equal_approx(Formation.slot(1, 0, false).screen_x, Formation.ALLY_LANE), "a lone party card centres in its lane")
	var near: float = Formation.distance_for_fraction(3.45, Formation.ALLY_HEIGHT, 34.0)
	var far: float = Formation.distance_for_fraction(3.45, Formation.ENEMY_HEIGHT, 34.0)
	_expect(far > near * 1.5 and far < near * 1.9, "the enemy camp is clearly farther from the camera")


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

	# --- Defeat exits ----------------------------------------------------------
	var beast: Node3D = stage.card_for(enemies[0])
	var spirit: Node3D = stage.card_for(enemies[1])
	var beast_home: Vector3 = beast.home_position
	var spirit_home: Vector3 = spirit.home_position
	beast.defeat_animal()
	spirit.defeat_yumei()
	await create_timer(0.7).timeout
	_expect(beast.rotation.x < beast.home_rotation.x - 0.1 and beast.position.z < beast_home.z, "an animal tips backwards as it exits")
	_expect(spirit.position.y > spirit_home.y or spirit.scale.x > 1.0, "a 語魅 pulses and begins to rise")
	await create_timer(1.5).timeout
	_expect(not beast.visible and not spirit.visible, "defeated cards are gone once the exit ends")
	_expect(spirit.position.y > spirit_home.y + 1.0, "a 語魅 exits upward")
	beast.visible = true
	beast.set_fade(0.0)
	spirit.visible = true
	spirit.set_fade(0.0)
	beast.reset_pose()
	spirit.reset_pose()
	spirit.position = spirit_home


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
	_expect(fast.card_mesh.mesh.size == fast.face_size and fast.face_size.x > fast.card_size.x, "the face quad is the whole template (frame plus ornaments); the card body is its frame")
	_expect(is_equal_approx(fast.card_back.mesh.size.z, 0.04), "card thickness is 0.04 (one third thinner than 0.06)")
	_expect(fast.card_back.position.z + fast.card_back.mesh.size.z / 2.0 < 0.0, "the card edge stays behind the face")
	# Current game information is still on the face.
	_expect(fast.hp_label.visible and fast.mp_label.visible and fast.force_label.visible and fast.element_label.visible and not fast.level_label.visible, "party card keeps HP, MP, inner-force element and name; LV is removed")
	_expect(foe_fast.hp_label.visible and foe_fast.species_label.visible and foe_fast.element_label.visible and not foe_fast.mp_label.visible, "enemy card keeps HP, species and element")
	_expect(fast.card_viewport.size_2d_override.y > fast.card_viewport.size_2d_override.x, "card face canvas is portrait")
	_expect(is_equal_approx(fast.home_rotation.y, deg_to_rad(50.0)), "party cards default to a 50 degree turn toward the enemy")
	_expect(is_equal_approx(foe_fast.home_rotation.y, deg_to_rad(-12.0)) and foe_fast.home_rotation.y < 0.0, "enemy cards stay nearly frontal, turned slightly toward the party")
	_expect(stage.YAW_PRESETS == [45.0, 50.0, 55.0], "party yaw presets are 45 / 50 / 55")
	for preset: int in [0, 2, 1]:
		var applied: float = stage.set_yaw_preset(preset)
		_expect(is_equal_approx(fast.home_rotation.y, deg_to_rad(applied)) and is_equal_approx(slow.home_rotation.y, deg_to_rad(applied)) and fast.rotation.is_equal_approx(fast.home_rotation), "preset %d seats every party card at %d degrees" % [preset, int(applied)])
		_expect(is_equal_approx(foe_fast.home_rotation.y, deg_to_rad(-12.0)), "party yaw presets never change the enemy yaw")
	_expect(stage.cycle_yaw_preset() == 55.0 and stage.cycle_yaw_preset() == 45.0 and stage.cycle_yaw_preset() == 50.0, "party yaw cycles 50 -> 55 -> 45 -> 50")
	# Camp depth: the camps are pulled apart, never the cards of one camp.
	_expect(party_depths.min() - foe_fast.home_position.z >= 4.5, "enemy camp is at least 4.5 world units deeper than the party camp")
	var enemy_depths: Array = []
	for foe_actor: Dictionary in enemies:
		enemy_depths.append(stage.card_for(foe_actor).home_position.z)
	_expect(enemy_depths.max() - enemy_depths.min() < 0.6, "the enemy camp also shares one Z band")
	_expect(stage.background_depth < enemy_depths.min() - 5.0, "the backdrop is well behind the enemy camp")
	# Size difference comes from perspective only; no compensating scale.
	var ally_rect: Rect2 = stage.card_screen_rect(allies[0])
	var foe_rect: Rect2 = stage.card_screen_rect(enemies[0])
	_expect(stage.card_for(enemies[0]).scale == Vector3.ONE and foe_rect.size.y < ally_rect.size.y * 0.8, "farther enemy cards look smaller through perspective, not scale")
	var screen_h: float = root.get_visible_rect().size.y
	_expect(ally_rect.size.y / screen_h > 0.70 and ally_rect.size.y / screen_h < 0.80, "party cards fill about 3/4 of the screen height (%.2f)" % (ally_rect.size.y / screen_h))
	_expect(foe_rect.size.y / screen_h > 0.33 and foe_rect.size.y / screen_h < 0.47, "enemy cards fill about 2/5 of the screen height (%.2f)" % (foe_rect.size.y / screen_h))
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
		_expect(viewport_rect.grow(viewport_rect.size.x * 0.03).encloses(rect), "%s stays (almost) inside the viewport: %s" % [card.name, str(rect)])
		_expect(rect.end.y <= viewport_rect.size.y * 0.85, "%s stands above the command tray" % card.name)

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
		var enemy_centre: Vector2 = stage.card_portrait_center(enemies[index])
		_expect(box.global_position.x + box.size.x <= enemy_centre.x, "OS bubble %d stands beside its own portrait" % index)
		var tail: Control = box.get_node_or_null("Tail")
		_expect(tail != null and tail.target.is_equal_approx(enemy_centre), "OS bubble %d has a tail pointing at the middle of the portrait" % index)

	# --- Spatial motion ---------------------------------------------------------
	await _check_motion(fast, foe_fast, stage, "attack")
	await _check_motion(foe_fast, fast, stage, "hit")
	await _check_motion(stage.card_for(enemies[0]), fast, stage, "dodge")
	await _check_motion(stage.card_for(enemies[2]), fast, stage, "guard")

	# --- Combat values and FX volume -------------------------------------------
	var before: Array = (allies + enemies).duplicate(true)
	await stage.present_attack(allies[1], enemies[1], {}, {"hit": true, "crit": false})
	_expect(allies + enemies == before, "hit presentation leaves combat dictionaries untouched")
	# The hit spark leaves a short residue (cracks, ink flecks); it must clear by itself.
	var fx_guard: int = 0
	while stage.fx_root.get_child_count() > 0 and fx_guard < 400:
		await process_frame
		fx_guard += 1
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
			for fx_child: Node in stage.fx_root.get_children():
				if "last_endpoint" in fx_child and fx_child.last_endpoint != Vector3.ZERO:
					endpoint = fx_child.last_endpoint
		await process_frame
		_expect(endpoint != Vector3.ZERO, "miss ribbon reports a flight endpoint (target %d)" % target_index)
		_expect(endpoint.z < destination.home_position.z - 2.0, "miss ribbon passes behind the target's depth (target %d)" % target_index)
		_expect(endpoint.z > stage.background_depth + 1.0, "miss ribbon dissipates before the backdrop plane (target %d)" % target_index)
		_expect(endpoint.x > destination.home_position.x, "miss ribbon continues through to the far side (target %d)" % target_index)
		_expect(not stage.busy and stage.fx_root.get_child_count() == 0 and allies + enemies == before, "miss completes cleanly (target %d)" % target_index)

	# --- Card templates ------------------------------------------------------------
	var Templates = load("res://scripts/presentation/CardStageTemplates.gd")
	_expect(fast.template_key == "character" and slow.template_key == "character", "party members use the character template")
	_expect(foe_fast.template_key == "enemy", "an ordinary enemy uses the enemy template")
	_expect(Templates.key_for({"id": "molin_yanjiang"}, true) == "boss" and Templates.key_for({"id": "molin_yanjiang_phase2"}, true) == "boss" and Templates.key_for({"id": "x", "is_boss": true}, true) == "boss", "Molin Yanjiang (and flagged bosses) use the boss template")
	_expect(Templates.key_for({"id": "zuoyin_stalactite_guest", "is_guest": true}, false) == "character", "the guest uses the character template")
	_expect(Templates.key_for({"id": "bamboo_bobcat"}, true) == "beast" and Templates.key_for({"id": "bamboo_poison_snake"}, true) == "beast" and Templates.key_for({"id": "yumei_sewer_rat"}, true) == "enemy", "bamboo grove animals use the beast template, phantoms keep the enemy one")
	_expect(Templates.key_for({"id": "x", "card_template": "boss"}, true) == "boss", "an actor can force a template")
	for template_name: String in Templates.TEMPLATES.keys():
		var spec: Dictionary = Templates.TEMPLATES[template_name]
		_expect(FileAccess.file_exists(spec.face) and FileAccess.file_exists(spec.ink), "%s template files exist" % template_name)
		_expect(is_equal_approx(Templates.card_world_size(template_name).x, Templates.CARD_WORLD_WIDTH), "%s card body is as wide as every other card" % template_name)
		var canvas_rect := Rect2(Vector2.ZERO, spec.canvas)
		for slot_name: String in ["name", "window", "hp", "status"]:
			_expect(canvas_rect.encloses(spec[slot_name]) and (spec.frame as Rect2).encloses(spec[slot_name]), "%s: %s slot lies inside the card frame" % [template_name, slot_name])
		_expect((spec.window as Rect2).position.y > (spec.name as Rect2).end.y and (spec.hp as Rect2).position.y > (spec.window as Rect2).end.y, "%s: name above the window above the information slots" % template_name)
	_expect(fast.hp_bar.get_parent() == fast._content and fast.hp_label.get_index() > fast.hp_bar.get_index(), "HP text is drawn over its bar")
	_expect(Rect2(fast.hp_bar.position, fast.hp_bar.size).intersects(Rect2(fast.hp_label.position, fast.hp_label.size)) and (fast.template.hp as Rect2).encloses(Rect2(fast.hp_bar.position, fast.hp_bar.size)), "the HP bar fills the template's HP slot")
	_expect(not fast.mp_bar.get_parent().get_child(0) == null and (fast.template.mp as Rect2).encloses(Rect2(fast.mp_bar.position, fast.mp_bar.size)), "the MP bar fills the template's MP slot")
	_expect(not foe_fast.mp_label.visible and foe_fast.species_label.visible and foe_fast.hp_label.visible, "enemy cards show element / species / HP in their template slots")

	# --- Character art layers ------------------------------------------------------
	_expect(fast.art_layer.visible and not fast.portrait.visible, "an actor with new battle art shows it on its own layer instead of the old portrait")
	_expect(foe_fast.art_layer.visible and not foe_fast.portrait.visible, "an enemy with supplied art uses the art layer")
	var legacy_enemy_art: Dictionary = CardStageArtScript.entry_for({"id": "no_such_enemy"})
	_expect(legacy_enemy_art.is_empty(), "an actor without supplied art keeps its existing portrait")
	_expect(fast.ink_back != null and fast.ink_back.material_override is StandardMaterial3D and fast.ink_back.material_override.albedo_texture != null, "every card has the template ink-wash window behind its art")
	_expect(fast.ink_back.position.z < fast.art_layer.position.z and fast.art_layer.position.z < fast.card_mesh.position.z, "layers stack ink < art < face, giving real parallax")
	_expect(fast.card_back.position.z + fast.card_back.mesh.size.z / 2.0 < fast.ink_back.position.z, "the card edge sits behind every layer")
	var art_texture: Texture2D = fast.art_material.get_shader_parameter("art")
	_expect(art_texture != null and maxi(art_texture.get_width(), art_texture.get_height()) <= 1024, "battle art is downscaled to at most 1024 px")
	for art_path: String in ["liu_yu", "su_mien", "zuo_yin"]:
		var art_file: String = "res://assets/sprites/battle_cards/%s_battle_new.webp" % art_path
		_expect(FileAccess.file_exists(art_file) and FileAccess.get_file_as_bytes(art_file).size() < 1600000, "%s art is a lossless WebP under 1.6 MB (originals were 2.4-2.8 MB PNGs)" % art_path)
	_expect(fast.art_material.get_shader_parameter("clip_rect") == Vector4(fast.window_local.position.x, fast.window_local.position.y, fast.window_local.end.x, fast.window_local.end.y), "art is cropped to the template window")
	_expect(fast.window_local.position.x >= -fast.card_size.x / 2.0 and fast.window_local.end.x <= fast.card_size.x / 2.0 and fast.window_local.end.y <= fast.card_size.y / 2.0, "the art window lies inside the card frame (no overflow)")
	_expect(is_equal_approx(CardStageArtScript.quad_center({"focus": Vector2(0.5, 0.5), "size": 2.0, "target": Vector2(0.3, 0.7)}).x, 0.3), "art placement lands the face focus on the target point")
	var guest_entry: Dictionary = CardStageArtScript.entry_for({"id": "zuoyin_stalactite_guest"})
	_expect(String(guest_entry.get("path", "")).ends_with("zuo_yin_battle_new.webp"), "the stalactite guest resolves to Zuo Yin's new art")
	_expect(CardStageArtScript.entry_for({"id": "molin_yanjiang"}).mode == "cover", "Molin Yanjiang has landscape cover art")

	# --- Target selection: the hovered card lifts, its camp-mates step aside -----
	stage.set_hover_target({})
	await process_frame
	var offsets: Dictionary = stage.fan_offsets_for(stage.actor_key(allies[1]))
	_expect(offsets.has(stage.actor_key(allies[1])) and offsets[stage.actor_key(allies[1])].z >= 0.8, "the hovered card comes toward the camera")
	_expect(not offsets.has(stage.actor_key(enemies[0])) and not offsets.has(stage.actor_key(enemies[1])), "the other camp is never moved by the hover")
	var neighbour_offset: Vector3 = offsets.get(stage.actor_key(allies[0]), Vector3.ZERO)
	_expect(neighbour_offset.x < 0.0 and neighbour_offset.z < 0.0, "a neighbour on the left makes way outward and recedes")
	stage.set_hover_target(allies[1])
	for fan_frame: int in range(40):
		await process_frame
	_expect(fast.position.is_equal_approx(fast.home_position + offsets[stage.actor_key(allies[1])]), "the hovered card settles lifted")
	_expect(stage.card_for(allies[0]).position.x < stage.card_for(allies[0]).home_position.x, "the neighbour has stepped aside")
	for foe_actor: Dictionary in enemies:
		_expect(stage.card_for(foe_actor).position.is_equal_approx(stage.card_for(foe_actor).home_position), "enemy cards stay put while a party card is hovered")
	for card_key: String in stage.cards.keys():
		var settled: Rect2 = stage.card_screen_rect(_actor_of(stage.cards[card_key], stage, allies + enemies))
		_expect(viewport_rect.grow(viewport_rect.size.x * 0.03).encloses(settled), "a fanned card never leaves the screen (%s)" % card_key)
	# Hit-testing uses where the cards stand, so hovering does not make them flicker.
	var home_point: Vector2 = stage.card_screen_rect(allies[1]).get_center()
	_expect(String(stage.pick_actor(home_point, allies).get("battle_uid", "")) == String(allies[1].battle_uid), "picking is stable while a card is lifted")
	# Moving the pointer to another card retargets the fan; leaving returns everyone.
	stage.set_hover_target(allies[0])
	_expect(stage.hover_key == stage.actor_key(allies[0]), "hover retargets to the new card")
	stage.set_hover_target({})
	for fan_frame: int in range(40):
		await process_frame
	for card_key: String in stage.cards.keys():
		_expect(stage.cards[card_key].position.is_equal_approx(stage.cards[card_key].home_position), "%s returns home when the hover ends" % card_key)
	# An attack takes over a fanned card and still lands it back home.
	stage.set_hover_target(allies[1])
	await process_frame
	fast.hit_reaction()
	for fan_frame: int in range(90):
		await process_frame
	_expect(fast.position.is_equal_approx(fast.home_position), "a motion started on a fanned card ends at the home slot")
	stage.set_hover_target({})
	await process_frame
	# The real target picker drives the fan.
	ui.target_picker.begin(allies[0], enemies)
	ui.target_picker._update_pointer(stage.card_screen_rect(enemies[1]).get_center())
	_expect(stage.hover_key == stage.actor_key(enemies[1]), "the target picker hovers the card under the pointer")
	ui.target_picker.close()
	_expect(stage.hover_key == "", "closing target selection ends the hover")
	for fan_frame: int in range(40):
		await process_frame

	# --- Turn marker, white pulse and the card command pop-up -------------------
	_expect(not stage.command_tray.get_node("CommandConsole").visible and not stage.command_tray.get_node("CommandPlaque").visible, "the bottom command console is hidden on Card Stage")
	var tray_hit: bool = false
	for rect: Rect2 in stage.command_tray.get_button_screen_rects(stage.camera):
		tray_hit = tray_hit or stage.command_tray.pick(stage.camera, rect.get_center()) >= 0
	_expect(not tray_hit, "the hidden bottom command buttons can never be picked")
	_expect(stage.turn_marker != null and not stage.turn_marker.visible and stage.active_actor().is_empty(), "no turn marker before anyone acts")
	ui.begin_turn(allies[0])
	await process_frame
	var active_card: Node3D = stage.card_for(allies[0])
	_expect(stage.turn_marker.visible and active_card.turn_active and not stage.card_for(allies[1]).turn_active, "begin_turn marks exactly the acting card")
	_expect(stage.turn_marker.position.y > active_card.position.y + active_card.card_size.y / 2.0, "the brass arrow hangs above the active card")
	_expect(absf(stage.turn_marker.position.x - active_card.position.x) < 0.01, "the arrow stays centred over its card")
	_expect(stage.turn_marker.body.get_child_count() >= 4, "the arrow is a built 3D object (head, trim, collar, finial)")
	var peak: float = 0.0
	for pulse_frame: int in range(100):
		await process_frame
		peak = maxf(peak, active_card._turn_overlay.color.a)
	_expect(peak > 0.05 and peak <= active_card.TURN_PULSE_PEAK + 0.001, "the active card pulses white slowly (peak %.2f)" % peak)
	_expect(is_equal_approx(active_card._turn_overlay.color.r, 1.0) and is_equal_approx(active_card._turn_overlay.color.b, 1.0), "the pulse is white")
	# The pop-up opens only from the active card; the bottom has no commands.
	_expect(not ui.command_menu.visible, "no command pop-up until the card is clicked")
	stage.active_card_clicked.emit(allies[1])
	_expect(not ui.command_menu.visible, "clicking a card that is not acting opens nothing")
	stage.active_card_clicked.emit(allies[0])
	_expect(ui.command_menu.visible and ui.command_menu.get_child(0).get_child_count() == 6, "clicking the active card opens the command buttons (4 working + 逃跑 + 機關)")
	_expect(ui._command_buttons.keys().size() == 6 and ui._command_buttons["skill"].tooltip_text == "出招" and ui._command_buttons["mechanism"].tooltip_text == "機關" and ui._command_buttons["skill"].texture_hover != ui._command_buttons["skill"].texture_normal, "each button has art with a separate glow state")
	var menu_rect := Rect2(ui.command_menu.global_position, ui.command_menu.size)
	_expect(viewport_rect.encloses(menu_rect) and menu_rect.position.x >= stage.card_screen_rect(allies[0]).end.x, "the pop-up sits beside the active card, inside the screen")
	# 逃跑 / 機關 are placeholders: they must do nothing at all.
	var before_flee: Dictionary = {"menu": ui._menu, "on_action": ui.on_action_selection, "log": ui.log_panel.get_parsed_text()}
	ui._command_buttons["flee"].pressed.emit()
	ui._command_buttons["mechanism"].pressed.emit()
	await process_frame
	_expect(ui.command_menu.visible and ui._menu == before_flee.menu and ui.on_action_selection == before_flee.on_action and ui.log_panel.get_parsed_text() == before_flee.log, "逃跑 and 機關 do nothing when pressed")
	var log_plate: Control = ui._stage_hud.get_node("RecentLogPlate")
	_expect(log_plate.get_node("LogBarArt").texture != null and viewport_rect.encloses(Rect2(log_plate.position, log_plate.size)), "the supplied long bar frames the recent log, inside the screen")
	var archive_rect := Rect2(ui._stage_hud.get_node("Archive").position, ui._stage_hud.get_node("Archive").size)
	_expect(Rect2(log_plate.position, log_plate.size).encloses(archive_rect), "the 紀錄 button sits in the bar's slot")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await process_frame
	_expect(not ui.command_menu.visible, "ESC closes the pop-up")
	stage.active_card_clicked.emit(allies[0])
	ui._command_buttons["skill"].pressed.emit()
	await process_frame
	_expect(not ui.command_menu.visible and ui._menu == "skill", "choosing 出招 closes the pop-up and opens the same skill list as before")
	ui._cancel_menu()
	await process_frame
	# Enemy turns are marked through the controller hook.
	ui.present_turn_marker(enemies[1])
	_expect(stage.card_for(enemies[1]).turn_active and not stage.card_for(allies[0]).turn_active and stage.turn_marker.visible, "an enemy turn moves the marker and pulse to the enemy card")
	var foe_card: Node3D = stage.card_for(enemies[1])
	_expect(stage.turn_marker.position.y > foe_card.position.y + foe_card.card_size.y / 2.0, "the marker hangs above the enemy card")
	stage.clear_active_actor()
	_expect(not stage.turn_marker.visible and not foe_card.turn_active, "clearing removes the marker and the pulse")
	_expect(not has_node_recursive_visible(ui, "CardCommandMenu"), "no pop-up outside the player's turn")


	# --- Turn-order line-up: rows follow the REAL queue -------------------------------
	var manager: Node = controller.turn_manager
	manager.player_party = allies
	manager.enemy_party = enemies
	manager.turn_queue = (allies + enemies).duplicate()
	manager.turn_queue.sort_custom(Callable(manager, "_compare_speed"))
	manager.current_index = 0
	var ally_keys: Callable = func() -> Array:
		var row: Array = []
		for key: String in stage.order_keys():
			if not stage.cards[key].is_enemy:
				row.append(key)
		return row
	var enemy_keys: Callable = func() -> Array:
		var row: Array = []
		for key: String in stage.order_keys():
			if stage.cards[key].is_enemy:
				row.append(key)
		return row
	var fast_key: String = stage.actor_key(allies[1])
	var mid_key: String = stage.actor_key(allies[0])
	var slow_key: String = stage.actor_key(allies[2])
	_expect(ally_keys.call() == [fast_key, mid_key, slow_key], "round start: the party row is the real queue order (fastest acts next)")
	_expect(enemy_keys.call() == [stage.actor_key(enemies[1]), stage.actor_key(enemies[0]), stage.actor_key(enemies[2])], "round start: the enemy row is the real queue order")
	# The fastest ally finishes acting: they go to the back of the row.
	manager.current_index = manager.turn_queue.find(allies[1]) + 1
	_expect(ally_keys.call() == [mid_key, slow_key, fast_key], "after acting, a card goes to the far end of its row")
	# Everyone acted: the row is the next round's order (sorted by current speed).
	manager.current_index = manager.turn_queue.size()
	_expect(ally_keys.call() == [fast_key, mid_key, slow_key], "after the whole round, the row is the next round's order")
	# A speed change mid-round must NOT reorder the characters who have yet to act ...
	manager.current_index = manager.turn_queue.find(allies[1]) + 1
	allies[2]["speed"] = 99
	_expect(ally_keys.call() == [mid_key, slow_key, fast_key], "a mid-round speed-up does not move anyone who is still waiting (the real queue is fixed)")
	allies[2]["speed"] = 6
	# ... but it does reorder those who already acted, as the next round will.
	manager.current_index = manager.turn_queue.size()
	allies[0]["speed"] = 1
	_expect(ally_keys.call() == [fast_key, slow_key, mid_key], "a slowed character who already acted drops back for the next round")
	allies[0]["speed"] = 9
	# Defeated characters leave the queue; the row closes up.
	manager.current_index = 0
	allies[0]["hp"] = 0
	_expect(not ally_keys.call().has(mid_key) and ally_keys.call() == [fast_key, slow_key], "a defeated character leaves the line-up")
	allies[0]["hp"] = int(base_ally.hp)
	# Applying an order moves cards: the one that just acted wraps around, the rest slide.
	stage.hover_key = ""
	manager.current_index = 0
	stage._order_signature = ""
	stage.apply_order(stage.order_keys(), false)
	await process_frame
	var before_x: float = stage.cards[fast_key].home_position.x
	manager.current_index = manager.turn_queue.find(allies[1]) + 1
	stage._order_signature = "|".join(stage.order_keys())
	stage.apply_order(stage.order_keys(), true)
	var wrapper: Node3D = stage.cards[fast_key]
	_expect(wrapper.slot_rank == 2 and stage.cards[mid_key].slot_rank == 0 and stage.cards[slow_key].slot_rank == 1, "ranks follow the new order")
	_expect(wrapper.is_relocating() and stage.cards[mid_key].is_relocating(), "cards animate to their new slots")
	_expect(absf(wrapper.home_position.x) > absf(before_x) and absf(stage.cards[mid_key].home_position.x) < absf(stage.cards[slow_key].home_position.x), "the card that acted now stands outermost; the next to act is innermost")
	var always_visible: bool = true
	var min_z: float = wrapper.position.z
	var started_x: float = wrapper.position.x
	for wrap_frame: int in range(60):
		await process_frame
		always_visible = always_visible and wrapper.card_mesh.transparency < 0.01
		min_z = minf(min_z, wrapper.position.z)
	_expect(always_visible, "the card that acted never vanishes: it walks back to the end of the row")
	_expect(min_z < wrapper.home_position.z - 0.5, "on the way it passes behind the other cards (depth dip)")
	# Wait for the slides to finish (by state, not by a frame count that depends on the frame rate).
	var settle_guard: int = 0
	while settle_guard < 1200 and stage.is_lineup_moving():
		await process_frame
		settle_guard += 1
	await process_frame
	for card_key: String in stage.cards.keys():
		_expect(stage.cards[card_key].position.is_equal_approx(stage.cards[card_key].home_position) and is_equal_approx(stage.cards[card_key].card_mesh.transparency, 0.0), "%s settles at its slot, fully visible" % card_key)
	_expect(not has_node_recursive_visible(ui, "CardCommandMenu"), "reordering opens nothing")
	# The row is only rearranged while nothing is moving or attacking.
	stage.busy = true
	stage._order_signature = ""
	manager.current_index = 0
	stage._order_clock = 1.0
	stage._update_order(0.0)
	_expect(stage._order_signature.is_empty(), "no re-ordering while an action is being presented")
	stage.busy = false
	manager.turn_queue = []
	manager.current_index = 0
	stage._order_signature = ""
	var restore_order: Array[String] = [fast_key, mid_key, slow_key]
	stage.apply_order(restore_order, false)
	await process_frame

	# --- Legacy switch and empty slots ------------------------------------------
	ui.set_stage_enabled(false)
	_expect(not stage.visible and ui.ally_panel.visible, "F8 path restores the legacy panels")
	ui.set_stage_enabled(true)
	ui.set_teams([allies[0]], [enemies[0]])
	_expect(stage.cards.size() == 2, "empty slots are not drawn as cards")
	_expect(stage.card_for(allies[0]).slot_rank == 0, "a lone actor takes the only slot")
	# --- Boss presence ---------------------------------------------------------
	var boss_actor: Dictionary = enemies[0].duplicate(true)
	boss_actor["id"] = "molin_yanjiang"
	boss_actor["battle_uid"] = "molin_yanjiang#0"
	var plain_height: float = stage.card_screen_rect(enemies[0]).size.y
	ui.set_teams(allies, [boss_actor])
	var boss_height: float = ui.stage.card_screen_rect(boss_actor).size.y
	_expect(boss_height > plain_height * 1.25, "a boss card stands about a third larger than an ordinary enemy")
	ui.set_teams(allies, enemies)
	stage = ui.stage

	# --- The three-line message box keeps the log's colours ---------------------------
	var colour_log: Node = ui.log_panel
	colour_log._chars_per_sec = 1000000.0
	colour_log.log_system("輪到「測試」行動。")
	colour_log.log("擊中 測試，造成 [color=#ffd447]24[/color] 點傷害！")
	for wait_frame: int in range(120):
		await process_frame
		if not colour_log._typing and colour_log._queue.is_empty():
			break
	var boxed: String = colour_log.recent_bbcode(colour_log.get_parsed_text(), 3)
	_expect(boxed.contains("[color=#7fd0ff]輪到「測試」行動。[/color]"), "system lines keep their colour in the message box")
	_expect(boxed.contains("[color=#ffd447]24[/color]"), "damage numbers keep their colour in the message box")

	# --- OS bubble heights are staggered, sticky, and the tail tilts with them ---------
	var level_a: int = ui._bubble_level_for(allies[0], false)
	var level_b: int = ui._bubble_level_for(allies[1], false)
	var level_c: int = ui._bubble_level_for(allies[2], false)
	_expect(level_a != level_b and level_b != level_c and level_a != level_c, "speakers of one camp get different box heights")
	manager.current_index = 0
	stage._order_signature = ""
	stage.apply_order(stage.order_keys(), false)
	_expect(ui._bubble_level_for(allies[0], false) == level_a and ui._bubble_level_for(allies[1], false) == level_b, "a speaker's box height never changes after a reshuffle")
	var ally_slot: Control = ui.ally_slots[0]
	ui._actor_bubble_boxes.get(ui._get_bubble_key_for_slot(ally_slot))
	var ally_box: PanelContainer = ui._actor_bubble_boxes.get(ui._get_bubble_key_for_slot(ally_slot))
	if ally_box != null:
		ui._position_bubble_on_portrait(ally_slot, ally_box)
		var ally_tail: Control = ally_box.get_node_or_null("Tail")
		var polygon: PackedVector2Array = ally_tail.polygon_global()
		_expect(polygon[1].is_equal_approx(stage.card_portrait_center(allies[0])), "the tail tip is the portrait centre")
		_expect(not is_equal_approx(polygon[1].y, (polygon[0].y + polygon[2].y) / 2.0), "the tail is tilted toward the portrait, not simply shifted")

	# --- The boss shell breaks (slow motion, radial shards, a few bounce) -------------------
	var shell_boss: Dictionary = enemies[0].duplicate(true)
	shell_boss["id"] = "molin_yanjiang"
	shell_boss["battle_uid"] = "molin_yanjiang#9"
	ui.set_teams(allies, [shell_boss])
	stage = ui.stage
	var shell_card: Node3D = stage.card_for(shell_boss)
	var break_done: Array = [false]
	var break_runner := func() -> void:
		await stage.present_entangle_break(shell_boss)
		break_done[0] = true
	break_runner.call()
	await process_frame
	var burst: Node3D = null
	for child: Node in stage.fx_root.get_children():
		if child.has_method("piece_count"):
			burst = child
	_expect(burst != null and burst.piece_count() >= 60, "the shell breaks into many triangular pieces")
	_expect(is_equal_approx(Engine.time_scale, stage.BREAK_SLOWMO_SCALE), "the shatter runs in slow motion")
	if burst != null:
		var sample: Node3D = burst.get_child(0)
		var before_distance: float = (sample.global_position - shell_card.global_position).length()
		for slow_frame: int in range(20):
			await process_frame
		_expect((sample.global_position - shell_card.global_position).length() > before_distance, "pieces fly outward from the impact")
		_expect(burst.bouncy_count() > 0 and burst.bouncy_count() < burst.piece_count() / 2, "only some pieces are the bouncing kind")
	var wait_guard: int = 0
	while not break_done[0] and wait_guard < 60 * 8:
		await process_frame
		wait_guard += 1
	_expect(break_done[0] and is_equal_approx(Engine.time_scale, 1.0), "normal speed returns after the slow motion")
	_expect(shell_card.position.is_equal_approx(shell_card.home_position), "the boss has slowly come back to its place")
	ui.set_teams(allies, enemies)
	stage = ui.stage

	# --- Speech boxes of both camps never sit on top of each other --------------------
	ui._setup_actor_bubble_labels()
	ui.show_actor_line_for_actor(allies[0], "出手吧！這一式你接得住嗎？")
	ui.show_actor_line_for_actor(enemies[0], "休想從這裡過去！")
	await create_timer(0.25).timeout
	var shown_boxes: Array = []
	for bubble_box: PanelContainer in ui._actor_bubble_boxes.values():
		if bubble_box.visible:
			shown_boxes.append(Rect2(bubble_box.global_position, bubble_box.size))
	_expect(shown_boxes.size() >= 2, "both speakers' boxes are showing")
	for first_index: int in range(shown_boxes.size()):
		for second_index: int in range(first_index + 1, shown_boxes.size()):
			_expect(not (shown_boxes[first_index] as Rect2).intersects(shown_boxes[second_index]), "speech boxes do not overlap")

	_stage_checks_completed = true


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
			_expect(peak_distance > 2.0 and absf(peak_z_back) >= 1.0, "attack lunges toward the target with a clear Z movement (depth), not just sideways")
		"hit":
			_expect(peak_z_back <= -1.4, "heavy hit knocks the card back into depth")
		"dodge":
			_expect(peak_z_back <= -1.0 and peak_distance > 1.0, "dodge slips sideways and deeper")
		"guard":
			_expect(peak_z_back <= -0.3 and peak_distance < 0.6, "guard braces in place")


func has_node_recursive_visible(root_node: Node, node_name: String) -> bool:
	var found: Node = root_node.find_child(node_name, true, false)
	return found != null and found is CanvasItem and (found as CanvasItem).visible


func _check_enemy_art_table() -> void:
	var expected: Array = ["molin_yanjiang", "molin_yanjiang_phase2", "fidgety_sewer_fish", "broken_string_tone_phantom", "turbid_tone_phantom", "broken_talisman_tone_phantom", "bitterness_tone_phantom", "echo_tone_phantom", "fixation_tone_phantom", "yumei_sewer_bat", "yumei_sewer_rat", "bamboo_wild_boar", "bamboo_macaque", "bamboo_poison_snake", "bamboo_bobcat"]
	for enemy_id: String in expected:
		var entry: Dictionary = CardStageArtScript.entry_for({"id": enemy_id})
		_expect(not entry.is_empty() and FileAccess.file_exists(entry.path), "%s has supplied art that exists" % enemy_id)
		var texture: Texture2D = load(entry.path) as Texture2D
		_expect(texture != null and texture.get_width() <= 1024, "%s art loads, at most 1024 px wide" % enemy_id)
		for window: Vector2 in [Vector2(2.0, 1.55), Vector2(1.5, 1.15)]:
			var layout: Dictionary = CardStageArtScript.cover_layout(entry, window, float(texture.get_width()) / float(texture.get_height()))
			var half: Vector2 = layout.size / 2.0
			_expect(layout.size.x >= window.x - 0.0001 and layout.size.y >= window.y - 0.0001, "%s art covers the whole window" % enemy_id)
			_expect(absf(layout.center.x) + window.x / 2.0 <= half.x + 0.0001 and absf(layout.center.y) + window.y / 2.0 <= half.y + 0.0001, "%s art never exposes an empty edge" % enemy_id)
	_expect(CardStageArtScript.entry_for({"id": "x", "portrait_path": "res://assets/Enemy/wild_boar.png"}).path.ends_with("enemy_boar.webp"), "portrait file names resolve to the new art")


func _check_backgrounds() -> void:
	var script: Script = load("res://scripts/presentation/StageBattleUI.gd")
	var cases: Dictionary = {
		{"battle_tag": "yuheng_old_fighter_spar", "zone_id": "yuheng_old_fighter_spar"}: "bg_yuheng_arena.webp",
		{"battle_tag": "yuheng_sewer_random", "zone_id": "yuheng_sewer"}: "bg_sewer.webp",
		{"zone_id": "yuheng_bamboo_outskirts"}: "bg_bamboo.webp",
		{"battle_id": "boss_yuheng_molin_yanjiang_phase1"}: "stalactite_stage.png",
		{"battle_tag": "something_else"}: "Background_defult.jpg",
	}
	for context: Dictionary in cases.keys():
		var path: String = script.resolve_stage_background(context)
		_expect(path.ends_with(String(cases[context])) and ResourceLoader.exists(path), "background for %s is %s" % [str(context), cases[context]])
