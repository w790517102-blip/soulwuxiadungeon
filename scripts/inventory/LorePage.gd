extends "res://scripts/inventory/StudyPageBase.gd"
# 見聞頁：三本書（奇物、豪傑、神怪）。美術包 v1（assets/UI/lore）已套用。
# 流程：書架三選一 → 點一本，其他兩本壓暗退場、那本浮到最上層、封面翻開 → 點右頁翻下一筆、點左頁翻上一筆（頁面彎曲翻過去，翻完攤平）
#   → 末頁再往後點：「後續內容待君發掘」→ 右鍵或「合上」收書回書架。底下有「目錄」可直接跳到某一筆。
# 一筆資料兩頁：右頁＝名稱、圖、簡述；左頁＝詳細資料（奇物、神怪是「標籤＋欄位」列，豪傑是一整段人物誌）。
# 未收錄的也佔頁（頁面美術自帶「？」與「尚未收錄」），翻頁時快速翻過去，直接停在下一筆已收錄的。
# 翻頁是純 2D：每一頁在 SubViewport 裡排版，貼到切成多段的網格上，由頂點 shader 彎曲（見 tools/book_flip_demo.gd）。
# 座標依 docs/system_menu/lore_pack_v1/layout.json（2 倍像素 ÷ 2 ＝ 邏輯 px）。

const EntriesScript = preload("res://scripts/inventory/LoreEntries.gd")

const LD := "res://assets/UI/lore/"
const CAT_FILE := {"奇物": "item", "豪傑": "hero", "神怪": "monster"}
const PAGE := Vector2(350, 480)
const BASE_POS := Vector2(186, 62)           # 書底（780×520）左上；兩個頁面孔洞在 (30,20) 與 (400,20)
const LEFT_POS := Vector2(216, 82)
const RIGHT_POS := Vector2(586, 82)
const HINGE := Vector2(576, 82)              # 書脊（兩頁中間 20px 的裝訂縫）
const HINGE_GAP := 10.0                      # 頁面離書脊的距離
const SHELF_SIZE := Vector2(260, 338)        # 斜放書（800×1040 ×0.65 ÷2）
const SHELF_POS := [Vector2(200, 155), Vector2(494, 155), Vector2(788, 155)]
const SHELF_SCALE := 0.325
const SHELF_HOOK := Vector2(667.8, 177.5)    # 吊飾在斜放書圖上的掛點（原圖像素）
const CHARM_PIVOT := Vector2(128, 10)
const CHARM_SCALE := 0.55
const COVER_PROGRESS := Vector2(370, 860)    # 封面進度安全區中心（原圖像素），經投影換到斜放書
const HOMOGRAPHY := [[0.9045526666038237, -0.06772240680197403, 88.0], [0.05790911421041597, 0.90986710475589, 40.0], [8.55634536982765e-06, -4.1092636561222095e-05, 1.0]]
const COLS := 64
const FLIP_DUR := 0.9
const FAST_DUR := 0.13
const FAST_MAX := 6
const INK_COL := Color("#2B1B0E")
const GOLD_COL := Color("#E8D49A")

const SHADER := "shader_type canvas_item;
uniform float t = 0.0;
uniform float curl = 1.5;
uniform vec2 page_size = vec2(350.0, 480.0);
uniform sampler2D back_tex : filter_linear;
varying float ang;
void vertex() {
	float s = VERTEX.x;
	float th = t * 3.14159265;
	float k = curl * sin(th) / page_size.x;
	float a = th - k * s;
	float x = s * cos(th);
	float z = s * sin(th);
	if (abs(k) > 0.00001) {
		x = (sin(th) - sin(a)) / k;
		z = (cos(a) - cos(th)) / k;
	}
	float cy = page_size.y * 0.5;
	VERTEX.x = x;
	VERTEX.y = cy + (VERTEX.y - cy) * (1.0 + z * 0.00035);
	ang = a;
}
void fragment() {
	vec4 c;
	if (ang > 1.5707963) {
		c = texture(back_tex, vec2(1.0 - UV.x, UV.y));
	} else {
		c = texture(TEXTURE, UV);
	}
	c.rgb *= 0.72 + 0.28 * abs(cos(ang));
	COLOR = c;
}"

var mode := "shelf"            # shelf／opening／book／closing
var _busy := false
var _cat := ""
var _list: Array = []
var _spread := 0
var _books: Dictionary = {}    # 分類 → 書架上的那一本（Control，含落影、書、吊飾、進度）
var _shelf_img: Dictionary = {}
var _shelf_shadow: Dictionary = {}
var _charms: Dictionary = {}
var _progress_lbl: Dictionary = {}
var _page_vps: Dictionary = {}
var _fly: TextureRect
var _fly_cover: TextureRect
var _dim: ColorRect
var _book: Control
var _shadow: TextureRect
var _base: TextureRect
var _left: TextureRect
var _right: TextureRect
var _leaf: MeshInstance2D
var _mat: ShaderMaterial
var _zone_l: Control
var _zone_r: Control
var _btn_back: Button
var _btn_toc: Button
var _btn_close: Button
var _blank_tex: Texture2D
var _inside_tex: Texture2D
var _t := 0.0

func _ready() -> void:
	name = "LorePage"
	set_meta("skip_menu_skin", true)
	soft_halo = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100
	_build_background(false)
	_build_nav("TabLore")
	_build_scene()
	_build_shelf()
	_build_foreground()
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.z_index = 30
	add_child(_dim)
	_build_book()
	_btn_back = _tex_button(Vector2(165, 38), Vector2(494, 590), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	_btn_back.text = "返回"
	_btn_back.pressed.connect(func(): close_requested.emit())
	_btn_toc = _tex_button(Vector2(150, 38), Vector2(404, 590), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	_btn_toc.text = "目錄"
	_btn_toc.pressed.connect(_open_toc)
	_btn_close = _tex_button(Vector2(150, 38), Vector2(598, 590), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	_btn_close.text = "合上"
	_btn_close.pressed.connect(close_book)
	for b in [_btn_toc, _btn_close]:
		b.z_index = 45
	_build_toast()
	_build_overlay()
	_overlay.z_index = 50
	_apply_mode_buttons()
	refresh()

func _foreground_preset() -> String:
	return "none"

func refresh() -> void:
	if mode == "book" or mode == "opening" or mode == "closing":
		return
	for cat in EntriesScript.CATEGORIES:
		_refresh_progress(cat)

# ------------------------------------------------------------------
# 素材小工具
# ------------------------------------------------------------------
func lore_tex(name_: String) -> Texture2D:
	var p := "%s%s.png" % [LD, name_]
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

func _lore_image(name_: String, pos: Vector2, size_: Vector2, parent: Node = self) -> TextureRect:
	var r := TextureRect.new()
	r.texture = lore_tex(name_)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.position = pos
	r.size = size_
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _tex_half(name_: String) -> Vector2:
	var t := lore_tex(name_)
	return t.get_size() * 0.5 if t != null else Vector2.ZERO

# ------------------------------------------------------------------
# 書架畫面：大卷軸底板、左側直牌與題句、三本斜放書、左右前景
# ------------------------------------------------------------------
func _build_scene() -> void:
	_lore_image("lore_scroll_board", Vector2(0, 68), _tex_half("lore_scroll_board"))
	_lore_image("lore_title_plate", Vector2(40, 97), _tex_half("lore_title_plate"))
	_lore_image("lore_quote_plate", Vector2(30, 442), _tex_half("lore_quote_plate"))

func _build_foreground() -> void:
	for pair in [["lore_fg_left", Vector2(0, 430)], ["lore_fg_right", Vector2(960, 420)]]:
		var shadow := _lore_image(pair[0] + "_shadow", pair[1], _tex_half(pair[0]))
		shadow.z_index = 6
		var img := _lore_image(pair[0], pair[1], _tex_half(pair[0]))
		img.z_index = 7

func _build_shelf() -> void:
	for i in EntriesScript.CATEGORIES.size():
		var cat: String = EntriesScript.CATEGORIES[i]
		var file: String = CAT_FILE[cat]
		var b := Control.new()
		b.name = "Book_" + file
		b.position = SHELF_POS[i]
		b.size = SHELF_SIZE
		b.z_index = 3
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		_shelf_shadow[cat] = _lore_image("lore_book_%s_shelf_shadow" % file, Vector2.ZERO, SHELF_SIZE, b)
		var img := _lore_image("lore_book_%s_shelf" % file, Vector2.ZERO, SHELF_SIZE, b)
		img.mouse_filter = Control.MOUSE_FILTER_STOP
		img.gui_input.connect(_on_book_input.bind(cat))
		var home_y: float = (SHELF_POS[i] as Vector2).y
		img.mouse_entered.connect(func():
			if mode == "shelf" and not _busy:
				create_tween().tween_property(b, "position:y", home_y - 10.0, 0.12)
				_kick_charm(cat))
		img.mouse_exited.connect(func():
			if mode == "shelf" and not _busy:
				create_tween().tween_property(b, "position:y", home_y, 0.12))
		_shelf_img[cat] = img
		_books[cat] = b
		# 吊飾（獨立貼圖，繩圈固定、下端自然擺動）
		var cs := CHARM_SCALE * SHELF_SCALE
		var charm := _lore_image("lore_charm_" + file, Vector2.ZERO, Vector2(256, 1024) * cs, b)
		charm.pivot_offset = CHARM_PIVOT * cs
		charm.position = SHELF_HOOK * SHELF_SCALE - CHARM_PIVOT * cs
		_charms[cat] = charm
		_start_sway(charm, float(i) * 0.7)
		# 進度（已錄 ○／○）：封面下方安全區中心經投影換到斜放書上
		var c := _project(COVER_PROGRESS) * SHELF_SCALE
		var lbl := Label.new()
		lbl.size = Vector2(120, 22)
		lbl.position = c - lbl.size * 0.5
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", FONT)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", GOLD_COL)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lbl)
		_progress_lbl[cat] = lbl

## 封面像素 → 斜放書圖像素（美術附的投影矩陣，三本相同）
func _project(p: Vector2) -> Vector2:
	var h: Array = HOMOGRAPHY
	var w: float = float(h[2][0]) * p.x + float(h[2][1]) * p.y + float(h[2][2])
	return Vector2((float(h[0][0]) * p.x + float(h[0][1]) * p.y + float(h[0][2])) / w, (float(h[1][0]) * p.x + float(h[1][1]) * p.y + float(h[1][2])) / w)

func _start_sway(charm: Control, phase: float) -> void:
	charm.rotation_degrees = 0.0
	var tw := charm.create_tween().set_loops()
	tw.tween_interval(phase)
	tw.tween_property(charm, "rotation_degrees", 3.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(charm, "rotation_degrees", -3.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(charm, "rotation_degrees", 0.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _kick_charm(cat: String) -> void:
	var c: Control = _charms[cat]
	var tw := create_tween()
	tw.tween_property(c, "rotation_degrees", 9.0, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "rotation_degrees", -6.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "rotation_degrees", 0.0, 0.4).set_trans(Tween.TRANS_SINE)

func _refresh_progress(cat: String) -> void:
	var p := EntriesScript.progress(EntriesScript.entries(cat))
	(_progress_lbl[cat] as Label).text = "已錄 %d ／ %d" % [p.x, p.y]

func _on_book_input(event: InputEvent, cat: String) -> void:
	if mode != "shelf" or _busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_book(cat)

# ------------------------------------------------------------------
# 攤開的書（獨立最上層）：書底、左右頁、翻動的那一張、點擊區與箭頭
# ------------------------------------------------------------------
func _build_book() -> void:
	_book = Control.new()
	_book.name = "Book"
	_book.visible = false
	_book.z_index = 31
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book)
	_shadow = _lore_image("lore_book_open_shadow", BASE_POS, Vector2(780, 520), _book)
	_left = _page_rect(LEFT_POS)
	_right = _page_rect(RIGHT_POS)
	_book.add_child(_left)
	_book.add_child(_right)
	_base = _lore_image("lore_book_open_base", BASE_POS, Vector2(780, 520), _book)      # 兩個頁面孔洞是透明的：頁面在它後面、被它框住
	_leaf = MeshInstance2D.new()
	_leaf.mesh = _grid_mesh()
	_leaf.position = HINGE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("page_size", PAGE)
	_leaf.material = _mat
	_leaf.visible = false
	_book.add_child(_leaf)
	_zone_l = _make_zone(LEFT_POS, -1)
	_zone_r = _make_zone(RIGHT_POS, 1)
	_blank_tex = lore_tex("lore_page_blank")
	_inside_tex = lore_tex("lore_cover_inside")

func _make_zone(pos: Vector2, dir: int) -> Control:
	var z := Control.new()
	z.position = pos
	z.size = PAGE
	z.z_index = 35
	z.mouse_filter = Control.MOUSE_FILTER_STOP
	var arrow := Label.new()
	arrow.text = "▶" if dir > 0 else "◀"
	arrow.add_theme_font_size_override("font_size", 40)
	arrow.add_theme_color_override("font_color", Color("#7A4A12"))
	arrow.add_theme_color_override("font_outline_color", Color("#F2E2B8"))
	arrow.add_theme_constant_override("outline_size", 6)
	arrow.position = Vector2(PAGE.x - 60 if dir > 0 else 14, PAGE.y * 0.5 - 28)
	arrow.modulate.a = 0.0
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.add_child(arrow)
	z.mouse_entered.connect(func(): if mode == "book" and not _busy: arrow.modulate.a = 0.9)
	z.mouse_exited.connect(func(): arrow.modulate.a = 0.0)
	z.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and mode == "book" and not _busy:
			_turn(dir))
	z.visible = false
	add_child(z)
	return z

func _page_rect(pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.position = pos
	r.size = PAGE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _grid_mesh() -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in COLS + 1:
		var u := float(i) / float(COLS)
		for j in 2:
			verts.append(Vector2(HINGE_GAP + u * PAGE.x, j * PAGE.y))
			uvs.append(Vector2(u, float(j)))
	for i in COLS:
		var a := i * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _set_t(v: float, opening := false) -> void:
	_t = v
	_mat.set_shader_parameter("t", v)
	if opening:
		var a := clampf(v * 3.0, 0.0, 1.0)
		_shadow.modulate.a = a
		_base.modulate.a = a

## 翻一張：front＝正面（原本在右）、back＝翻過去後在左看到的背面。forward＝由右翻到左；反向就是 t 由 1 回到 0
func _flip(front: Texture2D, back: Texture2D, left_static: Texture2D, right_under: Texture2D, forward: bool, dur: float, opening := false) -> void:
	_leaf.texture = front
	_mat.set_shader_parameter("back_tex", back)
	_left.texture = left_static
	_right.texture = right_under
	_leaf.visible = true
	var from := 0.0 if forward else 1.0
	var to := 1.0 if forward else 0.0
	_set_t(from, opening)
	var tw := create_tween()
	tw.tween_method(func(v: float): _set_t(v, opening), from, to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

# ------------------------------------------------------------------
# 頁面內容：美術頁底圖＋程式文字，在 SubViewport 以 2 倍解析度排版，再當貼圖貼上
# ------------------------------------------------------------------
func _new_vp() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(PAGE * 2.0)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	return vp

func _vroot(vp: SubViewport) -> Control:
	var c := Control.new()
	c.scale = Vector2(2, 2)
	vp.add_child(c)
	return c

func _vlabel(parent: Node, text: String, pos: Vector2, size_: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := true) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(size_.x, 0)
	l.text = text
	l.position = pos
	l.size = size_
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = not wrap
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func _vimage(parent: Node, name_: String, pos: Vector2, size_: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = lore_tex(name_)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = pos
	r.size = size_
	parent.add_child(r)
	return r

## 第 idx 頁。偶數＝右頁（名稱、圖、簡述），奇數＝左頁（詳細資料）。超出範圍：-1＝封面內側，其餘空白頁
func _page_tex(idx: int) -> Texture2D:
	if idx < 0:
		return _inside_tex
	if idx >= _list.size() * 2:
		return _blank_tex
	if _page_vps.has(idx):
		return (_page_vps[idx] as SubViewport).get_texture()
	var e: Dictionary = _list[idx / 2]
	var unlocked: bool = bool(e.get("unlocked", false))
	var right: bool = idx % 2 == 0
	var vp := _new_vp()
	var c := _vroot(vp)
	var art := "lore_item_page_%s%s" % ["right" if right else "left", "" if unlocked else "_locked"]
	_vimage(c, art, Vector2.ZERO, PAGE)
	if right:
		_vlabel(c, _cat, Vector2(28, 26), Vector2(90, 22), 13, GOLD_COL, HORIZONTAL_ALIGNMENT_CENTER, false)
		_vlabel(c, "第 %d 筆" % (idx / 2 + 1), Vector2(126, 26), Vector2(120, 22), 14, Color("#7A4A12"), HORIZONTAL_ALIGNMENT_LEFT, false)
		_vlabel(c, String(e["name"]), Vector2(58, 56), Vector2(234, 36), 26, INK_COL, HORIZONTAL_ALIGNMENT_LEFT, false)
		if unlocked:
			var art_path := String(e.get("art", ""))
			if art_path != "" and ResourceLoader.exists(art_path):
				var tr := TextureRect.new()
				tr.texture = load(art_path) as Texture2D
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				tr.position = Vector2(60, 118)
				tr.size = Vector2(230, 180)
				c.add_child(tr)
			var s := _vlabel(c, String(e["summary"]), Vector2(50, 348), Vector2(248, 78), 15, INK_COL)
			s.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		_vlabel(c, "詳細資料", Vector2(28, 26), Vector2(90, 22), 13, GOLD_COL, HORIZONTAL_ALIGNMENT_CENTER, false)
		if unlocked:
			_vlabel(c, String(e["name"]), Vector2(58, 56), Vector2(234, 36), 26, INK_COL, HORIZONTAL_ALIGNMENT_LEFT, false)
			_fill_details(c, e)
	_vlabel(c, str(idx + 1), Vector2(0, 434), Vector2(PAGE.x, 20), 12, Color("#8A7A5A"), HORIZONTAL_ALIGNMENT_CENTER, false)
	_page_vps[idx] = vp
	return vp.get_texture()

## 左頁的詳細資料：奇物、神怪＝「標籤牌＋欄位」逐列（列高 24、間距 32，最多九列）；豪傑＝一整段人物誌
func _fill_details(c: Control, e: Dictionary) -> void:
	var prose := String(e.get("prose", ""))
	if prose != "":
		_vimage(c, "lore_hero_prose_field", Vector2(30, 112), Vector2(290, 330))
		var t := _vlabel(c, prose, Vector2(44, 126), Vector2(262, 300), 17, INK_COL)
		t.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		return
	var y := 112.0
	for row in e.get("rows", []):
		_vimage(c, "lore_row_label_shared", Vector2(30, y), Vector2(90, 24))
		_vimage(c, "lore_row_field_shared", Vector2(120, y), Vector2(200, 24))
		_vlabel(c, String(row[0]), Vector2(34, y), Vector2(82, 24), 13, GOLD_COL, HORIZONTAL_ALIGNMENT_CENTER, false)
		_vlabel(c, String(row[1]), Vector2(138, y), Vector2(172, 24), 13, INK_COL, HORIZONTAL_ALIGNMENT_LEFT, false)
		y += 32.0
	var desc := String(e.get("summary", ""))
	if String(e.get("art", "")) != "" and desc != "" and (e.get("rows", []) as Array).size() <= 3:
		_vimage(c, "lore_row_label_shared", Vector2(30, y + 4), Vector2(90, 24))
		_vlabel(c, "敘述", Vector2(34, y + 4), Vector2(82, 24), 13, GOLD_COL, HORIZONTAL_ALIGNMENT_CENTER, false)
		var d := _vlabel(c, desc, Vector2(32, y + 36), Vector2(286, 200), 16, INK_COL)
		d.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _trim_pages(center: int) -> void:
	for k in _page_vps.keys():
		if absi(int(k) - center) > 8:
			(_page_vps[k] as SubViewport).queue_free()
			_page_vps.erase(k)

func _set_idle(k: int) -> void:
	_spread = k
	_leaf.visible = false
	_left.texture = _page_tex(2 * k - 1)
	_right.texture = _page_tex(2 * k) if 2 * k < _list.size() * 2 else null
	_trim_pages(2 * k)

# ------------------------------------------------------------------
# 開書、翻頁、收書
# ------------------------------------------------------------------
func _rect_tween(node: Control, pos: Vector2, size_: Vector2, dur: float, tw: Tween) -> void:
	tw.tween_property(node, "position", pos, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "size", size_, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func open_book(cat: String) -> void:
	if _busy or mode != "shelf":
		return
	_busy = true
	_cat = cat
	_list = EntriesScript.entries(cat)
	_page_vps.clear()
	var start := EntriesScript.first_unlocked(_list)
	_spread = start
	mode = "opening"
	_apply_mode_buttons()
	var file: String = CAT_FILE[cat]
	var src_pos: Vector2 = (_books[cat] as Control).position
	# 其他兩本退場；這一本浮到最上層：斜放圖飛到右頁位置，同時淡入正面封面
	for c2 in _books.keys():
		if c2 != cat:
			create_tween().tween_property(_books[c2], "modulate:a", 0.0, 0.25)
	_shelf_img[cat].visible = false
	_shelf_shadow[cat].visible = false
	(_charms[cat] as Control).modulate.a = 0.0
	(_progress_lbl[cat] as Label).modulate.a = 0.0
	_fly = _lore_image("lore_book_%s_shelf" % file, src_pos, SHELF_SIZE)
	_fly.z_index = 32
	_fly_cover = _lore_image("lore_book_%s_cover" % file, src_pos, SHELF_SIZE)
	_fly_cover.z_index = 33
	_fly_cover.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	_rect_tween(_fly, RIGHT_POS, PAGE, 0.5, tw)
	_rect_tween(_fly_cover, RIGHT_POS, PAGE, 0.5, tw)
	tw.tween_property(_fly, "modulate:a", 0.0, 0.5)
	tw.tween_property(_fly_cover, "modulate:a", 1.0, 0.5)
	tw.tween_property(_dim, "color:a", 0.62, 0.5)
	await tw.finished
	_fly.queue_free()
	_fly_cover.queue_free()
	_book.visible = true
	_shadow.modulate.a = 0.0
	_base.modulate.a = 0.0
	await _flip(lore_tex("lore_book_%s_cover" % file), _inside_tex, _inside_tex, _page_tex(0), true, 0.8, true)
	_set_idle(0)
	mode = "book"
	if start > 0:
		await _go(start)
	_busy = false
	_apply_mode_buttons()

func close_book() -> void:
	if _busy or mode != "book":
		return
	_busy = true
	mode = "closing"
	_apply_mode_buttons()
	_overlay.visible = false
	if _spread != 0:
		_set_idle(0)
	_page_vps.clear()
	var file: String = CAT_FILE[_cat]
	var i := EntriesScript.CATEGORIES.find(_cat)
	await _flip(lore_tex("lore_book_%s_cover" % file), _inside_tex, _inside_tex, _page_tex(0), false, 0.7, true)
	_book.visible = false
	_leaf.visible = false
	_fly = _lore_image("lore_book_%s_cover" % file, RIGHT_POS, PAGE)
	_fly.z_index = 32
	_fly_cover = _lore_image("lore_book_%s_shelf" % file, RIGHT_POS, PAGE)
	_fly_cover.z_index = 33
	_fly_cover.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	_rect_tween(_fly, SHELF_POS[i], SHELF_SIZE, 0.45, tw)
	_rect_tween(_fly_cover, SHELF_POS[i], SHELF_SIZE, 0.45, tw)
	tw.tween_property(_fly, "modulate:a", 0.0, 0.45)
	tw.tween_property(_fly_cover, "modulate:a", 1.0, 0.45)
	tw.tween_property(_dim, "color:a", 0.0, 0.45)
	for c2 in _books.keys():
		if c2 != _cat:
			tw.tween_property(_books[c2], "modulate:a", 1.0, 0.35)
	await tw.finished
	_fly.queue_free()
	_fly_cover.queue_free()
	_shelf_img[_cat].visible = true
	_shelf_shadow[_cat].visible = true
	create_tween().tween_property(_charms[_cat], "modulate:a", 1.0, 0.25)
	create_tween().tween_property(_progress_lbl[_cat], "modulate:a", 1.0, 0.25)
	mode = "shelf"
	_busy = false
	_refresh_progress(_cat)
	_apply_mode_buttons()

func _entry_unlocked(e: int) -> bool:
	return e >= 0 and e < _list.size() and bool((_list[e] as Dictionary).get("unlocked", false))

## 這一個跨頁有沒有東西可看：左頁（前一筆的詳細資料）或右頁（這一筆的簡述）有一邊已收錄
func _valid_spread(j: int) -> bool:
	return _entry_unlocked(j - 1) or _entry_unlocked(j)

func _turn(dir: int) -> void:
	var n := _list.size()
	if dir > 0:
		if _spread >= n:
			_notice("後續內容待君發掘……\n\n繼續行走江湖，見聞自會增添。")
			return
		var j := _spread + 1
		while j <= n and not _valid_spread(j):
			j += 1
		await _go(mini(j, n))
	else:
		var j := _spread - 1
		while j >= 0 and not _valid_spread(j):
			j -= 1
		if j < 0:
			return
		await _go(j)

## 翻到第 target 個跨頁：相鄰就慢慢翻；中間隔了好幾頁就快速連翻，讓玩家瞥見中間還有很多尚未收錄的
func _go(target: int) -> void:
	if target == _spread or _busy and mode != "book":
		return
	_busy = true
	var steps := absi(target - _spread)
	var forward := target > _spread
	var shown := mini(steps, FAST_MAX)
	var base := _spread
	var cur := base
	for i in shown:
		var nxt: int = target if i == shown - 1 else base + int(round(float(steps) * float(i + 1) / float(shown))) * (1 if forward else -1)
		if forward:
			await _flip(_page_tex(2 * cur), _page_tex(2 * nxt - 1), _page_tex(2 * cur - 1), _page_tex(2 * nxt), true, FLIP_DUR if steps == 1 else FAST_DUR)
		else:
			await _flip(_page_tex(2 * nxt), _page_tex(2 * cur - 1), _page_tex(2 * nxt - 1), _page_tex(2 * cur), false, FLIP_DUR if steps == 1 else FAST_DUR)
		_set_idle(nxt)
		cur = nxt
	_busy = false

# ------------------------------------------------------------------
# 目錄與提示
# ------------------------------------------------------------------
func _open_toc() -> void:
	if mode != "book" or _busy:
		return
	_clear_overlay()
	_overlay.visible = true
	var pos := Vector2(336, 104)
	var size_ := Vector2(480, 440)
	_lore_image("lore_toc_panel", pos, size_, _overlay)
	_label("目錄　%s" % _cat, pos + Vector2(140, 6), Vector2(200, 34), 22, Color("#F6E7B4"), HORIZONTAL_ALIGNMENT_CENTER, _overlay).add_theme_constant_override("outline_size", 4)
	var sc := ScrollContainer.new()
	sc.position = pos + Vector2(180, 70)
	sc.size = Vector2(size_.x - 270, size_.y - 150)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(sc)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(size_.x - 300, 0)
	sc.add_child(box)
	for i in _list.size():
		var e: Dictionary = _list[i]
		var b := Button.new()
		b.text = "%d　%s" % [i + 1, String(e["name"])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", Color("#F6E7B4") if bool(e["unlocked"]) else Color("#B8AC8C"))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_outline_color", Color.BLACK)
		b.add_theme_constant_override("outline_size", 3)
		b.pressed.connect(func():
			_overlay.visible = false
			_go(i))
		box.add_child(b)
	var close := _tex_button(Vector2(120, 32), pos + Vector2((size_.x - 120.0) * 0.5, size_.y - 40), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	close.text = "關閉"
	close.pressed.connect(_close_overlay)

func _notice(text: String) -> void:
	_clear_overlay()
	_overlay.visible = true
	var pos := Vector2(336, 104)
	var size_ := Vector2(480, 440)
	_lore_image("lore_toc_panel", pos, size_, _overlay)
	var l := _label(text, pos + Vector2(90, 130), Vector2(size_.x - 180, 150), 22, INK_COL, HORIZONTAL_ALIGNMENT_CENTER, _overlay)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok := _tex_button(Vector2(120, 32), pos + Vector2((size_.x - 120.0) * 0.5, size_.y - 40), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, _overlay)
	ok.text = "知道了"
	ok.pressed.connect(_close_overlay)

func _apply_mode_buttons() -> void:
	var reading := mode == "book"
	_btn_back.visible = mode == "shelf"
	_btn_toc.visible = reading
	_btn_close.visible = reading
	_zone_l.visible = reading
	_zone_r.visible = reading

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and mode == "book":
		get_viewport().set_input_as_handled()
		if _overlay.visible:
			_close_overlay()
		else:
			close_book()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _overlay.visible:
			_close_overlay()
		elif mode == "book":
			close_book()
		elif mode == "shelf":
			close_requested.emit()
	elif mode == "book" and not _busy and not _overlay.visible:
		if event.is_action_pressed("ui_right"):
			_turn(1)
		elif event.is_action_pressed("ui_left"):
			_turn(-1)
