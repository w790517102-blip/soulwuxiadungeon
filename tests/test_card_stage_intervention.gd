extends SceneTree
## Focused presentation contract for support cards (僚卡): same ADB slot,
## distinct return/break endings, and no hand-off while a break is still visible.

const EntityFactory = preload("res://scripts/battlescripts/StageEntityFactory.gd")

var _failures: Array[String] = []
var _assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _entity(kind: String, entity_id: String, owner_id: String) -> RefCounted:
	var art: String = "res://assets/sprites/battle_cards/liuyu_sheath.webp" if kind == "sheath_card" else "res://assets/sprites/battle_cards/substitute_talisman.webp"
	var config: Dictionary = {
		"entity_type": kind,
		"display_name": "持鞘" if kind == "sheath_card" else "替身符",
		"faction": "player",
		"card_kind": "token",
		"card_config": {"art": art, "card_size": Vector2(1.955, 3.1912)},
	}
	var entity: RefCounted = EntityFactory.create(config, owner_id)
	entity.set("entity_id", entity_id)
	return entity


func _run() -> void:
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	_expect(fixture.prepared, "card stage fixture prepares")
	if fixture.prepared:
		await _check_interventions(fixture)
	fixture.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: %d assertions; card stage support-card intervention" % _assertions)
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check_interventions(fixture: Node) -> void:
	var context: Dictionary = fixture.build_preview_context()
	var ally: Dictionary = context.player_party[0]
	var enemy: Dictionary = context.enemy_party[0]
	fixture.controller.player_party = [ally]
	fixture.controller.enemy_party = [enemy]
	fixture.controller.ruleset = context.ruleset
	fixture.ui.set_teams([ally], [enemy])
	var stage: Node3D = fixture.ui.stage
	var protected: Node3D = stage.card_for(ally)
	var protected_home: Vector3 = protected.home_position
	var order_before: Array = stage.order_keys()
	var spear: Dictionary = {"weapon_type": "槍"}

	var sheath: RefCounted = _entity("sheath_card", "test_sheath", String(ally.get("id", "")))
	var sheath_home: Vector3 = protected_home + Vector3(-1.0, 0.0, 0.15)
	var sheath_card: Node3D = stage.spawn_stage_entity_card(sheath, sheath_home)
	var sheath_result: Dictionary = {"hit": false, "blocked": true, "blocker_type": "sheath_card", "blocker_entity_id": "test_sheath"}
	_expect(stage._intervention_for_result(sheath_result).get("type") == "sheath_card", "sheath block selects the shared intervention route")
	stage.present_attack(enemy, ally, spear, sheath_result)
	await create_timer(0.7).timeout
	_expect(protected.position.is_equal_approx(protected_home) and protected.rotation.is_equal_approx(protected.home_rotation), "protected actor remains composed during the intercepted hit")
	var sheath_guard: int = 0
	while stage.busy and sheath_guard < 300:
		await process_frame
		sheath_guard += 1
	_expect(sheath_card.position.is_equal_approx(sheath_home), "sheath returns to its original slot after collision")
	_expect(sheath_card.scale.is_equal_approx(Vector3.ONE), "sheath loses its temporary draw-out scale")
	_expect(protected.position.is_equal_approx(protected_home), "protected actor does not react as though struck by the sheath-blocked blow")
	_expect(stage.order_keys() == order_before, "sheath intervention does not reorder the ADB")
	_expect(not stage.busy, "sheath animation finishes before the stage releases the action")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "collision slow motion restores normal game speed before hand-off")
	await stage.present_attack(enemy, ally, {}, sheath_result)
	_expect(sheath_card.position.is_equal_approx(sheath_home), "generic attack trail also ends with the sheath back in its slot")
	await stage.present_enemy_area(enemy, {"fx_style": "staff_sweep"}, [{"target": ally, "hit": false, "crit": false, "blocker_type": "sheath_card", "blocker_entity_id": "test_sheath"}])
	_expect(sheath_card.position.is_equal_approx(sheath_home), "sheath also returns after intercepting an area sweep")
	_expect(protected.position.is_equal_approx(protected_home), "area interception does not make the protected actor dodge")
	_expect(not stage.busy, "area interception waits for sheath return before hand-off")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "area interception also restores normal game speed")
	stage.remove_stage_entity_card(sheath)
	await process_frame

	var substitute: RefCounted = _entity("substitute_talisman", "test_substitute", String(ally.get("id", "")))
	var substitute_home: Vector3 = protected_home + Vector3(-1.0, 0.0, 0.15)
	var substitute_card: Node3D = stage.spawn_stage_entity_card(substitute, substitute_home)
	var substitute_result: Dictionary = {"hit": false, "blocked": true, "blocker_type": "substitute_talisman", "blocker_entity_id": "test_substitute"}
	_expect(stage._intervention_for_result({"strikes": [substitute_result]}).get("type") == "substitute_talisman", "multi-strike metadata also resolves the substitute")
	_expect(stage._intervention_for_result({"hit": false, "strikes": [substitute_result, substitute_result]}).get("type") == "substitute_talisman", "fully intercepted multi-strike can use the shared support-card route")
	_expect(stage._intervention_for_result({"hit": true, "strikes": [substitute_result, {"hit": true, "damage": 10}]}).is_empty(), "mixed multi-strike damage must not be portrayed as full protection")
	await stage.present_attack(enemy, ally, spear, substitute_result)
	_expect(not substitute_card.position.is_equal_approx(substitute_home), "sacrificial card stays at interception point until break")
	_expect(protected.position.is_equal_approx(protected_home), "substitute protects actor without ordinary hit motion")
	_expect(stage.order_keys() == order_before, "substitute flight does not reorder the ADB")
	stage.present_substitute_break(substitute)
	await create_timer(0.2).timeout
	_expect(stage.busy, "break remains a blocking action while cracks and shards play")
	await create_timer(2.0).timeout
	_expect(stage.busy and substitute_card._burn_sheet == null, "substitute remains on stage through the light-in-the-cuts phase and the break")
	var shards: Node3D = substitute_card._shard_burst
	_expect(shards != null and shards.piece_count() == 7, "substitute falls apart along its tangram cuts into seven pieces")
	if shards != null and shards.get_child_count() > 0:
		var shard_colour: Color = (shards.get_child(0).material_override as StandardMaterial3D).albedo_color
		_expect(shard_colour.b <= shard_colour.r, "substitute shards use paper and ink rather than violet")
	await create_timer(1.2).timeout
	_expect(stage.busy and substitute_card._burn_sheet != null, "burn sheet starts after the one-second broken-paper pause")
	if substitute_card._burn_sheet != null:
		var burn_material: ShaderMaterial = substitute_card._burn_sheet.material_override
		var flame_edge: Color = burn_material.get_shader_parameter("flame_edge")
		_expect(flame_edge.r > flame_edge.b * 3.0, "substitute burn front is red, not purple")
	var red_fire_found: bool = false
	for child: Node in substitute_card.get_children():
		if child.has_method("ray_burst") and String(child.get("palette")) == "red":
			red_fire_found = true
	_expect(red_fire_found, "substitute sparks and fire rays use the red palette")
	var guard: int = 0
	while stage.busy and guard < 600:
		await process_frame
		guard += 1
	_expect(not stage.busy, "break eventually releases the action")
	_expect(substitute_card.card_mesh.transparency > 0.9, "card is fully gone before the action is released")
	stage.remove_stage_entity_card(substitute)
	await process_frame
	await _check_two_actor_area(fixture, ally, enemy)


func _check_two_actor_area(fixture: Node, ally: Dictionary, enemy: Dictionary) -> void:
	var second: Dictionary = ally.duplicate(true)
	second["id"] = "test_second_protected"
	second["battle_uid"] = "test_second_protected"
	second["name"] = "第二名受保護者"
	fixture.controller.player_party = [ally, second]
	fixture.controller.turn_manager.player_party = [ally, second]
	fixture.controller.turn_manager.turn_queue = [ally, second, enemy]
	fixture.ui.set_teams([ally, second], [enemy])
	var stage: Node3D = fixture.ui.stage
	await stage.wait_for_lineup_settled()
	var first_card: Node3D = stage.card_for(ally)
	var second_card: Node3D = stage.card_for(second)
	_expect(first_card != null and second_card != null, "two protected actors are present on the card stage")
	if first_card == null or second_card == null:
		return
	var first_home: Vector3 = first_card.home_position
	var second_home: Vector3 = second_card.home_position
	var substitute: RefCounted = _entity("substitute_talisman", "test_shared_substitute", String(ally.get("id", "")))
	var token_home: Vector3 = (first_home + second_home) * 0.5 + Vector3(-0.9, 0.0, 0.15)
	var token: Node3D = stage.spawn_stage_entity_card(substitute, token_home)
	var events: Array = [
		{"target": ally, "hit": false, "crit": false, "blocker_type": "substitute_talisman", "blocker_entity_id": "test_shared_substitute"},
		{"target": second, "hit": false, "crit": false, "blocker_type": "substitute_talisman", "blocker_entity_id": "test_shared_substitute"},
	]
	stage.present_enemy_area(enemy, {"fx_style": "staff_sweep"}, events)
	await create_timer(0.7).timeout
	_expect(first_card.position.is_equal_approx(first_home), "first protected actor does not dodge the shared area interception")
	_expect(second_card.position.is_equal_approx(second_home), "second protected actor does not dodge the shared area interception")
	var guard: int = 0
	while stage.busy and guard < 300:
		await process_frame
		guard += 1
	_expect(not token.position.is_equal_approx(token_home), "one substitute steps forward between the sweep and both protected actors")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "shared interception restores normal game speed")
	stage.remove_stage_entity_card(substitute)
