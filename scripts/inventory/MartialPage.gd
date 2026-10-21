extends "res://scripts/inventory/StudyPageBase.gd"
# 武術頁：雙抽屜式內外功管理（共邊國概念圖）。左抽屜＝目前運行的內功心法（按「更換內功」開選擇視窗），
# 右抽屜＝已習得的外功武術（分類依已習得動態產生），中央＝人物與「內外功搭配」說明。
# 資料與規則全部沿用現有系統：已習得清單 CharacterSkill／SkillDB、內功 TeamData、搭配 SkillDB.get_inner_force_linkage_entries
# （MartialSynergy 的統一表）。這個檔案只負責畫面與操作。抽屜與名帖的底板目前用程式畫的暫代，美術素材交來後換。
# 版面依據：docs/system_menu/武術頁_現況盤點與可行性評估.md（座標為邏輯 px，1152×648）。

const MartialInfoScript = preload("res://scripts/inventory/MartialInfo.gd")

const BUTTON_Y := 586
const FIGURE_POS := Vector2(468, 66)
const FIGURE_SIZE := Vector2(254, 486)
const NAME_POS := Vector2(750, 100)
const NAME_BOX := Vector2(60, 300)
const ROSTER_RECT := Rect2(24, 92, 146, 506)
const CARD_SIZE := Vector2(138, 96)
const LEFT_RECT := Rect2(178, 92, 236, 486)
const RIGHT_RECT := Rect2(836, 92, 266, 486)
const SYN_RECT := Rect2(420, 404, 386, 174)
const HANDLE_SIZE := Vector2(38, 64)
const MD := "res://assets/UI/martial/"       # 共邊國武術頁素材（2 倍圖，邏輯尺寸見 docs/system_menu/martial_originals/交接說明.md）
const WEAPON_ICONS := {"刀": "dao", "劍": "jian", "琴": "qin", "筆": "brush", "棍": "staff", "槍": "spear", "拳": "fist", "掌": "palm", "通用": "universal"}
const ELEMENT_ICONS := {"快": "fast", "遲": "slow", "柔": "soft", "剛": "hard"}
const COMPANION_SLOTS := 4                    # 左邊名帖列至少排這麼多格，不足的用空位補滿
const ROW_SIZE := Vector2(206, 36)
const CAT_W := 206.0                           # 右抽屜紙面的內容寬度（V2 外框）
const PAPER := Color(0.91, 0.85, 0.70, 0.97)
const PAPER_DIM := Color(0.84, 0.77, 0.62, 1.0)
const GOLD_EDGE := Color("#8A6A2E")
const DARK := Color(0.10, 0.08, 0.06, 0.96)
const OK_GREEN := Color("#2F6B3A")
const MUTED := Color("#8A7F6A")

## 抽屜開關記在這裡：切頁、重開選單都維持上次的樣子
static var left_open := true
static var right_open := true

var category := "全部"
var selected_skill: Dictionary = {}
var _skills: Array = []
var _cats: Array = []
var _cat_page := 0
var _left: Control
var _right: Control
var _left_body: Control
var _right_body: Control
var _left_handle: TextureButton
var _right_handle: TextureButton
var _doll: Control
var _fallback: TextureRect
var _name_box: Control
var _roster_scroll: VBoxContainer
var _force_icon_holder: Control
var _force_name: Label
var _force_tag: Control
var _force_desc: RichTextLabel
var _force_element_holder: Control
var _force_effects: RichTextLabel
var _btn_switch_force: Button
var _cat_row: Control
var _skill_rows: VBoxContainer
var _detail_vals: Dictionary = {}
var _detail_effects: RichTextLabel
var _syn_left: Control
var _syn_right: Control
var _syn_text: RichTextLabel
var _pick_element := "全部"
var _pick_force_id := ""
var _drawer_tween: Tween

func _ready() -> void:
	name = "MartialPage"
	set_meta("skip_menu_skin", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100      # 舊分頁的節點 z_index 是 1024，新頁要蓋在它上面
	_build_background(false)
	_image(E + "equip_scroll_complete", Vector2(0, 0), Vector2(1152, 648.5))
	_m_image("martial_panel", Vector2(178, 92), Vector2(924, 486), self)      # 中間頁面板塊：蓋在原卷軸內頁上
	_build_nav("TabSkill")
	_build_figure()
	_build_left_drawer()
	_build_right_drawer()
	_build_synergy()
	_build_roster()
	var back := _tex_button(Vector2(165, 38), Vector2(494, BUTTON_Y), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	back.text = "返回"
	back.pressed.connect(func(): close_requested.emit())
	_build_toast()
	_build_overlay()
	_apply_drawer_positions(false)
	if InventorySync:
		InventorySync.equipment_changed.connect(_refresh)
	_refresh()

## 武術頁沿用裝備頁的前景方案（備案 2）
func _foreground_preset() -> String:
	return "cloth_big"

# ------------------------------------------------------------------
# 小元件（暫代素材：程式畫的紙面、深色標題條、圓形圖示）
# ------------------------------------------------------------------
func _paper(rect: Rect2, parent: Node, fill: Color = PAPER) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(2)
	sb.border_color = GOLD_EDGE
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p

func _title_bar(text: String, width: float, parent: Node) -> void:
	var p := Panel.new()
	p.size = Vector2(width, 34)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = DARK
	sb.set_border_width_all(2)
	sb.border_color = GOLD_EDGE
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	_label(text, Vector2.ZERO, Vector2(width, 34), 19, GOLD, HORIZONTAL_ALIGNMENT_CENTER, parent)

## 圓形圖示（暫代：圈裡一個字；之後換成分類圖示或各招圖示）
func _glyph_icon(glyph: String, size: float, parent: Node, pos: Vector2, active := false) -> Control:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.14, 0.12) if not active else Color(0.18, 0.24, 0.36)
	sb.set_corner_radius_all(int(size / 2.0))
	sb.set_border_width_all(2)
	sb.border_color = GOLD_EDGE
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	_label(glyph, Vector2.ZERO, Vector2(size, size), int(size * 0.5), CREAM, HORIZONTAL_ALIGNMENT_CENTER, p)
	return p

func _chip(text: String, rect: Rect2, parent: Node, bg: Color, fg: Color, font_size := 12) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	_label(text, Vector2.ZERO, rect.size, font_size, fg, HORIZONTAL_ALIGNMENT_CENTER, p)
	return p

func _rich(rect: Rect2, parent: Node, font_size := 13) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.position = rect.position
	t.size = rect.size
	t.bbcode_enabled = true
	t.fit_content = false
	t.scroll_active = true
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	t.add_theme_font_override("normal_font", FONT)
	t.add_theme_font_size_override("normal_font_size", font_size)
	t.add_theme_color_override("default_color", INK)
	var bar := t.get_v_scroll_bar()
	bar.custom_minimum_size.x = 6
	parent.add_child(t)
	return t

## 共邊國素材載入：mart("handle_left_open")。沒有檔案回傳 null（呼叫處自行退回暫代畫法）
func mart(name_: String) -> Texture2D:
	var p := "%s%s.png" % [MD, name_]
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

func _m_image(name_: String, pos: Vector2, size: Vector2, parent: Node) -> TextureRect:
	var r := TextureRect.new()
	r.texture = mart(name_)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

## 圖示：武器分類或內功屬性，圖片優先；沒有對應的才退回圓形文字
func _icon(kind: String, key: String, size: float, parent: Node, pos: Vector2, active := false) -> Control:
	var file := String(ELEMENT_ICONS.get(key, "")) if kind == "element" else String(WEAPON_ICONS.get(key, ""))
	if file != "" and mart("category_" + file) != null:
		return _m_image("category_" + file, pos, Vector2(size, size), parent)
	return _glyph_icon(key.substr(0, 1) if key != "" else "武", size, parent, pos, active)

## 三態小按鈕（把手、分類切換鈕）：normal／hover／pressed 各一張
func _tri_button(rect: Rect2, normal: String, hover: String, pressed: String, parent: Node) -> TextureButton:
	var b := TextureButton.new()
	b.position = rect.position
	b.size = rect.size
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.focus_mode = Control.FOCUS_NONE
	b.texture_normal = mart(normal)
	b.texture_hover = mart(hover)
	b.texture_pressed = mart(pressed)
	parent.add_child(b)
	return b

func _handle_button(parent: Node, pos: Vector2) -> TextureButton:
	var b := _tri_button(Rect2(pos, HANDLE_SIZE), "handle_left_closed", "handle_left_closed", "handle_left_closed", parent)
	b.modulate = Color.WHITE
	return b

# ------------------------------------------------------------------
# 建立畫面
# ------------------------------------------------------------------
func _build_roster() -> void:
	# 窄版名帖（暫代：頭像加名字條；共邊國的窄版名帖三態與空位交來後換成素材）
	var back := Panel.new()
	back.position = ROSTER_RECT.position
	back.size = ROSTER_RECT.size
	back.z_index = 3
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.08, 0.96)
	sb.set_border_width_all(2)
	sb.border_color = GOLD_EDGE
	sb.set_corner_radius_all(4)
	back.add_theme_stylebox_override("panel", sb)
	add_child(back)
	_image(E + "equip_roster_title", Vector2(28, 98), Vector2(138, 21)).z_index = 4
	_image(E + "equip_roster_title_cut", Vector2(28, 96), Vector2(138, 24)).z_index = 4
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(ROSTER_RECT.position.x + 4, 128)
	scroll.size = Vector2(138, 466)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.z_index = 4
	add_child(scroll)
	_roster_scroll = VBoxContainer.new()
	_roster_scroll.add_theme_constant_override("separation", 8)
	_roster_scroll.custom_minimum_size = Vector2(136, 0)
	scroll.add_child(_roster_scroll)

func _build_figure() -> void:
	_doll = EquipmentDollScript.new()
	_doll.name = "PaperDoll"
	_doll.position = FIGURE_POS
	_doll.size = FIGURE_SIZE
	_doll.z_index = 1
	add_child(_doll)
	_fallback = TextureRect.new()
	_fallback.name = "PortraitFallback"
	_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fallback.position = FIGURE_POS + Vector2(0, 40)
	_fallback.size = Vector2(FIGURE_SIZE.x, 250)
	_fallback.z_index = 1
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fallback)
	_name_box = Control.new()
	_name_box.name = "VerticalName"
	_name_box.position = NAME_POS
	_name_box.size = NAME_BOX
	_name_box.z_index = 1
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_box)

func _build_left_drawer() -> void:
	_left = Control.new()
	_left.name = "LeftDrawer"
	_left.position = LEFT_RECT.position
	_left.size = LEFT_RECT.size
	_left.z_index = 2
	add_child(_left)
	_left_body = Control.new()
	_left_body.name = "Body"
	_left.add_child(_left_body)
	_m_image("drawer_inner", Vector2.ZERO, LEFT_RECT.size, _left_body)
	# V2 外框：原概念圖的框邊保持比例縮進 236×486，內容紙面約 x45–212、y50–468（抽屜內邏輯座標），中軸 x=129
	_outlined(_label("內功心法", Vector2(45, 19), Vector2(167, 29), 18, Color("#F6E7B4"), HORIZONTAL_ALIGNMENT_CENTER, _left_body))
	_force_icon_holder = Control.new()
	_force_icon_holder.position = Vector2(71, 48)
	_force_icon_holder.size = Vector2(116, 116)
	_force_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_body.add_child(_force_icon_holder)
	_force_name = _label("", Vector2(58, 166), Vector2(100, 24), 17, INK, HORIZONTAL_ALIGNMENT_LEFT, _left_body)
	_force_tag = _chip("運行中", Rect2(160, 168, 46, 19), _left_body, Color("#9A2A2A"), Color.WHITE, 11)
	_force_desc = _rich(Rect2(58, 192, 148, 58), _left_body, 11)
	_label("內功屬性傾向", Vector2(58, 252), Vector2(148, 20), 12, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, _left_body)
	# 內功屬性只顯示目前這門的那一個圖章（快／遲／柔／剛），不一次排四個
	_force_element_holder = Control.new()
	_force_element_holder.position = Vector2(105, 280)
	_force_element_holder.size = Vector2(48, 48)
	_force_element_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_body.add_child(_force_element_holder)
	_btn_switch_force = _tex_button(Vector2(142, 30), Vector2(58, 334), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _left_body)
	_btn_switch_force.text = "更換內功"
	_btn_switch_force.add_theme_font_size_override("font_size", 15)
	_btn_switch_force.pressed.connect(_open_force_picker)
	_label("當前效果", Vector2(58, 370), Vector2(100, 20), 13, INK, HORIZONTAL_ALIGNMENT_LEFT, _left_body)
	_force_effects = _rich(Rect2(58, 392, 148, 72), _left_body, 12)
	_left_handle = _handle_button(_left, Vector2(LEFT_RECT.size.x, 178))      # 邏輯 (412,270)
	_left_handle.pressed.connect(func(): _toggle_drawer(true))

func _build_right_drawer() -> void:
	_right = Control.new()
	_right.name = "RightDrawer"
	_right.position = RIGHT_RECT.position
	_right.size = RIGHT_RECT.size
	_right.z_index = 2
	add_child(_right)
	_right_body = Control.new()
	_right_body.name = "Body"
	_right.add_child(_right_body)
	_m_image("drawer_outer", Vector2.ZERO, RIGHT_RECT.size, _right_body)
	# V2 外框：內容紙面約 x40–252、y50–468；標題墨條 y14–45
	_outlined(_label("外功武術", Vector2(40, 14), Vector2(190, 31), 18, Color("#F6E7B4"), HORIZONTAL_ALIGNMENT_CENTER, _right_body))
	_cat_row = Control.new()
	_cat_row.position = Vector2(44, 54)
	_cat_row.size = Vector2(CAT_W, 28)
	_right_body.add_child(_cat_row)
	var list_scroll := ScrollContainer.new()
	list_scroll.position = Vector2(44, 88)
	list_scroll.size = Vector2(CAT_W, 190)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_body.add_child(list_scroll)
	_skill_rows = VBoxContainer.new()
	_skill_rows.add_theme_constant_override("separation", 3)
	_skill_rows.custom_minimum_size = Vector2(ROW_SIZE.x, 0)
	list_scroll.add_child(_skill_rows)
	_label("招式詳情", Vector2(46, 282), Vector2(100, 20), 14, INK, HORIZONTAL_ALIGNMENT_LEFT, _right_body)
	var rows := [["type", "類型"], ["cost", "消耗"], ["target", "目標"]]
	for i in rows.size():
		var y := 304.0 + i * 24.0
		_chip(rows[i][1], Rect2(46, y, 40, 20), _right_body, DARK, CREAM, 12)
		_detail_vals[rows[i][0]] = _label("", Vector2(92, y), Vector2(156, 20), 13, INK, HORIZONTAL_ALIGNMENT_LEFT, _right_body)
	_detail_effects = _rich(Rect2(46, 380, 202, 84), _right_body, 12)
	_right_handle = _handle_button(_right, Vector2(-HANDLE_SIZE.x, 178))      # 邏輯 (800,270)
	_right_handle.pressed.connect(func(): _toggle_drawer(false))

func _build_synergy() -> void:
	var box := Control.new()
	box.name = "Synergy"
	box.position = SYN_RECT.position
	box.size = SYN_RECT.size
	box.z_index = 2
	add_child(box)
	_m_image("combination_panel", Vector2.ZERO, SYN_RECT.size, box)
	# V2 搭配框保持原比例縮入，左右各有透明留邊：框體約 x41–345、紙面 x56–330、y20–162；標題墨條 (145,10)–(252,29)
	_outlined(_label("內外功搭配", Vector2(145, 9), Vector2(107, 21), 13, Color("#F6E7B4"), HORIZONTAL_ALIGNMENT_CENTER, box))
	_syn_left = Control.new()
	_syn_left.position = Vector2(48, 38)
	_syn_left.size = Vector2(130, 66)
	box.add_child(_syn_left)
	_syn_right = Control.new()
	_syn_right.position = Vector2(208, 38)
	_syn_right.size = Vector2(130, 66)
	box.add_child(_syn_right)
	_label("×", Vector2(160, 40), Vector2(66, 40), 28, INK, HORIZONTAL_ALIGNMENT_CENTER, box)
	_syn_text = _rich(Rect2(62, 104, 262, 54), box, 12)

# ------------------------------------------------------------------
# 抽屜開關
# ------------------------------------------------------------------
func _drawer_x(is_left: bool, open: bool) -> float:
	if is_left:
		return LEFT_RECT.position.x if open else LEFT_RECT.position.x - LEFT_RECT.size.x
	return RIGHT_RECT.position.x if open else RIGHT_RECT.end.x      # 收起時往右平移一個抽屜寬，把手停在 (1066,270)

func _toggle_drawer(is_left: bool) -> void:
	if is_left:
		left_open = not left_open
	else:
		right_open = not right_open
	_apply_drawer_positions(true)

func _apply_drawer_positions(animate: bool) -> void:
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	var lx := _drawer_x(true, left_open)
	var rx := _drawer_x(false, right_open)
	if left_open:
		_left_body.visible = true
	if right_open:
		_right_body.visible = true
	if animate and is_inside_tree():
		_drawer_tween = create_tween().set_parallel(true)
		_drawer_tween.finished.connect(func():
			_left_body.visible = left_open      # 收起後只留把手，抽屜本體不再露在畫面邊緣
			_right_body.visible = right_open)
		_drawer_tween.tween_property(_left, "position:x", lx, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_drawer_tween.tween_property(_right, "position:x", rx, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_left.position.x = lx
		_right.position.x = rx
		_left_body.visible = left_open
		_right_body.visible = right_open
	# 箭頭永遠指向「按下去會往哪邊收／展」
	_set_handle_art(_left_handle, "handle_left_open" if left_open else "handle_left_closed")
	_set_handle_art(_right_handle, "handle_right_open" if right_open else "handle_right_closed")

func _set_handle_art(b: TextureButton, art: String) -> void:
	var t := mart(art)
	b.texture_normal = t
	b.texture_hover = t
	b.texture_pressed = t

# ------------------------------------------------------------------
# 資料
# ------------------------------------------------------------------
func _actor_ids() -> Array:
	return menu._get_all_character_ids() if menu != null else ["liuyu"]

## 這位角色已習得的外功（沿用舊頁的篩法）
func _known_skills(id: String) -> Array:
	var out: Array = []
	if menu == null or menu._skill_db == null or not menu._skill_db.has_method("get_effective_skills_for_actor"):
		return out
	var all_skills: Array = menu._skill_db.get_effective_skills_for_actor(id, null, false)
	for s in all_skills:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		if not menu._skill_data_db.is_available_for_actor(String((s as Dictionary).get("id", "")), id):
			continue
		out.append(s)
	return out

func _forces() -> Array:
	return TeamData.get_effective_inner_forces(actor_id) if TeamData else []

func _current_force() -> Dictionary:
	var cur_id := String(TeamData.get_current_inner_force_id(actor_id)) if TeamData else ""
	for f in _forces():
		if typeof(f) == TYPE_DICTIONARY and String(f.get("id", "")) == cur_id:
			return f
	return {}

func _actor_dict() -> Dictionary:
	return _actor(actor_id)

func _refresh() -> void:
	var ids := _actor_ids()
	if ids.is_empty():
		return
	if actor_id == "" or not ids.has(actor_id):
		var remembered: String = menu._get_tab_actor("martial") if menu != null else ""
		actor_id = remembered if ids.has(remembered) else String(ids[0])
	_skills = _known_skills(actor_id)
	_cats = MartialInfoScript.categories(_skills)
	if category != "全部" and not _cats.has(category):
		category = "全部"          # 新角色沒有上一位選的分類：退回「全部」
	var still := false
	for s in _skills:
		if String(s.get("id", "")) == String(selected_skill.get("id", "")):
			still = true
	if not still:
		selected_skill = {}
	_rebuild_roster()
	_refresh_figure()
	_refresh_left()
	_rebuild_categories()
	_rebuild_skill_rows()
	_refresh_detail()
	_refresh_synergy()

func _on_actor_pressed(id: String) -> void:
	if id == actor_id:
		return
	actor_id = id
	if menu != null:
		menu._remember_tab_actor("martial", id)
	selected_skill = {}
	category = "全部"
	_cat_page = 0
	_refresh()

func _rebuild_roster() -> void:
	for c in _roster_scroll.get_children():
		_roster_scroll.remove_child(c)
		c.queue_free()
	for id in _actor_ids():
		var a := _actor(String(id))
		var on: bool = String(id) == actor_id
		var card := Button.new()
		card.custom_minimum_size = CARD_SIZE
		card.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		_roster_scroll.add_child(card)
		var clip := Control.new()
		clip.size = CARD_SIZE
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(clip)
		var pr := TextureRect.new()
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pr.size = CARD_SIZE - Vector2(0, 22)          # 頭像放框下方，只露出框的開口；下方墨色名條不被頭像蓋住
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head: Texture2D = EquipmentDollScript.head_portrait(String(id))
		if head != null:
			pr.texture = head
		else:
			var path := String(a.get("portrait_path", ""))
			if path != "" and ResourceLoader.exists(path):
				pr.texture = load(path) as Texture2D
		clip.add_child(pr)
		var frame := _m_image("companion_selected" if on else "companion_normal", Vector2.ZERO, CARD_SIZE, card)
		if not on:
			card.mouse_entered.connect(func(): frame.texture = mart("companion_hover"))
			card.mouse_exited.connect(func(): frame.texture = mart("companion_normal"))
		_outlined(_label(String(a.get("name", id)), Vector2(0, CARD_SIZE.y - 24), Vector2(CARD_SIZE.x, 22), 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, card))
		card.pressed.connect(_on_actor_pressed.bind(String(id)))
	# 不足的格子用空位補滿（只是版面，不能點）
	for i in range(maxi(0, COMPANION_SLOTS - _actor_ids().size())):
		var empty := Control.new()
		empty.custom_minimum_size = CARD_SIZE
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_roster_scroll.add_child(empty)
		_m_image("companion_empty", Vector2.ZERO, CARD_SIZE, empty)

func _refresh_figure() -> void:
	_doll.show_actor(actor_id)
	var has_figure: bool = _doll.has_figure()
	_fallback.visible = not has_figure
	if not has_figure:
		var path := String(_actor_dict().get("portrait_path", ""))
		_fallback.texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	fill_vertical_name(_name_box, actor_id)

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _refresh_left() -> void:
	var force := _current_force()
	_clear(_force_icon_holder)
	if force.is_empty():
		_force_name.text = "（未修習內功）"
		_force_tag.visible = false
		_force_desc.text = "還沒有運行中的內功。"
		_force_effects.text = ""
		_btn_switch_force.disabled = _forces().is_empty()
	else:
		_m_image("inner_liuchen_icon_large", Vector2.ZERO, Vector2(116, 116), _force_icon_holder)      # 內功心法的象徵圖（打坐人像），不是屬性
		_force_name.text = MartialInfoScript.force_name(force)
		_force_tag.visible = true
		var desc := String(force.get("description", ""))
		_force_desc.text = "%s" % desc
		_force_effects.text = "\n".join(MartialInfoScript.force_effect_lines(force, _actor_dict()).map(func(l): return "• " + String(l)))
		_btn_switch_force.disabled = _forces().size() <= 1
	var cur_el := String(force.get("element", ""))
	_clear(_force_element_holder)
	if ELEMENT_ICONS.has(cur_el):
		# 暫代：先用屬性徽記；共邊國交「快遲柔剛」單字素材後換成單字
		_m_image("attribute_%s" % ELEMENT_ICONS[cur_el], Vector2.ZERO, Vector2(48, 48), _force_element_holder)

func _rebuild_categories() -> void:
	_clear(_cat_row)
	var tabs: Array = ["全部"] + _cats
	var per := 4
	var pages := maxi(1, int(ceil(float(tabs.size()) / float(per))))
	_cat_page = clampi(_cat_page, 0, pages - 1)
	# 選中的分類一定要在看得到的那一頁
	var idx := tabs.find(category)
	if idx >= 0:
		_cat_page = idx / per
	var overflow := tabs.size() > per
	var left_x := 0.0
	var tab_x := 30.0 if overflow else 0.0
	var tab_w := (CAT_W - (60.0 if overflow else 0.0)) / float(per)
	if overflow:
		var prev := _tri_button(Rect2(0, 1, 26, 26), "switch_left_normal", "switch_left_hover", "switch_left_pressed", _cat_row)
		prev.disabled = _cat_page <= 0
		prev.modulate = Color(1, 1, 1, 0.4) if prev.disabled else Color.WHITE
		prev.pressed.connect(func(): _cat_page = maxi(0, _cat_page - 1); _rebuild_categories())
		var nxt := _tri_button(Rect2(CAT_W - 26.0, 1, 26, 26), "switch_right_normal", "switch_right_hover", "switch_right_pressed", _cat_row)
		nxt.disabled = _cat_page >= pages - 1
		nxt.modulate = Color(1, 1, 1, 0.4) if nxt.disabled else Color.WHITE
		nxt.pressed.connect(func(): _cat_page = mini(pages - 1, _cat_page + 1); _rebuild_categories())
	var first := _cat_page * per
	for i in range(first, mini(first + per, tabs.size())):
		var name_: String = tabs[i]
		var b := Button.new()
		b.position = Vector2(tab_x + (i - first) * tab_w, 0)
		b.size = Vector2(tab_w - 2.0, 28)
		b.text = name_
		b.focus_mode = Control.FOCUS_NONE
		var on: bool = name_ == category
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#9A2A2A") if on else DARK
		sb.set_border_width_all(2)
		sb.border_color = GOLD_EDGE
		sb.set_corner_radius_all(4)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", CREAM if on else GOLD)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(func(): _select_category(name_))
		_cat_row.add_child(b)

func _style_small_button(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = DARK
	sb.set_border_width_all(2)
	sb.border_color = GOLD_EDGE
	sb.set_corner_radius_all(4)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.36, 0.3))

func _select_category(name_: String) -> void:
	category = name_
	_rebuild_categories()
	_rebuild_skill_rows()

func _visible_skills() -> Array:
	var out: Array = []
	for s in _skills:
		if category == "全部" or String(s.get("weapon_type", "")).strip_edges() == category:
			out.append(s)
	return out

func _rebuild_skill_rows() -> void:
	_clear(_skill_rows)
	var list := _visible_skills()
	if list.is_empty():
		var empty := _label("還沒有學會這類武術。" if not _skills.is_empty() else "還沒有學會任何武術。", Vector2.ZERO, Vector2(240, 60), 14, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, _skill_rows)
		empty.custom_minimum_size = Vector2(240, 60)
		return
	for s in list:
		var sel: bool = String(s.get("id", "")) == String(selected_skill.get("id", ""))
		var row := Button.new()
		row.custom_minimum_size = ROW_SIZE
		row.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			row.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		_skill_rows.add_child(row)
		var base := _m_image("technique_row_selected" if sel else "technique_row_normal", Vector2.ZERO, ROW_SIZE, row)
		if not sel:
			row.mouse_entered.connect(func(): base.texture = mart("technique_row_hover"))
			row.mouse_exited.connect(func(): base.texture = mart("technique_row_normal"))
		var wt := String(s.get("weapon_type", "")).strip_edges()
		_icon("weapon", wt, 26, row, Vector2(6, 5))
		_label(String(s.get("name", "???")), Vector2(38, 0), Vector2(110, 20), 14, INK, HORIZONTAL_ALIGNMENT_LEFT, row)
		_label(wt, Vector2(38, 20), Vector2(90, 14), 10, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, row)
		var usable: bool = menu._can_use_skill_now(s, actor_id) if menu != null else true
		_chip("可施展" if usable else "不可施展", Rect2(ROW_SIZE.x - 54, 8, 50, 20), row, Color("#2F6B3A") if usable else Color("#7A7468"), Color.WHITE, 11)
		row.pressed.connect(_on_skill_pressed.bind(s))

func _on_skill_pressed(s: Dictionary) -> void:
	selected_skill = s
	_rebuild_skill_rows()
	_refresh_detail()
	_refresh_synergy()

func _refresh_detail() -> void:
	if selected_skill.is_empty():
		_detail_vals["type"].text = "—"
		_detail_vals["cost"].text = "—"
		_detail_vals["target"].text = "—"
		_detail_effects.text = "請選擇武術。"
		return
	_detail_vals["type"].text = "%s・%s" % [String(selected_skill.get("weapon_type", "")), String(selected_skill.get("category", ""))]
	var mp := int(selected_skill.get("mp_cost", 0))
	_detail_vals["cost"].text = ("內力 %d" % mp) if mp > 0 else "無"
	_detail_vals["target"].text = MartialInfoScript.target_text(selected_skill)
	var lines: Array = MartialInfoScript.effect_lines(selected_skill)
	_detail_effects.text = "\n".join(lines.map(func(l): return "• " + String(l)))

func _refresh_synergy() -> void:
	_clear(_syn_left)
	_clear(_syn_right)
	var force := _current_force()
	if force.is_empty():
		_glyph_icon("—", 36, _syn_left, Vector2(47, 2))
		_label("尚未修習", Vector2(0, 44), Vector2(130, 18), 13, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, _syn_left)
	else:
		_m_image("inner_liuchen_icon", Vector2(45, 0), Vector2(40, 40), _syn_left)      # 內功一律用心法象徵圖
		_label("%s（%s）" % [MartialInfoScript.force_name(force), String(force.get("element", ""))], Vector2(0, 44), Vector2(130, 18), 13, INK, HORIZONTAL_ALIGNMENT_CENTER, _syn_left)
	if selected_skill.is_empty():
		_glyph_icon("？", 36, _syn_right, Vector2(47, 2))
		_label("請選擇外功", Vector2(0, 44), Vector2(130, 18), 13, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, _syn_right)
		_syn_text.text = "在右邊的外功清單選一招，這裡會顯示目前的內功對它的影響。"
		return
	var wt := String(selected_skill.get("weapon_type", "")).strip_edges()
	_icon("weapon", wt, 40, _syn_right, Vector2(45, 0))
	_label("%s（%s）" % [String(selected_skill.get("name", "???")), wt], Vector2(0, 44), Vector2(130, 18), 13, INK, HORIZONTAL_ALIGNMENT_CENTER, _syn_right)
	var lines: Array = []
	if menu != null and menu._skill_data_db != null and menu._skill_data_db.has_method("get_inner_force_linkage_entries"):
		var rows_any = menu._skill_data_db.get_inner_force_linkage_entries(selected_skill, _actor_dict(), force)
		if typeof(rows_any) == TYPE_ARRAY:
			for row_any in rows_any:
				if typeof(row_any) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = row_any
				var text := String(row.get("text_long", ""))
				if text == "":
					continue
				var met := bool(row.get("met", false))
				lines.append("[color=%s]• %s：%s[/color]" % ["#2F6B3A" if met else "#6B614D", String(row.get("kind", "聯動")), text])
	_syn_text.text = "\n".join(lines) if not lines.is_empty() else "目前的內功與這一招沒有特別的相合。"

# ------------------------------------------------------------------
# 更換內功視窗
# ------------------------------------------------------------------
func _open_force_picker() -> void:
	var cur := _current_force()
	_pick_force_id = String(cur.get("id", ""))
	_pick_element = "全部"
	_show_force_picker()

func _forces_in(element: String) -> Array:
	var out: Array = []
	for f in _forces():
		if typeof(f) != TYPE_DICTIONARY:
			continue
		if element == "全部" or String(f.get("element", "")).strip_edges() == element:
			out.append(f)
	return out

func _show_force_picker() -> void:
	_clear_overlay()
	_overlay.visible = true
	var pos := Vector2(206, 110)
	var size := Vector2(740, 430)
	_panel("confirm_panel", 28, 24, pos, size, _overlay)
	_label("更換內功", pos + Vector2(40, 22), Vector2(300, 30), 22, GOLD, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	# 五個篩選標籤：全部｜快｜遲｜柔｜剛
	var tabs: Array = ["全部"] + Array(MartialInfoScript.ELEMENTS)
	for i in tabs.size():
		var t: String = tabs[i]
		var on: bool = t == _pick_element
		var b := _tex_button(Vector2(62, 30), pos + Vector2(40 + i * 66, 58), "btn_primary_normal" if on else "btn_normal", "btn_primary_hover" if on else "btn_hover", "btn_primary_pressed", "btn_disabled", 24, 12, _overlay)
		b.text = t
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func():
			_pick_element = t
			var list := _forces_in(t)
			if not list.is_empty() and not list.any(func(f): return String(f.get("id", "")) == _pick_force_id):
				_pick_force_id = String(list[0].get("id", ""))
			_show_force_picker())
	var scroll := ScrollContainer.new()
	scroll.position = pos + Vector2(40, 100)
	scroll.size = Vector2(300, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(290, 0)
	scroll.add_child(rows)
	var cur_id := String(_current_force().get("id", ""))
	var list := _forces_in(_pick_element)
	if list.is_empty():
		var none := _label("這個分類還沒有學會的內功。", Vector2.ZERO, Vector2(290, 60), 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, rows)
		none.custom_minimum_size = Vector2(290, 60)
	for f in list:
		var fid := String(f.get("id", ""))
		var row := Button.new()
		row.custom_minimum_size = Vector2(290, 48)
		row.focus_mode = Control.FOCUS_NONE
		var normal := _box("row_normal", 16, 4)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			row.add_theme_stylebox_override(st, normal)
		row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		rows.add_child(row)
		if fid == _pick_force_id:
			_image("row_selected", Vector2.ZERO, Vector2(290, 48), row)
		_m_image("inner_liuchen_icon", Vector2(6, 6), Vector2(36, 36), row)
		_label(MartialInfoScript.force_name(f), Vector2(52, 0), Vector2(150, 48), 17, INK, HORIZONTAL_ALIGNMENT_LEFT, row)
		if fid == cur_id:
			_chip("運行中", Rect2(218, 14, 54, 20), row, Color("#9A2A2A"), Color.WHITE)
		row.pressed.connect(func():
			_pick_force_id = fid
			_show_force_picker())
	# 右邊：選中那門內功的說明
	var chosen: Dictionary = {}
	for f in _forces():
		if String(f.get("id", "")) == _pick_force_id:
			chosen = f
	if not chosen.is_empty():
		_label(MartialInfoScript.force_name(chosen), pos + Vector2(380, 98), Vector2(320, 32), 24, CREAM, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
		_label("屬性：%s" % String(chosen.get("element", "")), pos + Vector2(380, 130), Vector2(320, 22), 14, GOLD, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
		var detail := RichTextLabel.new()
		detail.position = pos + Vector2(380, 158)
		detail.size = Vector2(320, 196)
		detail.bbcode_enabled = true
		detail.add_theme_font_override("normal_font", FONT)
		detail.add_theme_font_size_override("normal_font_size", 14)
		detail.add_theme_color_override("default_color", CREAM)
		var eff: Array = MartialInfoScript.force_effect_lines(chosen, _actor_dict())
		detail.text = "%s\n\n[color=#E6C46A]效果[/color]\n%s" % [String(chosen.get("description", "")), "\n".join(eff.map(func(l): return "• " + String(l)))]
		_overlay.add_child(detail)
	var ok := _tex_button(Vector2(170, 40), pos + Vector2(size.x - 40 - 170 - 190, size.y - 66), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, _overlay)
	ok.text = "更換"
	ok.disabled = chosen.is_empty() or _pick_force_id == cur_id
	var cancel := _tex_button(Vector2(170, 40), pos + Vector2(size.x - 40 - 170, size.y - 66), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	cancel.text = "取消"
	ok.pressed.connect(func():
		var id := _pick_force_id
		_close_overlay()
		_switch_force(id))
	cancel.pressed.connect(_close_overlay)

## 換內功：完全沿用現有規則（TeamData.set_inner_force），這裡不加任何新的切換功能
func _switch_force(force_id: String) -> void:
	if force_id == "" or not TeamData or not TeamData.has_method("set_inner_force"):
		return
	if bool(TeamData.set_inner_force(actor_id, force_id)):
		var f := _current_force()
		show_toast("已改修「%s」" % MartialInfoScript.force_name(f))
		_refresh()
	else:
		show_toast("現在無法更換內功")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _overlay.visible:
			_close_overlay()
		else:
			close_requested.emit()
