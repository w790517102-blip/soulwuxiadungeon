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
const SYN_FRAME := Rect2(413, 392, 392, 224)      # 搭配框獨立圖（共邊國單獨摳出）的位置與大小
const NAME_POS := Vector2(722, 120)
const NAME_BOX := Vector2(76, 197)      # 書法名字（含紅印）的框，依概念圖紅框
const ROSTER_POS := Vector2(28, 140)
const CARD_SIZE := Vector2(138, 96)
const MD := "res://assets/UI/martial/"       # 共邊國武術頁素材（2 倍圖；說明見 docs/system_menu/martial_originals/）
const WEAPON_ICONS := {"刀": "dao", "劍": "jian", "琴": "qin", "筆": "brush", "棍": "staff", "槍": "spear", "拳": "fist", "掌": "palm", "通用": "universal"}
const ELEMENT_ICONS := {"快": "fast", "遲": "slow", "柔": "soft", "剛": "hard"}
const COMPANION_SLOTS := 3                    # 左邊名帖列至少排這麼多格，不足的用空位補滿
## 內功面板（紙面 x214–397、y144–599）
const FORCE_X := 222.0
const FORCE_W := 168.0
## 外功面板（紙面 x838–1077、y144–602）
const OUTER_X := 842.0
const CAT_W := 234.0
const ROW_SIZE := Vector2(232, 46)
## 搭配區（紙面 x438–780、y423–599）
const SYN_RECT := Rect2(438, 410, 342, 180)
const GOLD_EDGE := Color("#8A6A2E")
const PAPER_ACCENT := Color("#7A4A12")         # 宣紙視窗上的小標題色（深棕）
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
var _btn_detail: Button
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
	_build_foreground_overlays()
	var back := _tex_button(Vector2(165, 38), Vector2(494, BUTTON_Y), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	back.text = "返回"
	back.pressed.connect(func(): close_requested.emit())
	_build_toast()
	_build_overlay()
	if InventorySync:
		InventorySync.equipment_changed.connect(_refresh)
	_refresh()

## 武術頁用自己的前景（左下、右下、右緣，見 _build_foreground_overlays），不用共用前景
func _foreground_preset() -> String:
	return "none"

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
	_outline_rich(t)
	var bar := t.get_v_scroll_bar()
	bar.custom_minimum_size.x = 6
	parent.add_child(t)
	return t

## 共邊國素材載入：mart("martial_page_v3")。沒有檔案回傳 null（呼叫處自行退回暫代畫法）
func mart(name_: String) -> Texture2D:
	for ext in ["png", "webp"]:
		var p := "%s%s.%s" % [MD, name_, ext]
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null

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
	_doll = EquipmentDollScript.new()
	_doll.name = "PaperDoll"
	_doll.position = FIGURE_POS
	_doll.size = FIGURE_SIZE
	_doll.z_index = 1      # 搭配框（z 2）疊在人物前面，人物完整站在後面
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


## 內功面板：標題「內功心法」烤在底圖上。順序（上到下）：大圖示、名稱＋描述、當前效果、更換內功鈕、內功屬性。
## 底圖上原本固定的兩條小標題（內功屬性傾向、當前效果）位置不對，這裡先用同區的空白紙面蓋掉、再把原標題圖剪下來貼到新位置。
func _build_force_panel() -> void:
	_cover_baked(Rect2(232, 363, 150, 26), Rect2(232, 325, 150, 26))                     # 蓋掉舊的「內功屬性傾向」
	_cover_baked(Rect2(220, 495, 170, 30), Rect2(220, 545, 170, 30))                     # 蓋掉舊的「當前效果」及其右側細線
	_baked_piece(Rect2(464, 726, 300, 52), Vector2(232, 503), Vector2(150, 26))           # 「內功屬性傾向」貼到最下面
	_baked_piece(Rect2(444, 993, 222, 52), Vector2(222, 364), Vector2(111, 26))           # 「當前效果」貼到名稱描述之後
	_force_icon_holder = Control.new()
	_force_icon_holder.position = Vector2(237, 146)
	_force_icon_holder.size = Vector2(136, 136)
	_force_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_force_icon_holder)
	_force_name = _label("", Vector2(FORCE_X, 281), Vector2(112, 26), 18, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_force_tag = _chip("運行中", Rect2(FORCE_X + FORCE_W - 48, 285, 48, 19), self, Color("#9A2A2A"), Color.WHITE, 11)
	_force_desc = _rich(Rect2(FORCE_X + 6, 306, FORCE_W - 16, 58), self, 10)
	_force_desc.get_v_scroll_bar().modulate.a = 0.0      # 描述字數少，不顯示捲軸（太長時仍可滾輪捲動）
	_force_effects = _rich(Rect2(FORCE_X, 394, FORCE_W, 62), self, 12)
	_btn_switch_force = _art_button(Rect2(231, 459, 147, 38), "change_inner_normal", "change_inner_hover", "change_inner_pressed", "change_inner_disabled")
	_btn_switch_force.pressed.connect(_open_force_picker)
	# 內功屬性只顯示目前這門的那一個圖章（快／遲／柔／剛），不一次排四個
	_force_element_holder = Control.new()
	_force_element_holder.position = Vector2(281, 533)
	_force_element_holder.size = Vector2(48, 48)
	_force_element_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_force_element_holder)

## 用底圖（整頁圖）上的一塊貼圖：src 是底圖的邏輯座標矩形（會換算成 2 倍像素）
func _baked_region(src: Rect2) -> AtlasTexture:
	var base := mart("martial_page_v3")
	var at := AtlasTexture.new()
	at.atlas = base
	at.region = Rect2(src.position * 2.0, src.size * 2.0)
	return at

## 蓋掉底圖上的一塊：用同一面板內的空白紙面（src）貼在 dest 上
func _cover_baked(dest: Rect2, src: Rect2) -> void:
	var r := TextureRect.new()
	r.texture = _baked_region(src)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = dest.position
	r.size = dest.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

## 把底圖上的一塊（原像素矩形，2 倍像素）剪下來貼到新位置
func _baked_piece(src_px: Rect2, pos: Vector2, size_: Vector2) -> void:
	var at := AtlasTexture.new()
	at.atlas = mart("martial_page_v3")
	at.region = src_px
	var r := TextureRect.new()
	r.texture = at
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.position = pos
	r.size = size_
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

## 外功面板：標題「外功武術」「招式詳情」烤在底圖上
func _build_outer_panel() -> void:
	# 底圖上烤的「招式詳情」小標題改成按鈕：先用同面板的空白紙面蓋掉（要在列表之前建，列表才會壓在上面）
	_cover_baked(Rect2(840, 472, 192, 34), Rect2(840, 548, 192, 34))
	_cat_row = Control.new()
	_cat_row.position = Vector2(OUTER_X, 148)
	_cat_row.size = Vector2(CAT_W, 28)
	add_child(_cat_row)
	var list_scroll := ScrollContainer.new()
	list_scroll.position = Vector2(OUTER_X, 182)
	list_scroll.size = Vector2(CAT_W + 2, 346)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(list_scroll)
	_skill_rows = VBoxContainer.new()
	_skill_rows.add_theme_constant_override("separation", 2)
	_skill_rows.custom_minimum_size = Vector2(ROW_SIZE.x, 0)
	list_scroll.add_child(_skill_rows)
	# 「招式詳情」按鈕：按下才彈出視窗，列出選中招式的類型、消耗、目標與效果
	_btn_detail = _art_button(Rect2(OUTER_X + 43, 548, 147, 38), "change_inner_normal", "change_inner_hover", "change_inner_pressed", "change_inner_disabled", "招式詳情")
	_btn_detail.pressed.connect(_open_skill_detail)

func _build_synergy() -> void:
	var box := Control.new()
	box.name = "Synergy"
	box.position = SYN_RECT.position
	box.size = SYN_RECT.size
	box.z_index = 3
	add_child(box)
	_m_image("combination_frame", SYN_FRAME.position, SYN_FRAME.size, self).z_index = 2      # 疊在人物前面
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
	_syn_text = _rich(Rect2(16, 106, 310, 58), box, 12)

## 讀進素材的按鈕（四態）：一般／移入／按下／停用，字由程式放
func _art_button(rect: Rect2, normal: String, hover: String, pressed: String, disabled: String, label := "更換內功") -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.text = label
	var arts := {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled}
	for st in arts.keys():
		var sb := StyleBoxTexture.new()
		sb.texture = mart(String(arts[st]))
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 4)
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
		_force_icon(force, Vector2.ZERO, 136, true, _force_icon_holder)      # 內功心法象徵圖：有 force_<id>.png 就用，沒有用打坐人像（不是屬性）
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
		b.add_theme_color_override("font_outline_color", Color.BLACK)
		b.add_theme_constant_override("outline_size", 4)
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
		_skill_icon(s, 28, row, Vector2(19, 9))
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
	_btn_detail.disabled = selected_skill.is_empty()

## 招式詳情視窗：按「招式詳情」才彈出
func _open_skill_detail() -> void:
	if selected_skill.is_empty():
		return
	_clear_overlay()
	_overlay.visible = true
	# 卷軸的裝飾：右上竹葉（x>76%、y<45%）、左下竹子（x<16%）、右下山水（x>45%、y>55%）。文字只放在左欄與中上方，避開這三塊
	var pos := Vector2(186, 104)
	var size := Vector2(780, 440)
	_paper_dialog(pos, size)
	_skill_icon(selected_skill, 72, _overlay, pos + Vector2(124, 46))
	_label(String(selected_skill.get("name", "???")), pos + Vector2(124, 126), Vector2(220, 34), 26, INK, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	_label("%s・%s" % [String(selected_skill.get("weapon_type", "")), String(selected_skill.get("category", ""))], pos + Vector2(124, 160), Vector2(220, 22), 14, PAPER_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	var usable: bool = menu._can_use_skill_now(selected_skill, actor_id) if menu != null else true
	_chip("可施展" if usable else "不可施展", Rect2(pos.x + 124, pos.y + 190, 76, 24), _overlay, Color("#2F6B3A") if usable else Color("#7A7468"), Color.WHITE, 13)
	var mp := int(selected_skill.get("mp_cost", 0))
	var rows := [["消耗", ("內力 %d" % mp) if mp > 0 else "無"], ["目標", MartialInfoScript.target_text(selected_skill)]]
	for i in rows.size():
		var y := pos.y + 232.0 + i * 30.0
		_chip(rows[i][0], Rect2(pos.x + 124, y, 48, 24), _overlay, Color(0.30, 0.24, 0.16), CREAM, 13)
		_label(String(rows[i][1]), Vector2(pos.x + 180, y), Vector2(160, 24), 15, INK, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	var body := RichTextLabel.new()
	body.position = pos + Vector2(360, 62)
	body.size = Vector2(230, 190)
	body.bbcode_enabled = true
	body.add_theme_font_override("normal_font", FONT)
	body.add_theme_font_size_override("normal_font_size", 14)
	_outline_rich(body)
	var effects: Array = MartialInfoScript.effect_lines(selected_skill)
	var desc := String(selected_skill.get("description", selected_skill.get("desc", ""))).strip_edges()
	body.text = "%s[color=#7A4A12]效果[/color]\n%s" % [(desc + "\n\n") if desc != "" else "", "\n".join(effects.map(func(l): return "• " + String(l)))]
	_overlay.add_child(body)
	var close := _tex_button(Vector2(160, 40), pos + Vector2(150, size.y - 70), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	close.text = "關閉"
	close.pressed.connect(_close_overlay)

func _refresh_synergy() -> void:
	_clear(_syn_left)
	_clear(_syn_right)
	var force := _current_force()
	if force.is_empty():
		_glyph_icon("—", 36, _syn_left, Vector2(47, 2))
		_label("尚未修習", Vector2(0, 44), Vector2(130, 18), 13, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, _syn_left)
	else:
		_force_icon(force, Vector2(45, 0), 40, false, _syn_left)
		_label("%s（%s）" % [MartialInfoScript.force_name(force), String(force.get("element", ""))], Vector2(0, 44), Vector2(130, 18), 13, INK, HORIZONTAL_ALIGNMENT_CENTER, _syn_left)
	if selected_skill.is_empty():
		_glyph_icon("？", 36, _syn_right, Vector2(47, 2))
		_label("請選擇外功", Vector2(0, 44), Vector2(130, 18), 13, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, _syn_right)
		_syn_text.text = "在右邊的外功清單選一招，這裡會顯示目前的內功對它的影響。"
		return
	var wt := String(selected_skill.get("weapon_type", "")).strip_edges()
	_skill_icon(selected_skill, 40, _syn_right, Vector2(45, 0))
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
	var pos := Vector2(126, 84)
	var size := Vector2(900, 480)
	_paper_dialog(pos, size)
	_label("更換內功", pos + Vector2(140, 44), Vector2(300, 30), 22, PAPER_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	# 五個篩選標籤：全部｜快｜遲｜柔｜剛
	var tabs: Array = ["全部"] + Array(MartialInfoScript.ELEMENTS)
	for i in tabs.size():
		var t: String = tabs[i]
		var on: bool = t == _pick_element
		var b := _tex_button(Vector2(62, 30), pos + Vector2(140 + i * 66, 82), "btn_primary_normal" if on else "btn_normal", "btn_primary_hover" if on else "btn_hover", "btn_primary_pressed", "btn_disabled", 24, 12, _overlay)
		b.text = t
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_outline_color", Color.BLACK)
		b.add_theme_constant_override("outline_size", 4)
		b.pressed.connect(func():
			_pick_element = t
			var list := _forces_in(t)
			if not list.is_empty() and not list.any(func(f): return String(f.get("id", "")) == _pick_force_id):
				_pick_force_id = String(list[0].get("id", ""))
			_show_force_picker())
	var scroll := ScrollContainer.new()
	scroll.position = pos + Vector2(140, 124)
	scroll.size = Vector2(300, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(290, 0)
	scroll.add_child(rows)
	var cur_id := String(_current_force().get("id", ""))
	var list := _forces_in(_pick_element)
	if list.is_empty():
		var none := _label("這個分類還沒有學會的內功。", Vector2.ZERO, Vector2(290, 60), 15, INK, HORIZONTAL_ALIGNMENT_CENTER, rows)
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
		_force_icon(f, Vector2(6, 6), 36, false, row)
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
		_label(MartialInfoScript.force_name(chosen), pos + Vector2(515, 90), Vector2(185, 32), 24, INK, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
		_label("屬性：%s" % String(chosen.get("element", "")), pos + Vector2(515, 122), Vector2(185, 22), 14, PAPER_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
		var detail := RichTextLabel.new()
		detail.position = pos + Vector2(515, 148)
		detail.size = Vector2(190, 170)
		detail.bbcode_enabled = true
		detail.add_theme_font_override("normal_font", FONT)
		detail.add_theme_font_size_override("normal_font_size", 13)
		_outline_rich(detail)
		var eff: Array = MartialInfoScript.force_effect_lines(chosen, _actor_dict())
		detail.text = "%s\n\n[color=#7A4A12]效果[/color]\n%s" % [String(chosen.get("description", "")), "\n".join(eff.map(func(l): return "• " + String(l)))]
		_overlay.add_child(detail)
	var ok := _tex_button(Vector2(160, 40), pos + Vector2(150, size.y - 76), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, _overlay)
	ok.text = "更換"
	ok.disabled = chosen.is_empty() or _pick_force_id == cur_id
	var cancel := _tex_button(Vector2(160, 40), pos + Vector2(330, size.y - 76), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
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

## 武術頁專用前景（共邊國 martial_final_overlays）：左下、右下、右緣。圖已裁到內容邊界，依概念圖位置貼邊；全部不吃滑鼠
func _build_foreground_overlays() -> void:
	var defs := [
		["foreground_left", Vector2(0, 648), Vector2(365, 0), Vector2(0, 1)],        # 左下：寬 365，底貼畫布底、左貼畫布左
		["foreground_right", Vector2(1152, 648), Vector2(332, 0), Vector2(1, 1)],    # 右下：寬 332，右下角貼齊
		["foreground_edge_right", Vector2(1152, 0), Vector2(0, 561), Vector2(1, 0)], # 右緣：高 561，右上角貼齊
	]
	for d in defs:
		var tex := mart(String(d[0]))
		if tex == null:
			continue
		var tsize := tex.get_size()
		var size_: Vector2 = d[2]
		if size_.x == 0.0:
			size_.x = size_.y * tsize.x / tsize.y
		elif size_.y == 0.0:
			size_.y = size_.x * tsize.y / tsize.x
		var anchor: Vector2 = d[3]
		var r := _m_image(String(d[0]), Vector2(d[1]) - size_ * anchor, size_, self)
		r.z_index = 5

## 內功心法象徵圖：assets/UI/martial/force_<id>.png（共邊國之後逐門補），沒有就用共通的打坐人像
func _force_icon(force: Dictionary, pos: Vector2, size_: float, large: bool, parent: Node) -> TextureRect:
	var specific := "force_%s" % String(force.get("id", ""))
	var art := specific if mart(specific) != null else ("inner_liuchen_icon_large" if large else "inner_liuchen_icon")
	return _m_image(art, pos, Vector2(size_, size_), parent)

## 武術圖示：assets/UI/martial/skill_<id 去掉 skill_>.png（共邊國分批補），沒有就退回武器類別圖示
func _skill_icon(skill: Dictionary, size_: float, parent: Node, pos: Vector2) -> Control:
	var specific := "skill_%s" % String(skill.get("id", "")).trim_prefix("skill_")
	if mart(specific) != null:
		return _m_image(specific, pos, Vector2(size_, size_), parent)
	return _icon("weapon", String(skill.get("weapon_type", "")).strip_edges(), size_, parent, pos)

## 宣紙風格視窗底板：用專案現成的卷軸（scroll_body，與道具、裝備頁同一張）
func _paper_dialog(pos: Vector2, size_: Vector2) -> void:
	# 現成素材：道具頁、裝備頁同一張卷軸（scroll_body）攤開當視窗，整張縮放（兩端軸桿保留）
	var scroll := _image("scroll_body", pos, size_, _overlay)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## 本頁所有文字統一：白字＋黑色外框（與狀態頁、裝備頁一致），不被紙面底圖吃掉
func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, parent: Node = self) -> Label:
	var l := super(text, pos, size, font_size, color, align, parent)      # 保留原本的字色，只加黑色外框
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2 if font_size <= 16 else 3)
	return l

func _outline_rich(t: RichTextLabel) -> void:
	t.add_theme_color_override("default_color", INK)
	t.add_theme_color_override("font_outline_color", Color.BLACK)
	t.add_theme_constant_override("outline_size", 2)
