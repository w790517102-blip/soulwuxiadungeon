extends Node
## Card Inspect: the pointed card is taken in front of the camera on the left of the screen (nearer than every
## other card, turned to face the player), the rest of the stage is dimmed and frozen, and the panel with the details
## slides in on the right. Closing puts the card back in its place and lets time run again. Presentation only: it
## changes no battle rule and no card position (`home_position` is never touched, so the line-up is as it was).
##
## While a card is inspected the battlefield is in a time freeze: the engine's time scale is practically 0, so every
## animation, effect and particle of the stage stands still. The inspection animates itself from the real clock
## (`Time.get_ticks_usec`), never from the scaled frame time.

const Formation = preload("res://scripts/presentation/CardStageFormation.gd")
const InspectData = preload("res://scripts/presentation/CardInspectData.gd")
const InspectPanel = preload("res://scripts/presentation/CardInspectPanel.gd")

signal opened(key: String)
signal closed

const FOCUS_FRACTION: float = 0.70       # the card's height as a share of the screen's
const FOCUS_SCREEN_X: float = 0.27       # where on the screen it hangs
const FOCUS_SCREEN_Y: float = 0.47
const DIM_ALPHA: float = 0.78
const NEAR_MARGIN: float = 1.4           # the pulled card stays at least this much nearer the camera than any other card
const MOVE_SECONDS: float = 0.38
## Not exactly 0: the engine divides by its time scale in places. This is a stand-still for every purpose.
const FROZEN_TIME_SCALE: float = 0.0001

var ui: Object = null
var stage: Node3D = null
var panel: PanelContainer = null
var _key: String = ""
var _card: Node3D = null
var _dim: MeshInstance3D = null
var _closing: bool = false
var _plan: Dictionary = {}
var _card_scale: Vector3 = Vector3.ONE
var _frozen: bool = false
var _previous_time_scale: float = 1.0
var _panel_rect_target: Rect2 = Rect2()
## The running animation: {start, seconds, from/to of position, rotation, scale, dim alpha, panel slide, done}.
var _anim: Dictionary = {}


func setup(ui_ref: Object, stage_ref: Node3D, _hud: Control, font: Font) -> void:
	ui = ui_ref
	stage = stage_ref
	var layer := CanvasLayer.new()
	layer.name = "InspectLayer"
	layer.layer = 60
	add_child(layer)
	panel = InspectPanel.new(font)
	panel.hide()
	layer.add_child(panel)
	panel.close_requested.connect(close)


func is_open() -> bool:
	return _card != null


func current_key() -> String:
	return _key


## Opens the card with this key ("ent:<id>" for a support card, otherwise the actor key). False when there is no
## such card.
func open_key(key: String) -> bool:
	if is_open() or stage == null or panel == null:
		return false
	var data: Dictionary = {}
	var node: Node3D = null
	if key.begins_with("ent:"):
		var entity: Object = _entity_for(key.trim_prefix("ent:"))
		node = stage.entity_cards.get(key.trim_prefix("ent:")) as Node3D
		if entity == null or node == null:
			return false
		data = InspectData.for_entity(ui, entity)
	else:
		var actor: Dictionary = _actor_for(key)
		node = stage.cards.get(key) as Node3D
		if actor.is_empty() or node == null:
			return false
		data = InspectData.for_actor(ui, actor, bool(node.get("is_enemy")))
	_key = key
	_card = node
	_closing = false
	stage.busy = true
	stage._apply_hover("")
	_stop_card_motion(node)
	_card_scale = node.scale
	_plan = _focus_plan(node)
	_freeze_time()
	_make_dim()
	panel.show_data(data)
	_panel_rect_target = _panel_rect()
	panel.place(_panel_rect_target)
	_start_animation(_pulled_state(node), 0.0, 1.0, Callable())
	opened.emit(key)
	return true


func close() -> void:
	if not is_open() or _closing:
		return
	_closing = true
	var card: Node3D = _card
	var state: Dictionary = {}
	if is_instance_valid(card):
		state = {"position": card.home_position, "rotation": card.home_rotation, "scale": _card_scale}
	_start_animation(state, DIM_ALPHA, 0.0, _finish_close, true)


func _finish_close() -> void:
	if is_instance_valid(_card):
		_card.position = _card.home_position
		_card.rotation = _card.home_rotation
		_card.scale = _card_scale
	if _dim != null:
		_dim.queue_free()
		_dim = null
	panel.set_slide(0.0)
	_card = null
	_key = ""
	_closing = false
	_anim = {}
	_thaw_time()
	if stage != null:
		stage.busy = false
		stage.hover_key = ""
	closed.emit()


# --- Animation from the real clock -----------------------------------------------------------------------------

## Starts moving the card to `target` (position / rotation / scale), the dim to `to_alpha` and the panel to
## `to_slide`, from where they are now.
func _start_animation(target: Dictionary, from_alpha: float, to_slide: float, done: Callable, close_motion: bool = false) -> void:
	var card: Node3D = _card
	var dim_alpha: float = (_dim.material_override as StandardMaterial3D).albedo_color.a if _dim != null else 0.0
	_anim = {
		"start": Time.get_ticks_usec(), "seconds": MOVE_SECONDS, "close": close_motion, "done": done,
		"from_position": card.position if is_instance_valid(card) else Vector3.ZERO,
		"from_rotation": card.rotation if is_instance_valid(card) else Vector3.ZERO,
		"from_scale": card.scale if is_instance_valid(card) else Vector3.ONE,
		"to_position": target.get("position", Vector3.ZERO), "to_rotation": target.get("rotation", Vector3.ZERO), "to_scale": target.get("scale", Vector3.ONE),
		"from_alpha": dim_alpha, "to_alpha": DIM_ALPHA if to_slide > 0.5 else 0.0,
		"from_slide": panel.slide_value(), "to_slide": to_slide,
	}


func _process(_delta: float) -> void:
	if _anim.is_empty():
		return
	var elapsed: float = float(Time.get_ticks_usec() - int(_anim.start)) / 1000000.0
	var progress: float = clampf(elapsed / float(_anim.seconds), 0.0, 1.0)
	var eased: float = (1.0 - pow(1.0 - progress, 3.0)) if not bool(_anim.close) else (progress * progress * (3.0 - 2.0 * progress))
	if is_instance_valid(_card):
		_card.position = (_anim.from_position as Vector3).lerp(_anim.to_position, eased)
		_card.rotation = (_anim.from_rotation as Vector3).lerp(_anim.to_rotation, eased)
		_card.scale = (_anim.from_scale as Vector3).lerp(_anim.to_scale, eased)
	if _dim != null:
		var material: StandardMaterial3D = _dim.material_override as StandardMaterial3D
		var color: Color = material.albedo_color
		color.a = lerpf(float(_anim.from_alpha), float(_anim.to_alpha), eased)
		material.albedo_color = color
	panel.set_slide(lerpf(float(_anim.from_slide), float(_anim.to_slide), eased))
	if progress >= 1.0:
		var done: Callable = _anim.done
		var finished_close: bool = bool(_anim.close)
		if not finished_close:
			_anim = {}
		if done.is_valid():
			done.call()


# --- The freeze ----------------------------------------------------------------------------------------------

func _freeze_time() -> void:
	if _frozen:
		return
	_frozen = true
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = FROZEN_TIME_SCALE


func _thaw_time() -> void:
	if not _frozen:
		return
	_frozen = false
	Engine.time_scale = _previous_time_scale


func _exit_tree() -> void:
	_thaw_time()


# --- Where the card hangs ------------------------------------------------------------------------------------

## Opening and closing take the card out of whatever it was doing and put it exactly back on its slot.
func _stop_card_motion(card: Node3D) -> void:
	if card.has_method("_kill_motion"):
		card._kill_motion()
	if card.has_method("fan_to"):
		card.fan_to(Vector3.ZERO, 0.0)
	card.position = card.home_position
	card.rotation = card.home_rotation


## How far in front of the camera the card hangs and how much it is scaled to keep (a little more than) its apparent
## size: always clearly nearer than every other card, so it can never cut into a neighbour (the party cards stand
## close to the camera).
func _focus_plan(card: Node3D) -> Dictionary:
	var camera: Camera3D = stage.camera
	var focus: float = Formation.distance_for_fraction(float(card.card_size.y), FOCUS_FRACTION, camera.fov)
	var nearest: float = INF
	for other: Node3D in stage._fan_nodes().values():
		if other != card and other.visible:
			nearest = minf(nearest, camera.global_position.distance_to(other.global_position))
	var distance: float = focus * 0.92
	if nearest < INF:
		distance = minf(distance, nearest - NEAR_MARGIN)
	distance = maxf(distance, 1.2)
	return {"distance": distance, "nearest": nearest, "scale": distance / focus * 1.06}


func _pulled_state(card: Node3D) -> Dictionary:
	var camera: Camera3D = stage.camera
	var screen: Vector2 = stage.get_viewport().get_visible_rect().size
	var world: Vector3 = camera.project_position(Vector2(screen.x * FOCUS_SCREEN_X, screen.y * FOCUS_SCREEN_Y), float(_plan.distance))
	return {"position": stage.actor_root.to_local(world), "rotation": Vector3.ZERO, "scale": _card_scale * float(_plan.scale)}


## A dark sheet across the whole view, behind the pulled card and in front of every other card.
func _make_dim() -> void:
	var camera: Camera3D = stage.camera
	var screen: Vector2 = stage.get_viewport().get_visible_rect().size
	var dim_distance: float = float(_plan.distance) + 0.7
	if float(_plan.nearest) < INF:
		dim_distance = clampf(dim_distance, float(_plan.distance) + 0.2, float(_plan.nearest) - 0.6)
	var visible_height: float = 2.0 * dim_distance * tan(deg_to_rad(camera.fov) / 2.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(visible_height * (screen.x / maxf(screen.y, 1.0)) * 1.4, visible_height * 1.4)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.0, 0.0, 0.02, 0.0)
	_dim = MeshInstance3D.new()
	_dim.name = "InspectDim"
	_dim.mesh = quad
	_dim.material_override = material
	_dim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(_dim)
	var basis: Basis = camera.global_transform.basis
	_dim.global_transform = Transform3D(basis, camera.global_position - basis.z * dim_distance)


func _panel_rect() -> Rect2:
	var screen: Vector2 = stage.get_viewport().get_visible_rect().size
	var left: float = screen.x * 0.50
	return Rect2(left, 36.0, screen.x - left - 28.0, screen.y - 36.0 - 150.0)


func _entity_for(entity_id: String) -> Object:
	var controller: Object = ui.get("combat_controller") as Object
	if controller == null or controller.get("stage_entities") == null:
		return null
	return controller.stage_entities.get_entity(entity_id)


func _actor_for(key: String) -> Dictionary:
	var pool: Array = []
	pool.append_array(ui.get("allies"))
	pool.append_array(ui.get("enemies"))
	var controller: Object = ui.get("combat_controller") as Object
	if controller != null and controller.get("turn_manager") != null and not (controller.turn_manager.guest_actor as Dictionary).is_empty():
		pool.append(controller.turn_manager.guest_actor)
	for actor: Variant in pool:
		if typeof(actor) == TYPE_DICTIONARY and stage.actor_key(actor) == key:
			return actor
	return {}
