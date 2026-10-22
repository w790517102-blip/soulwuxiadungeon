extends "res://scripts/inventory/StudyPageBase.gd"
# 見聞頁：三本書（奇物、豪傑、神怪）。點一本，書浮到前面、封面翻開；點右頁翻下一頁、點左頁翻上一頁（頁面彎曲翻過去，翻完攤平）；
# 一筆資料兩頁：右頁＝名稱、圖、簡述，左頁（翻過來的背面）＝詳細資料。未收錄的也佔頁（？？？），但翻頁時會快速翻過去，直接停在下一筆已收錄的。
# 末頁再往後點：跳出「後續內容待君發掘」。右鍵或「合上」收書回到三選一。底下有「目錄」可直接跳到某一筆。
# 翻頁用純 2D：每一頁在 SubViewport 裡正常排版，貼到切成多段的網格上，由頂點 shader 彎曲（示範見 tools/book_flip_demo.gd）。
# 美術暫代：封面、紙頁都是程式畫的，等梨蕎與澂的封面與左右頁、目錄版型交來後換成圖。

const EntriesScript = preload("res://scripts/inventory/LoreEntries.gd")

const PAGE := Vector2(350, 480)
const SPINE := Vector2(576, 96)
const SLOT_SCALE := 0.62
const SLOTS_X := [225.0, 576.0, 927.0]      # 三本書在書架上的中心 x
const SLOT_Y := 150.0
const COLS := 64
const PAPER := Color("#E9DAB5")
const COVER_COLORS := {"奇物": Color("#6B4A2A"), "豪傑": Color("#2E3A52"), "神怪": Color("#5A2A26")}
const FLIP_DUR := 0.9
const FAST_DUR := 0.13
const FAST_MAX := 6

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
var _covers: Dictionary = {}   # 分類 → TextureRect（書架上的封面）
var _cover_tex: Dictionary = {}
var _page_vps: Dictionary = {}  # 頁碼 → SubViewport
var _book: Control
var _base: ColorRect
var _left: TextureRect
var _right: TextureRect
var _leaf: MeshInstance2D
var _mat: ShaderMaterial
var _zone_l: Control
var _zone_r: Control
var _arrow_l: Label
var _arrow_r: Label
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
	_build_shelf()
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
	_build_toast()
	_build_overlay()
	_apply_mode_buttons()
	refresh()

func _foreground_preset() -> String:
	return "none"

## 重新整理（切到見聞頁、收錄有變動時）
func refresh() -> void:
	if mode == "book" or mode == "opening":
		return
	_cover_tex.clear()
	for cat in EntriesScript.CATEGORIES:
		_refresh_cover(cat)

# ------------------------------------------------------------------
# 書架（三選一）
# ------------------------------------------------------------------
func _build_shelf() -> void:
	for i in EntriesScript.CATEGORIES.size():
		var cat: String = EntriesScript.CATEGORIES[i]
		var r := TextureRect.new()
		r.name = "Cover_" + cat
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = PAGE * SLOT_SCALE
		r.position = _slot_pos(i)
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		r.gui_input.connect(_on_cover_input.bind(cat))
		r.mouse_entered.connect(func():
			if mode == "shelf" and not _busy:
				create_tween().tween_property(r, "position:y", SLOT_Y - 12.0, 0.12))
		r.mouse_exited.connect(func():
			if mode == "shelf" and not _busy:
				create_tween().tween_property(r, "position:y", SLOT_Y, 0.12))
		add_child(r)
		_covers[cat] = r

func _slot_pos(i: int) -> Vector2:
	return Vector2(float(SLOTS_X[i]) - PAGE.x * SLOT_SCALE * 0.5, SLOT_Y)

func _refresh_cover(cat: String) -> void:
	var list := EntriesScript.entries(cat)
	var p := EntriesScript.progress(list)
	var vp := _new_vp()
	_paper_bg(vp, COVER_COLORS[cat], Color("#C9A24A"))
	_vlabel(vp, cat, Vector2(0, 150), Vector2(PAGE.x, 100), 72, Color("#F2E2B8"), HORIZONTAL_ALIGNMENT_CENTER)
	_vlabel(vp, "江湖見聞錄", Vector2(0, 80), Vector2(PAGE.x, 30), 20, Color("#C9A24A"), HORIZONTAL_ALIGNMENT_CENTER)
	_vlabel(vp, "已錄 %d ／ %d" % [p.x, p.y], Vector2(0, 380), Vector2(PAGE.x, 34), 24, Color("#F2E2B8"), HORIZONTAL_ALIGNMENT_CENTER)
	_cover_tex[cat] = vp.get_texture()
	(_covers[cat] as TextureRect).texture = vp.get_texture()

func _on_cover_input(event: InputEvent, cat: String) -> void:
	if mode != "shelf" or _busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_book(cat)

# ------------------------------------------------------------------
# 書本（翻頁元件）
# ------------------------------------------------------------------
func _build_book() -> void:
	_book = Control.new()
	_book.name = "Book"
	_book.visible = false
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book)
	_base = ColorRect.new()
	_base.color = Color("#4A2A18")
	_base.position = SPINE - Vector2(PAGE.x + 14, 14)
	_base.size = Vector2(PAGE.x * 2 + 28, PAGE.y + 28)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_base)
	_left = _page_rect(SPINE - Vector2(PAGE.x, 0))
	_right = _page_rect(SPINE)
	_book.add_child(_left)
	_book.add_child(_right)
	var spine := ColorRect.new()
	spine.color = Color(0, 0, 0, 0.3)
	spine.position = SPINE + Vector2(-3, 0)
	spine.size = Vector2(6, PAGE.y)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(spine)
	_leaf = MeshInstance2D.new()
	_leaf.mesh = _grid_mesh()
	_leaf.position = SPINE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("page_size", PAGE)
	_leaf.material = _mat
	_book.add_child(_leaf)
	# 點擊區與方向箭頭
	_zone_l = _make_zone(SPINE - Vector2(PAGE.x, 0), -1)
	_zone_r = _make_zone(SPINE, 1)
	_blank_tex = _make_blank(Color("#D9C9A0"))
	_inside_tex = _make_blank(Color("#C9B68A"))

func _make_zone(pos: Vector2, dir: int) -> Control:
	var z := Control.new()
	z.position = pos
	z.size = PAGE
	z.mouse_filter = Control.MOUSE_FILTER_STOP
	var arrow := Label.new()
	arrow.text = "▶" if dir > 0 else "◀"
	arrow.add_theme_font_size_override("font_size", 40)
	arrow.add_theme_color_override("font_color", Color("#7A4A12"))
	arrow.add_theme_color_override("font_outline_color", Color("#F2E2B8"))
	arrow.add_theme_constant_override("outline_size", 6)
	arrow.position = Vector2(PAGE.x - 56 if dir > 0 else 10, PAGE.y * 0.5 - 28)
	arrow.modulate.a = 0.0
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.add_child(arrow)
	if dir > 0:
		_arrow_r = arrow
	else:
		_arrow_l = arrow
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
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _grid_mesh() -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in COLS + 1:
		var u := float(i) / float(COLS)
		for j in 2:
			verts.append(Vector2(u * PAGE.x, j * PAGE.y))
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
		_base.modulate.a = clampf(v * 3.0, 0.0, 1.0)

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
# 頁面內容（SubViewport 排版，貼成貼圖）
# ------------------------------------------------------------------
func _new_vp() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(PAGE)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp

func _paper_bg(vp: SubViewport, color: Color, edge: Color) -> void:
	var paper := ColorRect.new()
	paper.color = color
	paper.size = PAGE
	vp.add_child(paper)
	var border := ReferenceRect.new()
	border.position = Vector2(12, 12)
	border.size = PAGE - Vector2(24, 24)
	border.border_color = edge
	border.border_width = 2.0
	border.editor_only = false
	vp.add_child(border)

func _vlabel(parent: Node, text: String, pos: Vector2, size: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(size.x, 0)
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func _make_blank(color: Color) -> Texture2D:
	var vp := _new_vp()
	var r := ColorRect.new()
	r.color = color
	r.size = PAGE
	vp.add_child(r)
	return vp.get_texture()

## 第 idx 頁（0 起算）。偶數＝右頁（名稱、圖、簡述），奇數＝左頁（詳細資料）。超出範圍回傳空白頁
func _page_tex(idx: int) -> Texture2D:
	if idx < 0:
		return _inside_tex
	if idx >= _list.size() * 2:
		return _blank_tex
	if _page_vps.has(idx):
		return (_page_vps[idx] as SubViewport).get_texture()
	var e: Dictionary = _list[idx / 2]
	var unlocked: bool = bool(e.get("unlocked", false))
	var vp := _new_vp()
	_paper_bg(vp, PAPER if unlocked else Color("#D7C9A6"), Color("#8A6A2E"))
	var ink := Color("#2B1B0E")
	if idx % 2 == 0:
		_vlabel(vp, "%s　第 %d 筆" % [_cat, idx / 2 + 1], Vector2(28, 26), Vector2(PAGE.x - 56, 22), 14, Color("#7A4A12"))
		_vlabel(vp, String(e["name"]), Vector2(28, 50), Vector2(PAGE.x - 56, 46), 32, ink)
		if unlocked and String(e.get("art", "")) != "" and ResourceLoader.exists(String(e["art"])):
			var tr := TextureRect.new()
			tr.texture = load(String(e["art"])) as Texture2D
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(50, 108)
			tr.size = Vector2(PAGE.x - 100, 200)
			vp.add_child(tr)
		elif not unlocked:
			_vlabel(vp, "？", Vector2(0, 130), Vector2(PAGE.x, 140), 110, Color("#B8A67E"), HORIZONTAL_ALIGNMENT_CENTER)
		var s := _vlabel(vp, String(e["summary"]), Vector2(30, 330), Vector2(PAGE.x - 60, 120), 18, ink)
		s.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		_vlabel(vp, "詳細資料", Vector2(28, 26), Vector2(PAGE.x - 56, 22), 14, Color("#7A4A12"))
		_vlabel(vp, String(e["name"]), Vector2(28, 50), Vector2(PAGE.x - 56, 46), 32, ink)
		var y := 112.0
		for line in e["detail"]:
			var l := _vlabel(vp, String(line), Vector2(30, y), Vector2(PAGE.x - 60, 60), 18, ink)
			l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			y += 26.0 * maxf(1.0, ceilf(float(String(line).length()) / 15.0)) + 8.0
	_vlabel(vp, str(idx + 1), Vector2(0, PAGE.y - 36), Vector2(PAGE.x, 20), 13, Color("#8A7A5A"), HORIZONTAL_ALIGNMENT_CENTER)
	_page_vps[idx] = vp
	return vp.get_texture()

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
	var cover: TextureRect = _covers[cat]
	# 其他兩本退場，這一本浮到前面（右頁的位置）
	for c in _covers.keys():
		if c != cat:
			create_tween().tween_property(_covers[c], "modulate:a", 0.0, 0.25)
	cover.z_index = 5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(cover, "position", SPINE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cover, "size", PAGE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	# 換成「封面翻開」：封面當翻動的那一張，背面是封面內側
	cover.visible = false
	_book.visible = true
	_base.modulate.a = 0.0
	await _flip(_cover_tex[cat], _inside_tex, _blank_tex, _page_tex(0), true, 0.8, true)
	_set_idle(0)
	# 起點不是第一筆（前面有未收錄的）：快速翻到第一筆已收錄的
	if start > 0:
		mode = "book"
		await _go(start)
	mode = "book"
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
	await _flip(_cover_tex[_cat], _inside_tex, _blank_tex, _page_tex(0), false, 0.7, true)
	_book.visible = false
	var cover: TextureRect = _covers[_cat]
	cover.visible = true
	var i := EntriesScript.CATEGORIES.find(_cat)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(cover, "position", _slot_pos(i), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cover, "size", PAGE * SLOT_SCALE, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for c in _covers.keys():
		if c != _cat:
			tw.tween_property(_covers[c], "modulate:a", 1.0, 0.3)
	await tw.finished
	cover.z_index = 0
	mode = "shelf"
	_busy = false
	_refresh_cover(_cat)
	_apply_mode_buttons()

func _entry_unlocked(e: int) -> bool:
	return e >= 0 and e < _list.size() and bool((_list[e] as Dictionary).get("unlocked", false))

## 這一個跨頁有沒有東西可看：左頁（前一筆的詳細資料）或右頁（這一筆的簡述）有一邊已收錄
func _valid_spread(j: int) -> bool:
	return _entry_unlocked(j - 1) or _entry_unlocked(j)

func _turn(dir: int) -> void:
	var n := _list.size()
	if dir > 0:
		var j := _spread + 1
		while j <= n and not _valid_spread(j):
			j += 1
		if _spread >= n:
			_notice("後續內容待君發掘……\n\n繼續行走江湖，見聞自會增添。")
			return
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
	var pos := Vector2(336, 110)
	var size := Vector2(480, 440)
	var bg := ColorRect.new()
	bg.color = Color("#E9DAB5")
	bg.position = pos
	bg.size = size
	_overlay.add_child(bg)
	_label("目錄　%s" % _cat, pos + Vector2(24, 12), Vector2(300, 34), 24, Color("#2B1B0E"), HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	var sc := ScrollContainer.new()
	sc.position = pos + Vector2(16, 56)
	sc.size = Vector2(size.x - 32, size.y - 120)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(sc)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(size.x - 52, 0)
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
		b.add_theme_color_override("font_color", Color("#2B1B0E") if bool(e["unlocked"]) else Color("#9A8A6A"))
		b.pressed.connect(func():
			_overlay.visible = false
			_go(i))
		box.add_child(b)
	var close := _tex_button(Vector2(140, 36), pos + Vector2((size.x - 140.0) * 0.5, size.y - 52), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	close.text = "關閉"
	close.pressed.connect(_close_overlay)

func _notice(text: String) -> void:
	_clear_overlay()
	_overlay.visible = true
	var pos := Vector2(326, 190)
	var size := Vector2(500, 250)
	var bg := ColorRect.new()
	bg.color = Color("#E9DAB5")
	bg.position = pos
	bg.size = size
	_overlay.add_child(bg)
	var l := _label(text, pos + Vector2(30, 30), Vector2(size.x - 60, 120), 22, Color("#2B1B0E"), HORIZONTAL_ALIGNMENT_CENTER, _overlay)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok := _tex_button(Vector2(140, 36), pos + Vector2((size.x - 140.0) * 0.5, size.y - 56), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, _overlay)
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
