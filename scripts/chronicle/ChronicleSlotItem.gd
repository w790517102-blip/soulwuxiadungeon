extends Button
class_name ChronicleSlotItem
# 《江湖行跡錄》左側目錄的單筆欄位（312×88）。
# 子節點：Thumb（縮圖 112×63）、NumberLabel、MapLabel、DateLabel。由 ChronicleScreen 動態建立 10 個、翻頁時重複使用。

const FONT := preload("res://assets/fonts/UIFontKaiti.tres")
const ITEM_SIZE := Vector2(322, 98)
const THUMB_SIZE := Vector2(112, 63)

const COL_BG := Color(0.075, 0.06, 0.05, 0.96)
const COL_BG_HOVER := Color(0.13, 0.10, 0.075, 0.98)
const COL_BG_SELECTED := Color(0.22, 0.06, 0.05, 0.98)
const COL_BORDER := Color(0.42, 0.34, 0.17, 1.0)
const COL_BORDER_SELECTED := Color(0.85, 0.68, 0.28, 1.0)
const COL_BORDER_CORRUPT := Color(0.65, 0.2, 0.15, 1.0)
# 文字顏色一律走 ChronicleSkin.color()（美術換淺色羊皮紙底時，在 skin.json 改成深色字）

enum Kind { FILLED, EMPTY, CORRUPT }

var slot_index := 0
var kind: int = Kind.EMPTY
var is_selected := false

var skin_bg: NinePatchRect = null
var skin_thumb_frame: NinePatchRect = null
var thumb: TextureRect
var number_label: Label
var map_label: Label
var date_label: Label

func _init() -> void:
	custom_minimum_size = ITEM_SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	text = ""

	var thumb_frame := Panel.new()
	thumb_frame.name = "ThumbFrame"
	thumb_frame.position = Vector2(8, 15)
	thumb_frame.size = THUMB_SIZE + Vector2(4, 4)
	thumb_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tf := StyleBoxFlat.new()
	tf.bg_color = Color(0, 0, 0, 0.8)
	tf.set_border_width_all(1)
	tf.border_color = COL_BORDER
	thumb_frame.add_theme_stylebox_override("panel", tf)
	add_child(thumb_frame)

	thumb = TextureRect.new()
	thumb.name = "Thumb"
	thumb.position = Vector2(2, 2)
	thumb.size = THUMB_SIZE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_frame.add_child(thumb)

	number_label = _make_label("NumberLabel", Vector2(132, 9), Vector2(180, 26), 20, ChronicleSkin.color("slot_gold"))
	map_label = _make_label("MapLabel", Vector2(132, 40), Vector2(180, 22), 15, ChronicleSkin.color("slot_text"))
	date_label = _make_label("DateLabel", Vector2(132, 67), Vector2(180, 20), 12, ChronicleSkin.color("slot_dim"))
	map_label.clip_text = true
	map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_setup_skin()
	draw.connect(_refresh_skin_state)

## 有貼圖才套用：欄位底（5 狀態）與縮圖框；沒有貼圖就維持下面 _apply_styles 的暫用色塊。
func _setup_skin() -> void:
	if ChronicleSkin.has("slot_bg_normal"):
		skin_bg = ChronicleSkin.make_nine("slot_bg_normal", ITEM_SIZE)
		skin_bg.name = "SkinBg"
		skin_bg.show_behind_parent = true
		add_child(skin_bg)
		move_child(skin_bg, 0)
	if ChronicleSkin.has("thumb_frame_small"):
		skin_thumb_frame = ChronicleSkin.make_nine("thumb_frame_small", THUMB_SIZE + Vector2(4, 4))
		skin_thumb_frame.position = Vector2(8, 15)
		add_child(skin_thumb_frame)
		(get_node("ThumbFrame") as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())

## 欄位底貼圖的狀態：選中 > Hover > 異常 > 空白 > 正常（缺圖的狀態退回 normal）
func _skin_state_name() -> String:
	if is_selected:
		return "selected"
	if get_draw_mode() == BaseButton.DRAW_HOVER:
		return "hover"
	if kind == Kind.CORRUPT:
		return "corrupt"
	if kind == Kind.EMPTY:
		return "empty"
	return "normal"

func _refresh_skin_state() -> void:
	if skin_bg == null:
		return
	var skin_name := "slot_bg_" + _skin_state_name()
	if not ChronicleSkin.has(skin_name):
		skin_name = "slot_bg_normal"
	var tex := ChronicleSkin.texture(skin_name)
	if skin_bg.texture != tex:
		skin_bg.texture = tex
		var m := ChronicleSkin.margin(skin_name)
		skin_bg.patch_margin_left = m
		skin_bg.patch_margin_right = m
		skin_bg.patch_margin_top = m
		skin_bg.patch_margin_bottom = m

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

static func _box(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(3)
	return s

## 設定這一格要顯示的內容。texture 可為 null（沒有縮圖）。
func show_slot(slot: int, new_kind: int, texture: Texture2D, map_text: String, date_text: String) -> void:
	slot_index = slot
	kind = new_kind
	number_label.text = "存檔 %02d" % slot
	number_label.add_theme_color_override("font_color", ChronicleSkin.color("slot_empty_gold") if kind == Kind.EMPTY else ChronicleSkin.color("slot_gold"))
	thumb.texture = texture
	match kind:
		Kind.FILLED:
			map_label.text = map_text
			date_label.text = date_text
			map_label.add_theme_color_override("font_color", ChronicleSkin.color("slot_text"))
		Kind.EMPTY:
			map_label.text = "— 空白紀錄 —"
			date_label.text = ""
			map_label.add_theme_color_override("font_color", ChronicleSkin.color("slot_empty_dim"))
		Kind.CORRUPT:
			map_label.text = "存檔異常"
			date_label.text = "無法讀取這份紀錄"
			map_label.add_theme_color_override("font_color", ChronicleSkin.color("slot_corrupt"))
	_apply_styles()

func set_selected(value: bool) -> void:
	is_selected = value
	z_index = 1 if value else 0   # 欄位之間略為重疊，選中的那格壓在最上面
	_apply_styles()

func _apply_styles() -> void:
	if skin_bg != null:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_refresh_skin_state()
		return
	var border := COL_BORDER
	var bg := COL_BG
	var hover_bg := COL_BG_HOVER
	var width := 2
	if kind == Kind.CORRUPT:
		border = COL_BORDER_CORRUPT
	if is_selected:
		border = COL_BORDER_SELECTED
		bg = COL_BG_SELECTED
		hover_bg = COL_BG_SELECTED
		width = 3
	add_theme_stylebox_override("normal", _box(bg, border, width))
	add_theme_stylebox_override("hover", _box(hover_bg, COL_BORDER_SELECTED if not is_selected else border, width))
	add_theme_stylebox_override("pressed", _box(COL_BG_SELECTED, COL_BORDER_SELECTED, 3))
	add_theme_stylebox_override("disabled", _box(bg, border, width))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
