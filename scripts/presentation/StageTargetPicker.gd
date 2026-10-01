extends Control
## Presentation state only. Final confirmation delegates to BattleUI's existing
## target callback; selecting/cancelling never spends resources or ends a turn.
signal target_confirmed(actor: Dictionary)
signal selection_cancelled

enum State { CLOSED, PICKING, CONFIRMING }
var state := State.CLOSED
var active: bool:
	get: return state != State.CLOSED
var stage: Node3D
var caster: Dictionary = {}
var candidates: Array = []
var selected: Dictionary = {}
var pointer := Vector2.ZERO
var include_dead: bool = false
var prompt: PanelContainer
var confirmation: PanelContainer
var _confirmation_text: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 150
	prompt = _panel("TargetPrompt")
	var row := HBoxContainer.new()
	prompt.add_child(row)
	var title := Label.new()
	title.text = "請選擇目標"
	row.add_child(title)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(cancel_layer)
	row.add_child(cancel)
	confirmation = _panel("TargetConfirmation")
	var column := VBoxContainer.new()
	confirmation.add_child(column)
	_confirmation_text = Label.new()
	column.add_child(_confirmation_text)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for text: String in ["確定", "取消"]:
		var button := Button.new()
		button.text = text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
		button.pressed.connect(confirm_target if text == "確定" else cancel_layer)
	preload("res://scripts/presentation/BattleTypography.gd").apply(self)
	close()


func _panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101822")
	style.border_color = Color("c9a565")
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_theme_font_size_override("font_size", 20)
	add_child(panel)
	return panel


func begin(source: Dictionary, targets: Array, allow_dead: bool = false) -> void:
	caster = source
	candidates = targets
	include_dead = allow_dead
	selected = {}
	state = State.PICKING
	pointer = get_viewport().get_mouse_position()
	show()
	prompt.show()
	confirmation.hide()
	_update_pointer(pointer)


func close() -> void:
	_clear_focus()
	if stage and stage.has_method("set_hover_target"): stage.set_hover_target({})
	state = State.CLOSED
	selected = {}
	caster = {}
	candidates = []
	hide()
	if prompt: prompt.hide()
	if confirmation: confirmation.hide()
	queue_redraw()


func cancel_layer() -> void:
	if state == State.CONFIRMING:
		selected = {}
		state = State.PICKING
		confirmation.hide()
		_update_pointer(pointer)
	elif state == State.PICKING:
		close()
		selection_cancelled.emit()


func select_at(screen_position: Vector2) -> void:
	if state != State.PICKING:
		return
	selected = stage.pick_actor(screen_position, candidates, include_dead)
	if selected.is_empty():
		return
	pointer = screen_position
	state = State.CONFIRMING
	_confirmation_text.text = "確認目標？\n%s" % String(selected.get("display_name", selected.get("name", "")))
	confirmation.show()
	confirmation.reset_size()
	_place_confirmation()
	_update_focus(selected)
	queue_redraw()


func confirm_target() -> void:
	if state != State.CONFIRMING:
		return
	if int(selected.get("hp", 0)) <= 0 and not include_dead:
		cancel_layer()
		return
	var target := selected
	close()
	target_confirmed.emit(target)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and state == State.PICKING:
		_update_pointer(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_layer()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_layer()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_at(event.position)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not active:
		return
	position = -get_parent().global_position
	size = get_viewport_rect().size
	prompt.position = Vector2((size.x - prompt.size.x) / 2.0, 56)
	if state == State.CONFIRMING: _place_confirmation()
	queue_redraw()


func _place_confirmation() -> void:
	var screen := get_viewport_rect().size
	confirmation.position = (pointer + Vector2(20, 16)).clamp(Vector2(12, 100), screen - confirmation.size - Vector2(12, 160))


func _clear_focus() -> void:
	if not stage: return
	for card in stage.cards.values(): card.set_target_focus(false)


func _update_focus(actor: Dictionary) -> void:
	_clear_focus()
	var card: Node3D = stage.card_for(actor)
	if card: card.set_target_focus(true)
	# Presentations that fan their cards (CARD_STAGE) react to the hovered card.
	if stage.has_method("set_hover_target"): stage.set_hover_target(actor)


func _update_pointer(point: Vector2) -> void:
	pointer = point
	_update_focus(stage.pick_actor(pointer, candidates, include_dead))
	queue_redraw()


func _draw() -> void:
	if not active or not stage:
		return
	var rectangle: Rect2 = stage.card_screen_rect(caster)
	var start := Vector2(rectangle.end.x, rectangle.get_center().y)
	var end := pointer
	var bend := (start + end) * 0.5 + Vector2(0, -minf(140, start.distance_to(end) * 0.3))
	var points := PackedVector2Array()
	for i in range(41):
		var t := float(i) / 40.0
		points.append(start.lerp(bend, t).lerp(bend.lerp(end, t), t))
	draw_polyline(points, Color("f5d98c"), 3, true)
	var direction := (end - points[39]).normalized()
	draw_colored_polygon(PackedVector2Array([end, end - direction.rotated(0.55) * 17, end - direction.rotated(-0.55) * 17]), Color("f5d98c"))
