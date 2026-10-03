extends "res://scripts/presentation/CombatStage25D.gd"
## Card Stage: the same camera, background, FX volume and command tray as
## STAGE_25D, with upright portrait cards placed in one row per camp (see
## CardStageFormation). The party camp stands in the foreground on the left and
## fills about 3/4 of the screen height; the enemy camp stands far back on the
## right at about 2/5. Both sizes come from the perspective camera (distance and
## FOV), never from scale. Party cards turn hard toward the enemy; enemy cards
## stay nearly frontal so their information remains easy to read.

const CardStageActorCard = preload("res://scripts/presentation/CardStageActorCard.gd")
const Templates = preload("res://scripts/presentation/CardStageTemplates.gd")
const Art = preload("res://scripts/presentation/CardStageArt.gd")
const Formation = preload("res://scripts/presentation/CardStageFormation.gd")
const CardStageCommandTray = preload("res://scripts/presentation/CardStageCommandTray.gd")
const CardStageTurnMarker = preload("res://scripts/presentation/CardStageTurnMarker.gd")
## Turn marker size (an ornament, not a character, so scaling it is fine) and the
## gap between its tip and the card top.
const MARKER_SCALE: float = 0.8
const MARKER_GAP: float = 0.05

const CAMERA_Z: float = 18.0
## Backdrop sits well behind the enemy camp so MISS ribbons dissipate in front of it.
const CARD_STAGE_BACKGROUND_DEPTH: float = -11.0
## Party yaw presets in degrees (turned toward the enemy); F9 cycles in debug builds.
const YAW_PRESETS: Array[float] = [45.0, 50.0, 55.0]
const DEFAULT_YAW_PRESET: int = 1
## Enemy cards keep a slight inward turn only.
const ENEMY_YAW_DEGREES: float = 12.0

var yaw_preset: int = DEFAULT_YAW_PRESET
var enemy_yaw_degrees: float = ENEMY_YAW_DEGREES
## actor key -> layout + world position; read by tests and debug tools.
var slots: Dictionary = {}
## A guest is only drawn while the party has fewer cards than this (the game's current
## party size rule, not a limit of the stage: any number of cards can be placed).
var guest_party_limit: int = 3


func _ready() -> void:
	# Camp depth is derived from the camp's template card height (character / enemy).
	var ally_height: float = Templates.card_world_size("character").y
	var enemy_height: float = Templates.card_world_size("enemy").y
	player_depth = CAMERA_Z - Formation.distance_for_fraction(ally_height, Formation.ALLY_HEIGHT, camera_fov)
	enemy_depth = CAMERA_Z - Formation.distance_for_fraction(enemy_height, Formation.ENEMY_HEIGHT, camera_fov)
	background_depth = CARD_STAGE_BACKGROUND_DEPTH
	yaw_preset = DEFAULT_YAW_PRESET
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--card-yaw="):
			var found: int = YAW_PRESETS.find(float(argument.trim_prefix("--card-yaw=")))
			if found >= 0:
				yaw_preset = found
		elif argument.begins_with("--enemy-yaw="):
			enemy_yaw_degrees = clampf(float(argument.trim_prefix("--enemy-yaw=")), 0.0, 40.0)
	card_yaw_degrees = YAW_PRESETS[yaw_preset]
	super._ready()
	_install_card_stage_extras()


## The pointer-picked active card was clicked (the UI decides what that opens).
signal active_card_clicked(actor: Dictionary)

var turn_marker: Node3D
var _active_actor: Dictionary = {}
var _active_card: Node3D


func _install_card_stage_extras() -> void:
	# Main commands pop up from the active card; the bottom tray keeps only its
	# expanded option pages. Swap the inherited tray for the reduced one.
	var old_tray: Node3D = command_tray
	remove_child(old_tray)
	old_tray.free()
	command_tray = CardStageCommandTray.new()
	command_tray.name = "FrontCommandBand"
	add_child(command_tray)
	command_tray.command_requested.connect(_on_command)
	command_tray.option_requested.connect(_on_option)
	# A real light + ambient so the lacquered/brass turn marker has form. Cards,
	# backdrop and FX are unshaded and unaffected.
	var light := DirectionalLight3D.new()
	light.name = "MarkerLight"
	light.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	light.light_energy = 1.3
	add_child(light)
	var environment: Environment = camera.environment
	if environment:
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.62, 0.62, 0.68)
		environment.ambient_light_energy = 0.9
		# Glow: only things brighter than white (the hit sparks, emitted HDR) bloom.
		environment.glow_enabled = true
		environment.glow_hdr_threshold = 1.0
		environment.glow_intensity = 0.9
		environment.glow_strength = 1.0
		environment.glow_bloom = 0.0
		environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	turn_marker = CardStageTurnMarker.new()
	turn_marker.name = "TurnMarker"
	turn_marker.scale = Vector3.ONE * MARKER_SCALE
	turn_marker.visible = false
	add_child(turn_marker)


## Marks whose turn it is: the card pulses white and a brass arrow hangs above it.
func set_active_actor(actor: Dictionary) -> void:
	clear_active_actor()
	_active_actor = actor
	var card: Node3D = card_for(actor)
	if card == null:
		return
	_active_card = card
	card.set_turn_active(true)
	turn_marker.visible = true
	_follow_marker()


func clear_active_actor() -> void:
	if is_instance_valid(_active_card):
		_active_card.set_turn_active(false)
	_active_card = null
	_active_actor = {}
	if turn_marker:
		turn_marker.visible = false


func active_actor() -> Dictionary:
	return _active_actor


func _follow_marker() -> void:
	if not is_instance_valid(_active_card):
		return
	# The arrow tip rests just above the card's top edge and follows its motion.
	turn_marker.position = _active_card.position + Vector3(0.0, _active_card.card_size.y / 2.0 + MARKER_GAP, 0.05)


func _process(delta: float) -> void:
	super._process(delta)
	_update_order(delta)
	_update_defeats()
	_ensure_registry_bound()
	if _active_card != null and not is_instance_valid(_active_card):
		clear_active_actor()
	elif turn_marker and turn_marker.visible:
		_follow_marker()


## A defeated enemy leaves the stage with an exit by family: animals shake and tip backwards,
## 語魅 beat like a heart and drift upward. Waits until the blow has finished playing, and
## holds `busy` so the next action starts after the card is gone. A revived card returns.
func _update_defeats() -> void:
	if busy:
		return
	var manager: Node = _turn_manager()
	if manager == null:
		return
	for actor: Dictionary in manager.enemy_party:
		var card: Node3D = card_for(actor)
		if card == null or not card.has_method("defeat_animal"):
			continue
		if card.get("template_key") == "boss":
			continue  # a boss has its own finale (present_boss_finale)
		var dead: bool = int(actor.get("hp", 0)) <= 0
		if not dead:
			if card.defeat_played:
				card.defeat_played = false
				card.visible = true
				card.set_fade(0.0)
				card.reset_pose()
			continue
		if card.defeat_played or not _cards_idle():
			continue
		busy = true
		if String(actor.get("family", "")) == "yumei":
			await card.defeat_yumei()
		else:
			await card.defeat_animal()
		busy = false
		return


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not enabled or not input_enabled or busy or _active_actor.is_empty():
		return
	if _ui and _ui.get("target_picker") and _ui.target_picker.active:
		return
	if get_viewport().is_input_handled():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not pick_actor(event.position, [_active_actor], true).is_empty():
			active_card_clicked.emit(_active_actor)
			get_viewport().set_input_as_handled()


## Dev aid: cycles the party yaw 50 -> 55 -> 45 -> 50 and re-seats idle cards.
func cycle_yaw_preset() -> float:
	if busy:
		return card_yaw_degrees
	return set_yaw_preset((yaw_preset + 1) % YAW_PRESETS.size())


func set_yaw_preset(index: int) -> float:
	yaw_preset = clampi(index, 0, YAW_PRESETS.size() - 1)
	card_yaw_degrees = YAW_PRESETS[yaw_preset]
	for card: Node3D in cards.values():
		card.set_home(card.home_position, _yaw_for(card.is_enemy))
	return card_yaw_degrees


func _yaw_for(enemy: bool) -> float:
	# +yaw turns a party card toward the right; mirrored for the enemy.
	return -enemy_yaw_degrees if enemy else card_yaw_degrees


func set_teams(allies: Array, enemies: Array, guest: Dictionary = {}, status_source: Callable = Callable()) -> void:
	_status_source = status_source
	clear_active_actor()
	for card in cards.values():
		card.queue_free()
	cards.clear()
	hover_key = ""
	_order_signature = ""
	slots.clear()
	var party: Array = allies.duplicate()
	if not guest.is_empty() and party.size() < guest_party_limit:
		var guest_view: Dictionary = guest.duplicate(true)
		guest_view["is_guest"] = true
		party.append(guest_view)
	_place_side(party, false)
	_place_side(enemies, true)


func _place_side(actors: Array, enemy: bool) -> void:
	var present: Array = []
	for actor: Dictionary in actors:
		if not actor.is_empty():
			present.append(actor)
	var ranks: Array[int] = Formation.assign_ranks(present)
	for index: int in range(present.size()):
		var actor: Dictionary = present[index]
		var card: Node3D = CardStageActorCard.new()
		# The card template (character / enemy / boss) must be known before it builds.
		card.prepare_for(actor, enemy)
		actor_root.add_child(card)
		card.configure(actor, enemy, _status_text(actor))
		card.scale = Vector3.ONE
		var layout: Dictionary = Formation.slot(present.size(), ranks[index], enemy, _actor_height_ratio(card))
		var position: Vector3 = Formation.world_position(layout, card.card_size.y, CAMERA_Z, camera_fov)
		card.set_home(position, _yaw_for(enemy))
		card.slot_rank = layout.rank
		card.hit_landed.connect(_on_card_hit_landed)
		var key: String = actor_key(actor)
		card.name = "Card_%d_%s" % [layout.rank, key.replace("#", "_")]
		cards[key] = card
		layout["position"] = position
		slots[key] = layout


# Cards here are portrait-sized, so picking and screen rectangles use each card's
# own size instead of the landscape constant in the inherited implementation.
func card_screen_rect(actor: Dictionary) -> Rect2:
	var card := card_for(actor)
	if not card:
		return Rect2()
	var half: Vector2 = card.card_size / 2.0
	var result := Rect2(camera.unproject_position(card.to_global(Vector3.ZERO)), Vector2.ZERO)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		result = result.expand(camera.unproject_position(card.to_global(Vector3(corner.x * half.x, corner.y * half.y, 0))))
	return result


func pick_actor(screen_position: Vector2, candidates: Array, include_dead: bool = false) -> Dictionary:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var nearest: float = INF
	var selected: Dictionary = {}
	for actor: Dictionary in candidates:
		var card := card_for(actor)
		if not card or (int(actor.get("hp", 0)) <= 0 and not include_dead):
			continue
		# Hit-test the card where it STANDS (home), not where hover animation has moved
		# it: otherwise a lifted card would slip from under the pointer and flicker.
		var inverse: Transform3D = (actor_root.global_transform * Transform3D(Basis.from_euler(card.home_rotation), card.home_position)).affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_direction: Vector3 = inverse.basis * direction
		if absf(local_direction.z) < 0.0001:
			continue
		var distance: float = -local_origin.z / local_direction.z
		var point: Vector3 = local_origin + local_direction * distance
		if distance > 0 and distance < nearest and absf(point.x) < card.card_size.x / 2.0 and absf(point.y) < card.card_size.y / 2.0:
			nearest = distance
			selected = actor
	return selected


# --- Target selection: the hovered card lifts, its camp-mates step aside -------------

## How far a hovered card comes toward the camera and up.
const FAN_LIFT := Vector3(0.0, 0.10, 0.9)
## Breathing room kept between the lifted card and the neighbours that make way.
const FAN_MARGIN: float = 0.14
## Neighbours also recede a little so the lifted card clearly leads.
const FAN_RECEDE: float = 0.2

var hover_key: String = ""


## Called by the target picker with the card under the pointer ({} = none). Cards of
## the hovered camp that would overlap it slide outward (like picking from a hand of
## cards); everything returns when the pointer leaves or the selection closes.
func set_hover_target(actor: Dictionary) -> void:
	var key: String = "" if actor.is_empty() else actor_key(actor)
	if key == hover_key:
		return
	hover_key = key
	var offsets: Dictionary = fan_offsets_for(key)
	for card_key: String in cards.keys():
		var card: Node3D = cards[card_key]
		card.fan_to(offsets.get(card_key, Vector3.ZERO), 0.2 if card_key == key else 0.24, card_key == key)


## Pure layout of the fan: card key -> offset from its home position.
func fan_offsets_for(key: String) -> Dictionary:
	var result: Dictionary = {}
	if key.is_empty() or not cards.has(key):
		return result
	var hovered: Node3D = cards[key]
	result[key] = FAN_LIFT
	var hovered_extent: float = _half_extent(hovered)
	for side: float in [-1.0, 1.0]:
		var neighbours: Array = []
		for other_key: String in cards.keys():
			var other: Node3D = cards[other_key]
			if other_key == key or other.is_enemy != hovered.is_enemy:
				continue
			if signf(other.home_position.x - hovered.home_position.x) == side:
				neighbours.append(other_key)
		neighbours.sort_custom(func(a: String, b: String) -> bool:
			return absf(cards[a].home_position.x - hovered.home_position.x) < absf(cards[b].home_position.x - hovered.home_position.x)
		)
		var inner_x: float = hovered.home_position.x
		var inner_extent: float = hovered_extent
		for other_key: String in neighbours:
			var other: Node3D = cards[other_key]
			var needed: float = inner_extent + _half_extent(other) + FAN_MARGIN
			var gap: float = side * (other.home_position.x - inner_x)
			var shift: float = maxf(0.0, needed - gap)
			shift = _limit_shift_to_screen(other, side, shift)
			result[other_key] = Vector3(side * shift, 0.0, -FAN_RECEDE if shift > 0.0 else 0.0)
			inner_x = other.home_position.x + side * shift
			inner_extent = _half_extent(other)
	return result


## Half of a card's sideways extent as seen from the camera (it is turned by yaw).
func _half_extent(card: Node3D) -> float:
	return card.card_size.x / 2.0 * absf(cos(card.home_rotation.y))


## Never slide a card off the screen: shrink the shift until its edge is on screen.
func _limit_shift_to_screen(card: Node3D, side: float, shift: float) -> float:
	var screen_width: float = get_viewport().get_visible_rect().size.x
	var margin: float = screen_width * 0.01
	var extent: float = _half_extent(card)
	for attempt: int in range(10):
		var centre: Vector3 = card.home_position + Vector3(side * shift, 0.0, 0.0)
		var edge: Vector3 = centre + Vector3(side * extent, 0.0, 0.0)
		var x: float = camera.unproject_position(actor_root.to_global(edge)).x
		if x >= margin and x <= screen_width - margin:
			return shift
		shift *= 0.7
	return 0.0


# --- Turn-order line-up ---------------------------------------------------------------
# Each camp's row mirrors the REAL action order: the card nearest the exchange zone acts
# next. Whoever finished acting goes to the far end; the rest of the row follows the
# real queue. Speed changes made mid-round only show from the next round, because the
# round's queue is fixed at its start (nothing here changes any combat rule).

const ORDER_POLL_SECONDS: float = 0.1
var _order_clock: float = 0.0
var _order_signature: String = ""


func _turn_manager() -> Node:
	var controller: Variant = _ui.get("combat_controller") if _ui else null
	if controller == null:
		return null
	return controller.get("turn_manager") as Node


## Next-to-act first, as card keys: the rest of this round in queue order, then the
## characters who already acted, sorted the way the next round will sort them.
func order_keys() -> Array[String]:
	var manager: Node = _turn_manager()
	var keys: Array[String] = []
	if manager == null or manager.get("turn_queue") == null:
		return keys
	var queue: Array = manager.turn_queue
	var index: int = clampi(int(manager.current_index), 0, queue.size())
	var alive_all: Array = []
	for actor: Dictionary in manager.player_party + manager.enemy_party:
		if int(actor.get("hp", 0)) > 0 and manager._is_actor_alive(actor):
			alive_all.append(actor)
	var remaining: Array = []
	for actor: Dictionary in queue.slice(index):
		if alive_all.has(actor):
			remaining.append(actor)
	var acted: Array = []
	for actor: Dictionary in alive_all:
		if not remaining.has(actor):
			acted.append(actor)
	acted.sort_custom(Callable(manager, "_compare_speed"))
	for actor: Dictionary in remaining + acted:
		var key: String = actor_key(actor)
		if cards.has(key):
			keys.append(key)
	return keys


## Rank (0 = nearest the exchange zone) for every card, from the real order. Guests and
## defeated characters keep the outer positions, in their previous relative order.
func ranks_from_order(keys: Array[String]) -> Dictionary:
	var ranks: Dictionary = {}
	for enemy_side: bool in [false, true]:
		var row: Array[String] = []
		for key: String in keys:
			if cards[key].is_enemy == enemy_side:
				row.append(key)
		var actor_count: int = row.size()
		var rest: Array = []
		for key: String in cards.keys():
			if cards[key].is_enemy == enemy_side and not row.has(key):
				rest.append(key)
		rest.sort_custom(func(a: String, b: String) -> bool: return cards[a].slot_rank < cards[b].slot_rank)
		# Row entities sit between the acting order and the outer extras (guests, the
		# fallen): `row_edge_distance` counts positions in from the outer end.
		var inserts: Array = []
		for entity: Object in _row_entities(enemy_side):
			var index: int = clampi(actor_count - int(entity.get("row_edge_distance")), 0, actor_count)
			inserts.append([index, _row_key(entity)])
		inserts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
		for insert: Array in inserts:
			row.insert(insert[0], insert[1])
		for key: String in rest:
			row.append(key)
		for rank: int in range(row.size()):
			ranks[row[rank]] = rank
	return ranks


func apply_order(keys: Array[String], animated: bool) -> void:
	var ranks: Dictionary = ranks_from_order(keys)
	var counts: Dictionary = {false: 0, true: 0}
	for key: String in ranks.keys():
		counts[_row_card(key).is_enemy] += 1
	for key: String in ranks.keys():
		var card: Node3D = _row_card(key)
		var rank: int = ranks[key]
		var gaps: Array = _row_gaps(ranks, card.is_enemy, counts[card.is_enemy])
		var position: Vector3 = _row_position(card, counts[card.is_enemy], rank, card.is_enemy, gaps)
		# Re-centring when the row grows or shrinks moves cards even if their rank stays.
		if rank == card.slot_rank and position.is_equal_approx(card.home_position):
			continue
		var is_actor_card: bool = cards.has(key)
		var was_front: bool = card.slot_rank == 0
		card.slot_rank = rank
		if is_actor_card:
			card.name = "Card_%d_%s" % [rank, key.replace("#", "_")]
			var layout: Dictionary = Formation.slot(counts[card.is_enemy], rank, card.is_enemy, _actor_height_ratio(card))
			layout["position"] = position
			slots[key] = layout
		if animated:
			card.relocate(position, is_actor_card and was_front and rank > 0, _relocate_time_scale)
		else:
			card.set_home(position, _yaw_for(card.is_enemy))


func _cards_idle() -> bool:
	if busy:
		return false
	for card: Node3D in cards.values():
		if card._motion_tween != null and card._motion_tween.is_valid() and card._motion_tween.is_running():
			return false
	return true


func _update_order(delta: float) -> void:
	_order_clock += delta
	if _order_clock < ORDER_POLL_SECONDS or cards.is_empty():
		return
	_order_clock = 0.0
	var keys: Array[String] = order_keys()
	if keys.is_empty():
		return
	var signature: String = "|".join(keys) + "#" + _entity_signature()
	if signature == _order_signature or not _cards_idle():
		return
	var first: bool = _order_signature.is_empty()
	_order_signature = signature
	hover_key = ""
	apply_order(keys, not first)


# --- Stage entities (echoes, cover, tarot... : cards that are not actors) -----------------
# Presentation hooks only. A system registers a StageEntity in the controller's registry;
# this node draws it, keeps it up to date and removes it. Nothing here limits how many
# cards of any kind are on the stage.

const EntityCard = preload("res://scripts/presentation/CardStageEntityCard.gd")

## entity_id -> card node.
var entity_cards: Dictionary = {}
## card_kind -> Callable(entity) -> Node3D, to draw an entity with something other than
## the default small card. The node needs: home_position, home_rotation, card_size,
## interaction_priority, set_home(position, yaw), refresh(entity).
var entity_card_factories: Dictionary = {}
var _bound_registry: Object = null
var _entity_objects: Dictionary = {}
## Slows card slides while a new sub card is being inserted (2/3 speed = 1.5x time).
var _relocate_time_scale: float = 1.0


func spawn_stage_entity_card(entity: Object, home: Variant = null) -> Node3D:
	var key: String = String(entity.get("entity_id"))
	if entity_cards.has(key):
		return entity_cards[key]
	var card: Node3D
	var factory: Variant = entity_card_factories.get(String(entity.get("card_kind")))
	if factory is Callable and (factory as Callable).is_valid():
		card = (factory as Callable).call(entity)
	else:
		card = TokenCard.new() if String(entity.get("card_kind")) == "token" else EntityCard.new()
	actor_root.add_child(card)
	if card.has_method("configure"):
		card.configure(entity)
	var enemy_side: bool = String(entity.get("faction")) == "enemy"
	var position: Vector3
	if home is Vector3:
		position = home
	else:
		var index: int = 0
		for other: Object in _entity_objects.values():
			if (String(other.get("faction")) == "enemy") == enemy_side:
				index += 1
		position = Formation.world_position(Formation.entity_slot(index, enemy_side), card.card_size.y, CAMERA_Z, camera_fov)
	entity_cards[key] = card
	_entity_objects[key] = entity
	if entity.has_signal("changed") and not entity.changed.is_connected(update_stage_entity_card):
		entity.changed.connect(update_stage_entity_card)
	if _entity_row_side(entity) > 0 and not home is Vector3:
		_place_row_entity(entity, card, true)
	else:
		card.set_home(position, _yaw_for(enemy_side))
	return card


func remove_stage_entity_card(entity: Object) -> void:
	var key: String = String(entity.get("entity_id"))
	if entity.has_signal("changed") and entity.changed.is_connected(update_stage_entity_card):
		entity.changed.disconnect(update_stage_entity_card)
	var card: Node3D = entity_cards.get(key)
	entity_cards.erase(key)
	_entity_objects.erase(key)
	_order_signature = ""
	if card == null:
		return
	# A card that is still showing (it expired rather than broke) fades before it is freed.
	if card.has_method("set_fade") and card.get("card_mesh") != null and card.card_mesh.transparency < 0.9:
		var tween := create_tween()
		tween.tween_method(card.set_fade, 0.0, 1.0, 0.4)
		tween.tween_callback(card.queue_free)
	else:
		card.queue_free()


func update_stage_entity_card(entity: Object) -> void:
	var card: Node3D = entity_cards.get(String(entity.get("entity_id")))
	if card and card.has_method("refresh"):
		card.refresh(entity)


## Follows a StageEntityRegistry: cards appear and disappear with its entities.
func bind_entity_registry(registry: Object) -> void:
	if registry == null or registry == _bound_registry:
		return
	_bound_registry = registry
	registry.entity_registered.connect(spawn_stage_entity_card)
	registry.entity_unregistered.connect(remove_stage_entity_card)
	for entity: Object in registry.get_stage_entities():
		spawn_stage_entity_card(entity)


func _ensure_registry_bound() -> void:
	if _bound_registry != null or _ui == null:
		return
	var controller: Variant = _ui.get("combat_controller")
	if controller != null and controller.get("stage_entities") != null:
		bind_entity_registry(controller.stage_entities)


## The card standing for a target: an actor dictionary or a stage entity.
func target_card(target: Variant) -> Node3D:
	if target is Dictionary:
		return card_for(target)
	if target is Object:
		return entity_cards.get(String((target as Object).get("entity_id")))
	return null


## Like pick_actor, but the candidates may be actors AND stage entities. The nearest card
## under the pointer wins; at equal distance the higher interaction_priority does.
func pick_target(screen_position: Vector2, candidates: Array, include_dead: bool = false) -> Variant:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var nearest: float = INF
	var best_priority: int = -2147483648
	var selected: Variant = null
	for target: Variant in candidates:
		var card := target_card(target)
		if card == null:
			continue
		if target is Dictionary and int(target.get("hp", 0)) <= 0 and not include_dead:
			continue
		if target is Object and not include_dead and not (target as Object).is_alive():
			continue
		var inverse: Transform3D = (actor_root.global_transform * Transform3D(Basis.from_euler(card.home_rotation), card.home_position)).affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_direction: Vector3 = inverse.basis * direction
		if absf(local_direction.z) < 0.0001:
			continue
		var distance: float = -local_origin.z / local_direction.z
		var point: Vector3 = local_origin + local_direction * distance
		if distance <= 0.0 or absf(point.x) >= card.card_size.x / 2.0 or absf(point.y) >= card.card_size.y / 2.0:
			continue
		var priority: int = int(card.get("interaction_priority")) if card.get("interaction_priority") != null else 0
		if distance < nearest - 0.0005 or (absf(distance - nearest) <= 0.0005 and priority > best_priority):
			nearest = distance
			best_priority = priority
			selected = target
	return selected if selected != null else {}


# --- Stage entities standing IN a card row (替身符...) ---------------------------------------
# A row entity has `row` = "party" / "enemy" and `row_edge_distance` (positions from the
# outer end, guests not counted). It is laid out together with the actors, so the row
# squeezes a little and the actors keep their real order around it.

const TokenCard = preload("res://scripts/presentation/CardStageTokenCard.gd")
const InkStroke = preload("res://scripts/presentation/InkStroke3D.gd")
const InkDrops = preload("res://scripts/presentation/InkDrops2D.gd")

var _spawn_origin: Variant = null
var _cast_stroke: Node3D = null
var _cast_center: Vector3 = Vector3.ZERO
var _drop_layer: CanvasLayer = null


func _entity_row_side(entity: Object) -> int:
	# 0 = not in a row, 1 = party row, 2 = enemy row
	match String(entity.get("row")):
		"party": return 1
		"enemy": return 2
	return 0


func _row_entities(enemy_side: bool) -> Array:
	var wanted: int = 2 if enemy_side else 1
	var result: Array = []
	for key: String in _entity_objects.keys():
		var entity: Object = _entity_objects[key]
		if _entity_row_side(entity) == wanted and entity_cards.has(key):
			result.append(entity)
	return result


func _row_key(entity: Object) -> String:
	return "ent:%s" % String(entity.get("entity_id"))


func _row_card(key: String) -> Node3D:
	if key.begins_with("ent:"):
		return entity_cards.get(key.trim_prefix("ent:"))
	return cards.get(key)


func _entity_signature() -> String:
	var parts: Array[String] = []
	for key: String in entity_cards.keys():
		var entity: Object = _entity_objects.get(key)
		if entity != null and _entity_row_side(entity) > 0:
			parts.append("%s@%d" % [key, int(entity.get("row_edge_distance"))])
	parts.sort()
	return ",".join(parts)


## A boss stands a third larger than an ordinary enemy, for presence.
const BOSS_HEIGHT_RATIO: float = 1.33


func _actor_height_ratio(card: Node3D) -> float:
	return BOSS_HEIGHT_RATIO if card.get("template_key") == "boss" else 1.0


## The card size of a row entity relative to an actor card (a smaller sub card).
func _size_ratio(card: Node3D) -> float:
	return clampf(card.card_size.y / Templates.card_world_size("character").y, 0.2, 1.0)


func _row_position(card: Node3D, count: int, rank: int, enemy_side: bool, gaps: Array = []) -> Vector3:
	var layout: Dictionary = Formation.slot(count, rank, enemy_side, _actor_height_ratio(card), gaps)
	if card is TokenCard or not card.has_method("cast_step_forward"):
		layout = Formation.slot(count, rank, enemy_side, _size_ratio(card), gaps)
	var world: Vector3 = Formation.world_position(layout, card.card_size.y, CAMERA_Z, camera_fov)
	# A sub card stands a little in front of the characters so a turned neighbour never hides it.
	if card is TokenCard:
		world.z += SUB_CARD_FRONT
	return world


## Where the row entities will stand: the new card is placed straight into its slot.
func _place_row_entity(entity: Object, card: Node3D, animate_in: bool) -> void:
	var enemy_side: bool = _entity_row_side(entity) == 2
	var keys: Array[String] = order_keys()
	var ranks: Dictionary = ranks_from_order(keys)
	var key: String = _row_key(entity)
	var count: int = 0
	for other: Node3D in cards.values():
		if other.is_enemy == enemy_side:
			count += 1
	count += _row_entities(enemy_side).size()
	var rank: int = int(ranks.get(key, count - 1))
	card.slot_rank = rank
	card.set_home(_row_position(card, count, rank, enemy_side, _row_gaps(ranks, enemy_side, count)), _yaw_for(enemy_side))
	if animate_in and _spawn_origin is Vector3 and card.has_method("play_spawn"):
		# It first walks to the outer end of its row (the far left for the party), then is
		# slid in once the row is ready (settle_entity_arrival).
		var outer: Vector3 = _row_position(card, count, count - 1, enemy_side, [])
		outer.x += (1.4 if enemy_side else -1.4)
		outer.z = player_depth + CAST_FRONT - 0.4
		card.play_spawn(_spawn_origin, outer)
	_spawn_origin = null
	# The actors re-space around it once nothing is moving (see _update_order).
	_order_signature = ""


## Fades a row entity out of its slot (expiry), then frees the card.
func fade_out_stage_entity_card(entity: Object) -> void:
	var card: Node3D = entity_cards.get(String(entity.get("entity_id")))
	if card == null or not card.has_method("set_fade"):
		return
	var tween := create_tween()
	tween.tween_method(card.set_fade, 0.0, 1.0, 0.45)


# --- Presentation: an attack on a stage entity ---------------------------------------------

func present_entity_attack(attacker: Dictionary, entity: Object, destroyed: bool, attacker_motion: bool = true, landed: bool = true) -> void:
	var source: Node3D = card_for(attacker)
	var card: Node3D = entity_cards.get(String(entity.get("entity_id")))
	if source == null or card == null:
		return
	busy = true
	command_tray.set_enabled(false)
	if attacker_motion:
		source.attack_motion(card.home_position)
		await get_tree().create_timer(0.14).timeout
	var trail: Node3D = SwordTrail.new()
	fx_root.add_child(trail)
	var shake_later := get_tree().create_timer(0.3)
	if landed:
		shake_later.timeout.connect(func() -> void:
			if is_instance_valid(card):
				card.hit_shake()
				_hit_spark(card.position + Vector3(0.0, card.card_size.y * 0.05, 0.5), 1.6, false)
		)
	await trail.play(source.position, card.home_position, landed)
	trail.queue_free()
	# A short hit-stop, then the charm tears apart if that was its last charge.
	await get_tree().create_timer(0.08).timeout
	if destroyed and is_instance_valid(card):
		await card.play_break()
	await get_tree().create_timer(0.18).timeout
	busy = false


# --- Presentation: casting 替身符 (one brush stroke, a burst, the card unfolds) ------------

## phase "windup": step forward, draw the stroke, burst, (the controller then registers the
## entity, whose card unfolds from the burst). phase "finish": settle and step back.
func present_stage_entity_cast(caster: Dictionary, phase: String) -> void:
	var card: Node3D = card_for(caster)
	if card == null:
		return
	if phase == "windup":
		busy = true
		command_tray.set_enabled(false)
		_cast_center = Vector3(0.2, 0.9, player_depth + CAST_FRONT)
		await card.cast_step_forward()
		# 1. The green ink swirl (the twin dragons) opens first, centred where the glyph will be.
		#    The sheet is sized so its ring is as tall as the glyph (the dragons reach beyond).
		await play_swirl_at(_cast_center, CAST_GLYPH_SIZE / SWIRL_RING_FRACTION)
		# 2. Then the talisman glyph is drawn.
		_cast_stroke = InkStroke.new()
		_cast_stroke.size = CAST_GLYPH_SIZE
		fx_root.add_child(_cast_stroke)
		_cast_stroke.position = _cast_center
		await _cast_stroke.draw_stroke(2.2)
		# Heartbeat before the burst: two beats, each throwing a ghost image outward.
		await _cast_stroke.heartbeat(2, 0.8)
		# 3. The glyph bursts into ink; the card is born from it (white, spinning about Y).
		_spawn_origin = _cast_center
		_burst_ink(_cast_center)
		_splash_camera_ink()
		var stroke: Node3D = _cast_stroke
		_cast_stroke = null
		stroke.contract_and_fade(0.3)
		get_tree().create_timer(0.6).timeout.connect(stroke.queue_free)
	else:
		# The burst has happened and the card is unfolding. Wait for it to land, let the
		# characters make room around it, and only then end the cast: nothing may act while
		# the card is still on its way into the row.
		await settle_entity_arrival()
		await card.cast_return()
		busy = false


func _burst_ink(centre: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var holder := Node3D.new()
	fx_root.add_child(holder)
	holder.position = centre
	for index: int in range(52):
		var drop := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.012, 0.055)
		sphere.height = sphere.radius * 2.0 * rng.randf_range(1.0, 2.6)
		drop.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.015, 0.015, 0.02, 0.96)
		material.no_depth_test = true
		material.render_priority = 21
		drop.material_override = material
		holder.add_child(drop)
		var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 1.0), rng.randf_range(-0.2, 1.0)).normalized()
		var reach: float = rng.randf_range(1.0, 2.6)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(drop, "position", direction * reach + Vector3(0.0, -0.5, 0.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(drop, "scale", Vector3.ONE * rng.randf_range(0.4, 0.9), 0.7)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.5).set_delay(0.3)
	get_tree().create_timer(1.0).timeout.connect(holder.queue_free)


func _splash_camera_ink() -> void:
	if _drop_layer == null or not is_instance_valid(_drop_layer):
		_drop_layer = CanvasLayer.new()
		_drop_layer.layer = 60
		add_child(_drop_layer)
	var drops: Control = InkDrops.new()
	_drop_layer.add_child(drops)
	drops.splash(4)


## Extra room beside a sub card (a charm between characters would otherwise be hidden).
const ENTITY_GAP: float = 1.5
const SUB_CARD_FRONT: float = -0.35
## The cast and the new card's entrance happen this far in front of the party row, so
## nothing (a turned character included) can hide it.
const CAST_FRONT: float = 2.2
const CAST_GLYPH_SIZE: float = 3.4


## Boundary gap multipliers for one row, from a rank map (see Formation.slot).
func _row_gaps(ranks: Dictionary, enemy_side: bool, count: int) -> Array:
	var entity_ranks: Dictionary = {}
	for key: String in ranks.keys():
		if key.begins_with("ent:") and entity_cards.has(key.trim_prefix("ent:")) and entity_cards[key.trim_prefix("ent:")].is_enemy == enemy_side:
			entity_ranks[int(ranks[key])] = true
	var gaps: Array = []
	for boundary: int in range(1, count):
		gaps.append(ENTITY_GAP if entity_ranks.has(boundary) or entity_ranks.has(boundary - 1) else 1.0)
	return gaps


## Waits until every row entity has finished unfolding and every card has slid to its final
## slot (the characters shifting to make room included).
func settle_entity_arrival() -> void:
	# The new card first plays its entrance (white spin, walk to the outer end of its row).
	var wait_guard: int = 0
	while wait_guard < 900 and _entrance_playing():
		await get_tree().process_frame
		wait_guard += 1
	# Then it is slid slowly into its slot while the row makes room around it.
	for card: Node3D in entity_cards.values():
		if card.has_method("is_staged") and card.is_staged():
			card.insert_into_slot(0.4 * INSERT_TIME_SCALE)
	# `busy` held the line-up still during the cast; release it so the row re-spaces now.
	var was_busy: bool = busy
	busy = false
	_order_clock = ORDER_POLL_SECONDS
	_order_signature = ""
	_relocate_time_scale = INSERT_TIME_SCALE
	_update_order(0.0)
	_relocate_time_scale = 1.0
	busy = was_busy
	var guard: int = 0
	while guard < 600 and _arrival_in_progress():
		await get_tree().process_frame
		guard += 1


## An entity card that is still playing its entrance (not yet waiting at the row's end).
func _entrance_playing() -> bool:
	for card: Node3D in entity_cards.values():
		if card.has_method("is_staged") and card.has_method("is_spawning") and card.is_spawning() and not card.is_staged():
			return true
	return false


func _arrival_in_progress() -> bool:
	for card: Node3D in entity_cards.values():
		if card.has_method("is_spawning") and card.is_spawning():
			return true
		if card.has_method("is_relocating") and card.is_relocating():
			return true
	for card: Node3D in cards.values():
		if card.is_relocating():
			return true
	return false


# --- Attack choreography -------------------------------------------------------------------

const INSERT_TIME_SCALE: float = 1.5
const StageHitEffects = preload("res://scripts/presentation/StageHitEffects.gd")


func _opposing_centre(card: Node3D) -> Vector3:
	var total := Vector3.ZERO
	var count: int = 0
	for other: Node3D in cards.values():
		if other.is_enemy != card.is_enemy and other.actor_id != "":
			total += other.home_position
			count += 1
	if count == 0:
		return Vector3(-card.home_position.x, card.home_position.y, -card.home_position.z)
	return total / float(count)


## Area attacks (no single target) press toward the middle of the opposing camp, not just
## sideways across the screen.
func attack_motion(actor: Dictionary) -> void:
	var card := card_for(actor)
	if card:
		card.attack_motion(_opposing_centre(card))


## Support actions (heal, buff, ...) on teammates or oneself: step forward, hold, return slowly.
func support_motion(actor: Dictionary) -> void:
	var card := card_for(actor)
	if card:
		card.support_step_hold()


func _on_card_hit_landed(card: Node3D, heavy: bool) -> void:
	_hit_spark(card.position + Vector3(0.0, card.card_size.y * 0.05, 0.5), 1.8, heavy)


func _is_sword_attack(skill: Dictionary) -> bool:
	return String(skill.get("weapon_type", "")) in ["劍", "刀", "拳"]


func _is_saber_attack(skill: Dictionary) -> bool:
	return String(skill.get("weapon_type", "")) == "刀"


func _is_fist_attack(skill: Dictionary) -> bool:
	return String(skill.get("weapon_type", "")) == "拳"

## Sword attacks: the attacker thrusts at the target and HOLDS; at contact a diagonal cut
## (袈裟斬) is drawn across the target; only when the cut is done does the attacker go back.
## Other weapons keep the ribbon trail.
func present_attack(attacker: Dictionary, target: Dictionary, skill: Dictionary, result: Dictionary) -> void:
	if not _is_sword_attack(skill):
		await super.present_attack(attacker, target, skill, result)
		return
	var source := card_for(attacker)
	var destination := card_for(target)
	if not source or not destination:
		return
	busy = true
	command_tray.set_enabled(false)
	await source.lunge_to(destination.home_position)
	var fist: bool = _is_fist_attack(skill)
	var saber: bool = _is_saber_attack(skill) or fist
	if saber:
		# 刀 and 拳: a tap first (the blade is set against the target), then the cut comes down very fast.
		var tap := create_tween()
		tap.tween_property(source, "position", source.position + Vector3(0.0, 0.07, 0.0), 0.05)
		tap.tween_property(source, "position", source.position + Vector3(0.0, -0.05, 0.0), 0.04)
		tap.tween_property(source, "position", source.position, 0.05)
		await get_tree().create_timer(0.30).timeout
	var hit: bool = bool(result.get("hit", true))
	var direction: float = 1.0 if destination.home_position.x >= source.home_position.x else -1.0
	var cut_centre: Vector3 = destination.position + Vector3(0.0, destination.card_size.y * 0.05, 0.4)
	var cut_length: float = destination.card_size.y * 1.15
	# A skill that strikes several times (連決劍 three, 流塵連決劍 four) cuts that many times, each cut
	# starting before the previous one has finished.
	var strikes: Array = result.get("strikes", [])
	if USE_BLADE_SLASH and strikes.size() > 1:
		await _play_sword_flurry(destination, target, strikes, cut_centre, cut_length, direction, saber, fist)
	elif hit:
		var cut_wait: float = 0.1
		var cut_hold: float = StageHitEffects.slash_duration() + 0.1
		if USE_BLADE_SLASH:
			_start_blade_slash(cut_centre, cut_length * (1.1 if fist else 1.5), direction, 0, saber, fist)
			cut_wait = 0.05 if saber else 0.16
			cut_hold = 0.34 if saber else 0.30
		else:
			StageHitEffects.slash(fx_root, cut_centre, cut_length, direction)
		# The target is struck as the cut lands (late in the draw), then reacts.
		await get_tree().create_timer(cut_wait).timeout
		if bool(target.get("defending", false)):
			destination.guard_motion()
		else:
			destination.hit_reaction(bool(result.get("crit", false)))
		# Let the whole cut finish (drawn, blue flicker, held) before the attacker withdraws.
		await get_tree().create_timer(cut_hold).timeout
	else:
		destination.dodge_motion()
		# The blade only finds air beside the target.
		var miss_centre: Vector3 = cut_centre + Vector3(direction * 0.9, 0.2, -0.6)
		if USE_BLADE_SLASH:
			_start_blade_slash(miss_centre, cut_length * (0.9 if fist else 1.1), direction, 0, saber, fist)
		else:
			StageHitEffects.slash(fx_root, miss_centre, cut_length, direction, 0.55)
		await get_tree().create_timer(0.34).timeout
	await source.lunge_return(0.4)
	await get_tree().create_timer(0.12).timeout
	busy = false


# --- Nothing acts while the line-up is being reshuffled ------------------------------------

func is_lineup_moving() -> bool:
	return _arrival_in_progress()


## Applies any pending re-ordering NOW and waits until every card is at rest. Enemy actions and
## the player's commands wait for this, so a hit never lands in the middle of a shuffle.
func wait_for_lineup_settled() -> void:
	var was_busy: bool = busy
	busy = false
	_order_clock = ORDER_POLL_SECONDS
	_update_order(0.0)
	busy = was_busy
	var guard: int = 0
	while guard < 900 and _arrival_in_progress():
		await get_tree().process_frame
		guard += 1


# --- Story encounter: 語魅 entanglement and Zuo Yin's moves ----------------------------------

const StoryFx = preload("res://scripts/presentation/StageStoryEffects.gd")


func _fx_point(card: Node3D, lift: float = 0.0) -> Vector3:
	return card.position + Vector3(0.0, card.card_size.y * 0.05 + lift, 0.6)


## The boss gathers the 語魅 around itself: it is drawn in from every side, then the card
## begins its slow white / purple / black pulse.
func present_entangle(boss: Dictionary) -> void:
	var card: Node3D = card_for(boss)
	if card == null:
		return
	busy = true
	command_tray.set_enabled(false)
	StoryFx.absorption(fx_root, _fx_point(card), 1.7)
	await get_tree().create_timer(1.5).timeout
	card.set_tint("entangled")
	await get_tree().create_timer(0.4).timeout
	busy = false


const ShardBurst = preload("res://scripts/presentation/CardStageShardBurst.gd")
const FocusLines = preload("res://scripts/presentation/CardStageFocusLines.gd")
const YanxingCinematic = preload("res://scripts/presentation/CardStageYanxingCinematic.gd")
## While the shell shatters the game runs slow for this many real seconds, then at full speed.
const BREAK_SLOWMO_SECONDS: float = 0.8
const BREAK_SLOWMO_SCALE: float = 0.22
var _slowmo_active: bool = false


func _exit_tree() -> void:
	if _slowmo_active:
		Engine.time_scale = 1.0


## The 語魅 shell breaks. In slow motion for 0.8 s the purple triangles blow apart radially
## (like a window hit by a ball), then fall; a few bounce on the floor. Focus lines burst out,
## and the boss reels backwards for 0.8 s before slowly coming back.
func present_entangle_break(boss: Dictionary) -> void:
	var card: Node3D = card_for(boss)
	if card == null:
		return
	var was_busy: bool = busy
	busy = true
	var impact_local := Vector2(-card.card_size.x * 0.12, card.card_size.y * 0.04)
	var impact_world: Vector3 = card.to_global(Vector3(impact_local.x, impact_local.y, 0.0))
	card.set_tint("")
	var burst := ShardBurst.new()
	fx_root.add_child(burst)
	burst.setup(card, card.card_size, impact_local, card.home_position.y - card.card_size.y * 0.5 + 0.02)
	FocusLines.burst(self, camera.unproject_position(impact_world))
	_slowmo_active = true
	Engine.time_scale = BREAK_SLOWMO_SCALE
	var reel: Vector3 = Vector3(0.55 if card.is_enemy else -0.55, 0.0, -1.1)
	# 0.16 game seconds at a fifth of the speed: the reel lasts the 0.8 real seconds of the slow motion.
	card.stagger_back(reel, BREAK_SLOWMO_SECONDS * BREAK_SLOWMO_SCALE)
	await get_tree().create_timer(BREAK_SLOWMO_SECONDS, true, false, true).timeout
	Engine.time_scale = 1.0
	_slowmo_active = false
	await card.stagger_recover(1.4)
	busy = was_busy


## Zuo Yin's scripted actions. `removes` = this action tears the 語魅 off the boss.
func present_guest_action(guest: Dictionary, action_id: String, boss: Dictionary, removes: bool) -> void:
	var card: Node3D = card_for(guest)
	if card == null:
		return
	busy = true
	command_tray.set_enabled(false)
	match action_id:
		"drink_to_qi":
			await card.drink_shakes()
		"wine_edge_charge":
			await card.drunken_sway()
			card.set_tint("drunk")
			await get_tree().create_timer(0.3).timeout
		"yanxing_wind_breaking_slash":
			var boss_card: Node3D = card_for(boss)
			# The whole move is the supplied animation: zoom into the portrait, play, white, back.
			var art_entry: Dictionary = Art.entry_for(guest)
			var art_texture: Texture2D = load(String(art_entry.get("path", ""))) as Texture2D if not art_entry.is_empty() else null
			if art_texture != null:
				# The whole card swells to the middle of the screen first, then the animation takes over.
				await _zoom_card_to_centre(card)
				var cinematic := YanxingCinematic.new()
				add_child(cinematic)
				await cinematic.play(self, _portrait_screen_rect(card), art_texture, Callable(self, "_restore_zoomed_card").bind(card))
				cinematic.queue_free()
			if boss_card != null:
				if removes:
					await present_entangle_break(boss)
				else:
					boss_card.hit_reaction(true)
			card.set_tint("")
	busy = false


# --- Green ink swirl (臨符 buffs, and the burst of 替身符) ----------------------------------

const SWIRL_SHEET := "res://assets/fx/ink_swirl_sheet.webp"
const SWIRL_COLUMNS: int = 4
const SWIRL_ROWS: int = 3
const SWIRL_FRAME_SECONDS: float = 0.075
## The swirl ring fills about a third of its frame; used to size the sheet to a wanted ring.
const SWIRL_RING_FRACTION: float = 0.33


## Plays the 12-frame swirl at a point (world space in the FX volume). Returns when it ends.
func play_swirl_at(point: Vector3, height: float = 2.6) -> void:
	var texture: Texture2D = load(SWIRL_SHEET) as Texture2D
	if texture == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(height, height)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 31
	material.albedo_texture = texture
	material.uv1_scale = Vector3(1.0 / float(SWIRL_COLUMNS), 1.0 / float(SWIRL_ROWS), 1.0)
	mesh.material_override = material
	fx_root.add_child(mesh)
	mesh.position = point
	for frame: int in range(SWIRL_COLUMNS * SWIRL_ROWS):
		material.uv1_offset = Vector3(float(frame % SWIRL_COLUMNS) / float(SWIRL_COLUMNS), float(frame / SWIRL_COLUMNS) / float(SWIRL_ROWS), 0.0)
		await get_tree().create_timer(SWIRL_FRAME_SECONDS).timeout
	mesh.queue_free()


func present_ink_swirl(targets: Array) -> void:
	busy = true
	command_tray.set_enabled(false)
	var plays: int = 0
	for target: Variant in targets:
		if typeof(target) != TYPE_DICTIONARY:
			continue
		var card: Node3D = card_for(target)
		if card == null:
			continue
		play_swirl_at(_fx_point(card, 0.3), card.card_size.y * 0.8)
		plays += 1
	if plays > 0:
		await get_tree().create_timer(float(SWIRL_COLUMNS * SWIRL_ROWS) * SWIRL_FRAME_SECONDS + 0.1).timeout
	busy = false


## Screen position of the middle of a card's portrait window (where an OS speech tail points).
func card_portrait_center(actor: Dictionary) -> Vector2:
	var card: Node3D = card_for(actor)
	if card == null:
		return Vector2.ZERO
	var window: Rect2 = Templates.to_local_rect(card.template_key, Templates.get_template(card.template_key).window)
	return camera.unproject_position(card.to_global(Vector3(window.get_center().x, window.get_center().y, 0.02)))


## Where a card's portrait picture is on screen right now: the projected art quad (the same
## picture a full-screen animation starts from, so the zoom into it joins up).
func _portrait_screen_rect(card: Node3D) -> Rect2:
	var layer: MeshInstance3D = card.get("art_layer")
	if layer == null or not (layer.mesh is QuadMesh):
		return Rect2(camera.unproject_position(card.global_position) - Vector2(120.0, 160.0), Vector2(240.0, 320.0))
	var half: Vector2 = (layer.mesh as QuadMesh).size * 0.5
	var corners: Array[Vector2] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		corners.append(camera.unproject_position(layer.to_global(Vector3(corner.x * half.x, corner.y * half.y, 0.0))))
	var result := Rect2(corners[0], Vector2.ZERO)
	for corner: Vector2 in corners:
		result = result.expand(corner)
	return result


# --- Zooming a whole card into the middle of the screen (the 燕行破風斬 intake) ------------------

const CARD_ZOOM_SECONDS: float = 0.6

var _zoom_dim: MeshInstance3D = null


## The card turns square to the camera and swells until its portrait fills the screen (it is moved
## toward the camera, so the growth is real perspective), while everything behind it dims.
func _zoom_card_to_centre(card: Node3D) -> void:
	# Sized so the portrait picture is exactly as large as the animation's square (the full
	# screen height) and sits in the middle: the rest of the card simply runs off the screen.
	var layer: MeshInstance3D = card.get("art_layer")
	var art_height: float = (layer.mesh as QuadMesh).size.y if layer != null and layer.mesh is QuadMesh else card.card_size.y
	var offset: Vector3 = layer.position if layer != null else Vector3.ZERO
	var distance: float = Formation.distance_for_fraction(art_height, 1.0, camera_fov)
	var target := Vector3(-offset.x, -offset.y, CAMERA_Z - distance - offset.z)
	var visible_height: float = 2.0 * distance * tan(deg_to_rad(camera_fov) / 2.0)
	var sheet := QuadMesh.new()
	sheet.size = Vector2(visible_height * 4.0, visible_height * 2.0)
	_zoom_dim = MeshInstance3D.new()
	_zoom_dim.mesh = sheet
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_zoom_dim.material_override = material
	_zoom_dim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(_zoom_dim)
	_zoom_dim.global_position = Vector3(0.0, 0.0, target.z + offset.z - 0.6)
	card._kill_motion()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "position", target, CARD_ZOOM_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "rotation", Vector3.ZERO, CARD_ZOOM_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(material, "albedo_color:a", 0.88, CARD_ZOOM_SECONDS)
	await tween.finished


## Puts the zoomed card back at its place (done while the screen is white).
func _restore_zoomed_card(card: Node3D) -> void:
	if is_instance_valid(card):
		card.position = card.home_position
		card.rotation = card.home_rotation
	if _zoom_dim != null and is_instance_valid(_zoom_dim):
		_zoom_dim.queue_free()
	_zoom_dim = null


# --- The second-phase boss is finally defeated ------------------------------------------------------

const GhostFire = preload("res://scripts/presentation/CardStageGhostFire.gd")
const FINALE_BURN_SECONDS: float = 5.0


## Whether this actor gets the dedicated boss finale instead of an ordinary defeat exit.
func has_boss_finale(actor: Dictionary) -> bool:
	var card: Node3D = card_for(actor)
	return card != null and card.get("template_key") == "boss"


## Directed finale: the card flashes white, slowly; on the last flash it stays white while the
## backdrop fades in to white, then the card returns to its normal colours and the backdrop fades
## out to black. Violet triangles then fly off the centre one at a time, in random directions,
## with campfire-like sparks, until the card is half burnt. The card burns for five seconds; the
## charred black husk shrinks and is squashed flat.
func present_boss_finale(boss: Dictionary) -> void:
	var card: Node3D = card_for(boss)
	if card == null:
		return
	busy = true
	command_tray.set_enabled(false)
	card.defeat_played = true
	card.set_tint("")
	card._kill_motion()
	# The backdrop sheet (sits behind the boss only), transparent for now.
	var distance: float = CAMERA_Z - (card.position.z - 1.0)
	var visible_height: float = 2.0 * distance * tan(deg_to_rad(camera_fov) / 2.0)
	var sheet_mesh := QuadMesh.new()
	sheet_mesh.size = Vector2(visible_height * 4.0, visible_height * 2.0)
	var sheet := MeshInstance3D.new()
	sheet.mesh = sheet_mesh
	var sheet_material := StandardMaterial3D.new()
	sheet_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sheet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheet_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	sheet_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	sheet.material_override = sheet_material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(sheet)
	sheet.global_position = Vector3(0.0, 0.0, card.position.z - 1.0)
	# 1. White, white, white ... slowly; the last flash stays white and the backdrop fades in white.
	var backdrop_white := func() -> void:
		var fade_in := create_tween()
		fade_in.tween_property(sheet_material, "albedo_color:a", 1.0, 0.8)
	await card.flash_white_pulses(6, 0.95, 0.55, backdrop_white)
	# 2. The card shows its normal colours again against the white.
	await card.fade_white_overlay(0.6)
	await get_tree().create_timer(0.3).timeout
	# 3. The white backdrop fades out to black.
	var fade_out := create_tween()
	fade_out.tween_property(sheet_material, "albedo_color", Color(0.0, 0.0, 0.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
	await fade_out.finished
	# 4. Violet fire: triangles fly off one by one until the card is half burnt, sparks all along.
	var fire := GhostFire.new()
	fx_root.add_child(fire)
	fire.global_position = card.global_position + Vector3(0.0, 0.0, 0.2)
	fire.play(card.card_size, FINALE_BURN_SECONDS + 1.0, 0.9 + FINALE_BURN_SECONDS * 0.5)
	await get_tree().create_timer(0.9).timeout
	# 5. The card burns, five seconds, to black.
	await card.burn_down(FINALE_BURN_SECONDS)
	# 6. The black husk shrinks and is squashed flat.
	await card.char_collapse(0.7)
	busy = false


# --- The sword cut: one silver-white blade crescent with black ink, upper left to lower right ---

const BladeSlash = preload("res://scripts/presentation/StageBladeSlash.gd")
## Sword cuts use the single silver-white blade band (false brings back the sprite-sheet slash).
const USE_BLADE_SLASH: bool = true
const BLADE_SLASH_SECONDS: float = 1.3


## Starts the blade cut (it frees itself); the caller times its own reaction.
func _start_blade_slash(centre: Vector3, length: float, direction: float, variant: int = 0, saber: bool = false, impact: bool = false) -> void:
	var slash := BladeSlash.new()
	slash.duration = BLADE_SLASH_SECONDS
	fx_root.add_child(slash)
	slash.setup(length, direction, variant, saber, impact)
	# Centre the half-circle on the target (successive cuts of a flurry are nudged apart).
	var jitter := Vector3(sin(float(variant) * 2.3), cos(float(variant) * 1.7), 0.0) * length * 0.035
	slash.position = centre + jitter + Vector3(direction * length * (0.0 if saber else 0.03), -length * (0.06 if saber else 0.13), 0.3 + 0.02 * float(variant))
	slash.play()


# --- The hit spark: a cold white burst in the sword cut's language (not a cartoon star) -----------

const HitSpark = preload("res://scripts/presentation/StageHitSpark.gd")
## false brings back the old red-yellow spark star.
const USE_COLD_HIT_SPARK: bool = true


func _hit_spark(centre: Vector3, size: float, heavy: bool) -> void:
	if USE_COLD_HIT_SPARK:
		HitSpark.play(fx_root, centre, size, heavy)
	else:
		StageHitEffects.spark(fx_root, centre, size, heavy)


# --- Multi-strike sword skills: a flurry of overlapping cuts -------------------------------------

## Seconds between the start of one cut and the start of the next (the previous cut is still on screen).
const FLURRY_GAP: float = 0.15


## One cut per strike, each beginning while the last is still fading, alternating forehand and
## backhand. A landed strike makes the target react (and spark) when its cut reaches it; if no
## strike landed at all, the target dodges once.
func _play_sword_flurry(destination: Node3D, target: Dictionary, strikes: Array, cut_centre: Vector3, cut_length: float, direction: float, saber: bool = false, fist: bool = false) -> void:
	var any_landed: bool = false
	for strike_any: Variant in strikes:
		any_landed = any_landed or bool((strike_any as Dictionary).get("hit", true))
	if not any_landed:
		destination.dodge_motion()
	var guarding: bool = bool(target.get("defending", false))
	for index: int in range(strikes.size()):
		var strike: Dictionary = strikes[index]
		var landed: bool = bool(strike.get("hit", true))
		if landed:
			_start_blade_slash(cut_centre, cut_length * (1.1 if fist else 1.5), direction, index, saber, fist)
			get_tree().create_timer(0.16).timeout.connect(_flurry_react.bind(destination, guarding, bool(strike.get("crit", false))))
		else:
			# The blade only finds air beside the target.
			_start_blade_slash(cut_centre + Vector3(direction * 0.9, 0.2, -0.6), cut_length * (0.9 if fist else 1.1), direction, index, saber, fist)
		if index < strikes.size() - 1:
			await get_tree().create_timer(FLURRY_GAP).timeout
	# Let the last cut land and play out before the attacker withdraws.
	await get_tree().create_timer(0.46).timeout


func _flurry_react(destination: Node3D, guarding: bool, crit: bool) -> void:
	if not is_instance_valid(destination):
		return
	if guarding:
		destination.guard_motion()
	else:
		destination.hit_reaction(crit)
