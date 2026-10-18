extends RefCounted
class_name MenuSkin
# 系統選單（狀態／道具／裝備／武術／隊伍／見聞／任務）的統一外觀：羊皮紙底上用墨色字、暗金邊的清單與按鈕。
# 重點：每一個換掉的 StyleBox 都「沿用原本的內距（content margin）」，所以不會推動任何子節點的位置——
# 以前把深色底拿掉會讓版面亂掉，就是因為內距跟著不見了。改完請跑 tools/menu_layout_snapshot 前後比對，確認 0 個控制項位移。

const INK := Color("#2B1B0E")            # 羊皮紙上的墨色字
const INK_DIM := Color("#5A4630")
const CREAM := Color("#F4E9CE")           # 深色底（選中、按鈕）上的字
const GOLD := Color("#D9AD47")
const GOLD_DIM := Color("#8A6A2A")
const PLATE := Color(0.10, 0.075, 0.055, 0.94)        # 按鈕、分頁用的深褐底
const PLATE_HOVER := Color(0.20, 0.13, 0.08, 0.96)
const PLATE_PRESSED := Color(0.30, 0.08, 0.07, 0.97)
const PLATE_DISABLED := Color(0.22, 0.19, 0.16, 0.75)
const SELECTED := Color(0.56, 0.11, 0.11, 0.92)       # 選中項目的朱紅底
const LIST_BG := Color(0.42, 0.30, 0.15, 0.13)        # 清單底：極淡的褐色，透出羊皮紙
const LIST_BORDER := Color(0.42, 0.33, 0.18, 0.55)

## 依來源樣式建立新樣式，並保留它的四邊內距
static func _flat(src: StyleBox, bg: Color, border: Color, border_w: int, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	if src != null:
		s.content_margin_left = src.get_margin(SIDE_LEFT)
		s.content_margin_right = src.get_margin(SIDE_RIGHT)
		s.content_margin_top = src.get_margin(SIDE_TOP)
		s.content_margin_bottom = src.get_margin(SIDE_BOTTOM)
	return s

static func _theme_box(c: Control, name: String, type_name: String = "") -> StyleBox:
	return c.get_theme_stylebox(name, type_name) if type_name != "" else c.get_theme_stylebox(name)

static func apply(root: Node) -> void:
	_walk(root)

static func _walk(node: Node) -> void:
	if node is PopupMenu:
		_skin_popup(node as PopupMenu)
	elif node is Control:
		_skin_control(node as Control)
	for child in node.get_children():
		_walk(child)

static func _inside_status_card(c: Node) -> bool:
	# 狀態卡（深色墨帶上的白字名字、數值）自己管顏色，不要動
	var n := c.get_parent()
	while n != null:
		if String(n.name).contains("Status"):
			return true
		n = n.get_parent()
	return false

static func _set_text_colors(c: Control, normal: Color, _dim: Color = INK_DIM) -> void:
	if _inside_status_card(c):
		return
	# 已經自己指定過顏色的（狀態卡的數值、盤纏等）整個不動，連描邊也保留，才不會變細或看不見；
	# 沒指定的才改成墨色字並去掉黑描邊（黑描邊在羊皮紙上會變粗變糊）
	if c.has_theme_color_override("font_color"):
		return
	c.add_theme_color_override("font_color", normal)
	c.add_theme_constant_override("outline_size", 0)

static func _skin_control(c: Control) -> void:
	if c is ItemList:
		_skin_item_list(c as ItemList)
	elif c is OptionButton:
		_skin_button(c as Button)
	elif c is Button:
		if c is CheckBox or c is CheckButton:
			return
		_skin_button(c as Button)
	elif c is TabContainer:
		_skin_tab_container(c as TabContainer)
	elif c is RichTextLabel:
		var r := c as RichTextLabel
		if not r.has_theme_color_override("default_color"):
			r.add_theme_color_override("default_color", INK)
			r.add_theme_constant_override("outline_size", 0)
	elif c is Label:
		_set_text_colors(c, INK)
	elif c is Panel or c is PanelContainer:
		# 預設的深灰底板（例如系統分頁）改成透明，保留內距；已經自己指定樣式的（狀態卡）不動
		if not c.has_theme_stylebox_override("panel"):
			var src := c.get_theme_stylebox("panel")
			var clear := StyleBoxFlat.new()
			clear.bg_color = Color(0, 0, 0, 0)
			clear.content_margin_left = src.get_margin(SIDE_LEFT)
			clear.content_margin_right = src.get_margin(SIDE_RIGHT)
			clear.content_margin_top = src.get_margin(SIDE_TOP)
			clear.content_margin_bottom = src.get_margin(SIDE_BOTTOM)
			c.add_theme_stylebox_override("panel", clear)

static func _skin_item_list(l: ItemList) -> void:
	var base := l.get_theme_stylebox("panel")
	l.add_theme_stylebox_override("panel", _flat(base, LIST_BG, LIST_BORDER, 1, 2))
	l.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	l.add_theme_stylebox_override("selected", _flat(l.get_theme_stylebox("selected"), SELECTED, GOLD, 1, 2))
	l.add_theme_stylebox_override("selected_focus", _flat(l.get_theme_stylebox("selected_focus"), SELECTED, GOLD, 2, 2))
	l.add_theme_stylebox_override("hovered", _flat(l.get_theme_stylebox("hovered"), Color(0.56, 0.11, 0.11, 0.22), GOLD_DIM, 1, 2))
	l.add_theme_stylebox_override("cursor", StyleBoxEmpty.new())
	l.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_hovered_color", INK)
	l.add_theme_color_override("font_selected_color", CREAM)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("guide_color", Color(0.42, 0.33, 0.18, 0.35))

static func _skin_button(b: Button) -> void:
	# 已經有自己的貼圖底（ChronicleSkin.skin_button 加的 SkinBg）：不要再用色塊蓋掉它
	if b.get_node_or_null("SkinBg") != null:
		return
	var tex_kind := String(b.get_meta("menu_skin", ""))
	# 每顆按鈕只套一次貼圖樣式：切分頁會重複呼叫 apply，若每次都在「已加大的內距」上再加，文字會越來越往上
	if b.has_meta("_menu_tex_skinned"):
		return
	if tex_kind != "" and _skin_button_textured(b, tex_kind):
		b.set_meta("_menu_tex_skinned", true)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", CREAM)
		b.add_theme_color_override("font_hover_color", Color("#FFF3D0"))
		b.add_theme_color_override("font_pressed_color", Color("#FFF3D0"))
		b.add_theme_color_override("font_hover_pressed_color", Color("#FFF3D0"))
		b.add_theme_color_override("font_disabled_color", Color(0.62, 0.57, 0.48))
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		b.add_theme_constant_override("outline_size", 0)
		return
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var src := b.get_theme_stylebox(state)
		match state:
			"normal": b.add_theme_stylebox_override(state, _flat(src, PLATE, GOLD_DIM, 2))
			"hover": b.add_theme_stylebox_override(state, _flat(src, PLATE_HOVER, GOLD, 2))
			"pressed", "hover_pressed": b.add_theme_stylebox_override(state, _flat(src, PLATE_PRESSED, GOLD, 2))
			"disabled": b.add_theme_stylebox_override(state, _flat(src, PLATE_DISABLED, Color(0.4, 0.35, 0.28, 0.7), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color("#FFF3D0"))
	b.add_theme_color_override("font_pressed_color", Color("#FFF3D0"))
	b.add_theme_color_override("font_focus_color", CREAM)
	b.add_theme_color_override("font_disabled_color", Color(0.62, 0.57, 0.48))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	b.add_theme_constant_override("outline_size", 0)
	b.mouse_default_cursor_shape = Control.CURSOR_ARROW

static func _skin_tab_container(t: TabContainer) -> void:
	var panel_src := t.get_theme_stylebox("panel")
	# 內容區底板：透明，但保留內距（拿掉內距會讓裡面的版面位移）
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.content_margin_left = panel_src.get_margin(SIDE_LEFT)
	clear.content_margin_right = panel_src.get_margin(SIDE_RIGHT)
	clear.content_margin_top = panel_src.get_margin(SIDE_TOP)
	clear.content_margin_bottom = panel_src.get_margin(SIDE_BOTTOM)
	t.add_theme_stylebox_override("panel", clear)
	for pair in [["tab_selected", SELECTED, GOLD], ["tab_unselected", PLATE, GOLD_DIM], ["tab_hovered", PLATE_HOVER, GOLD], ["tab_disabled", PLATE_DISABLED, GOLD_DIM], ["tab_focus", Color(0, 0, 0, 0), Color(0, 0, 0, 0)]]:
		var src := t.get_theme_stylebox(pair[0])
		t.add_theme_stylebox_override(pair[0], _flat(src, pair[1], pair[2], 1, 2))
	t.add_theme_color_override("font_selected_color", Color("#FFF3D0"))
	t.add_theme_color_override("font_unselected_color", CREAM)
	t.add_theme_color_override("font_hovered_color", Color("#FFF3D0"))
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	t.add_theme_constant_override("outline_size", 0)

static func _skin_popup(p: PopupMenu) -> void:
	p.add_theme_stylebox_override("panel", _flat(p.get_theme_stylebox("panel"), Color(0.94, 0.89, 0.76, 0.98), GOLD_DIM, 2))
	p.add_theme_stylebox_override("hover", _flat(p.get_theme_stylebox("hover"), SELECTED, GOLD, 1, 2))
	p.add_theme_color_override("font_color", INK)
	p.add_theme_color_override("font_hover_color", CREAM)
	p.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	p.add_theme_constant_override("outline_size", 0)


# ------------------------------------------------------------------
# 用《江湖行跡錄》的貼圖皮膚（ChronicleSkin）做按鈕與外框：貼圖是 2 倍解析度，這裡縮成一半再切九宮格，
# 角落裝飾的大小才和畫面其他元件一致。沒有貼圖時回傳 null，呼叫端退回色塊。
# ------------------------------------------------------------------
static var _half_cache: Dictionary = {}
## 按鈕貼圖（縮半後）左右端飾的寬度：端飾約 24px，留 2px 餘裕
const BUTTON_CAP_H := 26
## 按鈕貼圖底部有一條陰影，可見的框體比整張圖偏上；文字上提這麼多 px（邏輯像素）才會看起來在框中央
const TEXT_LIFT := 3

static func _half_texture(skin_name: String) -> Texture2D:
	var key := ChronicleSkin.skin_id + "/" + skin_name
	if _half_cache.has(key):
		return _half_cache[key]
	var tex := ChronicleSkin.texture(skin_name)
	var out: Texture2D = null
	if tex != null:
		var img := tex.get_image()
		img.resize(maxi(1, img.get_width() / 2), maxi(1, img.get_height() / 2), Image.INTERPOLATE_LANCZOS)
		out = ImageTexture.create_from_image(img)
	_half_cache[key] = out
	return out

## margin：貼圖（已縮半）的九宮格邊寬；content：文字離邊的距離（可傳 -1 = 沿用 src 的內距）
## margin_h：左右邊寬（<0 = 同 margin）。按鈕要用「左端飾 | 素淨中段 | 右端飾」：左右邊寬要蓋住整個端飾，中段才不會把端飾的一部分重複平鋪。
static func texture_box(skin_name: String, margin: int, src: StyleBox = null, content: float = -1.0, margin_h: int = -1) -> StyleBoxTexture:
	var tex := _half_texture(skin_name)
	if tex == null:
		return null
	var s := StyleBoxTexture.new()
	s.texture = tex
	var mh := margin if margin_h < 0 else margin_h
	s.texture_margin_left = mh
	s.texture_margin_right = mh
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	# 邊與中段用「平鋪」而不是拉伸：圖案原尺寸重複排列，長條框不會把花紋拉糊（TILE_FIT 會微調比例讓整數個圖案剛好排滿，不切斷）
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	if content >= 0.0:
		s.content_margin_left = content
		s.content_margin_right = content
		s.content_margin_top = content
		s.content_margin_bottom = content
	elif src != null:
		s.content_margin_left = src.get_margin(SIDE_LEFT)
		s.content_margin_right = src.get_margin(SIDE_RIGHT)
		s.content_margin_top = src.get_margin(SIDE_TOP)
		s.content_margin_bottom = src.get_margin(SIDE_BOTTOM)
	return s

## 按鈕貼圖組：meta "menu_skin" = "cat"（分類標籤：一般＝黑金、選中＝朱紅）或 "primary"（主要按鈕：朱紅）
static func _skin_button_textured(b: Button, kind: String) -> bool:
	var names := {}
	if kind == "cat":
		names = {"normal": "btn_normal", "hover": "btn_hover", "pressed": "btn_primary_normal", "hover_pressed": "btn_primary_hover", "disabled": "btn_disabled"}
	else:
		names = {"normal": "btn_primary_normal", "hover": "btn_primary_hover", "pressed": "btn_primary_pressed", "hover_pressed": "btn_primary_hover", "disabled": "btn_primary_disabled"}
	if _half_texture(names["normal"]) == null:
		return false
	for state in names.keys():
		var src := b.get_theme_stylebox(state)
		var box := texture_box(names[state], 15, src, -1.0, BUTTON_CAP_H)
		if box == null:
			return false
		# 上內距清零、下內距 = 上提量×2：文字上移 TEXT_LIFT，而按鈕總高度不增加
		box.content_margin_top = 0.0
		box.content_margin_bottom = TEXT_LIFT * 2.0
		b.add_theme_stylebox_override(state, box)
	return true
