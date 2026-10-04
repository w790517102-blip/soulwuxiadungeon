extends Node3D

const ActorCard = preload("res://scripts/presentation/StageActorCard.gd")
const CommandTray = preload("res://scripts/presentation/StageCommandTray.gd")
const SwordTrail = preload("res://scripts/presentation/SwordTrail3D.gd")
const STAGE_BACKGROUND := "res://assets/presentation/stalactite_stage.png"
const DEFAULT_BACKGROUND := "res://assets/background/battleUI/defult/Background_defult.jpg"

@export_range(12.0, 40.0) var card_yaw_degrees: float = 22.0
@export_range(25.0, 55.0) var camera_fov: float = 34.0
@export_range(0.6, 0.7) var gaze_dead_zone: float = 0.66
@export var gaze_amplitude: Vector2 = Vector2(0.20, 0.10)
@export var gaze_response: float = 2.0
@export var player_depth: float = 1.0
@export var enemy_depth: float = -1.0
@export var background_depth: float = -8.0

var camera: Camera3D
var command_tray: Node3D
var fx_root: Node3D
var actor_root: Node3D
var backdrop: MeshInstance3D
var cards: Dictionary = {}
var enabled: bool = true
var input_enabled: bool = false
var busy: bool = false
var _camera_home: Vector3 = Vector3(0.0, 0.0, 18.0)
var _status_source: Callable
var _ui: Node
var _background_path: String = ""
var _pointer: Vector2 = Vector2(0.5, 0.5)


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "StageCamera"
	camera.position = _camera_home
	camera.fov = camera_fov
	add_child(camera)
	camera.make_current()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080e16")
	camera.environment = environment
	backdrop = MeshInstance3D.new()
	backdrop.name = "BackgroundBand"
	var quad := QuadMesh.new()
	quad.size = Vector2(33.0, 18.6)
	backdrop.mesh = quad
	backdrop.position.z = background_depth
	add_child(backdrop)
	set_background(DEFAULT_BACKGROUND)
	actor_root = Node3D.new()
	actor_root.name = "ActorBands"
	add_child(actor_root)
	fx_root = Node3D.new()
	fx_root.name = "CombatFXVolume"
	add_child(fx_root)
	command_tray = CommandTray.new()
	command_tray.name = "FrontCommandBand"
	add_child(command_tray)
	command_tray.command_requested.connect(_on_command)
	command_tray.option_requested.connect(_on_option)


func bind_ui(ui: Node) -> void:
	_ui = ui


func set_background(path: String) -> void:
	if path == _background_path:
		return
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		path = DEFAULT_BACKGROUND
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if ResourceLoader.exists(path):
		material.albedo_texture = load(path) as Texture2D
	else:
		# Preview can open before the editor imports the supplied PNG.
		var bitmap := Image.load_from_file(path)
		if not bitmap.is_empty():
			material.albedo_texture = ImageTexture.create_from_image(bitmap)
	material.albedo_color = Color(0.65, 0.69, 0.75)
	backdrop.material_override = material
	_background_path = path


func set_teams(allies: Array, enemies: Array, guest: Dictionary = {}, status_source: Callable = Callable()) -> void:
	_status_source = status_source
	for card in cards.values():
		card.queue_free()
	cards.clear()
	var party: Array = allies.duplicate()
	if not guest.is_empty() and party.size() < 3:
		var guest_view: Dictionary = guest.duplicate(true)
		guest_view["is_guest"] = true
		party.append(guest_view)
	# Preserve the fixed-slot contract, even while the prototype uses one actor.
	for i in range(3):
		var actor: Dictionary = party[i] if i < party.size() else {}
		_add_card(actor, false, i, party.size())
	for i in range(3):
		var actor: Dictionary = enemies[i] if i < enemies.size() else {}
		_add_card(actor, true, i, enemies.size())


func _add_card(actor: Dictionary, enemy: bool, index: int, occupied_count: int) -> void:
	var card: Node3D = ActorCard.new()
	actor_root.add_child(card)
	card.configure(actor, enemy, _status_text(actor))
	var side: float = 1.0 if enemy else -1.0
	var depth: float = enemy_depth if enemy else player_depth
	var y: float = 1.3
	var s: float = 1.0
	if occupied_count > 1:
		y = 3.0 - index * 2.5
	elif index > 0:
		y = -0.6 - (index - 1) * 0.66
		s = 0.22
	card.scale = Vector3.ONE * s
	# +Yaw on the left: left edge is closer to camera. Mirrored on the right.
	card.set_home(Vector3(side * 6.15, y, depth), -side * card_yaw_degrees)
	var key: String = actor_key(actor) if not actor.is_empty() else "%s_empty_%d" % [side, index]
	card.name = "Card_%s" % key.replace("#", "_")
	cards[key] = card


func actor_key(actor: Dictionary) -> String:
	return String(actor.get("battle_uid", actor.get("id", "")))


func card_for(actor: Dictionary) -> Node3D:
	return cards.get(actor_key(actor)) as Node3D


func card_screen_rect(actor: Dictionary) -> Rect2:
	var card := card_for(actor)
	if not card:
		return Rect2()
	var result := Rect2(camera.unproject_position(card.to_global(Vector3.ZERO)), Vector2.ZERO)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		result = result.expand(camera.unproject_position(card.to_global(Vector3(corner.x * ActorCard.CARD_SIZE.x / 2.0, corner.y * ActorCard.CARD_SIZE.y / 2.0, 0))))
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
		if distance > 0 and distance < nearest and absf(point.x) < ActorCard.CARD_SIZE.x / 2.0 and absf(point.y) < ActorCard.CARD_SIZE.y / 2.0:
			nearest = distance
			selected = actor
	return selected


func _status_text(actor: Dictionary) -> String:
	if actor.is_empty() or not _status_source.is_valid():
		return ""
	var data: Dictionary = _status_source.call(actor)
	return String(data.get("text", ""))


func refresh_actor(actor: Dictionary) -> void:
	var card := card_for(actor)
	if card:
		card.refresh(actor, _status_text(actor))


func refresh_statuses(allies: Array, enemies: Array) -> void:
	# Called by explicit UI refresh hooks, not an HP-difference damage detector.
	for actor in allies + enemies:
		refresh_actor(actor)


func present_attack(attacker: Dictionary, target: Dictionary, _skill: Dictionary, result: Dictionary) -> void:
	var source := card_for(attacker)
	var destination := card_for(target)
	if not source or not destination:
		return
	busy = true
	command_tray.set_enabled(false)
	source.attack_motion(destination.home_position)
	await get_tree().create_timer(0.14).timeout
	var hit: bool = bool(result.get("hit", true))
	if not hit:
		destination.dodge_motion()
	var trail: Node3D = SwordTrail.new()
	fx_root.add_child(trail)
	# Reaction begins at the ribbon arrival, while the attacker returns on its
	# own tween. No Engine.time_scale / SceneTree pause changes combat timing.
	_react_at_impact(destination, target, hit, bool(result.get("crit", false)))
	await trail.play(source.position, destination.home_position, hit)
	trail.queue_free()
	await get_tree().create_timer(0.24).timeout
	busy = false


func _react_at_impact(card: Node3D, target: Dictionary, hit: bool, heavy: bool) -> void:
	await get_tree().create_timer(0.32).timeout
	if not hit or not is_instance_valid(card):
		return
	if bool(target.get("defending", false)):
		card.guard_motion()
	else:
		card.hit_reaction(heavy)


func attack_motion(actor: Dictionary) -> void:
	var card := card_for(actor)
	if card:
		card.attack_motion(Vector3(-card.home_position.x, card.home_position.y, -card.home_position.z))


func react(actor: Dictionary, kind: String) -> void:
	var card := card_for(actor)
	if card == null:
		return
	match kind:
		"hit": card.hit_reaction()
		"dodge": card.dodge_motion()
		"guard": card.guard_motion()
		"defend_on":
			if card.has_method("set_guarding"):
				card.set_guarding(true)
			else:
				card.guard_motion()
		"defend_off":
			if card.has_method("set_guarding"):
				card.set_guarding(false)
			card.reset_pose()
		"reset": card.reset_pose()


func gaze_offset(normalized_pointer: Vector2) -> Vector2:
	var centered: Vector2 = normalized_pointer * 2.0 - Vector2.ONE
	var excess := Vector2.ZERO
	for axis in range(2):
		var amount: float = maxf(absf(centered[axis]) - gaze_dead_zone, 0.0) / (1.0 - gaze_dead_zone)
		excess[axis] = signf(centered[axis]) * smoothstep(0.0, 1.0, amount)
	return excess * gaze_amplitude


func _process(delta: float) -> void:
	if not enabled:
		return
	var offset: Vector2 = gaze_offset(_pointer)
	camera.position = camera.position.lerp(_camera_home + Vector3(offset.x, -offset.y, 0.0), 1.0 - exp(-gaze_response * delta))


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if _ui and _ui.get("target_picker") and _ui.target_picker.active:
		return
	if event is InputEventMouseMotion:
		_pointer = event.position / get_viewport().get_visible_rect().size
		command_tray.set_hover(command_tray.pick(camera, event.position) if input_enabled else -1)
	if not input_enabled or busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var option: int = command_tray.pick_option(camera, event.position)
		if option >= 0:
			command_tray.press_option(option)
			get_viewport().set_input_as_handled()
			return
		var index: int = command_tray.pick(camera, event.position)
		if index >= 0:
			command_tray.press(index)
			get_viewport().set_input_as_handled()


func _on_command(command: String) -> void:
	if _ui and input_enabled:
		_ui.dispatch_stage_command(command)


func _on_option(index: int) -> void:
	if _ui and input_enabled:
		_ui.select_stage_option(index)
