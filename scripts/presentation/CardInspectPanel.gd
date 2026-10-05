extends PanelContainer
## The right-hand side of Card Inspect: the data container of CardInspectData drawn as a title, a few blocks of
## text and the list of statuses (an icon where there is art, the old word where there is not).

const StatusRow = preload("res://scripts/presentation/CardStageStatusRow.gd")

signal close_requested

const GOLD := Color("c9a565")
const PAPER := Color("eee4ca")
const MUTED := Color("b9b29c")
const BUFF_COLOR := Color("67e08a")
const DEBUFF_COLOR := Color("ff6b6b")
const GUARD_COLOR := Color("c79bff")
const INFO_COLOR := Color("8fc4ff")

var _font: Font = null
var _content: VBoxContainer
var _scroll: ScrollContainer
var _close_button: Button
var _tab_overview: Button
var _tab_skills: Button
var _skills_root: HBoxContainer
var _skills_description: RichTextLabel
var _skill_group: ButtonGroup
var _data: Dictionary = {}
var _skills_built: bool = false
var _page: String = "overview"


func _init(font: Font = null) -> void:
	_font = font
	name = "CardInspectPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	outer.add_child(top)
	# Two pages: the overview, and the skills (a list with one description). The skills tab exists only for a character.
	_tab_overview = _tab_button("總覽")
	_tab_overview.pressed.connect(func() -> void: _show_page("overview"))
	top.add_child(_tab_overview)
	_tab_skills = _tab_button("武學")
	_tab_skills.pressed.connect(func() -> void: _show_page("skills"))
	top.add_child(_tab_skills)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_close_button = Button.new()
	_close_button.text = "關閉  [ESC]"
	_close_button.focus_mode = Control.FOCUS_NONE
	if _font != null:
		_close_button.add_theme_font_override("font", _font)
	_close_button.add_theme_font_size_override("font_size", 20)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	top.add_child(_close_button)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	_scroll.add_child(_content)
	_skills_root = HBoxContainer.new()
	_skills_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skills_root.add_theme_constant_override("separation", 14)
	_skills_root.hide()
	outer.add_child(_skills_root)


## Fills the panel. `data` is a CardInspectData container. It always opens on the overview.
func show_data(data: Dictionary) -> void:
	_data = data
	_skills_built = false
	_tab_skills.visible = data.has("skill_page")
	_show_page("overview")
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_content.add_child(_label(String(data.get("title", "")), 34, PAPER))
	if String(data.get("subtitle", "")) != "":
		_content.add_child(_label(String(data.get("subtitle", "")), 18, MUTED))
	_content.add_child(HSeparator.new())
	# The first block (the basics), then the statuses - the part the player comes for - then the rest.
	var blocks: Array = data.get("blocks", [])
	if not blocks.is_empty():
		_add_block(blocks[0])
	var statuses: Array = data.get("statuses", [])
	_content.add_child(_label("目前狀態", 20, GOLD))
	if statuses.is_empty():
		_content.add_child(_label("無", 18, MUTED))
	for status_any: Variant in statuses:
		_content.add_child(_status_row(status_any))
	for index: int in range(1, blocks.size()):
		_add_block(blocks[index])
	for note: Variant in data.get("notes", []):
		_content.add_child(_rich("[color=#b9b29c]%s[/color]" % String(note)))
	_scroll.scroll_vertical = 0


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _rich(bbcode: String) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font != null:
		rich.add_theme_font_override("normal_font", _font)
		rich.add_theme_font_override("bold_font", _font)
	rich.add_theme_font_size_override("normal_font_size", 18)
	rich.add_theme_font_size_override("bold_font_size", 18)
	rich.add_theme_color_override("default_color", PAPER)
	rich.text = bbcode
	return rich


## One status: [icon or word]  name  effect  /  turns left  /  source.
func _status_row(status_any: Variant) -> Control:
	var status: Dictionary = status_any
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Color = DEBUFF_COLOR
	match String(status.get("kind", "debuff")):
		"buff":
			color = BUFF_COLOR
		"guard":
			color = GUARD_COLOR
		"info":
			color = INFO_COLOR
	var texture: Texture2D = StatusRow.texture_for(String(status.get("id", ""))) if String(status.get("id", "")) != "" else null
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	else:
		var word := _label("[%s]" % String(status.get("glyph", "?")), 24, color)
		word.custom_minimum_size = Vector2(48, 48)
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(word)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head: String = String(status.get("name", ""))
	if String(status.get("effect", "")) != "":
		head += "　%s" % String(status.get("effect", ""))
	text.add_child(_label(head, 19, color))
	var detail: Array[String] = []
	if String(status.get("turns", "")) != "":
		detail.append(String(status.get("turns", "")))
	if String(status.get("source", "")) != "":
		detail.append("來源：%s" % String(status.get("source", "")))
	if not detail.is_empty():
		text.add_child(_label("｜".join(detail), 16, MUTED))
	row.add_child(text)
	return row


## Where the panel stands when fully shown; `set_slide` moves it between hidden (0) and shown (1).
var _rect: Rect2 = Rect2()
var _slide_value: float = 0.0


func place(rect: Rect2) -> void:
	_rect = rect
	size = rect.size
	set_slide(0.0)


func slide_value() -> float:
	return _slide_value


## 0 = off to the right and invisible, 1 = in place. Driven by Card Inspect from the real clock.
func set_slide(amount: float) -> void:
	_slide_value = clampf(amount, 0.0, 1.0)
	visible = _slide_value > 0.001
	position = Vector2(_rect.position.x + _rect.size.x * 0.6 * (1.0 - _slide_value), _rect.position.y)
	modulate.a = _slide_value


func _add_block(block_any: Variant) -> void:
	var block: Dictionary = block_any
	_content.add_child(_label(String(block.get("heading", "")), 20, GOLD))
	for line: Variant in block.get("lines", []):
		_content.add_child(_rich(String(line)))


# --- Pages ------------------------------------------------------------------------------------------------------

func _tab_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 22)
	return button


func current_page() -> String:
	return _page


func _show_page(page: String) -> void:
	if page == "skills" and not _data.has("skill_page"):
		page = "overview"
	_page = page
	_tab_overview.set_pressed_no_signal(page == "overview")
	_tab_skills.set_pressed_no_signal(page == "skills")
	_scroll.visible = page == "overview"
	_skills_root.visible = page == "skills"
	if page == "skills" and not _skills_built:
		_build_skills_page()


func _list_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.14, 0.09, 0.95) if selected else Color(0.07, 0.08, 0.1, 0.0)
	style.border_color = GOLD if selected else Color(0, 0, 0, 0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


## The skill page: the list on the left (inner forces, then martial skills), the description frame on the right.
func _build_skills_page() -> void:
	_skills_built = true
	for child: Node in _skills_root.get_children():
		_skills_root.remove_child(child)
		child.queue_free()
	var left := ScrollContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.9
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_skills_root.add_child(left)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	left.add_child(list)
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.5
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	frame_style.border_color = Color(GOLD, 0.7)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(4)
	frame_style.content_margin_left = 16
	frame_style.content_margin_right = 12
	frame_style.content_margin_top = 12
	frame_style.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel", frame_style)
	_skills_root.add_child(frame)
	var frame_scroll := ScrollContainer.new()
	frame_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(frame_scroll)
	_skills_description = RichTextLabel.new()
	_skills_description.bbcode_enabled = true
	_skills_description.fit_content = true
	_skills_description.scroll_active = false
	_skills_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font != null:
		_skills_description.add_theme_font_override("normal_font", _font)
		_skills_description.add_theme_font_override("bold_font", _font)
	_skills_description.add_theme_font_size_override("normal_font_size", 19)
	_skills_description.add_theme_font_size_override("bold_font_size", 24)
	_skills_description.add_theme_color_override("default_color", PAPER)
	frame_scroll.add_child(_skills_description)
	_skill_group = ButtonGroup.new()
	var first: Button = null
	var page: Dictionary = _data.get("skill_page", {})
	for section_any: Variant in page.get("sections", []):
		var section: Dictionary = section_any
		list.add_child(_label("【%s】" % String(section.get("heading", "")), 20, GOLD))
		for entry_any: Variant in section.get("entries", []):
			var entry: Dictionary = entry_any
			var button := Button.new()
			var text: String = String(entry.get("name", ""))
			if String(entry.get("tag", "")) != "":
				text += "　" + String(entry.get("tag", ""))
			button.text = text
			button.toggle_mode = true
			button.button_group = _skill_group
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.focus_mode = Control.FOCUS_NONE
			button.clip_text = true
			if _font != null:
				button.add_theme_font_override("font", _font)
			button.add_theme_font_size_override("font_size", 20)
			var color: Color = entry.get("color", Color.WHITE)
			for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
				button.add_theme_color_override(key, color)
			button.add_theme_stylebox_override("normal", _list_style(false))
			button.add_theme_stylebox_override("hover", _list_style(false))
			button.add_theme_stylebox_override("pressed", _list_style(true))
			button.add_theme_stylebox_override("hover_pressed", _list_style(true))
			button.pressed.connect(_select_skill_entry.bind(entry))
			list.add_child(button)
			if first == null:
				first = button
				first.set_meta("entry", entry)
	if first != null:
		first.set_pressed_no_signal(true)
		_select_skill_entry(first.get_meta("entry"))


func _select_skill_entry(entry: Dictionary) -> void:
	_skills_description.text = "\n".join(PackedStringArray(entry.get("lines", [])))


## The text of the description frame (for tests).
func skills_description_text() -> String:
	return _skills_description.text if _skills_description != null else ""


## Selects the skill-page entry with this id (for tests; the player clicks).
func select_skill_entry_by_id(entry_id: String) -> bool:
	for section_any: Variant in (_data.get("skill_page", {}) as Dictionary).get("sections", []):
		for entry_any: Variant in (section_any as Dictionary).get("entries", []):
			if String((entry_any as Dictionary).get("id", "")) == entry_id:
				_select_skill_entry(entry_any)
				return true
	return false
