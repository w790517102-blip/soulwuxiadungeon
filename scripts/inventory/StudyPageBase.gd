extends Control
# 新版系統頁（書房桌面＋卷軸）共用的底層：素材與版面輔助函式、背景外殼、導航列、提示、彈出視窗遮罩。
# 道具頁（InventoryPage）、裝備頁（EquipmentPage）都繼承它；座標、尺寸一律是邏輯 px（素材為 2 倍，這裡縮成一半）。

signal close_requested
signal tab_requested(tab_name: String)

const DIR := "res://assets/UI/inventory/"
const FONT := preload("res://assets/fonts/UIFontKaiti.tres")

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
## 氣血/內力條的陰影位移（往左下，邏輯 px）
const BAR_SHADOW_OFFSET := Vector2(-2, 2)

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
	if soft_halo and color.get_luminance() < 0.4:
		_halo(l)
	parent.add_child(l)
	return l


## 深色字的白色柔邊（紙面上的墨字更清楚，不被紙紋與山水吃掉）。武術頁不用（soft_halo = false）
var soft_halo := true

func _halo(l: Control) -> void:
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 4)

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
	# 氣血/內力條：外面有框。不做柔化毛邊，改成往左下的硬陰影；金褐色框（比條大一圈）＋條本身縮在框內，不再蓋住框
	var shadow := Panel.new()
	shadow.position = pos + Vector2(-4, -4) + BAR_SHADOW_OFFSET
	shadow.size = Vector2(width + 8, 18)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.02, 0.6)
	sb.set_corner_radius_all(3)
	shadow.add_theme_stylebox_override("panel", sb)
	parent.add_child(shadow)
	var base := Panel.new()
	base.position = pos + Vector2(-4, -4)
	base.size = Vector2(width + 8, 18)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0.09, 0.06, 0.04, 1.0)
	sb2.set_corner_radius_all(3)
	base.add_theme_stylebox_override("panel", sb2)
	parent.add_child(base)
	var frame := _image("bar_%s_frame" % kind, pos + Vector2(-3, -3), Vector2(width + 6, 16), parent)
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	var fill := _image("bar_%s_fill" % kind, pos + Vector2(0, 0), Vector2(width, 10), parent)
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	var ratio := clampf(value / max_value, 0.0, 1.0)
	fill.clip_contents = true
	fill.size.x = width * ratio
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE




# ------------------------------------------------------------------
# 裝備格（裝備頁與狀態頁的「裝備摘要」共用）
# ------------------------------------------------------------------
const E := "equipment/"                  # 素材資料夾前綴（assets/UI/equipment/）
## 格內版面（邏輯 px，以 100×96 的格子為準；其他大小會等比縮放）：上＝部位名稱、其餘全是大圖示；留白越少越好
const SLOT_BASE := Vector2(100, 96)
const SLOT_ICON_BOX := Rect2(-1, 6, 102, 98)        # 圖示蓋過邊框也沒關係（像棋子壓在棋盤格上），盡量填滿
## 個別格子的圖示縮放（往下靠齊，避免頂到上面的部位名稱）
const SLOT_ICON_SCALE := {"head": 0.80}
## 個別格子的圖示位移（邏輯 px，負＝往上）：圖本身的重心不在中心，用位移校正
const SLOT_ICON_SHIFT := {"body": Vector2(0, -8)}
## 八格底框：先把對比度調高一點點，再把 alpha 調低（讓格子融進卷軸、圖示更突出）
const SLOT_FRAME_CONTRAST := 1.12
const SLOT_FRAME_ALPHA := 0.86
const SLOT_FRAME_SHADER := "shader_type canvas_item;
uniform float contrast = 1.12;
uniform float alpha = 0.86;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = clamp((c.rgb - 0.5) * contrast + 0.5, 0.0, 1.0);
	c.a *= alpha;
	COLOR = c;
}
"
const SLOT_LABEL_CHAR_PX := 13.0          # 部位名稱每個字的大小（八格統一）
const SLOT_LABEL_CHARS := {"main_weapon": 3, "off_weapon": 3, "head": 2, "body": 2, "hands": 2, "feet": 2, "accessory": 2, "mechanism": 2}
var _slot_frame_material: ShaderMaterial
## 候選底框（老闆提供的新框：金邊、黑墨暈邊、紙面墨圈）。true＝八格都用它，不加外暈與對比度處理；false＝共邊國 V3 框
static var use_candidate_slot_frame := true
var _trim_cache: Dictionary = {}

## 做一格裝備格（底框、部位名稱、空格剪影、物品圖、選中金光）。回傳的 Button 沒有接 pressed，由頁面決定要不要互動。
## size 是這格的大小（邏輯 px）；其他元件按 size.x / 100 等比縮放。
func make_slot_tile(slot_id: String, size: Vector2, parent: Node) -> Button:
	var part := _empty_icon_name(slot_id)
	var k := size.x / SLOT_BASE.x
	var b := Button.new()
	b.name = "Slot_" + slot_id
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.z_index = 1
	b.set_meta("tile_scale", k)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	parent.add_child(b)
	var frame: TextureRect
	if use_candidate_slot_frame:
		frame = _image(E + "slots/slot_frame_candidate", Vector2.ZERO, size, b)
	else:
		_image(E + "slots/slot_bleed_" + part, Vector2(-8, -8) * k, Vector2(116, 112) * k, b).name = "Bleed"
		frame = _image(E + "slots/slot_frame_" + part, Vector2.ZERO, size, b)
		frame.material = _frame_material()
	frame.name = "Frame"
	var label_tex := _tex(E + "slots/label_" + part)
	if label_tex != null:
		var char_px := SLOT_LABEL_CHAR_PX * k
		var per_char := label_tex.get_size().x / float(SLOT_LABEL_CHARS.get(part, 2))
		var disp := label_tex.get_size() * (char_px / per_char)
		var pl := _image(E + "slots/label_" + part, Vector2((size.x - disp.x) * 0.5, 5.0 * k + (char_px - disp.y) * 0.5), disp, b)
		pl.name = "PartLabel"
	var icon_rect := _slot_icon_rect(part, k)
	var empty_icon := _image(E + "slots/ghost_" + part, icon_rect.position, icon_rect.size, b)
	empty_icon.name = "EmptyIcon"
	empty_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon := _image_from("", icon_rect.position, icon_rect.size, b)
	icon.name = "Icon"
	if b.has_node("PartLabel"):
		b.move_child(b.get_node("PartLabel"), b.get_child_count() - 1)       # 部位名稱蓋在圖示上面，不被劍尖之類擋住
	# 金光：兩層疊加（加色混合）；內層是共邊國的光暈（240×232，疊在格子 (-10,-10)），外層放大一圈做出更粗的光邊。素材是靜態的，呼吸由程式調透明度。
	var glow := Control.new()
	glow.name = "SelectedGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = false
	b.add_child(glow)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for layer in [[Vector2(-20, -20), Vector2(140, 136), 0.5], [Vector2(-10, -10), Vector2(120, 116), 0.8], [Vector2(-10, -10), Vector2(120, 116), 0.55]]:
		var g := _image(E + "slots/slot_selected_gold_overlay", Vector2(layer[0]) * k, Vector2(layer[1]) * k, glow)
		g.material = additive
		g.modulate = Color(1.0, 0.80, 0.32, layer[2])      # 偏金色，不要加成純白
	var breath := glow.create_tween().set_loops()
	breath.tween_property(glow, "modulate:a", 0.8, 1.1).set_trans(Tween.TRANS_SINE)
	breath.tween_property(glow, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	# 沒有移入圖，用提亮代替
	b.mouse_entered.connect(func(): if not b.disabled: b.modulate = Color(1.1, 1.08, 1.02))
	b.mouse_exited.connect(func(): b.modulate = Color(0.55, 0.52, 0.48) if b.disabled else Color.WHITE)
	return b

## 把格子填成「穿了 item_id」（空字串＝空格剪影）。locked＝固定欄位（整格壓暗），selected＝選中（金光、蓋在鄰格上面）。
func fill_slot_tile(b: Button, item_id: String, locked: bool, selected: bool) -> void:
	b.set_pressed_no_signal(selected)
	(b.get_node("SelectedGlow") as Control).visible = selected and not locked
	b.z_index = 3 if selected else 1
	b.disabled = locked
	b.modulate = Color(0.55, 0.52, 0.48) if locked else Color.WHITE      # 停用（固定欄位）：整格壓暗
	var icon := b.get_node("Icon") as TextureRect
	var empty_icon := b.get_node("EmptyIcon") as TextureRect
	if item_id != "":
		icon.texture = _slot_icon_texture(item_id, ItemDB.get_def(item_id))
		empty_icon.visible = false
	else:
		icon.texture = null
		empty_icon.visible = true

## 空格剪影的檔名（V3：slots/ghost_<名稱>.png）
func _empty_icon_name(slot_id: String) -> String:
	match slot_id:
		"weapon_1": return "main_weapon"
		"weapon_2": return "off_weapon"
		"armor_head": return "head"
		"armor_body": return "body"
		"armor_hands": return "hands"
		"armor_feet": return "feet"
		"accessory_1": return "accessory"
	return "mechanism"

func _slot_icon_rect(part: String, k: float = 1.0) -> Rect2:
	var s: float = float(SLOT_ICON_SCALE.get(part, 1.0))
	var size := SLOT_ICON_BOX.size * s
	return Rect2((SLOT_ICON_BOX.position + (SLOT_ICON_BOX.size - size) * Vector2(0.5, 1.0) + Vector2(SLOT_ICON_SHIFT.get(part, Vector2.ZERO))) * k, size * k)

## 底框用的材質（對比度與 alpha 的參數在上面的常數）
func _frame_material() -> ShaderMaterial:
	if _slot_frame_material == null:
		var sh := Shader.new()
		sh.code = SLOT_FRAME_SHADER
		_slot_frame_material = ShaderMaterial.new()
		_slot_frame_material.shader = sh
		_slot_frame_material.set_shader_parameter("contrast", SLOT_FRAME_CONTRAST)
		_slot_frame_material.set_shader_parameter("alpha", SLOT_FRAME_ALPHA)
	return _slot_frame_material

## 格子用的圖示：用大圖（380×560）裁到不透明範圍再縮小，比放大 80×80 小圖清楚，而且圖形填得滿
func _slot_icon_texture(item_id: String, def: Dictionary) -> Texture2D:
	var art_path := ItemIconMap.art_path(item_id, def)
	if ResourceLoader.exists(art_path):
		if _trim_cache.has(art_path):
			return _trim_cache[art_path]
		var tex := load(art_path) as Texture2D
		if tex != null:
			var used := tex.get_image().get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = used
				_trim_cache[art_path] = atlas
				return atlas
	var icon_path := ItemIconMap.icon_path(item_id, def)
	return load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null

# ------------------------------------------------------------------
# 左側同行俠客（裝備頁與狀態頁共用）
# ------------------------------------------------------------------
const EquipmentDollScript = preload("res://scripts/inventory/EquipmentDoll.gd")
## 三個角色卡槽（V2 placement.json 的 runtime 座標 ÷ 2）
const ROSTER_SLOTS := [Rect2(55, 142, 246.5, 123), Rect2(55, 273, 246.5, 123.5), Rect2(55, 402.5, 246.5, 122)]
const COMPANION_CARD := Vector2(233, 124)          # 共邊國 V3 角色卡的卡框大小（金光留白另算）
var menu: Node                      # 系統選單（提供 compute_overview_stats、鎖定欄等）
var actor_id := ""                  # 目前查看的角色
var _roster_box: Control
var _roster_buttons: Dictionary = {}

func _actor(id: String) -> Dictionary:
	return TeamData.get_character_by_id(id) if TeamData else {}

## 白字加黑色外框，不會被背景的山水畫或卡片紙紋吃掉（右頁文字與左側角色卡文字都用）
func _outlined(l: Label) -> Label:
	var current := l.get_theme_color("font_color")
	if current == INK or current == INK_DIM or current == CREAM:
		l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l

## 左側面板：標題牌（老闆截的「同行俠客」）＋放角色卡的容器；with_quote＝底部那塊框底（裝備頁有，狀態頁沒有；框裡沒有字也沒有印章）
func build_roster_panel(with_quote: bool) -> void:
	_image(E + "equip_roster_title", Vector2(55, 96), Vector2(246.5, 37))
	_image(E + "equip_roster_title_cut", Vector2(55, 93), Vector2(246.5, 43.2))
	# 底部的框只當 FRAME 的底（老闆定案：不放引言文字，也不放紅色印章）
	if with_quote:
		_panel(E + "equip_roster_quote", 22, 22, Vector2(62, 530), Vector2(233, 38))
	_roster_box = Control.new()
	_roster_box.position = Vector2.ZERO
	_roster_box.size = Vector2(1152, 648)
	_roster_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster_box.z_index = 1
	add_child(_roster_box)

## 左側的角色卡槽（永遠三個；名冊多於三位時顯示包含選中者的那三位）。pick＝點卡時呼叫 pick.call(角色 id)。
func rebuild_roster(ids: Array, selected_id: String, pick: Callable) -> void:
	for c in _roster_box.get_children():
		_roster_box.remove_child(c)
		c.queue_free()
	_roster_buttons.clear()
	# 永遠三個卡槽；名冊多於三位時，顯示包含目前角色的那三位
	var start := 0
	var selected_index := ids.find(selected_id)
	if ids.size() > ROSTER_SLOTS.size():
		start = clampi(selected_index - 1, 0, ids.size() - ROSTER_SLOTS.size())
	for i in ROSTER_SLOTS.size():
		var slot_rect: Rect2 = ROSTER_SLOTS[i]
		# 共邊國 V3 角色卡：卡框 233×124；三態都是整合圖（506×288 的畫布，卡框在 (20,20)，外圈是金光留白，不可裁切）
		var rect := Rect2(slot_rect.position.x + (slot_rect.size.x - COMPANION_CARD.x) * 0.5, slot_rect.position.y, COMPANION_CARD.x, COMPANION_CARD.y)
		var index := start + i
		if index >= ids.size():
			# 空位：還沒有同行的人（名冊沒解鎖更多角色），畫暗一點的一般卡
			var empty := _image(E + "companion/actor_card_normal", rect.position - Vector2(10, 10), Vector2(253, 144), _roster_box)
			empty.modulate = Color(0.72, 0.68, 0.62, 0.85)
			_outlined(_label("尚未同行", rect.position, rect.size, 14, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, _roster_box))
			continue
		var id := String(ids[index])
		var a := _actor(id)
		var on: bool = id == selected_id
		var card := Button.new()
		card.position = rect.position
		card.size = rect.size
		card.focus_mode = Control.FOCUS_NONE
		card.toggle_mode = true
		card.set_pressed_no_signal(on)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		_roster_box.add_child(card)
		var art := _image(E + "companion/actor_card_" + ("selected" if on else "normal"), Vector2(-10, -10), Vector2(253, 144), card)
		art.name = "StateArt"
		if not on:
			card.mouse_entered.connect(func(): art.texture = _tex(E + "companion/actor_card_hover"))
			card.mouse_exited.connect(func(): art.texture = _tex(E + "companion/actor_card_normal"))
		# 頭像：直接融進卡面（V3 沒有額外頭像框），放在左側 100×108，裁在範圍內
		var clip := Control.new()
		clip.position = Vector2(7, 8)
		clip.size = Vector2(100, 108)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(clip)
		# 頭像：有立繪的角色用立繪的頭部（會跟著衣裝換），沒有就退回戰鬥頭像
		var pr := TextureRect.new()
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pr.size = clip.size
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var head: Texture2D = EquipmentDollScript.head_portrait(id)
		if head != null:
			pr.texture = head
		else:
			var portrait_path := String(a.get("portrait_path", ""))
			if portrait_path != "" and ResourceLoader.exists(portrait_path):
				pr.texture = load(portrait_path) as Texture2D
		clip.add_child(pr)
		if TeamData and TeamData.current_team_ids.has(id):
			_image(E + "companion/deployed_tag", Vector2(1, 8), Vector2(22, 40), card)      # 原圖的「上陣」字版
		var job := String(a.get("job", ""))
		var subclass := String(a.get("subclass", ""))
		var job_text := "%s·%s" % [subclass, job] if subclass != "" and job != "" else (job + subclass)
		_outlined(_label(String(a.get("name", id)), Vector2(118, 12), Vector2(110, 24), 18, INK, HORIZONTAL_ALIGNMENT_LEFT, card))
		_outlined(_label(job_text, Vector2(118, 36), Vector2(110, 18), 12, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, card))
		_outlined(_label("Lv.%d" % int(a.get("level", 1)), Vector2(118, 54), Vector2(110, 18), 13, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, card))
		# 氣血、內力：與狀態頁同一套顯示（含裝備加成的最大值；本來是滿的就顯示滿）
		var stats: Dictionary = menu.compute_overview_stats(a, InventorySync.get_equipment_stat_bonus(id)) if menu != null else {}
		var hp_max := int(stats.get("max_hp", a.get("max_hp", 1)))
		var mp_max := int(stats.get("max_mp", a.get("max_mp", 1)))
		var hp_now: int = menu._displayed_resource(int(a.get("hp", 0)), int(a.get("max_hp", 1)), hp_max) if menu != null else int(a.get("hp", 0))
		var mp_now: int = menu._displayed_resource(int(a.get("mp", 0)), int(a.get("max_mp", 1)), mp_max) if menu != null else int(a.get("mp", 0))
		_bar(card, Vector2(120, 82), "hp", float(hp_now), float(maxi(1, hp_max)), 64.0)
		_outlined(_label("%d/%d" % [hp_now, hp_max], Vector2(190, 77), Vector2(44, 18), 11, INK, HORIZONTAL_ALIGNMENT_LEFT, card))
		_bar(card, Vector2(120, 101), "mp", float(mp_now), float(maxi(1, mp_max)), 64.0)
		_outlined(_label("%d/%d" % [mp_now, mp_max], Vector2(190, 96), Vector2(44, 18), 11, INK, HORIZONTAL_ALIGNMENT_LEFT, card))
		card.pressed.connect(pick.bind(id))
		_roster_buttons[id] = card


# 確認視窗（道具頁的丟棄、裝備頁的卸下共用）
var _confirm_action: Callable

func _show_confirm(title: String, body: String, ok_text: String, action: Callable) -> void:
	_confirm_action = action
	_clear_overlay()
	_overlay.visible = true
	var panel_pos := Vector2(276, 148)
	_panel("confirm_panel", 28, 24, panel_pos, Vector2(600, 344), _overlay)
	_label(title, panel_pos + Vector2(56, 54), Vector2(488, 34), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER, _overlay)
	var b := _label(body, panel_pos + Vector2(56, 100), Vector2(488, 130), 17, CREAM, HORIZONTAL_ALIGNMENT_CENTER, _overlay)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var ok := _tex_button(Vector2(190, 40), panel_pos + Vector2(72, 248), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, _overlay)
	ok.text = ok_text
	var cancel := _tex_button(Vector2(190, 40), panel_pos + Vector2(600 - 72 - 190, 248), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	cancel.text = "取消"
	ok.pressed.connect(func():
		var a := _confirm_action
		_close_overlay()
		if a.is_valid():
			a.call())
	cancel.pressed.connect(_close_overlay)


# ------------------------------------------------------------------
# 直排姓名（狀態頁、武術頁共用）
# ------------------------------------------------------------------
const STATUS_DIR := "res://assets/UI/status/"

## 直排姓名：有美術摳的字（assets/UI/status/name_<角色id>.png）就用圖，沒有就用程式直排（一個字一個 Label），職業小字接在下面
func fill_vertical_name(box: Control, id: String) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var a := _actor(id)
	var art_path := STATUS_DIR + "name_%s.png" % id
	if ResourceLoader.exists(art_path):
		var r := _image_from(art_path, Vector2.ZERO, box.size, box)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		return
	var full := String(a.get("name", id))
	var y := 0.0
	for ch in full:
		_label(ch, Vector2(0, y), Vector2(box.size.x, 46), 42, INK, HORIZONTAL_ALIGNMENT_CENTER, box)
		y += 46.0
	var job := String(a.get("job", ""))
	var subclass := String(a.get("subclass", ""))
	var job_text := "%s/%s" % [job, subclass] if job != "" and subclass != "" else job + subclass
	y += 6.0
	for ch in job_text:
		_label(ch, Vector2(0, y), Vector2(box.size.x, 17), 14, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, box)
		y += 17.0
