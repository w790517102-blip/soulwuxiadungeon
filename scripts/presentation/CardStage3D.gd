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
				card.clear_burn()
			continue
		if card.defeat_played or not _cards_idle():
			continue
		busy = true
		if String(actor.get("family", "")) == "yumei":
			await card.defeat_yumei(_start_yumei_fire.bind(card))
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
	# The turn manager knows the real order, including stage entities that take part in it (臨符).
	if manager.has_method("get_display_order"):
		for entry: Dictionary in manager.get_display_order():
			if bool(entry.get("is_stage_entity", false)):
				var entity_key: String = "ent:%s" % String(entry.get("entity_id", ""))
				if entity_cards.has(String(entry.get("entity_id", ""))):
					keys.append(entity_key)
			else:
				var actor_key_text: String = actor_key(entry)
				if cards.has(actor_key_text):
					keys.append(actor_key_text)
		return keys
	var queue: Array = manager.turn_queue
	var index: int = clampi(int(manager.current_index), 0, queue.size())
	var alive_all: Array = []
	for actor: Dictionary in manager.get_all_actors():
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
			if _row_card(key).is_enemy == enemy_side:
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
			if bool(entity.get("joins_turn_order")):
				continue   # a card that takes part in the order is already placed by it
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
	_refresh_ward_auras()
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
	if entity.has_method("has_tag") and entity.has_tag("talisman") and card.visible:
		_paper_dissolve(card)
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
## How the next row entity enters: "burst" (the ink burst) or "draw" (pulled from behind `_spawn_wielder`).
var _spawn_style: String = "burst"
var _spawn_wielder: Node3D = null
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
		if _spawn_style == "draw" and _spawn_wielder != null and is_instance_valid(_spawn_wielder) and card.has_method("play_draw"):
			card.play_draw(_spawn_wielder, outer)
		else:
			card.play_spawn(_spawn_origin, outer)
	_spawn_origin = null
	_spawn_style = "burst"
	_spawn_wielder = null
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
func present_stage_entity_cast(caster: Dictionary, phase: String, animation: String = "ink_talisman") -> void:
	var card: Node3D = card_for(caster)
	if card == null:
		return
	if phase == "windup":
		busy = true
		command_tray.set_enabled(false)
		_cast_center = Vector3(0.2, 0.9, player_depth + CAST_FRONT)
		await card.cast_step_forward()
		if animation == "sheath_draw":
			# 拔劍持鞘: no brush, no ink. A cold glint of the drawn sword; the scabbard card is then pulled
			# out from behind the wielder toward the upper left (see TokenCard.play_draw).
			_hit_spark(card.position + Vector3(_toward_row(card) * card.card_size.x * 0.4, card.card_size.y * 0.1, 0.7), 2.2, false)
			await get_tree().create_timer(0.2).timeout
			_spawn_origin = card.position
			_spawn_style = "draw"
			_spawn_wielder = card
			return
		# 1. The talisman glyph is drawn (the twin dragons that used to open the cast are gone).
		_cast_stroke = InkStroke.new()
		_cast_stroke.size = CAST_GLYPH_SIZE
		fx_root.add_child(_cast_stroke)
		_cast_stroke.position = _cast_center
		await _cast_stroke.draw_stroke(2.2)
		# Heartbeat before the burst: two beats, each throwing a ghost image outward.
		await _cast_stroke.heartbeat(2, 0.8)
		# 2. The glyph bursts into ink; the card is born from it (white, spinning about Y).
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
	if _suppress_card_spark:
		return
	_hit_spark(card.position + Vector3(0.0, card.card_size.y * 0.05, 0.5), 1.8, heavy)


func _is_sword_attack(skill: Dictionary) -> bool:
	return String(skill.get("weapon_type", "")) in ["劍", "刀"]


func _is_saber_attack(skill: Dictionary) -> bool:
	return String(skill.get("weapon_type", "")) == "刀"


## Sword attacks: the attacker thrusts at the target and HOLDS; at contact a diagonal cut
## (袈裟斬) is drawn across the target; only when the cut is done does the attacker go back.
## Other weapons keep the ribbon trail.
func present_attack(attacker: Dictionary, target: Dictionary, skill: Dictionary, result: Dictionary) -> void:
	if _is_spear_attack(skill):
		await _present_spear_attack(attacker, target, result)
		return
	if _is_staff_attack(skill):
		await _present_staff_attack(attacker, target, result)
		return
	if _is_talisman_skill(skill):
		await _present_talisman_attack(attacker, target, result)
		return
	if _is_lute_attack(skill):
		await _present_lute_attack(attacker, target, result)
		return
	if _is_pen_attack(skill):
		await _present_pen_attack(attacker, target, result)
		return
	if _is_punch_attack(skill):
		await _present_punch_attack(attacker, target, result)
		return
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
	var saber: bool = _is_saber_attack(skill)
	if saber:
		# 刀: a tap first (the blade is set against the target), then the cut comes down very fast.
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
		await _play_sword_flurry(destination, target, strikes, cut_centre, cut_length, direction, saber)
	elif hit:
		var cut_wait: float = 0.1
		var cut_hold: float = StageHitEffects.slash_duration() + 0.1
		if USE_BLADE_SLASH:
			_start_blade_slash(cut_centre, cut_length * 1.5, direction, 0, saber, bool(result.get("crit", false)))
			cut_wait = 0.05 if saber else 0.16
			_blade_hit_feedback(cut_centre, cut_length, bool(result.get("crit", false)), destination)
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
			_start_blade_slash(miss_centre, cut_length * 1.1, direction, 0, saber)
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
	if _slowmo_active or _hit_stop_active:
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
func _start_blade_slash(centre: Vector3, length: float, direction: float, variant: int = 0, saber: bool = false, critical: bool = false) -> void:
	var slash := BladeSlash.new()
	slash.tremble = critical
	slash.duration = BLADE_SLASH_SECONDS
	fx_root.add_child(slash)
	slash.setup(length, direction, variant, saber)
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
func _play_sword_flurry(destination: Node3D, target: Dictionary, strikes: Array, cut_centre: Vector3, cut_length: float, direction: float, saber: bool = false) -> void:
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
			_start_blade_slash(cut_centre, cut_length * 1.5, direction, index, saber, bool(strike.get("crit", false)))
			_blade_hit_feedback(cut_centre, cut_length, bool(strike.get("crit", false)), destination)
			get_tree().create_timer(0.16).timeout.connect(_flurry_react.bind(destination, guarding, bool(strike.get("crit", false))))
		else:
			# The blade only finds air beside the target.
			_start_blade_slash(cut_centre + Vector3(direction * 0.9, 0.2, -0.6), cut_length * 1.1, direction, index, saber)
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


# --- Fists (拳): compress, burst, shake -----------------------------------------------------------
# The attacker rushes in, the game stands still for a heartbeat at the contact (hit-stop), a cold white
# core flashes, a broken ring of ink and white sparks burst outward, and the struck card is knocked back
# and springs home. Every blow of a flurry is a light one except the last, which is heavy.

const PunchHitFX = preload("res://scripts/presentation/punch_fx/PunchHitFX.gd")
const SpaceWarpFX = preload("res://scripts/presentation/punch_fx/SpaceWarpFX.gd")
var _suppress_card_spark: bool = false
var _hit_stop_active: bool = false


func _is_punch_attack(skill: Dictionary) -> bool:
	return USE_BLADE_SLASH and String(skill.get("weapon_type", "")) == "拳"


## Freezes the game almost still for `seconds` of real time (the weight of a blow).
func _hit_stop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.03
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false


func _present_punch_attack(attacker: Dictionary, target: Dictionary, result: Dictionary) -> void:
	var strikes: Array = result.get("strikes", [])
	if strikes.is_empty():
		strikes = [{"hit": bool(result.get("hit", true)), "crit": bool(result.get("crit", false))}]
	var events: Array = []
	for strike_any: Variant in strikes:
		var strike: Dictionary = strike_any
		events.append({"target": target, "hit": bool(strike.get("hit", true)), "crit": bool(strike.get("crit", false))})
	await present_punch_events(attacker, events)


## A flurry of punches, one per event ({target, hit, crit}), in order. Like the sword flurry, the
## next blow starts while the last one's light is still fading; each lands on its own spot of the
## target and sends its afterimages back along its own line. The last blow on each target is a heavy
## one (it also stops the game for a heartbeat); the blows before it are light. Used for the
## single-target multi-hit punches (天驚拳) and, with several targets, the area versions
## (石破天驚拳, 真．石破天驚拳).
const PUNCH_SPOTS: Array[Vector2] = [Vector2(-0.18, 0.22), Vector2(0.20, -0.18), Vector2(0.02, 0.04), Vector2(-0.14, -0.30), Vector2(0.18, 0.30)]
const PUNCH_ANGLES: Array[float] = [0.0, 0.55, -0.5, 0.28, -0.3]
const PUNCH_GAP: float = 0.10


func present_punch_events(attacker: Dictionary, events: Array) -> void:
	var source := card_for(attacker)
	if source == null or events.is_empty():
		return
	busy = true
	command_tray.set_enabled(false)
	var first_card := card_for((events[0] as Dictionary).target)
	if first_card == null:
		busy = false
		return
	await source.lunge_to(first_card.home_position)
	# Per target: did any blow land, and which event is its last one?
	var landed: Dictionary = {}
	var last_event: Dictionary = {}
	for index: int in range(events.size()):
		var key: String = actor_key((events[index] as Dictionary).target)
		landed[key] = bool(landed.get(key, false)) or bool((events[index] as Dictionary).hit)
		last_event[key] = index
	var struck: Array = []
	for key: String in landed.keys():
		var struck_card: Node3D = cards.get(key) as Node3D
		if struck_card == null:
			continue
		if landed[key]:
			struck.append(struck_card)
		else:
			struck_card.dodge_motion()
	_suppress_card_spark = true
	var per_target_count: Dictionary = {}
	for index: int in range(events.size()):
		var event: Dictionary = events[index]
		var destination := card_for(event.target)
		if destination == null:
			continue
		var key: String = actor_key(event.target)
		var count: int = int(per_target_count.get(key, 0))
		per_target_count[key] = count + 1
		var direction: float = 1.0 if destination.home_position.x >= source.home_position.x else -1.0
		var heavy: bool = int(last_event[key]) == index
		var guarding: bool = bool(event.target.get("defending", false))
		if bool(event.hit):
			var hit_size: float = destination.card_size.y * 0.5
			var params: Dictionary = PunchHitFX.heavy_preset(hit_size) if heavy else PunchHitFX.light_preset(hit_size)
			params["direction"] = direction
			params["critical"] = bool(event.crit)
			params["angle"] = PUNCH_ANGLES[count % PUNCH_ANGLES.size()]
			var spot: Vector2 = PUNCH_SPOTS[count % PUNCH_SPOTS.size()]
			var point: Vector3 = destination.position + Vector3(spot.x * destination.card_size.x, destination.card_size.y * 0.05 + spot.y * destination.card_size.y * 0.5, 0.5)
			# The fist presses in a little as it lands; the other hand follows on the next blow.
			var press := create_tween()
			press.tween_property(source, "position", source.position + Vector3(direction * 0.12, 0.05 * (1.0 if index % 2 == 0 else -1.0), 0.0), 0.04)
			PunchHitFX.play_at(fx_root, point, params)
			if heavy:
				await _hit_stop(float(params.hit_stop_time))
			if guarding:
				destination.guard_motion()
			else:
				destination._flash(Color(0.92, 0.96, 1.0, 0.5))
				destination.stagger_back(Vector3(direction * float(params.recoil_distance), 0.05, -0.3), 0.07 if heavy else 0.05)
				if bool(event.crit):
					get_tree().create_timer(0.09 if heavy else 0.06).timeout.connect(destination.shudder.bind(0.22 if heavy else 0.14, 0.09 if heavy else 0.05))
		if index < events.size() - 1:
			await get_tree().create_timer(PUNCH_GAP).timeout
	_suppress_card_spark = false
	await get_tree().create_timer(0.30).timeout
	for struck_card: Node3D in struck:
		if is_instance_valid(struck_card):
			struck_card.stagger_recover(0.4)
	await get_tree().create_timer(0.14).timeout
	await source.lunge_return(0.4)
	await get_tree().create_timer(0.12).timeout
	busy = false


## Feedback shared by every sword / 刀 cut that lands: a faint mirage ripple of the space around the
## hit. A critical hit has a much stronger ripple, a tremble in the cut's light near its end, and makes
## the struck card shudder after its knock-back.
func _blade_hit_feedback(cut_centre: Vector3, cut_length: float, critical: bool, destination: Node3D) -> void:
	var strength: float = SpaceWarpFX.CRITICAL_STRENGTH if critical else SpaceWarpFX.NORMAL_STRENGTH
	SpaceWarpFX.play_at(fx_root, cut_centre + Vector3(0.0, 0.0, 0.7), cut_length * (1.7 if critical else 1.3), strength, 0.5 if critical else 0.2)
	if critical and is_instance_valid(destination):
		get_tree().create_timer(0.22).timeout.connect(destination.shudder.bind(0.24, 0.09))


# --- 真．石破天驚拳 (the ultimate): zoom, animation, then a rain of punches over the whole screen ----------

const ULTIMATE_VIDEO := "res://assets/presentation/video/shi_po_tian_jing_quan_ultimate.ogv"
const ULTIMATE_VIDEO_SECONDS := 6.55
## Seconds between one impact of the rain and the next (real hits and the decorative ones between them).
const RAIN_GAP: float = 0.045
const RAIN_DECOR_PER_HIT: int = 5


## The ultimate fist skill. The card swells to the middle of the screen, the animation plays, then the
## card floats in mid-air (it does not walk up to anyone) and punches rain down all over the screen:
## every real blow lands on its target card, and many more impacts crack the rest of the picture.
func present_ultimate_fist_rain(attacker: Dictionary, events: Array) -> void:
	var source := card_for(attacker)
	if source == null or events.is_empty():
		return
	busy = true
	command_tray.set_enabled(false)
	var art_entry: Dictionary = Art.entry_for(attacker)
	var art_texture: Texture2D = load(String(art_entry.get("path", ""))) as Texture2D if not art_entry.is_empty() else null
	if art_texture != null and ResourceLoader.exists(ULTIMATE_VIDEO):
		await _zoom_card_to_centre(source)
		var cinematic := YanxingCinematic.new()
		cinematic.video_path = ULTIMATE_VIDEO
		cinematic.video_seconds = ULTIMATE_VIDEO_SECONDS
		add_child(cinematic)
		await cinematic.play(self, _portrait_screen_rect(source), art_texture, Callable(self, "_ultimate_after_white").bind())
		cinematic.queue_free()
	# The card is still in front of the camera where the zoom left it; from there it settles into the
	# hover position and hangs in the air, facing the camera, while the blows fall.
	source._kill_motion()
	var hover_position: Vector3 = source.home_position + Vector3(1.5, 0.15, 0.7)
	var hover := create_tween().set_parallel(true)
	hover.tween_property(source, "position", hover_position, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hover.tween_property(source, "rotation", Vector3.ZERO, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await hover.finished
	# Schedule: the real blows in order, with decorative impacts mixed between them.
	var last_event: Dictionary = {}
	var landed: Dictionary = {}
	for index: int in range(events.size()):
		var key: String = actor_key((events[index] as Dictionary).target)
		last_event[key] = index
		landed[key] = bool(landed.get(key, false)) or bool((events[index] as Dictionary).hit)
	var struck: Array = []
	for key: String in landed.keys():
		var struck_card: Node3D = cards.get(key) as Node3D
		if struck_card == null:
			continue
		if landed[key]:
			struck.append(struck_card)
		else:
			struck_card.dodge_motion()
	var rain_depth: float = CAMERA_Z - (enemy_depth + 1.0)
	var half_height: float = tan(deg_to_rad(camera_fov) * 0.5) * rain_depth
	var view: Vector2 = get_viewport().get_visible_rect().size
	var half_width: float = half_height * view.x / maxf(view.y, 1.0)
	var camera_home: Vector3 = camera.position
	_suppress_card_spark = true
	var per_target_count: Dictionary = {}
	var hover_clock: float = 0.0
	for index: int in range(events.size()):
		var event: Dictionary = events[index]
		var destination := card_for(event.target)
		if destination == null:
			continue
		var key: String = actor_key(event.target)
		var count: int = int(per_target_count.get(key, 0))
		per_target_count[key] = count + 1
		# Decorative impacts first: the screen cracks all around the real blow.
		for decor: int in range(RAIN_DECOR_PER_HIT):
			var spot := Vector3(randf_range(-half_width * 0.85, half_width * 0.85), randf_range(-half_height * 0.6, half_height * 0.8), CAMERA_Z - rain_depth + 0.6)
			_rain_impact(spot, source.position, randf_range(0.8, 1.7) * destination.card_size.y * 0.5, false, 0.0)
			camera.position = camera_home + Vector3(randf_range(-0.06, 0.06), randf_range(-0.05, 0.05), 0.0)
			hover_clock += RAIN_GAP
			source.position = hover_position + Vector3(0.0, sin(hover_clock * 24.0) * 0.05, 0.0)
			await get_tree().create_timer(RAIN_GAP).timeout
		var direction: float = 1.0 if destination.home_position.x >= source.home_position.x else -1.0
		var heavy: bool = int(last_event[key]) == index
		if bool(event.hit):
			var spot2: Vector2 = PUNCH_SPOTS[count % PUNCH_SPOTS.size()]
			var point: Vector3 = destination.position + Vector3(spot2.x * destination.card_size.x, destination.card_size.y * 0.05 + spot2.y * destination.card_size.y * 0.5, 0.5)
			var hit_size: float = destination.card_size.y * 0.5
			var params: Dictionary = PunchHitFX.heavy_preset(hit_size) if heavy else PunchHitFX.light_preset(hit_size)
			params["direction"] = 1.0
			params["angle"] = _angle_back_to(point, source.position)
			params["critical"] = bool(event.crit)
			PunchHitFX.play_at(fx_root, point, params)
			if heavy:
				await _hit_stop(float(params.hit_stop_time))
			if bool(event.target.get("defending", false)):
				destination.guard_motion()
			else:
				destination._flash(Color(0.92, 0.96, 1.0, 0.5))
				destination.stagger_back(Vector3(direction * float(params.recoil_distance), 0.05, -0.3), 0.07 if heavy else 0.05)
				if bool(event.crit):
					get_tree().create_timer(0.09).timeout.connect(destination.shudder.bind(0.22, 0.09))
		await get_tree().create_timer(RAIN_GAP).timeout
	camera.position = camera_home
	_suppress_card_spark = false
	await get_tree().create_timer(0.35).timeout
	for struck_card: Node3D in struck:
		if is_instance_valid(struck_card):
			struck_card.stagger_recover(0.45)
	# The card drifts back down to its place.
	var settle := create_tween().set_parallel(true)
	settle.tween_property(source, "position", source.home_position, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	settle.tween_property(source, "rotation", source.home_rotation, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await settle.finished
	await get_tree().create_timer(0.12).timeout
	busy = false


## The angle (see PunchHitFX.angle) that makes the afterimages of an impact trail back toward `origin`.
func _angle_back_to(point: Vector3, origin: Vector3) -> float:
	var back := Vector2(origin.x - point.x, origin.y - point.y)
	if back.length() < 0.001:
		return 0.0
	back = back.normalized()
	return atan2(-back.y, -back.x)


## One decorative impact of the rain, with its afterimages trailing back toward the card.
func _rain_impact(point: Vector3, origin: Vector3, size: float, _heavy: bool, _unused: float) -> void:
	var params: Dictionary = PunchHitFX.light_preset(size)
	params["direction"] = 1.0
	params["angle"] = _angle_back_to(point, origin)
	params["ink_amount"] = 0
	params["mark_scale"] = 1.1
	params["mark_life"] = 0.5
	params["spark_count"] = 5
	PunchHitFX.play_at(fx_root, point, params)



## Called while the animation's white fills the screen: the zoom's dimmer goes, but the card stays
## where the zoom left it (in front of the camera) and carries on from there.
func _ultimate_after_white() -> void:
	if _zoom_dim != null and is_instance_valid(_zoom_dim):
		_zoom_dim.queue_free()
	_zoom_dim = null


# --- Brush (筆): the pen is cracked like a whip -------------------------------------------------------

const PenWhipFX = preload("res://scripts/presentation/pen_fx/PenWhipFX.gd")


func _is_pen_attack(skill: Dictionary) -> bool:
	return USE_BLADE_SLASH and String(skill.get("weapon_type", "")) == "筆"


## Short light, a lash, a long stroke of ink and a few flung drops. The attacker snaps forward and
## back at once; the struck card only gives a quick side shudder.
func _present_pen_attack(attacker: Dictionary, target: Dictionary, result: Dictionary) -> void:
	var source := card_for(attacker)
	var destination := card_for(target)
	if not source or not destination:
		return
	busy = true
	command_tray.set_enabled(false)
	var strikes: Array = result.get("strikes", [])
	if strikes.is_empty():
		strikes = [{"hit": bool(result.get("hit", true)), "crit": bool(result.get("crit", false))}]
	var direction: float = 1.0 if destination.home_position.x >= source.home_position.x else -1.0
	var centre: Vector3 = destination.position + Vector3(0.0, destination.card_size.y * 0.05, 0.6)
	var any_landed: bool = false
	for strike_any: Variant in strikes:
		any_landed = any_landed or bool((strike_any as Dictionary).get("hit", true))
	if not any_landed:
		destination.dodge_motion()
	# Close combat like the sword: the writer steps right up to the target and stays there while the lash lands.
	await source.lunge_to(destination.home_position)
	for index: int in range(strikes.size()):
		var strike: Dictionary = strikes[index]
		var landed: bool = bool(strike.get("hit", true))
		var crit: bool = landed and bool(strike.get("crit", false))
		var spot := centre + Vector3(0.0, (float(index % 3) - 1.0) * destination.card_size.y * 0.12, 0.0)
		if not landed:
			spot += Vector3(direction * 0.9, 0.2, -0.6)
		var params: Dictionary = PenWhipFX.defaults()
		params["direction"] = direction
		params["critical"] = crit
		params["lash_angle"] = -0.12 + 0.16 * float(index % 3)
		params["ink_length"] = destination.card_size.y * 1.15
		params["ink_width"] = destination.card_size.y * 0.10
		params["whip_width"] = destination.card_size.y * 0.11
		params["burst_scale"] = destination.card_size.y * 0.62
		params["light_duration"] = 0.13
		params["hit_flash_scale"] = destination.card_size.y * 0.2
		if crit:
			params["ink_width"] = destination.card_size.y * 0.13
			params["card_hit_shake"] = 0.09
		PenWhipFX.play_at(fx_root, spot, params)
		if landed:
			# The struck card shudders sideways for an instant, then is still.
			get_tree().create_timer(0.13).timeout.connect(_hit_spark.bind(spot + Vector3(0.0, 0.0, 0.3), 1.5, crit))
			var shake: float = float(params.card_hit_shake)
			get_tree().create_timer(0.06).timeout.connect(destination.shudder.bind(0.1, shake))
			if crit:
				_blade_hit_feedback(centre, destination.card_size.y, true, destination)
		if index < strikes.size() - 1:
			await get_tree().create_timer(0.13).timeout
	await get_tree().create_timer(1.0).timeout
	await source.lunge_return()
	busy = false


# --- Lute (琴): a plucked string sets the air shaking; the struck card resonates -------------------

const LuteFX = preload("res://scripts/presentation/lute_fx/LuteFX.gd")


func _is_lute_attack(skill: Dictionary) -> bool:
	return USE_BLADE_SLASH and String(skill.get("weapon_type", "")) == "琴"


## The struck card shakes slightly and leans back a hair as the wave lands.
func _lute_recoil(card: Node, direction: float, crit: bool) -> void:
	if not is_instance_valid(card):
		return
	card.shudder(0.4 if crit else 0.26, 0.07 if crit else 0.045)
	_hit_spark(card.position + Vector3(0.0, card.card_size.y * 0.05, 0.8), 1.8, crit)
	_blade_hit_feedback(card.position + Vector3(0.0, card.card_size.y * 0.02, 0.5), card.card_size.y, crit, card)
	var lean := create_tween()
	lean.tween_property(card, "rotation", card.home_rotation + Vector3(0.0, 0.0, direction * (0.06 if crit else 0.035)), 0.06)
	lean.tween_property(card, "rotation", card.home_rotation, 0.2)
	# The neighbours on the same side step to the right so the leaning card is not hidden behind them.
	for other: Node3D in cards.values():
		if other == card or other.is_enemy != card.is_enemy or absf(other.home_position.x - card.home_position.x) > card.card_size.x * 2.2:
			continue
		var step := create_tween()
		step.tween_property(other, "position", other.home_position + Vector3(card.card_size.x * 0.28, 0.0, 0.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		step.tween_interval(0.14)
		step.tween_property(other, "position", other.home_position, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The player's card gives one short shake of the string (it does not walk up to anyone); a thin
## pressure front crosses to the target, which resonates: it trembles in place (no knock-back).
func _present_lute_attack(attacker: Dictionary, target: Dictionary, result: Dictionary) -> void:
	var source := card_for(attacker)
	var destination := card_for(target)
	if not source or not destination:
		return
	busy = true
	command_tray.set_enabled(false)
	var strikes: Array = result.get("strikes", [])
	if strikes.is_empty():
		strikes = [{"hit": bool(result.get("hit", true)), "crit": bool(result.get("crit", false))}]
	var any_landed: bool = false
	for strike_any: Variant in strikes:
		any_landed = any_landed or bool((strike_any as Dictionary).get("hit", true))
	if not any_landed:
		destination.dodge_motion()
	var direction: float = 1.0 if destination.home_position.x >= source.home_position.x else -1.0
	var centre: Vector3 = destination.position + Vector3(0.0, destination.card_size.y * 0.02, 0.5)
	for index: int in range(strikes.size()):
		var strike: Dictionary = strikes[index]
		var landed: bool = bool(strike.get("hit", true))
		var crit: bool = landed and bool(strike.get("crit", false))
		# Pluck: the card shivers in place and leans a hair toward the target.
		source.shudder(0.14, 0.06)
		var lean := create_tween()
		lean.tween_property(source, "rotation", source.home_rotation + Vector3(0.0, 0.0, -direction * 0.05), 0.05)
		lean.tween_property(source, "rotation", source.home_rotation, 0.12)
		var params: Dictionary = LuteFX.defaults()
		params["critical"] = crit
		params["card_width"] = destination.card_size.x
		params["card_height"] = destination.card_size.y
		params["wave_width"] = destination.card_size.y * 0.55
		params["outer_ring_size"] = destination.card_size.y * 1.15
		if crit:
			params["spark_count"] = 12
			params["shiver_marks"] = 5
			params["impact_flash_strength"] = 4.0
		elif strikes.size() > 1:
			params["spark_count"] = 4
			params["shiver_marks"] = 2
		var origin: Vector3 = source.position + Vector3(direction * source.card_size.x * 0.35, 0.0, 0.4)
		var aim: Vector3 = centre if landed else centre + Vector3(direction * 0.9, 0.2, -0.6)
		LuteFX.play_between(fx_root, origin, aim, params)
		if landed:
			# The struck card trembles where it stands for as long as the sound rings.
			get_tree().create_timer(float(params.wave_speed)).timeout.connect(_lute_recoil.bind(destination, direction, crit))
		if index < strikes.size() - 1:
			await get_tree().create_timer(0.16).timeout
	await get_tree().create_timer(0.55).timeout
	busy = false


# --- Talismans (符咒): paper appears, wakes, flies, sticks, seals, burns away ------------------------

const TalismanFX = preload("res://scripts/presentation/talisman_fx/TalismanFX.gd")


## Talisman skills by name (臨符, 殘符, 殘咒...). 替身符 has its own stage cast.
func _is_talisman_skill(skill: Dictionary) -> bool:
	var skill_name: String = String(skill.get("name", ""))
	if skill_name.contains("替身符"):
		return false
	return skill_name.contains("符") or skill_name.contains("殘咒") or String(skill.get("id", "")).contains("talisman")


func _talisman_params(destination: Node3D, blessing: bool, crit: bool, count: int, missed: bool) -> Dictionary:
	var params: Dictionary = TalismanFX.defaults()
	params["card_size"] = destination.card_size
	params["glyph_height"] = destination.card_size.y * 0.55
	params["brand_height"] = destination.card_size.y * 0.78
	params["stroke_width"] = destination.card_size.y * 0.020
	params["brand_width"] = destination.card_size.y * 0.016
	params["blessing"] = blessing
	params["critical"] = crit
	params["miss"] = missed
	params["arc_height"] = destination.card_size.y * 0.22
	return params


## An attack or debuff by talisman: the caster steps out, the sheets are woken and thrown, and
## the struck card is pressed back by the slap of the paper and the seal that spreads over it.
func _present_talisman_attack(attacker: Dictionary, target: Dictionary, result: Dictionary) -> void:
	var source := card_for(attacker)
	var destination := card_for(target)
	if not source or not destination:
		return
	busy = true
	command_tray.set_enabled(false)
	var landed: bool = bool(result.get("hit", true))
	var crit: bool = landed and bool(result.get("crit", false))
	var direction: float = 1.0 if destination.home_position.x >= source.home_position.x else -1.0
	await source.cast_step_forward()
	var origin: Vector3 = source.position + Vector3(direction * source.card_size.x * 0.55, source.card_size.y * 0.12, 0.7)
	var centre: Vector3 = destination.position + Vector3(0.0, destination.card_size.y * 0.02, 0.5)
	var fx := TalismanFX.play_between(fx_root, origin, centre, _talisman_params(destination, false, crit, 3 if crit else 2, not landed))
	if landed:
		fx.landed.connect(destination.shudder.bind(0.25, 0.015))
		fx.sealed.connect(_talisman_press.bind(destination, direction, crit))
	else:
		fx.landed.connect(destination.dodge_motion)
	await fx.finished
	await source.cast_return()
	busy = false


## The slap: the card is rocked back a little and trembles, then the seal holds it for a moment.
func _talisman_press(card: Node3D, direction: float, crit: bool) -> void:
	if not is_instance_valid(card):
		return
	card.shudder(0.3, 0.07 if crit else 0.05)
	var lean := create_tween()
	lean.tween_property(card, "rotation", card.home_rotation + Vector3(-0.07, 0.0, direction * 0.05), 0.07)
	lean.tween_interval(0.35)
	lean.tween_property(card, "rotation", card.home_rotation, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A talisman buff: the same sheets, gold and gentle, stuck onto each ally.
func present_talisman_cast(caster: Dictionary, targets: Array) -> void:
	var source := card_for(caster)
	busy = true
	command_tray.set_enabled(false)
	var stepped: bool = false
	if source and source.has_method("cast_step_forward"):
		stepped = true
		await source.cast_step_forward()
	var finishers: Array = []
	for target_any: Variant in targets:
		if typeof(target_any) != TYPE_DICTIONARY:
			continue
		var destination := card_for(target_any as Dictionary)
		if destination == null:
			continue
		var origin: Vector3 = (source.position if source else destination.position) + Vector3(0.0, (source.card_size.y if source else destination.card_size.y) * 0.12, 0.8)
		if source and source != destination:
			var heading: float = 1.0 if destination.home_position.x >= source.home_position.x else -1.0
			origin += Vector3(heading * source.card_size.x * 0.5, 0.0, 0.0)
		var centre: Vector3 = destination.position + Vector3(0.0, destination.card_size.y * 0.02, 0.5)
		finishers.append(TalismanFX.play_between(fx_root, origin, centre, _talisman_params(destination, true, false, 1, false)))
	# Every sheet runs on the same timing, so waiting for the first is waiting for all.
	if not finishers.is_empty():
		await (finishers[0] as Node).finished
	if stepped:
		await source.cast_return()
	busy = false


# --- Healing (HEAL): green breath poured up into the card, with drifting leaves -------------------

const HealFX = preload("res://scripts/presentation/heal_fx/HealFX.gd")
const BuffFX = preload("res://scripts/presentation/heal_fx/BuffFX.gd")


## Does not hold the line-up: the healing plays over the card while the turn goes on.
func present_heal(target: Dictionary) -> void:
	var card := card_for(target)
	if card == null:
		return
	HealFX.play_at(fx_root, card.position + Vector3(0.0, card.card_size.y * 0.02, 0.45), card.card_size)


## BUFF / DEBUFF: coloured breath rising (buffs) or a black-violet smoke sinking (debuffs).
func present_buff(target: Dictionary, kind: String) -> void:
	var card := card_for(target)
	if card == null:
		return
	BuffFX.play_at(fx_root, card.position + Vector3(0.0, card.card_size.y * 0.02, 0.45), card.card_size, kind)


## 語魅 burning as it rises: violet fire (the boss's finale fire) follows the card up.
func _start_yumei_fire(card: Node3D) -> void:
	var fire := GhostFire.new()
	fx_root.add_child(fire)
	fire.global_position = card.global_position + Vector3(0.0, 0.0, 0.2)
	fire.play(card.card_size, card.YUMEI_BURN_SECONDS, 0.0)
	var follow := create_tween()
	follow.tween_method(func(_value: float) -> void:
		if is_instance_valid(card) and is_instance_valid(fire):
			fire.global_position = card.global_position + Vector3(0.0, 0.0, 0.2), 0.0, 1.0, card.YUMEI_BURN_SECONDS)


# --- Staff (棍): a heavy flat sweep of air, a blunt sideways shove ------------------------------------

const StaffSweepFX = preload("res://scripts/presentation/staff_fx/StaffSweepFX.gd")
## How far a swept card is shoved sideways (world units), and how far it tilts (radians).
const STAFF_PUSH_DISTANCE: float = 0.95
const STAFF_TILT: float = 0.2
const STAFF_HIT_STOP: float = 0.05
## How far along the line to the target the wielder steps, compared with a sword (a long weapon keeps its distance).
const STAFF_REACH: float = 0.5


func _is_staff_attack(skill: Dictionary) -> bool:
	return USE_BLADE_SLASH and String(skill.get("weapon_type", "")) == "棍"


## The attacker winds up and swings sideways in one short motion; a broad band of air crosses the
## target, which is shoved away along the swing, tilts, hangs, and springs back.
func _present_staff_attack(attacker: Dictionary, target: Dictionary, result: Dictionary) -> void:
	var source := card_for(attacker)
	var destination := card_for(target)
	if not source or not destination:
		return
	busy = true
	command_tray.set_enabled(false)
	var strikes: Array = result.get("strikes", [])
	if strikes.is_empty():
		strikes = [{"hit": bool(result.get("hit", true)), "crit": bool(result.get("crit", false))}]
	var any_landed: bool = false
	for strike_any: Variant in strikes:
		any_landed = any_landed or bool((strike_any as Dictionary).get("hit", true))
	if not any_landed:
		destination.dodge_motion()
	var side: float = 1.0 if destination.home_position.x >= source.home_position.x else -1.0
	var centre: Vector3 = destination.position + Vector3(0.0, destination.card_size.y * 0.02, 0.5)
	for index: int in range(strikes.size()):
		var strike: Dictionary = strikes[index]
		var landed: bool = bool(strike.get("hit", true))
		var crit: bool = landed and bool(strike.get("crit", false))
		# Alternate the swing's direction on a flurry; a single swing goes toward the target's side.
		var swing: float = side if index % 2 == 0 else -side
		var params: Dictionary = StaffSweepFX.defaults()
		params["origin_offset"] = source.home_position - centre
		params["camera_offset"] = camera.global_position - fx_root.to_global(centre)
		params["direction"] = swing
		params["critical"] = crit
		if not landed:
			params["warp_strength"] = 0.0
			params["shockwave_strength"] = 0.0
		# Melee: the first swing starts with the attacker closing in (wind-up, then a hard step
		# toward the target); the sweep is released as the step lands.
		if index == 0:
			source.lunge_to(destination.home_position, STAFF_REACH)
			await get_tree().create_timer(0.2).timeout
		else:
			var twist := create_tween()
			twist.tween_property(source, "rotation", source.rotation + Vector3(0.0, 0.0, -swing * 0.16), 0.07)
			twist.tween_property(source, "rotation", source.rotation, 0.14)
			await get_tree().create_timer(0.06).timeout
		var spot: Vector3 = centre if landed else centre + Vector3(swing * 1.1, 0.25, -0.6)
		var fx := StaffSweepFX.play_at(fx_root, spot, destination.card_size, params)
		# The wielder's own short, clear sideways swing: a hard twist and slide along the sweep.
		var body_swing := create_tween().set_parallel(true)
		body_swing.tween_property(source, "position:x", source.position.x + swing * 0.4, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		body_swing.tween_property(source, "rotation:z", source.home_rotation.z - swing * 0.2, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if landed:
			fx.impact.connect(_staff_impact.bind(destination, swing, crit))
		if index < strikes.size() - 1:
			await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.5).timeout
	await source.lunge_return()
	busy = false


## The head of the sweep reaches the card: a hitch of time, then the card is thrown sideways.
func _staff_impact(card: Node3D, swing: float, crit: bool) -> void:
	if not is_instance_valid(card):
		return
	var distance: float = STAFF_PUSH_DISTANCE * (1.35 if crit else 1.0)

	# Swept: the whole card slides away along the swing, tilts, hangs for a moment, then springs back.
	card.shove(Vector3(swing * distance, 0.04, -0.1), -swing * STAFF_TILT * (1.4 if crit else 1.0), 0.14 if crit else 0.10)
	_hit_stop(STAFF_HIT_STOP * (1.6 if crit else 1.0))
	_hit_spark(card.position + Vector3(0.0, card.card_size.y * 0.05, 0.8), 2.0, crit)
	_blade_hit_feedback(card.position + Vector3(0.0, card.card_size.y * 0.02, 0.5), card.card_size.y, crit, card)


# --- Spear (槍): one point, one narrow line, straight through the target ---------------------------------

const SpearThrustFX = preload("res://scripts/presentation/spear_fx/SpearThrustFX.gd")
## How far along the line to the target the wielder steps (a long weapon keeps its distance).
const SPEAR_REACH: float = 0.55
## How far (world units, away from the camera) a speared card is driven back, and the hitch of time.
const SPEAR_RECOIL: float = 0.8
const SPEAR_HIT_STOP: float = 0.06


func _is_spear_attack(skill: Dictionary) -> bool:
	return USE_BLADE_SLASH and String(skill.get("weapon_type", "")) == "槍"


## The wielder steps in and drives the spear down a single line; the struck card is thrust back
## along its depth, rocks, hangs, and comes back.
func _present_spear_attack(attacker: Dictionary, target: Dictionary, result: Dictionary) -> void:
	var source := card_for(attacker)
	var destination := card_for(target)
	if not source or not destination:
		return
	busy = true
	command_tray.set_enabled(false)
	var strikes: Array = result.get("strikes", [])
	if strikes.is_empty():
		strikes = [{"hit": bool(result.get("hit", true)), "crit": bool(result.get("crit", false))}]
	var any_landed: bool = false
	for strike_any: Variant in strikes:
		any_landed = any_landed or bool((strike_any as Dictionary).get("hit", true))
	if not any_landed:
		destination.dodge_motion()
	var side: float = 1.0 if destination.home_position.x >= source.home_position.x else -1.0
	source.lunge_to(destination.home_position, SPEAR_REACH)
	await get_tree().create_timer(0.22).timeout
	for index: int in range(strikes.size()):
		var strike: Dictionary = strikes[index]
		var landed: bool = bool(strike.get("hit", true))
		var crit: bool = landed and bool(strike.get("crit", false))
		var height: float = destination.card_size.y
		# Each thrust of a flurry takes a slightly different line through the target.
		var line_offset: float = (float(index % 3) - 1.0) * height * 0.09
		var spot: Vector3 = destination.position + Vector3(0.0, height * 0.06 + line_offset, 0.5)
		if not landed:
			spot += Vector3(side * 0.5, height * 0.35, -0.3)
		var tip: Vector3 = source.position + Vector3(side * source.card_size.x * 0.45, source.card_size.y * 0.04 + line_offset * 0.4, 0.5)
		var params: Dictionary = SpearThrustFX.defaults()
		params["critical"] = crit
		if not landed:
			params["impact_flash_size"] = 0.25
		var fx := SpearThrustFX.play_between(fx_root, tip, spot, destination.card_size, params)
		if landed:
			fx.impact.connect(_spear_impact.bind(destination, crit))
		if index < strikes.size() - 1:
			await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(0.55).timeout
	await source.lunge_return()
	busy = false


## The point lands: a hitch of time, then the card is driven back along its depth and rocks.
func _spear_impact(card: Node3D, crit: bool) -> void:
	if not is_instance_valid(card):
		return
	card.stagger_back(Vector3(0.0, 0.03, -SPEAR_RECOIL * (1.35 if crit else 1.0)), 0.05)
	_hit_spark(card.position + Vector3(0.0, card.card_size.y * 0.06, 0.8), 1.6, crit)
	_blade_hit_feedback(card.position + Vector3(0.0, card.card_size.y * 0.04, 0.5), card.card_size.y, crit, card)
	await _hit_stop(SPEAR_HIT_STOP * (1.6 if crit else 1.0))
	await get_tree().create_timer(0.28).timeout
	if is_instance_valid(card):
		card.stagger_recover(0.3)


# --- 臨符 cards in the ADB: a jade glow on whoever they cover, an activation pulse, a dissolve ----------

const AdjacencyRules = preload("res://scripts/battlescripts/StageAdjacency.gd")


## Marks every card a 臨符 card is covering right now (from the live order, so it follows the rotation).
func _refresh_ward_auras() -> void:
	var wanted: Dictionary = {}
	var manager: Node = _turn_manager()
	if manager != null and manager.has_method("get_display_row") and not _entity_objects.is_empty():
		for enemy_side: bool in [false, true]:
			var row: Array = manager.get_display_row(enemy_side)
			for index: int in range(row.size()):
				var entry: Dictionary = row[index]
				if not AdjacencyRules.is_entity(entry):
					continue
				var entity: Object = _entity_objects.get(String(entry.get("entity_id", "")))
				if entity == null or not ("adjacency_effects" in entity) or (entity.get("adjacency_effects") as Array).is_empty():
					continue
				for recipient: Dictionary in AdjacencyRules.recipients(row, index, String(entity.get("adjacency_pattern"))):
					wanted[actor_key(recipient)] = true
	for key: String in cards.keys():
		var card: Node3D = cards[key]
		if card.has_method("set_ward_aura"):
			card.set_ward_aura(wanted.has(key))


## The card's own activation (its turn in the order).
func present_entity_activation(entity: Object) -> void:
	var card: Node3D = entity_cards.get(String(entity.get("entity_id")))
	if card == null:
		return
	if card.has_method("pulse"):
		card.pulse()
	await get_tree().create_timer(0.55).timeout


## A paper charm that has spent itself: gold dust and ash lift off the card as it fades.
func _paper_dissolve(card: Node3D) -> void:
	var unit: float = card.card_size.y
	for spec: Array in [
			[PackedColorArray([Color(1.0, 0.92, 0.6, 1.0), Color(0.6, 0.9, 0.7, 0.7), Color(0.3, 0.6, 0.5, 0.0)]), unit * 0.09, true, 22],
			[PackedColorArray([Color(0.6, 0.57, 0.52, 0.8), Color(0.35, 0.33, 0.3, 0.6), Color(0.2, 0.19, 0.18, 0.0)]), unit * 0.14, false, 16]]:
		var particles := GPUParticles3D.new()
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0.0, 1.0, 0.0)
		process.spread = 55.0
		process.initial_velocity_min = unit * 0.1
		process.initial_velocity_max = unit * 0.45
		process.damping_min = unit * 0.15
		process.damping_max = unit * 0.4
		process.gravity = Vector3(0.0, unit * 0.12, 0.0)
		process.scale_min = 0.5
		process.scale_max = 1.3
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(card.card_size.x * 0.4, card.card_size.y * 0.45, 0.04)
		process.color_ramp = GhostFire._ramp(spec[0], PackedFloat32Array([0.0, 0.5, 1.0]))
		particles.process_material = process
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE * float(spec[1]) * 0.25
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if bool(spec[2]) else BaseMaterial3D.BLEND_MODE_MIX
		material.vertex_color_use_as_albedo = true
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.render_priority = 43
		material.albedo_texture = _soft_dot_texture()
		mesh.material = material
		particles.draw_pass_1 = mesh
		particles.amount = int(spec[3])
		particles.lifetime = 1.1
		particles.one_shot = true
		particles.explosiveness = 0.5
		particles.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
		particles.position = card.position + Vector3(0.0, 0.0, 0.3)
		fx_root.add_child(particles)
		particles.emitting = true
		get_tree().create_timer(1.6).timeout.connect(particles.queue_free)


var _soft_dot: Texture2D = null


## A soft round dot, so dust and ash are specks of light and not squares.
func _soft_dot_texture() -> Texture2D:
	if _soft_dot == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_soft_dot = texture
	return _soft_dot


# --- 持鞘 (劉語塵's scabbard card) ---------------------------------------------------------------------

## +1 when the opposing camp stands on the +x side of a card.
func _toward_row(card: Node3D) -> float:
	return -1.0 if card.is_enemy else 1.0


## The card leaves its place in the row, strikes the target with its tail and goes back (the order
## then settles it at the far left). `result` is the strike's resolved outcome.
func present_sheath_strike(entity: Object, target: Dictionary, result: Dictionary) -> void:
	var card: Node3D = entity_cards.get(String(entity.get("entity_id")))
	var destination: Node3D = card_for(target)
	if card == null or destination == null:
		return
	busy = true
	command_tray.set_enabled(false)
	var home: Vector3 = card.position
	var strike_at: Vector3 = destination.position + Vector3(-_toward_row(destination) * destination.card_size.x * 0.1, destination.card_size.y * 0.02, 0.9)
	var lunge := create_tween()
	lunge.tween_property(card, "position", home + (strike_at - home) * 0.15 + Vector3(0.0, 0.25, 0.5), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge.tween_property(card, "position", strike_at, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lunge.finished
	if bool(result.get("hit", true)):
		_hit_spark(destination.position + Vector3(0.0, destination.card_size.y * 0.05, 0.9), 1.5, false)
		destination.hit_reaction()
		await _hit_stop(0.05)
	else:
		destination.dodge_motion()
	await get_tree().create_timer(0.2).timeout
	var back := create_tween()
	back.tween_property(card, "position", home, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await back.finished
	busy = false


## 收鞘於背: the card flies to the wielder's back and is gone.
func present_sheath_stow(actor: Dictionary, entity: Object) -> void:
	var card: Node3D = entity_cards.get(String(entity.get("entity_id")))
	var wielder: Node3D = card_for(actor)
	if card == null or wielder == null:
		return
	busy = true
	# The card goes to his side and is slid back in behind him, slowly: a swordsman sheathing a blade.
	if card.has_method("play_stow"):
		await card.play_stow(wielder)
	busy = false


## A blow meant for the wielder is blocked: his next dodge presentation becomes a block, and the
## scabbard card flashes.
func present_sheath_block(target: Dictionary, entity: Object) -> void:
	var card: Node3D = card_for(target)
	if card == null:
		return
	card.block_pending = true
	card.block_card = entity_cards.get(String(entity.get("entity_id"))) if entity != null else null
