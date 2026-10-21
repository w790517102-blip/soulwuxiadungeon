extends RefCounted
## Shared presentation only. Existing popup lists, data and callbacks remain
## authoritative; page navigation never confirms or executes an action.
const FONT = preload("res://assets/fonts/UIFontKaiti.tres")
const PAGE_SIZE := 8

static func install(popup: PopupPanel, list: ItemList, description: RichTextLabel, buttons: Control, title_text: String, quantity: Label = null) -> void:
	var column: VBoxContainer = popup.get_node("VBoxContainer")
	column.name = "ActionItemListPanel"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_top = 18
	column.offset_right = -18
	column.offset_bottom = -18
	column.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.name = "ActionTitle"
	title.text = title_text
	column.add_child(title)
	column.move_child(title, 0)
	var body := HBoxContainer.new()
	body.name = "ListAndDescription"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	column.move_child(body, 1)
	list.reparent(body)
	var details := VBoxContainer.new()
	details.name = "DescriptionArea"
	details.custom_minimum_size = Vector2(420, 280)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(details)
	description.reparent(details)
	if quantity: quantity.reparent(details)
	list.custom_minimum_size = Vector2(260, 280)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.max_columns = 1
	list.add_theme_constant_override("v_separation", 10)
	description.custom_minimum_size = Vector2(420, 240)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.scroll_active = true
	var pages := HBoxContainer.new()
	pages.name = "PageControls"
	pages.add_theme_constant_override("separation", 14)
	column.add_child(pages)
	column.move_child(pages, 2)
	var previous := Button.new()
	previous.name = "PreviousPage"
	previous.text = "上一頁"
	pages.add_child(previous)
	var indicator := Label.new()
	indicator.name = "PageIndicator"
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(indicator)
	var next := Button.new()
	next.name = "NextPage"
	next.text = "下一頁"
	pages.add_child(next)
	var update_pages := func(_index: int = -1) -> void:
		var selected: PackedInt32Array = list.get_selected_items()
		var page: int = int(selected[0] / PAGE_SIZE) if not selected.is_empty() else 0
		var count := maxi(1, ceili(float(list.item_count) / PAGE_SIZE))
		indicator.text = "%d / %d" % [page + 1, count]
		previous.disabled = page == 0
		next.disabled = page >= count - 1
	previous.pressed.connect(func(): _move_page(list, -1))
	next.pressed.connect(func(): _move_page(list, 1))
	list.item_selected.connect(update_pages)
	popup.about_to_popup.connect(update_pages)
	buttons.name = "ConfirmAndCancel"
	for button in buttons.get_children():
		if button is Button:
			button.custom_minimum_size = Vector2(96, 38)
			button.add_theme_stylebox_override("normal", _style(Color("182331")))
			button.add_theme_stylebox_override("hover", _style(Color("35445a")))
			button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Color("fff0a0")))
	for button in [previous, next]: button.custom_minimum_size = Vector2(96, 36)
	popup.size = Vector2i(820, 450)
	popup.add_theme_stylebox_override("panel", _style(Color("101822")))
	for child in popup.get_children():
		if child is Control and child != column: child.hide()
	list.add_theme_stylebox_override("panel", _style(Color("0b1118"), Color("685432")))
	list.add_theme_stylebox_override("selected", _style(Color("485365")))
	list.add_theme_stylebox_override("selected_focus", _style(Color("485365"), Color("fff0a0")))
	list.add_theme_stylebox_override("hovered", _style(Color("26354a")))
	description.add_theme_stylebox_override("normal", _style(Color("111b27"), Color("685432")))
	preload("res://scripts/presentation/BattleTypography.gd").apply(popup)
	_apply_text_metrics(column)
	update_pages.call()

static func _apply_text_metrics(root: Node) -> void:
	if root is Control:
		root.add_theme_font_size_override("font_size", 20)
		root.add_theme_font_size_override("normal_font_size", 20)
		root.add_theme_constant_override("outline_size", 0)
	for child in root.get_children(): _apply_text_metrics(child)

static func _move_page(list: ItemList, delta: int) -> void:
	if list.item_count == 0: return
	var selected := list.get_selected_items()
	var current := int(selected[0]) if not selected.is_empty() else 0
	var index := clampi((int(current / PAGE_SIZE) + delta) * PAGE_SIZE, 0, list.item_count - 1)
	while index < list.item_count and list.is_item_disabled(index): index += 1
	if index >= list.item_count: return
	list.select(index)
	list.item_selected.emit(index)
	list.ensure_current_is_visible()

static func _style(background: Color, border: Color = Color("c9a565")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	return style
