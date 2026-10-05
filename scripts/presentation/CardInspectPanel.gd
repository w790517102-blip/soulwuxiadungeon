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
var _slide: Tween = null


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
	outer.add_child(top)
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


## Fills the panel. `data` is a CardInspectData container.
func show_data(data: Dictionary) -> void:
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


## Slides in from the right edge to `target_rect` (the rest of the screen stays where it is).
func slide_in(target_rect: Rect2) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	position = Vector2(target_rect.position.x + target_rect.size.x * 0.6, target_rect.position.y)
	size = target_rect.size
	modulate.a = 0.0
	show()
	_slide = create_tween().set_parallel(true)
	_slide.tween_property(self, "position", target_rect.position, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(self, "modulate:a", 1.0, 0.22)


func slide_out(on_done: Callable = Callable()) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = create_tween().set_parallel(true)
	_slide.tween_property(self, "position:x", position.x + size.x * 0.5, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_slide.tween_property(self, "modulate:a", 0.0, 0.2)
	_slide.chain().tween_callback(func() -> void:
		hide()
		if on_done.is_valid():
			on_done.call())


func _add_block(block_any: Variant) -> void:
	var block: Dictionary = block_any
	_content.add_child(_label(String(block.get("heading", "")), 20, GOLD))
	for line: Variant in block.get("lines", []):
		_content.add_child(_rich(String(line)))
