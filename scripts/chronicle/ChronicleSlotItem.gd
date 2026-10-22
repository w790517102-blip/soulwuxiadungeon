extends Button
class_name ChronicleSlotItem
# 《江湖行跡錄》左側目錄的單筆欄位（書房卷軸版：用道具頁的列底素材）。
# 子節點：Thumb（縮圖）、NumberLabel、MapLabel、DateLabel。由 ChronicleScreen 動態建立 10 個、翻頁時重複使用。
# 縮圖外框沿用舊皮膚（ChronicleSkin 的 thumb_frame_small），因為書房風格沒有專屬的縮圖框。

const FONT := preload("res://assets/fonts/UIFontKaiti.tres")
const ITEM_SIZE := Vector2(276, 80)
const THUMB_SIZE := Vector2(100, 56)
const ROW_DIR := "res://assets/UI/inventory/"
const INK := Color("#2B1B0E")
const INK_DIM := Color("#5A4630")
const CORRUPT_RED := Color("#A63326")

enum Kind { FILLED, EMPTY, CORRUPT }

var slot_index := 0
var kind: int = Kind.EMPTY
var is_selected := false

var thumb: TextureRect
var number_label: Label
var map_label: Label
var date_label: Label
var _bg: StyleBoxTexture
var _sel_glow: ColorRect
var _sel_tex: TextureRect
var _hover_tex: TextureRect
var _frame: NinePatchRect

func _init() -> void:
	custom_minimum_size = ITEM_SIZE
	size = ITEM_SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = false
	text = ""
	# 列底：一般底永遠在（紙面），選中與移入是疊在上面的光暈（與道具頁同一套寫法）
	_bg = _row_box("row_normal")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, _bg if _bg != null else StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_hover_tex = _overlay_tex("row_hover")
	_hover_tex.modulate.a = 0.0
	_sel_glow = ColorRect.new()
	_sel_glow.size = ITEM_SIZE
	_sel_glow.color = Color(0.95, 0.72, 0.20, 0.0)
	_sel_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sel_glow)
	_sel_tex = _overlay_tex("row_selected")
	_sel_tex.modulate.a = 0.0
	mouse_entered.connect(func(): if not is_selected: _hover_tex.modulate.a = 0.6)
	mouse_exited.connect(func(): _hover_tex.modulate.a = 0.0)

	thumb = TextureRect.new()
	thumb.name = "Thumb"
	thumb.position = Vector2(12, 12)
	thumb.size = THUMB_SIZE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(thumb)
	if ChronicleSkin.has("thumb_frame_small"):
		_frame = ChronicleSkin.make_nine("thumb_frame_small", THUMB_SIZE + Vector2(8, 8))
		_frame.position = Vector2(8, 8)
		add_child(_frame)

	number_label = _make_label("NumberLabel", Vector2(124, 6), Vector2(144, 26), 18, INK)
	map_label = _make_label("MapLabel", Vector2(124, 32), Vector2(144, 22), 15, INK)
	date_label = _make_label("DateLabel", Vector2(124, 56), Vector2(148, 18), 12, INK_DIM)
	map_label.clip_text = true
	map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _row_box(name_: String) -> StyleBoxTexture:
	var p := "%s%s.png" % [ROW_DIR, name_]
	if not ResourceLoader.exists(p):
		return null
	var s := StyleBoxTexture.new()
	s.texture = load(p) as Texture2D
	s.texture_margin_left = 8
	s.texture_margin_right = 8
	s.texture_margin_top = 2
	s.texture_margin_bottom = 2
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return s

func _overlay_tex(name_: String) -> TextureRect:
	var r := TextureRect.new()
	var p := "%s%s.png" % [ROW_DIR, name_]
	r.texture = load(p) as Texture2D if ResourceLoader.exists(p) else null
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = ITEM_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _make_label(label_name: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = label_name
	l.position = pos
	l.size = label_size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

## 設定這一格要顯示的內容。texture 可為 null（沒有縮圖）。
func show_slot(slot: int, new_kind: int, texture: Texture2D, map_text: String, date_text: String) -> void:
	slot_index = slot
	kind = new_kind
	number_label.text = "存檔 %02d" % slot
	thumb.texture = texture
	thumb.visible = kind == Kind.FILLED
	modulate = Color.WHITE
	match kind:
		Kind.FILLED:
			map_label.text = map_text
			date_label.text = date_text
			map_label.add_theme_color_override("font_color", INK)
		Kind.EMPTY:
			map_label.text = "— 空白紀錄 —"
			date_label.text = ""
			map_label.add_theme_color_override("font_color", INK_DIM)
			modulate = Color(1, 1, 1, 0.62)       # 空的紀錄：整格淡一點
		Kind.CORRUPT:
			map_label.text = "存檔異常"
			date_label.text = "無法讀取這份紀錄"
			map_label.add_theme_color_override("font_color", CORRUPT_RED)
			modulate = Color(1.0, 0.82, 0.78, 1.0)  # 異常：整格偏紅
	_apply_selection()

func set_selected(value: bool) -> void:
	is_selected = value
	z_index = 1 if value else 0
	_apply_selection()

func _apply_selection() -> void:
	_sel_glow.color.a = 0.28 if is_selected else 0.0
	_sel_tex.modulate.a = 1.0 if is_selected else 0.0
	if is_selected:
		_hover_tex.modulate.a = 0.0
