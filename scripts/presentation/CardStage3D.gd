extends "res://scripts/presentation/CombatStage25D.gd"
## Card Stage: the same camera, background, FX volume and command tray as
## STAGE_25D, with upright portrait cards placed in one row per camp (see
## CardStageFormation). The party camp stands in the foreground on the left and
## fills about 3/4 of the screen height; the enemy camp stands far back on the
## right at about 2/5. Both sizes come from the perspective camera (distance and
## FOV), never from scale. Party cards turn hard toward the enemy; enemy cards
## stay nearly frontal so their information remains easy to read.

const CardStageActorCard = preload("res://scripts/presentation/CardStageActorCard.gd")
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
	var card_height: float = CardStageActorCard.PORTRAIT_SIZE.y
	player_depth = CAMERA_Z - Formation.distance_for_fraction(card_height, Formation.ALLY_HEIGHT, camera_fov)
	enemy_depth = CAMERA_Z - Formation.distance_for_fraction(card_height, Formation.ENEMY_HEIGHT, camera_fov)
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
		var inverse := card.global_transform.affine_inverse()
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
