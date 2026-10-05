extends Control
## The status row of a Card Stage card: an icon per status (a small word where the icon art is missing), laid out in
## the card template's status rectangle. All sizes are in the card's template canvas pixels.
##
##   entry = {"id": canonical status id, "glyph": the old single-word token, "kind": "buff" | "debuff" | "guard",
##            "blink": true on the last turn}
##
## An icon is `res://assets/UI/card_stage/status/<icon key>.png` (the key comes from StatusDisplayDB, `status_<id>`
## unless overridden). A missing or unloadable texture falls back to the word, in the same cell; icons and words
## may share a row. If the entries do not fit, the last cell shows "+N" instead of cutting them off.

const StatusDisplay = preload("res://scripts/db/StatusDisplayDB.gd")
const ICON_DIR := "res://assets/UI/card_stage/status/"
const GAP: float = 5.0
const BUFF_COLOR := Color("67e08a")
const DEBUFF_COLOR := Color("ff6b6b")
const GUARD_COLOR := Color("c79bff")
const OVERFLOW_COLOR := Color("f2d27a")

## id -> Texture2D, or null when there is no (loadable) art. Shared by every card.
static var _textures: Dictionary = {}

var icon_px: float = 64.0
var word_px: int = 40
var font: Font = null
var _signature: String = ""


func configure(rect: Rect2, icon_size: float, word_size: int, word_font: Font) -> void:
	position = rect.position
	size = rect.size
	icon_px = icon_size
	word_px = word_size
	font = word_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


## The texture of a status, or null (cached either way).
static func texture_for(status_id: String) -> Texture2D:
	if _textures.has(status_id):
		return _textures[status_id]
	var path: String = "%s%s.png" % [ICON_DIR, StatusDisplay.icon_key(status_id)]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_textures[status_id] = texture
	return texture


func columns() -> int:
	return maxi(1, int((size.x + GAP) / (icon_px + GAP)))


func rows() -> int:
	return maxi(1, int((size.y + GAP) / (icon_px + GAP)))


## How many cells the rectangle holds (the "+N" cell included).
func capacity() -> int:
	return columns() * rows()


## Which entries get a cell of their own and how many are left over ("+N" takes the last cell).
func plan(entries: Array) -> Dictionary:
	var slots: int = capacity()
	if entries.size() <= slots:
		return {"shown": entries.size(), "hidden": 0}
	return {"shown": slots - 1, "hidden": entries.size() - (slots - 1)}


func clear() -> void:
	_signature = ""
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func show_entries(entries: Array) -> void:
	var blink_on: bool = sin(float(Time.get_ticks_msec()) / 180.0) > 0.0
	var parts: PackedStringArray = []
	for entry_any: Variant in entries:
		var entry: Dictionary = entry_any
		parts.append("%s:%s:%s" % [String(entry.get("id", "")), String(entry.get("glyph", "")), "1" if (bool(entry.get("blink", false)) and not blink_on) else "0"])
	var signature: String = "|".join(parts)
	if signature == _signature:
		return
	_signature = signature
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var layout: Dictionary = plan(entries)
	var shown: int = int(layout.shown)
	var per_row: int = columns()
	var used_rows: int = mini(rows(), int(ceil(float(shown + (1 if int(layout.hidden) > 0 else 0)) / float(per_row))))
	# One row is centred in the rectangle; two stack from the top.
	var top: float = maxf(0.0, (size.y - (used_rows * icon_px + (used_rows - 1) * GAP)) * 0.5)
	for index: int in range(shown):
		var entry: Dictionary = entries[index]
		var faded: bool = bool(entry.get("blink", false)) and not blink_on
		_add_cell(index, per_row, top, entry, faded)
	if int(layout.hidden) > 0:
		_add_overflow(shown, per_row, top, int(layout.hidden))


func _cell_position(index: int, per_row: int, top: float) -> Vector2:
	return Vector2(float(index % per_row) * (icon_px + GAP), top + float(index / per_row) * (icon_px + GAP))


func _add_cell(index: int, per_row: int, top: float, entry: Dictionary, faded: bool) -> void:
	var at: Vector2 = _cell_position(index, per_row, top)
	var texture: Texture2D = texture_for(String(entry.get("id", "")))
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = at
		icon.size = Vector2(icon_px, icon_px)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(1, 1, 1, 0.3 if faded else 1.0)
		add_child(icon)
		return
	# No art: the old single word, in the same cell.
	var color: Color = DEBUFF_COLOR
	match String(entry.get("kind", "debuff")):
		"buff":
			color = BUFF_COLOR
		"guard":
			color = GUARD_COLOR
	var glyph: String = String(entry.get("glyph", "?"))
	_add_word(at, "·" if faded else glyph, color)


func _add_overflow(index: int, per_row: int, top: float, hidden: int) -> void:
	_add_word(_cell_position(index, per_row, top), "+%d" % hidden, OVERFLOW_COLOR)


func _add_word(at: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(icon_px, icon_px)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", word_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
