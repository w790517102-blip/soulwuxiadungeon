extends "res://scripts/inventory/StudyPageBase.gd"
# 武術頁：整頁靜態版面（共邊國 V3 整頁底圖）。左＝同行俠客名帖，中左＝目前運行的內功心法（按「更換內功」開選擇視窗），
# 中＝人物與「內外功搭配」說明，右＝已習得的外功武術（分類依已習得動態產生）。不再有收納式抽屜。
# 資料與規則全部沿用現有系統：已習得清單 CharacterSkill／SkillDB、內功 TeamData、搭配 SkillDB.get_inner_force_linkage_entries
# （MartialSynergy 的統一表）。這個檔案只負責畫面與操作。固定標題與外框都烤在底圖上，這裡只放動態內容。
# 版面座標為邏輯 px（1152×648），依 V3 底圖（assets/UI/martial/martial_page_v3.png）的框體量得。

const MartialInfoScript = preload("res://scripts/inventory/MartialInfo.gd")

const BUTTON_Y := 586
const FIGURE_POS := Vector2(486, 70)
const FIGURE_SIZE := Vector2(254, 486)
const FIGURE_CLIP := Rect2(412, 76, 400, 330)      # 搭配框標題飄帶（y≈410）以上才露出人物
const NAME_POS := Vector2(752, 100)
const NAME_BOX := Vector2(50, 300)
const ROSTER_POS := Vector2(28, 140)
const CARD_SIZE := Vector2(138, 96)
const MD := "res://assets/UI/martial/"       # 共邊國武術頁素材（2 倍圖；說明見 docs/system_menu/martial_originals/）
const WEAPON_ICONS := {"刀": "dao", "劍": "jian", "琴": "qin", "筆": "brush", "棍": "staff", "槍": "spear", "拳": "fist", "掌": "palm", "通用": "universal"}
const ELEMENT_ICONS := {"快": "fast", "遲": "slow", "柔": "soft", "剛": "hard"}
const COMPANION_SLOTS := 4                    # 左邊名帖列至少排這麼多格，不足的用空位補滿
## 內功面板（紙面 x214–397、y144–599）
const FORCE_X := 222.0
const FORCE_W := 168.0
## 外功面板（紙面 x838–1077、y144–602）
const OUTER_X := 842.0
const CAT_W := 234.0
const ROW_SIZE := Vector2(232, 46)
## 搭配區（紙面 x438–780、y423–599）
const SYN_RECT := Rect2(438, 420, 342, 180)
const GOLD_EDGE := Color("#8A6A2E")
const DARK := Color(0.10, 0.08, 0.06, 0.96)
const NAME_INK := Color("#2A1D12")
const MUTED := Color("#8A7F6A")

var category := "全部"
var selected_skill: Dictionary = {}
var _skills: Array = []
var _cats: Array = []
var _cat_page := 0
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

func _ready() -> void:
	name = "MartialPage"
	set_meta("skip_menu_skin", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100      # 舊分頁的節點 z_index 是 1024，新頁要蓋在它上面
	_build_background(false)
	_m_image("martial_page_v3", Vector2.ZERO, Vector2(1152, 648), self)      # 整頁底圖：位置對準畫布，框外透明
	_build_nav("TabSkill")
	_build_figure()
	_build_force_panel()
	_build_outer_panel()
	_build_synergy()
	_build_roster()
	var back := _tex_button(Vector2(165, 38), Vector2(494, BUTTON_Y), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	back.text = "返回"
	back.pressed.connect(func(): close_requested.emit())
	_build_toast()
	_build_overlay()
	if InventorySync:
		InventorySync.equipment_changed.connect(_refresh)
	_refresh()

## 武術頁沿用裝備頁的前景方案（備案 2）
func _foreground_preset() -> String:
	return "cloth_big"

# ------------------------------------------------------------------
# 小元件
# ------------------------------------------------------------------
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

## 共邊國素材載入：mart("martial_page_v3")。沒有檔案回傳 null（呼叫處自行退回暫代畫法）
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


# ------------------------------------------------------------------
# 建立畫面
# ------------------------------------------------------------------
func _build_roster() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = ROSTER_POS
	scroll.size = Vector2(142, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.z_index = 4
	add_child(scroll)
	_roster_scroll = VBoxContainer.new()
	_roster_scroll.add_theme_constant_override("separation", 8)
	_roster_scroll.custom_minimum_size = Vector2(138, 0)
	scroll.add_child(_roster_scroll)

func _build_figure() -> void:
	# 搭配框是底圖的一部分，人物不能蓋住它：人物放在一個裁切框裡，只露出搭配框上緣以上（半身，與概念圖相同）
	var clip := Control.new()
	clip.name = "FigureClip"
	clip.position = FIGURE_CLIP.position
	clip.size = FIGURE_CLIP.size
	clip.clip_contents = true
	clip.z_index = 1
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	_doll = EquipmentDollScript.new()
	_doll.name = "PaperDoll"
	_doll.position = FIGURE_POS - FIGURE_CLIP.position
	_doll.size = FIGURE_SIZE
	clip.add_child(_doll)
	_fallback = TextureRect.new()
	_fallback.name = "PortraitFallback"
	_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fallback.position = FIGURE_POS - FIGURE_CLIP.position + Vector2(0, 40)
	_fallback.size = Vector2(FIGURE_SIZE.x, 250)
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_fallback)
	_name_box = Control.new()
	_name_box.name = "VerticalName"
	_name_box.position = NAME_POS
	_name_box.size = NAME_BOX
	_name_box.z_index = 1
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_box)


## 內功面板：標題「內功心法」與各小標題都烤在底圖上，這裡只放動態內容
func _build_force_panel() -> void:
	_force_icon_holder = Control.new()
	_force_icon_holder.position = Vector2(251, 146)
	_force_icon_holder.size = Vector2(108, 108)
	_force_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_force_icon_holder)
	_force_name = _label("", Vector2(FORCE_X, 262), Vector2(112, 26), 18, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_force_tag = _chip("運行中", Rect2(FORCE_X + FORCE_W - 48, 266, 48, 19), self, Color("#9A2A2A"), Color.WHITE, 11)
	_force_desc = _rich(Rect2(FORCE_X, 290, FORCE_W, 70), self, 12)
	# 內功屬性只顯示目前這門的那一個圖章（快／遲／柔／剛），不一次排四個
	_force_element_holder = Control.new()
	_force_element_holder.position = Vector2(281, 391)
	_force_element_holder.size = Vector2(48, 48)
	_force_element_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_force_element_holder)
	_btn_switch_force = _art_button(Rect2(231, 446, 147, 38), "change_inner_normal", "change_inner_hover", "change_inner_pressed", "change_inner_disabled")
	_btn_switch_force.pressed.connect(_open_force_picker)
	_force_effects = _rich(Rect2(FORCE_X, 524, FORCE_W, 72), self, 12)

## 外功面板：標題「外功武術」「招式詳情」烤在底圖上
func _build_outer_panel() -> void:
	_cat_row = Control.new()
	_cat_row.position = Vector2(OUTER_X, 148)
	_cat_row.size = Vector2(CAT_W, 28)
	add_child(_cat_row)
	var list_scroll := ScrollContainer.new()
	list_scroll.position = Vector2(OUTER_X, 182)
	list_scroll.size = Vector2(CAT_W + 2, 288)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(list_scroll)
	_skill_rows = VBoxContainer.new()
	_skill_rows.add_theme_constant_override("separation", 2)
	_skill_rows.custom_minimum_size = Vector2(ROW_SIZE.x, 0)
	list_scroll.add_child(_skill_rows)
	var rows := [["type", "類型"], ["cost", "消耗"], ["target", "目標"]]
	for i in rows.size():
		var y := 502.0 + i * 20.0
		var tag := _m_image("detail_tag_blank", Vector2(OUTER_X + 2, y), Vector2(44, 18), self)
		_label(rows[i][1], Vector2.ZERO, tag.size, 11, CREAM, HORIZONTAL_ALIGNMENT_CENTER, tag)
		_detail_vals[rows[i][0]] = _label("", Vector2(OUTER_X + 52, y - 1), Vector2(180, 20), 13, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_detail_effects = _rich(Rect2(OUTER_X + 2, 563, CAT_W - 4, 38), self, 11)

func _build_synergy() -> void:
	var box := Control.new()
	box.name = "Synergy"
	box.position = SYN_RECT.position
	box.size = SYN_RECT.size
	box.z_index = 2
	add_child(box)
	# 底圖已含框、標題「內外功搭配」與紙面；這裡只放兩側圖示、名稱、× 與說明
	_syn_left = Control.new()
	_syn_left.position = Vector2(30, 36)
	_syn_left.size = Vector2(130, 70)
	box.add_child(_syn_left)
	_syn_right = Control.new()
	_syn_right.position = Vector2(182, 36)
	_syn_right.size = Vector2(130, 70)
	box.add_child(_syn_right)
	_label("×", Vector2(138, 40), Vector2(66, 40), 28, INK, HORIZONTAL_ALIGNMENT_CENTER, box)
	_syn_text = _rich(Rect2(16, 112, 310, 64), box, 12)

## 讀進素材的按鈕（四態）：一般／移入／按下／停用，字由程式放
func _art_button(rect: Rect2, normal: String, hover: String, pressed: String, disabled: String) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.text = "更換內功"
	var arts := {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled}
	for st in arts.keys():
		var sb := StyleBoxTexture.new()
		sb.texture = mart(String(arts[st]))
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.42))
	add_child(b)
	return b

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
		pr.size = Vector2(CARD_SIZE.x, 72)          # 頭像放框下方，只露出框上半部的開口；下方淺紙名條由程式寫姓名
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
		_label(String(a.get("name", id)), Vector2(0, 72), Vector2(CARD_SIZE.x, 20), 15, NAME_INK, HORIZONTAL_ALIGNMENT_CENTER, card)
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
		_m_image("inner_liuchen_icon_large", Vector2.ZERO, Vector2(108, 108), _force_icon_holder)      # 內功心法的象徵圖（打坐人像），不是屬性
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
	var tab_x := 26.0 if overflow else 0.0
	var tab_w := (CAT_W - (52.0 if overflow else 0.0)) / float(per)
	if overflow:
		var prev := _tri_button(Rect2(0, 2, 24, 24), "switch_left_normal", "switch_left_hover", "switch_left_pressed", _cat_row)
		prev.disabled = _cat_page <= 0
		prev.modulate = Color(1, 1, 1, 0.4) if prev.disabled else Color.WHITE
		prev.pressed.connect(func(): _cat_page = maxi(0, _cat_page - 1); _rebuild_categories())
		var nxt := _tri_button(Rect2(CAT_W - 24.0, 2, 24, 24), "switch_right_normal", "switch_right_hover", "switch_right_pressed", _cat_row)
		nxt.disabled = _cat_page >= pages - 1
		nxt.modulate = Color(1, 1, 1, 0.4) if nxt.disabled else Color.WHITE
		nxt.pressed.connect(func(): _cat_page = mini(pages - 1, _cat_page + 1); _rebuild_categories())
	var first := _cat_page * per
	for i in range(first, mini(first + per, tabs.size())):
		var name_: String = tabs[i]
		var b := Button.new()
		b.position = Vector2(tab_x + (i - first) * tab_w, 0)
		b.size = Vector2(tab_w - 2.0, 26)
		b.text = name_
		b.focus_mode = Control.FOCUS_NONE
		var on: bool = name_ == category
		var sb := StyleBoxTexture.new()
		sb.texture = mart("category_tab_selected" if on else "category_tab_normal")
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", CREAM if on else GOLD)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(func(): _select_category(name_))
		_cat_row.add_child(b)

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
		_icon("weapon", wt, 28, row, Vector2(19, 9))
		_label(String(s.get("name", "???")), Vector2(58, 4), Vector2(110, 20), 14, INK, HORIZONTAL_ALIGNMENT_LEFT, row)
		_label(wt, Vector2(58, 25), Vector2(90, 14), 10, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, row)
		var usable: bool = menu._can_use_skill_now(s, actor_id) if menu != null else true
		_chip("可施展" if usable else "不可施展", Rect2(ROW_SIZE.x - 58, 13, 52, 20), row, Color("#2F6B3A") if usable else Color("#7A7468"), Color.WHITE, 11)
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
