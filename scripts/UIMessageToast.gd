extends Node
signal queue_drained

const FADE_IN_SEC := 0.15
const HOLD_SEC := 3.0
const FADE_OUT_SEC := 0.25
const TYPE_INTERVAL_SEC := 0.04
const TOAST_FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")

var _queue: Array[String] = []
var _is_showing = false
var _layer: CanvasLayer = null
var _panel: PanelContainer = null
var _label: Label = null
var _skip_typing = false
var _skip_hold = false
var _current_full_text = ""

func push_message(text: String) -> void:
	var msg = text.strip_edges()
	if msg == "":
		return
	_queue.append(msg)
	_ensure_ui()
	_try_show_next()

func _process(_delta: float) -> void:
	if _layer == null or not is_instance_valid(_layer):
		_ensure_ui()
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	if _layer.get_parent() != scene:
		_ensure_ui()

func _try_show_next() -> void:
	if _is_showing:
		return
	if _queue.is_empty():
		return
	_ensure_ui()
	if _panel == null or _label == null:
		return

	_is_showing = true
	var full_text = _queue.pop_front()
	_current_full_text = full_text
	_panel.visible = true
	_panel.modulate.a = 0.0

	_skip_typing = false
	_skip_hold = false

	await _fade_to(1.0, FADE_IN_SEC)
	await _type_text(full_text)
	await _hold_visible()
	await _fade_to(0.0, FADE_OUT_SEC)

	if is_instance_valid(_panel):
		_panel.visible = false
	_is_showing = false
	if _queue.is_empty():
		queue_drained.emit()
	_try_show_next()

func _ensure_ui() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	if _layer != null and is_instance_valid(_layer) and _layer.get_parent() == scene:
		return
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()

	_layer = CanvasLayer.new()
	_layer.name = "UIMessageToastLayer"
	_layer.layer = 200
	scene.add_child(_layer)

	var root = Control.new()
	root.name = "MessageToastRoot"
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "MessageToastPanel"
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -260
	_panel.offset_top = 44
	_panel.offset_right = 260
	_panel.offset_bottom = 88
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	root.add_child(_panel)

	_label = Label.new()
	_label.name = "MessageToastText"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_override("font", TOAST_FONT)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_panel.add_child(_label)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _label == null:
		return
	if _label.text.length() < _current_full_text.length():
		_skip_typing = true
	else:
		_skip_hold = true

func _fade_to(target_alpha: float, duration: float) -> void:
	if _panel == null:
		return
	var tween = _panel.create_tween()
	tween.tween_property(_panel, "modulate:a", target_alpha, duration)
	await tween.finished

func _type_text(full_text: String) -> void:
	if _label == null:
		return
	_label.text = ""
	for i in full_text.length():
		if _skip_typing:
			break
		_label.text = full_text.substr(0, i + 1)
		await get_tree().create_timer(TYPE_INTERVAL_SEC).timeout
	_label.text = full_text

func _hold_visible() -> void:
	var elapsed = 0.0
	while elapsed < HOLD_SEC:
		if _skip_hold:
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func wait_until_idle() -> void:
	if not _is_showing and _queue.is_empty():
		return
	await queue_drained
