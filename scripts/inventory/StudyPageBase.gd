extends Control
# 新版系統頁（書房桌面＋卷軸）共用的底層：素材與版面輔助函式、背景外殼、導航列、提示、彈出視窗遮罩。
# 道具頁（InventoryPage）、裝備頁（EquipmentPage）都繼承它；座標、尺寸一律是邏輯 px（素材為 2 倍，這裡縮成一半）。

signal close_requested
signal tab_requested(tab_name: String)

const DIR := "res://assets/UI/inventory/"
const FONT := preload("res://assets/fonts/DotGothic16-Regular.ttf")

const INK := Color("#2B1B0E")
const INK_DIM := Color("#5A4630")
const CREAM := Color("#F4E9CE")
const GOLD := Color("#E6C46A")

const NAV_TABS := [
	{"name": "TabStatus", "label": "狀態"}, {"name": "TabItem", "label": "道具"}, {"name": "TabEquip", "label": "裝備"},
	{"name": "TabSkill", "label": "武術"}, {"name": "TabParty", "label": "隊伍"}, {"name": "TabLore", "label": "見聞"},
	{"name": "TabQuest", "label": "任務"}, {"name": "TabSystem", "label": "系統"},
]
const BUTTON_Z := 12   # 比前景前排（z 10）高：按鈕永遠不會被前景遮住

## 裝備頁紙面用哪一版：false＝共邊國原檔（預設）；true＝泛黃＋污漬＋燒焦的後製版（備案，tools/age_paper.gd 做的；缺點是紋理會被模糊掉）
static var use_aged_equipment_paper := false

var _half_cache: Dictionary = {}
var _shell: Node
var _toast: Control
var _toast_label: Label
var _overlay: Control               # 彈出視窗（選擇、確認）的遮罩層

# ------------------------------------------------------------------
# 素材輔助
# ------------------------------------------------------------------
func _tex(name: String) -> Texture2D:
	# "equipment/xxx" 讀 assets/UI/equipment/；其他讀 assets/UI/inventory/
	var p := "%s%s.png" % [DIR, name]
	if name.begins_with("equipment/"):
		p = "res://assets/UI/%s.png" % name
		# 備案：泛黃後製版放在 assets/UI/equipment_aged/（沒有的檔案退回原檔）
		if use_aged_equipment_paper:
			var aged := "res://assets/UI/equipment_aged/%s.png" % name.trim_prefix("equipment/")
			if ResourceLoader.exists(aged):
				p = aged
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## 縮成一半的貼圖（素材是 2 倍），用來做 StyleBoxTexture（它不能縮放貼圖）
func _half(name: String) -> Texture2D:
	if _half_cache.has(name):
		return _half_cache[name]
	var t := _tex(name)
	var out: Texture2D = null
	if t != null:
		var img := t.get_image()
		img.resize(maxi(1, img.get_width() / 2), maxi(1, img.get_height() / 2), Image.INTERPOLATE_LANCZOS)
		out = ImageTexture.create_from_image(img)
	_half_cache[name] = out
	return out


## 九宮格樣式（邊寬單位 = 2 倍素材像素；內部換算成一半）
func _box(name: String, mx: int, my: int, content_h: float = 0.0, content_v: float = 0.0) -> StyleBoxTexture:
	var t := _half(name)
	if t == null:
		return null
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = mx / 2
	s.texture_margin_right = mx / 2
	s.texture_margin_top = my / 2
	s.texture_margin_bottom = my / 2
	s.content_margin_left = content_h
	s.content_margin_right = content_h
	s.content_margin_top = content_v
	s.content_margin_bottom = content_v
	return s


func _image(name: String, pos: Vector2, size: Vector2, parent: Node = self) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.position = pos
	r.size = size
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(r)
	return r


func _panel(name: String, mx: int, my: int, pos: Vector2, size: Vector2, parent: Node = self) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := _box(name, mx, my)
	p.add_theme_stylebox_override("panel", b if b != null else StyleBoxEmpty.new())
	parent.add_child(p)
	return p


func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, parent: Node = self) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## 用貼圖樣式的按鈕。state 名稱對應檔名（例如 btn_normal / btn_hover / btn_pressed / btn_disabled）
func _tex_button(size: Vector2, pos: Vector2, normal: String, hover: String, pressed: String, disabled: String, mx: int, my: int, parent: Node = self) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = size
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.flat = false
	b.mouse_default_cursor_shape = Control.CURSOR_ARROW
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["hover_pressed", pressed]]:
		var bx := _box(pair[1], mx, my)
		b.add_theme_stylebox_override(pair[0], bx if bx != null else StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color("#FFF3D0"))
	b.add_theme_color_override("font_pressed_color", Color("#FFF3D0"))
	b.add_theme_color_override("font_disabled_color", Color(0.62, 0.57, 0.48))
	# 層級（由近到遠）：按鈕 > 前景 > 框（卷軸、分類欄底板、導航底板）> 後景。直接放在頁面上的按鈕要比前景（z 10）高。
	if parent == self:
		b.z_index = BUTTON_Z
	parent.add_child(b)
	return b


## 這一頁用的前景方案（StudyShell.PRESETS 的名稱）；子類別覆寫
func _foreground_preset() -> String:
	return ""

func _build_background(with_scroll_body := true) -> void:
	# 外殼：書房桌面背景＋桌上的前景物件（所有新版系統頁共用）
	_shell = StudyShell.new()
	_shell.preset_name = _foreground_preset()
	add_child(_shell)
	# 中層：卷軸（含景物，固定尺寸，不可平鋪）
	if with_scroll_body:
		_image("scroll_body", Vector2(158, 69), Vector2(972, 506))


func _build_nav(selected_tab: String) -> void:
	_panel("nav_bar", 0, 0, Vector2(138, 28), Vector2(889, 48))
	var x := 142.0
	for t in NAV_TABS:
		var selected: bool = t["name"] == selected_tab
		# 導航選中沿用 V1 的朱紅底（V2 的半透明疊層版太淡、選中看不出來，暫不採用）
		var b := _tex_button(Vector2(110, 48), Vector2(x, 28), "nav_tab_selected" if selected else "nav_tab_normal", "nav_tab_selected" if selected else "nav_tab_hover", "nav_tab_selected", "nav_tab_normal", 0, 0)
		b.text = t["label"]
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): tab_requested.emit(String(t["name"])))
		x += 110.0


func _build_toast() -> void:
	_toast = Control.new()
	_toast.position = Vector2(416, 540)
	_toast.size = Vector2(320, 36)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)
	_panel("toast_plate", 28, 12, Vector2.ZERO, Vector2(320, 36), _toast)
	_toast_label = _label("", Vector2.ZERO, Vector2(320, 36), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, _toast)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.z_index = 20
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	_overlay.add_child(dim)


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ------------------------------------------------------------------
# 彈出視窗：選擇隊友、確認
# ------------------------------------------------------------------
func _clear_overlay() -> void:
	for c in _overlay.get_children():
		if not (c is ColorRect):
			_overlay.remove_child(c)
			c.queue_free()


func _close_overlay() -> void:
	_overlay.visible = false
	_clear_overlay()


## 稀有度章：有 rarity_N.png 就用貼圖，沒有就畫色塊章（文字由程式輸出）
func _rarity_chip(level: int, pos: Vector2, size: Vector2, parent: Node) -> Control:
	var holder := Control.new()
	holder.position = pos
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var path := ItemRarity.badge_path(level)
	if ResourceLoader.exists(path):
		_image_from(path, Vector2.ZERO, size, holder)
	else:
		var p := Panel.new()
		p.size = size
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = ItemRarity.color_of(level)
		sb.set_corner_radius_all(6)
		p.add_theme_stylebox_override("panel", sb)
		holder.add_child(p)
	# 章的墨形右邊比較不規則、視覺中心偏左上，文字往左上挪一點才看起來置中
	_label(ItemRarity.label_of(level), Vector2(-3, -2), size, 12, Color("#F6EEDC"), HORIZONTAL_ALIGNMENT_CENTER, holder)
	return holder


func _image_from(path: String, pos: Vector2, size: Vector2, parent: Node) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.position = pos
	r.size = size
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(r)
	return r


func _bar(parent: Node, pos: Vector2, kind: String, value: float, max_value: float, width := 108.0) -> void:
	var frame := _image("bar_%s_frame" % kind, pos, Vector2(width, 10), parent)
	var fill := _image("bar_%s_fill" % kind, pos, Vector2(width, 10), parent)
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	var ratio := clampf(value / max_value, 0.0, 1.0)
	fill.clip_contents = true
	fill.size.x = width * ratio
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE


