extends SceneTree
## Focused presentation contract for support cards (僚卡): same ADB slot,
## distinct return/break endings, and no hand-off while a break is still visible.

const EntityFactory = preload("res://scripts/battlescripts/StageEntityFactory.gd")
const SpatialSeams = preload("res://scripts/presentation/CardStageSpatialSeams.gd")

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
	_expect(is_equal_approx(substitute_card.card_back.mesh.size.z, 0.02) and is_equal_approx(substitute_card.card_back.position.z, -0.02), "support card face and backing form a thinner stack")
	var substitute_result: Dictionary = {"hit": false, "blocked": true, "blocker_type": "substitute_talisman", "blocker_entity_id": "test_substitute"}
	_expect(stage._intervention_for_result({"strikes": [substitute_result]}).get("type") == "substitute_talisman", "multi-strike metadata also resolves the substitute")
	_expect(stage._intervention_for_result({"hit": false, "strikes": [substitute_result, substitute_result]}).get("type") == "substitute_talisman", "fully intercepted multi-strike can use the shared support-card route")
	_expect(stage._intervention_for_result({"hit": true, "strikes": [substitute_result, {"hit": true, "damage": 10}]}).is_empty(), "mixed multi-strike damage must not be portrayed as full protection")
	stage.present_attack(enemy, ally, spear, substitute_result)
	var break_deadline: int = Time.get_ticks_msec() + 8000
	while not substitute_card._break_playing and Time.get_ticks_msec() < break_deadline:
		await process_frame
	_expect(not substitute_card.position.is_equal_approx(substitute_home), "sacrificial card stays at interception point until break")
	_expect(substitute_card.position.x > protected.position.x + stage._half_extent(protected), "substitute stands just beyond the leading ally's turned face")
	_expect(stage.entity_screen_rect("test_substitute").get_center().x > stage.card_screen_rect(ally).get_center().x, "substitute stands to the right of the leading ally in the camera view")
	_expect(protected.position.is_equal_approx(protected_home), "substitute protects actor without ordinary hit motion")
	_expect(stage.order_keys() == order_before, "substitute flight does not reorder the ADB")
	_expect(stage.busy, "interception and break share the same blocking presentation")
	while substitute_card.find_children("*", "Node3D", false, false).all(func(child: Node) -> bool: return child.get_script() != SpatialSeams) and Time.get_ticks_msec() < break_deadline:
		await process_frame
	_expect(stage.busy, "break remains a blocking action while spatial slashes and fragments play")
	var cut_found: bool = false
	for child: Node in substitute_card.get_children():
		if child.get_script() == SpatialSeams:
			cut_found = true
			var cut: MeshInstance3D = child._beams[0].layers[0]
			var cut_material: StandardMaterial3D = cut.material_override as StandardMaterial3D
			_expect(not cut_material.no_depth_test and cut_material.render_priority == 0, "spatial cuts are sorted behind a nearer ally card")
			break
	_expect(cut_found, "substitute break creates spatial cuts")
	await create_timer(1.2).timeout
	_expect(stage.busy, "substitute remains blocking while the cut fragments are visible")
	var shards: Node3D = substitute_card._shard_burst
	_expect(shards != null and shards.piece_count() > 7, "spatial slashes leave more than seven irregular fragments")
	_expect(not substitute_card.card_mesh.visible and not substitute_card.card_back.visible, "intact substitute face and back disappear when the pieces separate")
	if shards != null and shards.get_child_count() > 0:
		var shard_material: StandardMaterial3D = shards.get_child(0).material_override as StandardMaterial3D
		var shard_colour: Color = shard_material.albedo_color
		_expect(shard_colour.b <= shard_colour.r, "substitute shards use paper and ink rather than violet")
		_expect(shard_material.albedo_texture != null, "spatial fragments keep the cut card artwork")
		_expect(shard_material.render_priority == 0, "spatial fragments remain depth-sorted with other cards")
	var burn_found: bool = false
	for child: Node in substitute_card.get_children():
		if child.name == "BurnSheet" or child.has_method("ray_burst"):
			burn_found = true
	_expect(not burn_found, "spatially shattered substitute does not ignite or recreate a burn sheet")
	var shard_ref: WeakRef = weakref(shards) if shards != null else null
	var guard: int = 0
	while stage.busy and Time.get_ticks_msec() < break_deadline:
		await process_frame
		guard += 1
	_expect(not stage.busy, "break eventually releases the action")
	_expect(shard_ref != null and shard_ref.get_ref() == null, "the stage waits for every fragment to vanish before hand-off")
	_expect(not substitute_card.card_mesh.visible, "card is fully gone before the action is released")
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
	var front: Node3D = first_card if first_card.position.x > second_card.position.x else second_card
	_expect(token.position.x > front.position.x + stage._half_extent(front), "shared substitute blocks just beyond the leading card's turned face")
	var front_actor: Dictionary = ally if front == first_card else second
	_expect(stage.entity_screen_rect("test_shared_substitute").get_center().x > stage.card_screen_rect(front_actor).get_center().x, "shared substitute remains to the right of the front ally in the camera view")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "shared interception restores normal game speed")
	stage.remove_stage_entity_card(substitute)
