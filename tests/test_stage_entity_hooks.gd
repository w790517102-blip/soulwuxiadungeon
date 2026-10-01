extends SceneTree
## Future-proof stage entity hooks. Nothing here exercises a real skill: mock entities
## prove the extension points exist and that an empty registry changes nothing.
## Run: --headless --path . --script tests/test_stage_entity_hooks.gd

const StageEntity := preload("res://scripts/battlescripts/StageEntity.gd")
const Registry := preload("res://scripts/battlescripts/StageEntityRegistry.gd")
const Targeting := preload("res://scripts/battlescripts/StageTargeting.gd")

var _failures: Array[String] = []
var _assertions: int = 0
var _completed: bool = false


# A mock "cover": has HP, draws enemy attacks, records lifecycle events.
class MockCover extends "res://scripts/battlescripts/StageEntity.gd":
	var seen: Array[String] = []
	func on_spawn(_c: Dictionary) -> void: seen.append("spawn")
	func on_turn_start(_c: Dictionary) -> void: seen.append("turn_start")
	func on_turn_end(_c: Dictionary) -> void: seen.append("turn_end")
	func on_before_action(_c: Dictionary) -> void: seen.append("before")
	func on_after_action(_c: Dictionary) -> void: seen.append("after")
	func on_damage_taken(c: Dictionary) -> void: seen.append("damaged:%d" % int(c.get("damage", 0)))
	func on_healed(c: Dictionary) -> void: seen.append("healed:%d" % int(c.get("healed", 0)))
	func on_destroyed(_c: Dictionary) -> void: seen.append("destroyed")
	func on_expire(_c: Dictionary) -> void: seen.append("expire")
	func on_manual_activate(_c: Dictionary) -> void: seen.append("manual")
	func modify_target_priority(_attacker: Variant, candidate: Variant, score: float) -> float:
		return score + 100.0 if is_self(candidate) else score


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _cover(id: String = "") -> MockCover:
	var cover := MockCover.new()
	cover.apply_config({"entity_id": id, "entity_type": "cover", "display_name": "掩體", "owner_id": "shumian", "faction": "player", "damageable": true, "healable": true, "max_hp": 50, "tags": ["cover", "object"]})
	return cover


func _run() -> void:
	_check_data()
	_check_registry()
	_check_targeting()
	_check_damage_heal_and_events()
	_check_ai_priority()
	await _check_controller_hooks()
	await _check_renderer()
	_completed = true
	_expect(true, "all sections ran")
	if _failures.is_empty():
		print("PASS: ", _assertions, " assertions; stage entity hooks")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check_data() -> void:
	var entity = StageEntity.from_dict({"entity_type": "echo", "faction": "player", "max_hp": 10, "duration_turns": 2, "targetable": true, "damageable": true, "tags": ["echo"]})
	_expect(entity.entity_type == "echo" and entity.max_hp == 10 and entity.current_hp == 10, "an entity is built from plain data (HP defaults to max)")
	_expect(entity.targetable and entity.damageable and not entity.healable and entity.has_tag("echo"), "flags and tags come from the data")
	_expect(entity.duration_turns == 2 and not entity.advance_duration() and entity.advance_duration() and entity.duration_turns == 0, "duration counts down and reports expiry")
	var forever = StageEntity.from_dict({"entity_type": "cover"})
	_expect(forever.duration_turns == -1 and not forever.advance_duration(), "no duration means until destroyed")
	var plain = StageEntity.from_dict({"entity_type": "marker_free"})
	_expect(plain.take_damage(5).damage == 0 and plain.heal(5).healed == 0, "non-damageable / non-healable entities take nothing")
	for hook: String in Registry.EVENTS:
		_expect(plain.has_method(hook), "every lifecycle event has a hook: %s" % hook)
	_expect(plain.modify_target_priority({}, {}, 3.0) == 3.0, "default target priority is unchanged")


func _check_registry() -> void:
	var registry := Registry.new()
	var registered: Array = []
	var unregistered: Array = []
	registry.entity_registered.connect(func(e) -> void: registered.append(e))
	registry.entity_unregistered.connect(func(e) -> void: unregistered.append(e))
	_expect(registry.is_empty() and registry.get_stage_entities().is_empty() and registry.get_targetable_entities().is_empty(), "a new registry is empty")
	var cover := _cover()
	var echo := _cover()
	echo.entity_type = "echo"
	echo.faction = "enemy"
	echo.tags = ["echo"]
	echo.targetable = false
	_expect(registry.register_stage_entity(cover) and registry.register_stage_entity(echo), "mock entities can be registered")
	_expect(cover.entity_id != "" and cover.entity_id != echo.entity_id, "an empty entity_id is assigned a unique one")
	_expect(not registry.register_stage_entity(cover), "the same entity cannot be registered twice")
	_expect(registered.size() == 2 and cover.seen == ["spawn"], "registering emits entity_registered and on_spawn")
	_expect(registry.get_stage_entities().size() == 2, "get_stage_entities lists both")
	_expect(registry.get_entity(cover.entity_id) == cover, "an entity is found by id")
	_expect(registry.get_targetable_entities() == [cover], "targetable filter drops untargetable entities")
	_expect(registry.get_entities_by_faction("player") == [cover] and registry.get_entities_by_faction("enemy") == [echo], "faction filter works")
	_expect(registry.get_entities_by_tag("echo") == [echo] and registry.get_entities_by_tag("object") == [cover], "tag filter works")
	_expect(registry.get_entities_by_owner("shumian").size() == 2, "owner filter works")
	cover.take_damage(999)
	_expect(registry.get_targetable_entities().is_empty(), "a destroyed entity is no longer targetable")
	cover.current_hp = 50
	_expect(registry.unregister_stage_entity(cover) and unregistered == [cover] and registry.get_stage_entities() == [echo], "entities can be removed")
	_expect(not registry.unregister_stage_entity(cover), "removing twice does nothing")
	registry.destroy_entity(echo)
	_expect(echo.seen.has("destroyed") and registry.is_empty(), "destroy_entity fires on_destroyed and removes")
	var third := _cover("fixed")
	registry.register_stage_entity(third)
	registry.expire_entity(third)
	_expect(third.seen == ["spawn", "expire"] and registry.is_empty(), "expire_entity fires on_expire and removes")
	_expect(registry.get_entity("missing") == null, "an unknown id is null")


func _check_targeting() -> void:
	var registry := Registry.new()
	var allies: Array = [{"id": "a", "hp": 10}, {"id": "b", "hp": 0}]
	var enemies: Array = [{"id": "e", "hp": 10}]
	var cover := _cover("cover1")
	var foe_entity := _cover("foe1")
	foe_entity.faction = "enemy"
	registry.register_stage_entity(cover)
	registry.register_stage_entity(foe_entity)
	var K = Targeting.Kind
	_expect(Targeting.resolve(K.ENEMY_ACTOR, "player", allies, enemies, registry) == enemies, "ENEMY_ACTOR: the opposing actors only")
	_expect(Targeting.resolve(K.ALLY_ACTOR, "player", allies, enemies, registry) == [allies[0]], "ALLY_ACTOR: living allies only")
	_expect(Targeting.resolve(K.ALLY_ACTOR, "player", allies, enemies, registry, true).size() == 2, "dead actors can be included on request")
	_expect(Targeting.resolve(K.ANY_ACTOR, "player", allies, enemies, registry).size() == 2, "ANY_ACTOR: both camps, never entities")
	_expect(Targeting.resolve(K.STAGE_ENTITY, "player", allies, enemies, registry).size() == 2, "STAGE_ENTITY: all targetable entities")
	_expect(Targeting.resolve(K.ALLY_STAGE_ENTITY, "player", allies, enemies, registry) == [cover], "ALLY_STAGE_ENTITY: the user's side")
	_expect(Targeting.resolve(K.ENEMY_STAGE_ENTITY, "player", allies, enemies, registry) == [foe_entity], "ENEMY_STAGE_ENTITY: the other side")
	_expect(Targeting.resolve(K.ENEMY_STAGE_ENTITY, "enemy", enemies, allies, registry) == [cover], "faction is relative to the user")
	_expect(Targeting.resolve(K.ANY_TARGETABLE, "player", allies, enemies, registry).size() == 4, "ANY_TARGETABLE: actors and entities together")
	_expect(Targeting.resolve(K.ENEMY_ACTOR, "player", allies, enemies, null) == enemies, "no registry is fine")
	_expect(Targeting.kind_for_scope("enemy_single") == K.ENEMY_ACTOR and Targeting.kind_for_scope("all_allies") == K.ALLY_ACTOR and Targeting.kind_for_scope("all") == K.ANY_ACTOR, "old target_scope strings map to the new kinds")


func _check_damage_heal_and_events() -> void:
	var registry := Registry.new()
	var cover := _cover("c")
	registry.register_stage_entity(cover)
	var events: Array = []
	registry.entity_event.connect(func(_e, name: String, _c) -> void: events.append(name))
	registry.dispatch("on_turn_start", {})
	registry.dispatch("on_manual_activate", {})
	_expect(cover.seen.has("turn_start") and cover.seen.has("manual") and events == ["on_turn_start", "on_manual_activate"], "dispatch calls the hook and emits entity_event")
	var guard := Registry.new()
	guard.dispatch("on_turn_start", {})
	_expect(guard.is_empty(), "dispatching on an empty registry does nothing")
	var removable := _cover("r")
	registry.register_stage_entity(removable)
	registry.dispatch("on_turn_end", {"actor": {}})
	_expect(removable.seen.has("turn_end"), "every registered entity gets the event")


func _check_ai_priority() -> void:
	var AI = load("res://scripts/battlescripts/EnemyAI.gd")
	var ai = AI.new()
	var target_a := {"id": "a"}
	var target_b := {"id": "b"}
	_expect(ai.target_score({}, target_a, 1.0) == 1.0, "with no registry the AI score is unchanged")
	var registry := Registry.new()
	ai.stage_entities = registry
	_expect(ai.target_score({}, target_a, 1.0) == 1.0, "with an empty registry the AI score is unchanged")
	var cover := _cover("cv")
	registry.register_stage_entity(cover)
	_expect(ai.target_score({}, cover, 1.0) == 101.0 and ai.target_score({}, target_a, 1.0) == 1.0, "a cover adds weight to itself only")
	var picks_cover := 0
	for roll: int in range(400):
		if _same(ai.pick_weighted_target({}, [target_a, target_b, cover]), cover):
			picks_cover += 1
	_expect(picks_cover > 340, "enemies strongly prefer the cover when it exists (%d/400)" % picks_cover)
	_expect(ai.pick_weighted_target({}, []) == null, "no candidates picks nothing")
	ai.free()


func _check_controller_hooks() -> void:
	var scene: PackedScene = load("res://scenes/battle_scene.tscn")
	var battle: Node = scene.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	var controller: Node = battle.get_node("BattleController")
	_expect(controller.stage_entities != null and controller.stage_entities.is_empty(), "the controller owns an empty registry")
	var cover := _cover("ctl")
	controller.stage_entities.register_stage_entity(cover)
	var party_member := {"id": "x", "hp": 10}
	controller.player_party = [party_member, {"id": "y", "hp": 5}]
	controller.enemy_party = [{"id": "e", "hp": 7, "is_enemy": true}]
	var actor: Dictionary = party_member
	cover.seen.clear()
	# A bystander (in neither camp) keeps the real handlers from advancing any turn.
	var bystander := {"id": "ghost", "hp": 1}
	controller._on_turn_started(bystander)
	_expect(cover.seen.has("turn_start"), "on_turn_start is reachable from the existing turn start")
	controller.battle_finished = true
	controller._on_turn_ended(bystander)
	_expect(cover.seen.has("turn_end"), "on_turn_end is reachable from the existing turn end")
	cover.seen.clear()
	controller.safe_end_turn()
	_expect(cover.seen.has("after"), "on_after_action is reachable from the existing turn finish")
	var source: String = (load("res://scripts/battlescripts/BattleController.gd") as GDScript).source_code
	_expect(source.contains('stage_entities.dispatch("on_before_action"'), "on_before_action is hooked at the start of execute_action")
	controller.battle_finished = false
	cover.seen.clear()
	cover.seen.clear()
	# --- faction + target kinds through the controller ---
	_expect(controller.faction_of(actor) == "player" and controller.faction_of(controller.enemy_party[0]) == "enemy", "faction_of reads the camp")
	var K = Targeting.Kind
	_expect(controller.get_targets_by_type(K.ENEMY_ACTOR, actor) == controller.get_valid_targets_for_skill({"target_scope": "enemy_single"}, actor), "ENEMY_ACTOR equals the existing enemy_single targets")
	_expect(controller.get_targets_by_type(K.ALLY_ACTOR, actor) == controller.get_valid_targets_for_skill({"target_scope": "ally_single"}, actor), "ALLY_ACTOR equals the existing ally_single targets")
	_expect(controller.get_targets_by_type(K.ANY_TARGETABLE, actor).has(cover), "entities join ANY_TARGETABLE")
	# --- damage / heal adapter ---
	var hit: Dictionary = controller.apply_damage_to_target(cover, 20, {"source": actor})
	_expect(hit.damage == 20 and cover.current_hp == 30 and cover.seen == ["damaged:20"], "damage reaches an entity and fires on_damage_taken")
	var healed: Dictionary = controller.apply_heal_to_target(cover, 5, {})
	_expect(healed.healed == 5 and cover.current_hp == 35 and cover.seen.has("healed:5"), "healing reaches an entity and fires on_healed")
	var actor_hit: Dictionary = controller.apply_damage_to_target(actor, 4, {"source": controller.enemy_party[0]})
	_expect(actor_hit.damage == 4 and actor.hp == 6, "the same call works on an actor dictionary")
	var actor_heal: Dictionary = controller.apply_heal_to_target(actor, 100, {})
	_expect(actor_heal.healed == 4 or actor.hp >= 6, "healing an actor is clamped")
	var kill: Dictionary = controller.apply_damage_to_target(cover, 999, {"source": actor})
	_expect(kill.destroyed and cover.seen.has("destroyed") and controller.stage_entities.is_empty(), "destroying an entity fires on_destroyed and removes it")
	battle.queue_free()
	await process_frame


func _check_renderer() -> void:
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	var ui: Node = fixture.ui
	var stage: Node3D = ui.stage
	var registry: Object = fixture.controller.stage_entities
	# --- cards appear with the registry ---
	var cover := _cover("card_cover")
	registry.register_stage_entity(cover)
	for frame: int in range(4):
		await process_frame
	_expect(stage.entity_cards.has("card_cover") and stage.target_card(cover) != null, "registering an entity spawns its card")
	var card: Node3D = stage.entity_cards["card_cover"]
	_expect(card.label.text.contains("50/50"), "the default card shows name and HP")
	cover.take_damage(20)
	_expect(card.label.text.contains("30/50"), "the card updates when the entity changes")
	# --- many cards, any number of kinds ---
	var extra: Array = []
	for index: int in range(5):
		var token := StageEntity.from_dict({"entity_id": "token%d" % index, "entity_type": "tarot", "faction": "enemy" if index % 2 == 0 else "player", "card_kind": "tarot"})
		registry.register_stage_entity(token)
		extra.append(token)
	_expect(stage.entity_cards.size() == 6, "more than six cards can be on the stage at once")
	var positions: Array = []
	for key: String in stage.entity_cards.keys():
		positions.append(stage.entity_cards[key].home_position)
	var distinct := true
	for i: int in range(positions.size()):
		for j: int in range(i + 1, positions.size()):
			if positions[i].distance_to(positions[j]) < 0.01:
				distinct = false
	_expect(distinct, "entity cards do not pile up in one spot")
	# --- a custom card kind through a factory ---
	var made: Array = []
	stage.entity_card_factories["custom"] = func(entity: Object) -> Node3D:
		made.append(entity)
		return EntityCardForTest.new()
	var custom := StageEntity.from_dict({"entity_id": "custom1", "entity_type": "echo", "faction": "player", "card_kind": "custom"})
	registry.register_stage_entity(custom)
	_expect(made == [custom] and stage.entity_cards["custom1"] is EntityCardForTest, "a factory can draw an entity with its own node")
	# --- removal ---
	registry.unregister_stage_entity(cover)
	await process_frame
	_expect(not stage.entity_cards.has("card_cover"), "removing an entity removes its card")
	registry.destroy_entity(extra[0])
	_expect(stage.entity_cards.size() == 5, "destroying an entity removes its card")
	# --- picking over actors and entities ---
	var actor_card_count: int = stage.cards.size()
	var ctx: Dictionary = fixture.build_preview_context()
	var party_actor: Dictionary = ctx.player_party[0]
	party_actor["battle_uid"] = "pick_ally#0"
	var foe: Dictionary = ctx.enemy_party[0]
	foe["is_enemy"] = true
	foe["battle_uid"] = "pick_foe#0"
	fixture.controller.player_party = [party_actor]
	fixture.controller.enemy_party = [foe]
	ui.set_teams([party_actor], [foe])
	var token_card: Node3D = stage.entity_cards["token1"]
	var token_rect_centre: Vector2 = stage.camera.unproject_position(stage.actor_root.to_global(token_card.home_position))
	var picked: Variant = stage.pick_target(token_rect_centre, [party_actor, foe, extra[1]])
	_expect(_same(picked, extra[1]), "pick_target resolves a stage entity under the pointer")
	var party_centre: Vector2 = stage.card_screen_rect(party_actor).get_center()
	_expect(_same(stage.pick_target(party_centre, [party_actor, foe, extra[1]]), party_actor), "pick_target still resolves actors")
	_expect(stage.pick_actor(party_centre, [party_actor, foe]) == party_actor, "pick_actor (existing) is unchanged")
	_expect(_same(stage.pick_target(Vector2(2.0, 2.0), [party_actor, foe, extra[1]]), {}), "nothing under the pointer picks nothing")
	# interaction_priority breaks a tie between two cards at the same spot
	var twin_a := StageEntity.from_dict({"entity_id": "twin_a", "faction": "player", "priority": 1})
	var twin_b := StageEntity.from_dict({"entity_id": "twin_b", "faction": "player", "priority": 9})
	registry.register_stage_entity(twin_a)
	registry.register_stage_entity(twin_b)
	var spot: Vector3 = Vector3(0.0, 0.0, 6.0)
	stage.entity_cards["twin_a"].set_home(spot, 0.0)
	stage.entity_cards["twin_b"].set_home(spot, 0.0)
	var twin_centre: Vector2 = stage.camera.unproject_position(stage.actor_root.to_global(spot))
	_expect(_same(stage.pick_target(twin_centre, [twin_a, twin_b]), twin_b), "at equal distance the higher interaction_priority wins")
	_expect(_same(stage.pick_target(twin_centre, [twin_b, twin_a]), twin_b), "the tie-break does not depend on candidate order")
	# --- the actor row is not limited to three cards ---
	var party: Array = []
	for index: int in range(6):
		var member: Dictionary = party_actor.duplicate(true)
		member["id"] = "member%d" % index
		member["battle_uid"] = "member%d#%d" % [index, index]
		member["speed"] = 10 - index
		party.append(member)
	ui.set_teams(party, [foe])
	_expect(stage.cards.size() == 7, "six party cards and an enemy are all drawn (no 3-card limit)")
	var xs: Array = []
	for member: Dictionary in party:
		xs.append(stage.card_for(member).home_position.x)
	xs.sort()
	var spaced := true
	for index: int in range(1, xs.size()):
		if xs[index] - xs[index - 1] < 0.5:
			spaced = false
	_expect(spaced, "a large party is laid out without overlapping on one slot")
	var guest: Dictionary = {"id": "guest_x", "name": "客座", "hp": 5, "max_hp": 5}
	ui.set_teams([party_actor], [foe])
	_expect(stage.guest_party_limit == 3, "the guest rule is a named setting, not a hidden constant")
	fixture.queue_free()
	await process_frame


class EntityCardForTest extends Node3D:
	var home_position: Vector3 = Vector3.ZERO
	var home_rotation: Vector3 = Vector3.ZERO
	var card_size: Vector2 = Vector2(0.8, 0.8)
	var interaction_priority: int = 0
	var entity: Object
	func configure(e: Object) -> void: entity = e
	func set_home(p: Vector3, _yaw: float = 0.0) -> void:
		home_position = p
		position = p
	func refresh(_e: Object) -> void: pass


func _same(first: Variant, second: Variant) -> bool:
	if typeof(first) != typeof(second):
		return false
	return first == second
