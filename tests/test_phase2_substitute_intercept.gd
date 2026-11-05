extends SceneTree

const EntityFactory = preload("res://scripts/battlescripts/StageEntityFactory.gd")
const Phase2Profile = preload("res://scripts/db/BattlePhaseProfileDB.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	_expect(fixture.prepared, "stage fixture prepares")
	if fixture.prepared:
		await _check_phase2_interception(fixture)
	fixture.queue_free()
	await process_frame
	for failure: String in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: Phase 2 guest area interception")
	quit(0 if failures.is_empty() else 1)


func _check_phase2_interception(fixture: Node) -> void:
	var context: Dictionary = fixture.build_preview_context()
	var ally: Dictionary = context.player_party[0]
	var second: Dictionary = ally.duplicate(true)
	second["id"] = "test_shumian"
	second["battle_uid"] = "test_shumian"
	second["name"] = "白書眠"
	var enemy: Dictionary = Phase2Profile.make_molin_phase2_context([ally, second]).enemy_party[0]
	var guest: Dictionary = Phase2Profile.ZUOYIN_STALACTITE_GUEST_PROFILE.duplicate(true)
	var guest_turn: Dictionary = {
		"id": guest.id, "hp": 1, "speed": guest.speed, "is_guest": true, "is_scripted_guest": true
	}
	fixture.controller.player_party = [ally, second]
	fixture.controller.enemy_party = [enemy]
	fixture.controller.turn_manager.player_party = [ally, second]
	fixture.controller.turn_manager.enemy_party = [enemy]
	fixture.controller.turn_manager.guest_actor = guest_turn
	fixture.controller.turn_manager.turn_queue = [ally, guest_turn, second, enemy]
	fixture.ui.set_teams([ally, second], [enemy])
	fixture.ui.set_guest_presentation(guest)
	var stage: Node3D = fixture.ui.stage
	await stage.wait_for_lineup_settled()
	var protected: Node3D = stage.card_for(second)
	var guest_card: Node3D = stage.card_for(guest)
	_expect(protected != null and guest_card != null, "Phase 2 has both ShuMian and guest cards")
	if protected == null or guest_card == null:
		return
	var protected_home: Vector3 = protected.position
	var guest_home: Vector3 = guest_card.position
	var single_talisman: RefCounted = EntityFactory.create({
		"entity_type": "substitute_talisman", "display_name": "替身符", "faction": "player",
		"card_kind": "token", "card_config": {"art": "res://assets/sprites/battle_cards/substitute_talisman.webp", "card_size": Vector2(1.955, 3.1912)}
	}, String(second.id))
	single_talisman.set("entity_id", "test_phase2_single_substitute")
	var single_token: Node3D = stage.spawn_stage_entity_card(single_talisman, protected_home + Vector3(-0.9, 0.0, 0.15))
	await stage.present_attack(enemy, second, {"fx_style": "water_bullet"}, {
		"hit": false, "blocked": true, "blocker_type": "substitute_talisman",
		"blocker_entity_id": "test_phase2_single_substitute"
	})
	_expect(single_token.position.x > protected.position.x, "single-target interception still flies with the guest present")
	stage.remove_stage_entity_card(single_talisman)
	await process_frame
	var talisman: RefCounted = EntityFactory.create({
		"entity_type": "substitute_talisman", "display_name": "替身符", "faction": "player",
		"card_kind": "token", "card_config": {"art": "res://assets/sprites/battle_cards/substitute_talisman.webp", "card_size": Vector2(1.955, 3.1912)}
	}, String(second.id))
	talisman.set("entity_id", "test_phase2_substitute")
	var token_home: Vector3 = protected_home + Vector3(-0.9, 0.0, 0.15)
	var token: Node3D = stage.spawn_stage_entity_card(talisman, token_home)
	var order_before: Array = stage.order_keys()
	var events: Array = [
		{"target": ally, "hit": true, "damage": 12},
		{"target": second, "hit": false, "blocker_type": "substitute_talisman", "blocker_entity_id": "test_phase2_substitute"},
	]
	fixture.ui.play_enemy_area_interceptions(enemy, events)
	var timeout: int = Time.get_ticks_msec() + 8000
	while not token._substitute_intercepted and Time.get_ticks_msec() < timeout:
		await process_frame
	_expect(token._substitute_intercepted and stage.busy, "collision holds the action before the card breaks")
	_expect(token._intercept_rim != null and token._intercept_rim.visible, "intercepting substitute has the reference gold rim")
	var intercept_sound_found: bool = false
	for child: Node in token.get_children():
		if child is AudioStreamPlayer and child.stream.resource_path.ends_with("SE_substitute_intercept.ogg"):
			intercept_sound_found = true
			_expect(is_equal_approx(child.volume_db, 2.698), "interception sound gains 8 dB over the battle baseline")
	_expect(intercept_sound_found, "new audio starts on the substitute collision")
	while stage.busy and Time.get_ticks_msec() < timeout:
		await process_frame
	var front: Node3D = stage.card_for(ally)
	if guest_card.position.x > front.position.x:
		front = guest_card
	if protected.position.x > front.position.x:
		front = protected
	_expect(token.position.x > front.position.x + (front.card_size.x + token.card_size.x) * 0.5,
		"substitute reaches the front of a party with ZuoYin")
	_expect(protected.position.is_equal_approx(protected_home), "protected actor does not dodge")
	_expect(guest_card.position.is_equal_approx(guest_home), "guest remains in his ADB slot")
	_expect(stage.order_keys() == order_before, "interception does not reorder the Phase 2 ADB")
	_expect(not stage.busy, "interception completes before the next action")
	_expect(token._break_complete and not token.card_mesh.visible, "area action waits until the intact card and every fragment are gone")
	await stage.present_substitute_break(talisman)
	_expect(not stage.busy and token._break_complete, "later logical cleanup does not replay the break")
	stage.remove_stage_entity_card(talisman)
	talisman.set("entity_id", "test_phase2_tail_substitute")
	token = stage.spawn_stage_entity_card(talisman, token_home)
	(events[1] as Dictionary)["blocker_entity_id"] = "test_phase2_tail_substitute"
	await stage.present_enemy_area(enemy, {"fx_style": "staff_sweep"}, events)
	_expect(token.position.x > front.position.x + (front.card_size.x + token.card_size.x) * 0.5,
		"tail sweep still sends the substitute to the front with the guest present")
	_expect(stage.order_keys() == order_before, "tail sweep leaves the Phase 2 ADB unchanged")
	_expect(token._break_complete and not token.card_mesh.visible, "tail sweep also waits for the complete shatter")
	stage.remove_stage_entity_card(talisman)
