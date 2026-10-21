extends Node3D
## Presentation-only command actors. The battle view owns input and eligibility.

signal command_requested(command_id: String)
signal option_requested(index: int)

const COMMAND_IDS: Array[String] = ["skill", "inner_force", "item", "defend"]
const COMMAND_LABELS: Array[String] = ["出招", "內功", "道具", "防禦"]
const BUTTON_SIZE := Vector2(1.25, 1.15)
const OPTION_SIZE := Vector2(2.35, 0.55)
const OPTIONS_PER_PAGE: int = 6
const PREVIOUS_PAGE: int = -2
const NEXT_PAGE: int = -3
const PAGE_INDICATOR: int = -4
const STAGE_FONT: Font = preload("res://assets/fonts/UIFontKaiti.tres")
const OPTION_FONT: Font = preload("res://assets/fonts/UIFontKaiti.tres")

var _buttons: Array[Node3D] = []
var _labels: Array[Label] = []
var _homes: Array[Vector3] = []
var _allowed: Dictionary = {}
var _options: Array[Node3D] = []
var _option_labels: Array[String] = []
var _option_tints: Array = []
var _footer_labels: Array[String] = []
var _option_source_indices: Array[int] = []
var _option_tweens: Array[Tween] = []
var _option_page: int = 0
var _options_root: Node3D
var _enabled: bool = true
var _expanded: bool = false
var _hovered: int = -1
var _pressing: bool = false
var _layout_tween: Tween
var _press_tween: Tween


func _ready() -> void:
	var console := _make_card("", Vector2(8.3, 1.5), Vector2i(1660, 300))
	console.name = "CommandConsole"
	console.position = Vector3(-4.1, -3.75, 2.4)
	console.get_node("Plate").material_override.render_priority = -1
	add_child(console)
	var plaque := _make_card("指\n令", Vector2(0.95, 1.25), Vector2i(190, 250))
	plaque.name = "CommandPlaque"
	plaque.position = Vector3(-7.0, -3.75, 2.5)
	add_child(plaque)
	for index: int in range(COMMAND_IDS.size()):
		var button: Node3D = _make_card(COMMAND_LABELS[index], BUTTON_SIZE, Vector2i(320, 294))
		button.name = COMMAND_IDS[index]
		add_child(button)
		var home := Vector3(-5.4 + float(index) * 1.45, -3.75, 2.5)
		button.position = home
		_buttons.append(button)
		_homes.append(home)
		_labels.append(button.get_node("Surface/Panel/Label") as Label)
		_allowed[COMMAND_IDS[index]] = bool(_allowed.get(COMMAND_IDS[index], true))
	_options_root = Node3D.new()
	_options_root.name = "ExpandedOptions"
	add_child(_options_root)
	_options_root.visible = false
	_build_option_page()
	_refresh_enabled_colors()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_hovered = -1
		_cancel_press()
	_refresh_enabled_colors()
	_reflow()


func set_allowed(command_id: String, allowed: bool) -> void:
	_allowed[command_id] = allowed
	_refresh_enabled_colors()


func set_hover(index: int) -> void:
	var next_hover: int = index if _enabled and index >= 0 and index < _buttons.size() else -1
	if _hovered == next_hover or _pressing:
		return
	_hovered = next_hover
	_reflow()


func press(index: int) -> void:
	if not _enabled or _pressing or index < 0 or index >= _buttons.size():
		return
	var command_id: String = COMMAND_IDS[index]
	if not bool(_allowed.get(command_id, true)):
		return
	_pressing = true
	if _layout_tween != null and _layout_tween.is_valid():
		_layout_tween.kill()
	var button: Node3D = _buttons[index]
	var release_position: Vector3 = button.position
	_press_tween = create_tween()
	_press_tween.tween_property(button, "position:z", release_position.z - 0.32, 0.07)
	_press_tween.tween_property(button, "position:z", release_position.z, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_press_tween.tween_callback(func() -> void:
		_pressing = false
		if _enabled and bool(_allowed.get(command_id, true)):
			command_requested.emit(command_id)
		_reflow()
	)


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	if _options_root == null:
		return
	_options_root.visible = expanded and not _options.is_empty()
	if expanded:
		_animate_options()
	else:
		_cancel_option_tweens()
	_reflow()


func set_options(labels: Array, footer_labels: Array = [], tints: Array = []) -> void:
	var previous_count: int = _option_labels.size()
	# Per option: a Color to show it in (a skill that cannot be used right now, muted), or null for the normal look.
	_option_tints = tints.duplicate()
	_option_labels.clear()
	for text: Variant in labels:
		_option_labels.append(str(text))
	_footer_labels.clear()
	for text: Variant in footer_labels:
		_footer_labels.append(str(text))
	# Keep the page when a selection only changes the label's check mark.
	_option_page = clampi(_option_page, 0, get_option_page_count() - 1) if previous_count == labels.size() else 0
	_build_option_page()


func get_option_page_count() -> int:
	return maxi(1, ceili(float(_option_labels.size()) / float(OPTIONS_PER_PAGE)))


func change_option_page(delta: int) -> void:
	if not _enabled or not _expanded:
		return
	var next_page: int = clampi(_option_page + delta, 0, get_option_page_count() - 1)
	if next_page != _option_page:
		_option_page = next_page
		_build_option_page()


func _build_option_page() -> void:
	if _options_root == null:
		return
	_cancel_option_tweens()
	for option: Node3D in _options:
		_options_root.remove_child(option)
		option.queue_free()
	_options.clear()
	_option_source_indices.clear()
	var first_index: int = _option_page * OPTIONS_PER_PAGE
	var last_index: int = mini(first_index + OPTIONS_PER_PAGE, _option_labels.size())
	for source_index: int in range(first_index, last_index):
		_add_option_card(_option_labels[source_index], source_index, source_index - first_index)
	if get_option_page_count() > 1:
		_add_option_card("上一頁", PREVIOUS_PAGE, 6)
		_add_option_card("%d / %d" % [_option_page + 1, get_option_page_count()], PAGE_INDICATOR, 7)
		_add_option_card("下一頁", NEXT_PAGE, 8)
	# Confirmation is outside the paginated entries and always accessible.
	for i: int in range(_footer_labels.size()):
		_add_option_card(_footer_labels[i], _option_labels.size() + i, 9 + i * 2)
	_options_root.visible = _expanded and not _options.is_empty()
	if _expanded:
		_animate_options()


func _add_option_card(text: String, source_index: int, layout_index: int) -> void:
	var option: Node3D = _make_card(text, OPTION_SIZE, Vector2i(600, 140))
	option.name = "Option%d" % _options.size()
	option.set_meta("layout_index", layout_index)
	_options_root.add_child(option)
	_options.append(option)
	_option_source_indices.append(source_index)
	option.position = _option_position(layout_index)
	if source_index >= 0 and source_index < _option_tints.size() and _option_tints[source_index] is Color:
		(option.get_node("Surface/Panel/Label") as Label).add_theme_color_override("font_color", _option_tints[source_index])
	var unavailable: bool = (source_index == PREVIOUS_PAGE and _option_page == 0) or (source_index == NEXT_PAGE and _option_page == get_option_page_count() - 1)
	if unavailable:
		var label: Label = option.get_node("Surface/Panel/Label") as Label
		label.modulate = Color(0.43, 0.43, 0.43)


func pick(camera: Camera3D, screen_position: Vector2) -> int:
	if not _enabled or not is_visible_in_tree():
		return -1
	return _pick_cards(_buttons, BUTTON_SIZE, camera, screen_position)


func pick_option(camera: Camera3D, screen_position: Vector2) -> int:
	if not _enabled or not _expanded or not is_visible_in_tree():
		return -1
	return _pick_cards(_options, OPTION_SIZE, camera, screen_position)


func press_option(index: int) -> void:
	if _enabled and _expanded and index >= 0 and index < _options.size():
		var source_index: int = _option_source_indices[index]
		if source_index == PREVIOUS_PAGE:
			change_option_page(-1)
		elif source_index == NEXT_PAGE:
			change_option_page(1)
		elif source_index >= 0:
			option_requested.emit(source_index)


func get_button_screen_rects(camera: Camera3D) -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	for button: Node3D in _buttons:
		var first: Vector2 = camera.unproject_position(button.to_global(Vector3(-BUTTON_SIZE.x * 0.5, -BUTTON_SIZE.y * 0.5, 0.0)))
		var rectangle := Rect2(first, Vector2.ZERO)
		for corner: Vector2 in [Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0)]:
			var world_corner: Vector3 = button.to_global(Vector3(corner.x * BUTTON_SIZE.x * 0.5, corner.y * BUTTON_SIZE.y * 0.5, 0.0))
			rectangle = rectangle.expand(camera.unproject_position(world_corner))
		rectangles.append(rectangle)
	return rectangles


func _make_card(text: String, dimensions: Vector2, pixels: Vector2i) -> Node3D:
	var card := Node3D.new()
	var viewport := SubViewport.new()
	viewport.name = "Surface"
	viewport.size = pixels
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	card.add_child(viewport)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.size = Vector2(pixels)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.035, 0.045, 0.055, 0.96)
	plate.border_color = Color(0.76, 0.57, 0.26)
	plate.set_border_width_all(4)
	plate.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", plate)
	viewport.add_child(panel)
	var label := Label.new()
	label.name = "Label"
	label.text = text
	label.position = Vector2(12.0, 10.0)
	label.size = Vector2(pixels) - Vector2(24.0, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", STAGE_FONT if dimensions == BUTTON_SIZE else OPTION_FONT)
	label.add_theme_font_size_override("font_size", 66 if dimensions == BUTTON_SIZE else 52)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58))
	panel.add_child(label)
	var quad := QuadMesh.new()
	quad.size = dimensions
	var mesh := MeshInstance3D.new()
	mesh.name = "Plate"
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = viewport.get_texture()
	mesh.material_override = material
	card.add_child(mesh)
	return card


func _refresh_enabled_colors() -> void:
	for index: int in range(_labels.size()):
		var active: bool = _enabled and bool(_allowed.get(COMMAND_IDS[index], true))
		_labels[index].modulate = Color.WHITE if active else Color(0.43, 0.43, 0.43)


func _reflow() -> void:
	if _buttons.is_empty() or _pressing:
		return
	if _layout_tween != null and _layout_tween.is_valid():
		_layout_tween.kill()
	_layout_tween = create_tween().set_parallel(true)
	_layout_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for index: int in range(_buttons.size()):
		var destination: Vector3 = _homes[index]
		var card_scale := Vector3.ONE
		if _expanded:
			destination.z -= 0.25
		if _hovered >= 0:
			if index == _hovered:
				destination.z += 0.55
				destination.y += 0.06
				card_scale = Vector3.ONE
			else:
				destination.z -= 0.18
				var push: float = 0.21 if absi(index - _hovered) == 1 else 0.08
				destination.x += push * signf(float(index - _hovered))
		_layout_tween.tween_property(_buttons[index], "position", destination, 0.24)
		_layout_tween.tween_property(_buttons[index], "scale", card_scale, 0.24)


func _cancel_press() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_pressing = false


func _option_position(index: int) -> Vector3:
	var column: int = index % 3
	var row: int = floori(float(index) / 3.0)
	return Vector3(-2.6 + float(column) * 2.6, 0.85 - float(row) * 0.68, 3.15 + float(row) * 0.025)


func _animate_options() -> void:
	_cancel_option_tweens()
	for index: int in range(_options.size()):
		var option: Node3D = _options[index]
		var destination: Vector3 = _option_position(int(option.get_meta("layout_index", index)))
		option.position = Vector3(destination.x, -2.45, 1.9)
		var tween: Tween = create_tween()
		_option_tweens.append(tween)
		tween.tween_interval(minf(float(index) * 0.025, 0.18))
		tween.tween_property(option, "position", destination, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _cancel_option_tweens() -> void:
	for tween: Tween in _option_tweens:
		if tween.is_valid():
			tween.kill()
	_option_tweens.clear()


func _pick_cards(cards: Array[Node3D], dimensions: Vector2, camera: Camera3D, screen_position: Vector2) -> int:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	var nearest_index: int = -1
	var nearest_distance: float = INF
	for index: int in range(cards.size()):
		var card: Node3D = cards[index]
		if not card.is_visible_in_tree():
			continue
		var inverse: Transform3D = card.global_transform.affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_direction: Vector3 = inverse.basis * direction
		if absf(local_direction.z) < 0.0001:
			continue
		var distance: float = -local_origin.z / local_direction.z
		if distance <= 0.0 or distance >= nearest_distance:
			continue
		var point: Vector3 = local_origin + local_direction * distance
		if absf(point.x) <= dimensions.x * 0.5 and absf(point.y) <= dimensions.y * 0.5:
			nearest_index = index
			nearest_distance = distance
	return nearest_index
