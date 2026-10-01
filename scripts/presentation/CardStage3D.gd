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
	if _active_card != null and not is_instance_valid(_active_card):
		clear_active_actor()
	elif turn_marker and turn_marker.visible:
		_follow_marker()


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
	if not guest.is_empty() and party.size() < 3:
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
		var layout: Dictionary = Formation.slot(present.size(), ranks[index], enemy)
		var card: Node3D = CardStageActorCard.new()
		# The card template (character / enemy / boss) must be known before it builds.
		card.prepare_for(actor, enemy)
		actor_root.add_child(card)
		card.configure(actor, enemy, _status_text(actor))
		card.scale = Vector3.ONE
		var position: Vector3 = Formation.world_position(layout, card.card_size.y, CAMERA_Z, camera_fov)
		card.set_home(position, _yaw_for(enemy))
		card.slot_rank = layout.rank
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
		var rest: Array = []
		for key: String in cards.keys():
			if cards[key].is_enemy == enemy_side and not row.has(key):
				rest.append(key)
		rest.sort_custom(func(a: String, b: String) -> bool: return cards[a].slot_rank < cards[b].slot_rank)
		for key: String in rest:
			row.append(key)
		for rank: int in range(row.size()):
			ranks[row[rank]] = rank
	return ranks


func apply_order(keys: Array[String], animated: bool) -> void:
	var ranks: Dictionary = ranks_from_order(keys)
	var counts: Dictionary = {false: 0, true: 0}
	for card: Node3D in cards.values():
		counts[card.is_enemy] += 1
	for key: String in ranks.keys():
		var card: Node3D = cards[key]
		var rank: int = ranks[key]
		if rank == card.slot_rank:
			continue
		var layout: Dictionary = Formation.slot(counts[card.is_enemy], rank, card.is_enemy)
		var position: Vector3 = Formation.world_position(layout, card.card_size.y, CAMERA_Z, camera_fov)
		var was_front: bool = card.slot_rank == 0
		card.slot_rank = rank
		card.name = "Card_%d_%s" % [rank, key.replace("#", "_")]
		layout["position"] = position
		slots[key] = layout
		if animated:
			card.relocate(position, was_front and rank > 0)
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
	var signature: String = "|".join(keys)
	if signature == _order_signature or not _cards_idle():
		return
	var first: bool = _order_signature.is_empty()
	_order_signature = signature
	hover_key = ""
	apply_order(keys, not first)
