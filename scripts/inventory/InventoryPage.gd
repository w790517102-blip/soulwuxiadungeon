extends "res://scripts/inventory/StudyPageBase.gd"
class_name InventoryPage
# 道具頁（江湖行囊）：共邊國美術版。整頁用 assets/UI/inventory/ 的素材在 1152×648 邏輯畫面上組出來，
# 資料與動作全部沿用現有系統：背包 InventorySync、分類 ItemCategory、使用／裝備／讀書流程由系統選單（menu）的
# use_item_by_id() 完成。這個檔案只負責「畫面與操作」。
# 座標、尺寸一律是邏輯 px（素材為 2 倍，這裡縮成一半使用）。版面依據：docs/system_menu/道具頁_美術規格.md。

const CAT_ICON := {"all": "all", "consumable": "consumable", "book": "book", "equipment": "equipment", "material": "material", "quest": "quest", "other": "other"}

# ---- 版面（邏輯 px）----
const ROW_H := 48
const LIST_POS := Vector2(200, 176)
const LIST_SIZE := Vector2(393, 384)
const BUTTON_Y := 586

var category := ItemCategory.ALL
var selected_id := ""
var _entries: Array = []            # 目前清單：[{id, def}]
var _row_buttons: Array = []
var _cat_buttons: Dictionary = {}

var _list_box: VBoxContainer
var _list_scroll: ScrollContainer
var _gold_label: Label
var _art: TextureRect
var _art_bg: TextureRect
var _name_label: Label
var _seal_label: Label
var _info_vals: Array[Label] = []
var _status_stamp: TextureRect
var _rarity_holder: Control
var _status_label: Label
var _detail_box: VBoxContainer
var _detail_scroll: ScrollContainer
var _effect_text: RichTextLabel
var _cond_text: RichTextLabel
var _desc_text: RichTextLabel
var _quote_box: Control
var _quote_label: Label
var _btn_use: Button
var _btn_sort: Button
var _btn_drop: Button
var _btn_back: Button
var _pick_callback: Callable
var _confirm_action: Callable

# ------------------------------------------------------------------
# 建立畫面
# ------------------------------------------------------------------
func _ready() -> void:
	name = "InventoryPage"
	set_meta("skip_menu_skin", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 5
	_build_background()
	_build_nav("TabItem")
	_build_categories()
	_build_gold()
	_build_list()
	_build_detail()
	_build_buttons()
	_build_toast()
	_build_overlay()
	if InventorySync:
		InventorySync.inventory_changed.connect(_refresh)
		InventorySync.equipment_changed.connect(_refresh)
		InventorySync.gold_changed.connect(func(_g): _refresh_gold())
	_refresh()

func _build_categories() -> void:
	_panel("cat_panel", 20, 28, Vector2(24, 76), Vector2(131, 440))
	var y := 82.0
	for tab_def in ItemCategory.TABS:
		var id: String = tab_def["id"]
		var b := _tex_button(Vector2(131, 58), Vector2(24, y), "cat_item_normal", "cat_item_hover", "cat_item_selected", "cat_item_normal", 20, 14)
		b.name = "Cat_" + id
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("h_separation", 6)
		var glow := _image("cat_item_selected", Vector2.ZERO, Vector2(131, 58), b)
		glow.name = "SelectedGlow"
		glow.visible = false
		var icon := _image("cat_icon_" + String(CAT_ICON.get(id, "other")), Vector2(14, 11), Vector2(36, 36), b)
		icon.name = "Icon"
		var lab := _label(String(tab_def["label"]), Vector2(56, 0), Vector2(70, 58), 22, CREAM, HORIZONTAL_ALIGNMENT_LEFT, b)
		lab.name = "Label"
		b.pressed.connect(_on_category_pressed.bind(id))
		_cat_buttons[id] = b
		y += 58.0
	_sync_category_buttons()

func _sync_category_buttons() -> void:
	for id in _cat_buttons.keys():
		var b: Button = _cat_buttons[id]
		var on: bool = id == category
		b.set_pressed_no_signal(on)
		# V2：底永遠是一般底；選中時疊半透明發光層，圖示換成另外畫的金色版
		b.get_node("SelectedGlow").visible = on
		(b.get_node("Icon") as TextureRect).texture = _tex("cat_icon_%s%s" % [String(CAT_ICON.get(id, "other")), "_on" if on else ""])
		var lab := b.get_node("Label") as Label
		lab.add_theme_color_override("font_color", Color("#FFF3D0") if on else CREAM)

func _build_gold() -> void:
	_panel("gold_plate", 28, 12, Vector2(210, 95), Vector2(320, 32))
	_image("icon_gold", Vector2(218, 97), Vector2(28, 28))
	_gold_label = _label("", Vector2(252, 95), Vector2(270, 30), 19, Color.WHITE)
	_refresh_gold()

func _build_list() -> void:
	_panel("list_header", 16, 4, Vector2(200, 148), Vector2(393, 28))
	_label("名稱", Vector2(270, 148), Vector2(70, 28), 15, INK_DIM)
	_label("數量", Vector2(475, 148), Vector2(60, 28), 15, INK_DIM)
	_label("類別", Vector2(535, 148), Vector2(60, 28), 15, INK_DIM)
	_list_scroll = ScrollContainer.new()
	_list_scroll.position = LIST_POS
	_list_scroll.size = LIST_SIZE
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 0)
	_list_box.custom_minimum_size = Vector2(LIST_SIZE.x - 10, 0)
	_list_scroll.add_child(_list_box)
	# 捲動條：貼圖版軌道與滑塊
	var bar := _list_scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 8
	var track := _box("scroll_track", 2, 4)
	bar.add_theme_stylebox_override("scroll", track if track != null else StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("scroll_focus", track if track != null else StyleBoxEmpty.new())
	for pair in [["grabber", "scroll_thumb_normal"], ["grabber_highlight", "scroll_thumb_hover"], ["grabber_pressed", "scroll_thumb_drag"]]:
		var gb := _box(pair[1], 2, 4)
		bar.add_theme_stylebox_override(pair[0], gb if gb != null else StyleBoxEmpty.new())
	_panel("divider_v", 2, 4, Vector2(599, 148), Vector2(4, 424))

func _build_detail() -> void:
	_art_bg = _image("detail_art_bg_empty", Vector2(613, 162), Vector2(214, 300))
	_art = _image("item_art_16", Vector2(625, 172), Vector2(190, 280))
	_name_label = _label("", Vector2(844, 164), Vector2(150, 40), 26, INK, HORIZONTAL_ALIGNMENT_LEFT)
	var seal := _image("seal_type", Vector2(1000, 162), Vector2(30, 56))
	_seal_label = _label("", Vector2(1000, 162), Vector2(30, 56), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_seal_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_seal_label.add_theme_constant_override("line_spacing", -2)
	var info_titles := ["類別", "持有數量", "使用類型"]
	for i in 3:
		_image("label_ink_s", Vector2(844, 208 + 30 * i), Vector2(80, 26))
		_label(info_titles[i], Vector2(850, 208 + 30 * i), Vector2(74, 26), 14, Color.WHITE)
		var v := _label("", Vector2(932, 208 + 30 * i), Vector2(190, 26), 16, INK)
		_info_vals.append(v)
	_rarity_holder = Control.new()
	_rarity_holder.position = Vector2(844, 190)
	_rarity_holder.size = Vector2(60, 18)
	_rarity_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rarity_holder)
	_status_stamp = _image("status_usable", Vector2(932, 270), Vector2(56, 22))
	_status_label = _label("", Vector2(929, 268), Vector2(56, 22), 12, Color("#F6EEDC"), HORIZONTAL_ALIGNMENT_CENTER)
	_info_vals[2].visible = false
	# 說明區（可捲動）：效果／使用條件／物品敘述／引用句
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.position = Vector2(844, 302)
	_detail_scroll.size = Vector2(282, 268)
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 4)
	_detail_box.custom_minimum_size = Vector2(272, 0)
	_detail_scroll.add_child(_detail_box)
	_effect_text = _section("效果")
	_cond_text = _section("使用條件")
	_desc_text = _section("物品敘述")
	_quote_box = Control.new()
	_quote_box.custom_minimum_size = Vector2(270, 56)
	_detail_box.add_child(_quote_box)
	var qp := Panel.new()
	qp.size = Vector2(270, 56)
	var qb := _box("quote_box", 20, 12)
	qp.add_theme_stylebox_override("panel", qb if qb != null else StyleBoxEmpty.new())
	_quote_box.add_child(qp)
	_quote_label = _label("", Vector2(14, 4), Vector2(236, 48), 13, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, _quote_box)
	_quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote_box.visible = false

func _section(title: String) -> RichTextLabel:
	var head := Control.new()
	head.custom_minimum_size = Vector2(100, 26)
	_detail_box.add_child(head)
	_image("label_ink_m", Vector2.ZERO, Vector2(100, 26), head)
	_label(title, Vector2(8, 0), Vector2(92, 26), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, head)
	var t := RichTextLabel.new()
	t.fit_content = true
	t.bbcode_enabled = true
	t.scroll_active = false
	t.custom_minimum_size = Vector2(270, 0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_override("normal_font", FONT)
	t.add_theme_font_size_override("normal_font_size", 14)
	t.add_theme_color_override("default_color", INK)
	_detail_box.add_child(t)
	return t

func _build_buttons() -> void:
	var xs := [300, 486, 661, 847]
	var labels := ["使用", "整理", "丟棄", "返回"]
	var made: Array[Button] = []
	for i in 4:
		var primary := i == 0
		var b := _tex_button(Vector2(165, 38), Vector2(xs[i], BUTTON_Y),
			"btn_primary_normal" if primary else "btn_normal", "btn_primary_hover" if primary else "btn_hover",
			"btn_primary_pressed" if primary else "btn_pressed", "btn_primary_disabled" if primary else "btn_disabled", 48, 16)
		b.text = labels[i]
		made.append(b)
	_btn_use = made[0]; _btn_sort = made[1]; _btn_drop = made[2]; _btn_back = made[3]
	_btn_use.pressed.connect(_on_use_pressed)
	_btn_sort.pressed.connect(_on_sort_pressed)
	_btn_drop.pressed.connect(_on_drop_pressed)
	_btn_back.pressed.connect(func(): close_requested.emit())

# ------------------------------------------------------------------
# 資料與重新整理
# ------------------------------------------------------------------
func _refresh_gold() -> void:
	if _gold_label == null:
		return
	var gold := 0
	if InventorySync and InventorySync.has_method("get_gold"):
		gold = int(InventorySync.get_gold())
	elif InventorySync:
		gold = int(InventorySync.get("gold") if InventorySync.get("gold") != null else 0)
	_gold_label.text = "盤纏：%d文" % gold

func _item_def(id: String) -> Dictionary:
	return InventorySync.get_item_by_id(id)

func _equipped_by(item_id: String) -> String:
	# 被任何隊員裝備中就回傳那位的 id；沒有回傳 ""。候選：已解鎖的角色（和系統選單的裝備流程用同一份名單）
	if TeamData == null or item_id == "":
		return ""
	var ids: Array = []
	if TeamData.has_method("get_roster_unlocked_actor_ids"):
		ids = TeamData.get_roster_unlocked_actor_ids()
	if not ids.has("liuyu"):
		ids.append("liuyu")
	for actor_id in ids:
		if InventorySync.is_equipped(item_id, String(actor_id)):
			return String(actor_id)
	return ""

func _refresh() -> void:
	_refresh_gold()
	_entries.clear()
	for item in InventorySync.get_items():
		if ItemCategory.matches(item, category):
			_entries.append(item)
	# 目前選中的道具還在清單裡就保留，否則選第一個
	var found := false
	for e in _entries:
		if String(e.get("id", "")) == selected_id:
			found = true
	if not found:
		selected_id = String(_entries[0].get("id", "")) if not _entries.is_empty() else ""
	_rebuild_rows()
	_refresh_detail()
	_sync_category_buttons()

func _rebuild_rows() -> void:
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	_row_buttons.clear()
	if _entries.is_empty():
		var empty := Label.new()
		empty.text = ItemCategory.empty_text(category)
		empty.custom_minimum_size = Vector2(LIST_SIZE.x - 10, 60)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_override("font", FONT)
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", INK_DIM)
		_list_box.add_child(empty)
		return
	for e in _entries:
		var id := String(e.get("id", ""))
		var sel := id == selected_id
		var b := Button.new()
		b.custom_minimum_size = Vector2(LIST_SIZE.x - 10, ROW_H)
		b.focus_mode = Control.FOCUS_NONE
		b.flat = false
		b.set_meta("item_id", id)
		# 所有狀態都用一般列底（紙面始終在）；選中與移入是「疊在上面的半透明金色光暈」，不會整塊換成不透明底
		var normal := _box("row_normal", 16, 4)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", normal)
		b.add_theme_stylebox_override("pressed", normal)
		# 疊在一般底上的兩層：程式畫的柔和金色光暈（夠亮）＋ V2 素材（乾筆紋理、細金線、菱形；本身偏淡，疊上去增加質感）
		var glow := _row_glow(Vector2(LIST_SIZE.x - 10, ROW_H))
		var tex_glow := _image("row_selected" if sel else "row_hover", Vector2.ZERO, Vector2(LIST_SIZE.x - 10, ROW_H), glow)
		tex_glow.name = "TexGlow"
		glow.modulate.a = 1.0 if sel else 0.0
		glow.get_node("Diamond").visible = sel
		b.add_child(glow)
		if not sel:
			b.mouse_entered.connect(func(): glow.modulate.a = 0.5)
			b.mouse_exited.connect(func(): glow.modulate.a = 0.0)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var def := e as Dictionary
		var icon := _image_from(ItemIconMap.icon_path(id, def), Vector2(8, 4), Vector2(40, 40), b)
		_label(String(def.get("name", id)), Vector2(56, 0), Vector2(150, ROW_H), 17, INK, HORIZONTAL_ALIGNMENT_LEFT, b)
		_label("× %d" % int(def.get("quantity", def.get("count", 0))), Vector2(270, 0), Vector2(70, ROW_H), 16, Color("#7A1C1C"), HORIZONTAL_ALIGNMENT_LEFT, b)
		var cat_id := ItemCategory.category_of(def)
		var badge_tex := _tex("badge_" + cat_id)
		if badge_tex != null:
			var br := _image("badge_" + cat_id, Vector2(316, 13), Vector2(62, 22), b)
			_label(ItemCategory.label_of(cat_id), Vector2(316, 13), Vector2(62, 22), 12, Color("#F6EEDC"), HORIZONTAL_ALIGNMENT_CENTER, b)
		var rar := ItemRarity.rarity_of(def)
		if rar >= 2:
			_rarity_chip(rar, Vector2(206, 14), Vector2(56, 20), b)
		if _equipped_by(id) != "":
			_image("badge_equipped", Vector2(108, 14), Vector2(44, 22), b)
			_label("裝備中", Vector2(108, 14), Vector2(44, 22), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, b)
		b.pressed.connect(_on_row_pressed.bind(id))
		_list_box.add_child(b)
		_row_buttons.append(b)

## 列的金色光暈（程式畫的）：中間淡金、左右漸隱成全透明，上下各一條細金線；選中時左端有一顆菱形標記。
## 共邊國交付半透明光暈素材（row_selected 改版）之後，換成素材即可。
var _glow_tex: GradientTexture2D = null
func _row_glow(size: Vector2) -> Control:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.10, 0.5, 0.90, 1.0])
		g.colors = PackedColorArray([Color(0.93, 0.74, 0.30, 0.0), Color(0.93, 0.74, 0.30, 0.42), Color(0.95, 0.80, 0.40, 0.55), Color(0.93, 0.74, 0.30, 0.42), Color(0.93, 0.74, 0.30, 0.0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill_from = Vector2(0, 0)
		_glow_tex.fill_to = Vector2(1, 0)
		_glow_tex.width = 256
		_glow_tex.height = 4
	var root := Control.new()
	root.name = "Glow"
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := TextureRect.new()
	fill.texture = _glow_tex
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.size = size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	for y in [0.0, size.y - 1.0]:
		var line := TextureRect.new()
		line.texture = _glow_tex
		line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		line.stretch_mode = TextureRect.STRETCH_SCALE
		line.position = Vector2(0, y)
		line.size = Vector2(size.x, 1)
		line.modulate = Color(1, 0.9, 0.55, 1.4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(line)
	var d := Polygon2D.new()
	d.name = "Diamond"
	d.position = Vector2(8, size.y * 0.5)
	d.polygon = PackedVector2Array([Vector2(0, -7), Vector2(7, 0), Vector2(0, 7), Vector2(-7, 0)])
	d.color = Color(0.93, 0.74, 0.30, 1)
	root.add_child(d)
	var ring := Line2D.new()
	ring.points = PackedVector2Array([Vector2(0, -7), Vector2(7, 0), Vector2(0, 7), Vector2(-7, 0), Vector2(0, -7)])
	ring.width = 1.5
	ring.default_color = Color(0.35, 0.22, 0.05, 0.9)
	d.add_child(ring)
	return root

func _set_detail_rarity(level: int) -> void:
	for c in _rarity_holder.get_children():
		_rarity_holder.remove_child(c)
		c.queue_free()
	_rarity_chip(level, Vector2.ZERO, Vector2(56, 20), _rarity_holder)

func _use_type(def: Dictionary) -> String:
	var action := String(def.get("use_action", "none"))
	var scope := String(def.get("use_scope", "none"))
	if action == "consume" and (scope == "any" or scope == "world"):
		return "usable"
	if action == "equip" and (scope == "any" or scope == "world"):
		return "usable"
	if action == "consume" and scope == "battle":
		return "battle"
	return "disabled"

func _refresh_detail() -> void:
	var def: Dictionary = _item_def(selected_id) if selected_id != "" else {}
	if def.is_empty():
		_art_bg.texture = _tex("detail_art_bg_empty")
		_art.texture = null
		_name_label.text = ""
		_seal_label.text = ""
		for c in _rarity_holder.get_children():
			_rarity_holder.remove_child(c)
			c.queue_free()
		for v in _info_vals:
			v.text = ""
		_status_stamp.visible = false
		_status_label.text = ""
		_effect_text.text = ""
		_cond_text.text = ""
		_desc_text.text = "請選擇道具。" if not _entries.is_empty() else ItemCategory.empty_text(category)
		_quote_box.visible = false
		_update_buttons({})
		return
	_art_bg.texture = _tex("detail_art_bg")
	var art_path := ItemIconMap.art_path(selected_id, def)
	_art.texture = load(art_path) as Texture2D if ResourceLoader.exists(art_path) else null
	_name_label.text = String(def.get("name", selected_id))
	_set_detail_rarity(ItemRarity.rarity_of(def))
	# 稀有度章貼在名稱右邊（名稱字數不同，位置跟著文字寬度）
	_rarity_holder.position = Vector2(844.0 + minf(_name_label.get_minimum_size().x, 150.0) + 8.0, 174.0)
	var cat_id := ItemCategory.category_of(def)
	var cat_label := ItemCategory.label_of(cat_id)
	_seal_label.text = "\n".join(Array(cat_label.split()))
	_info_vals[0].text = cat_label
	_info_vals[1].text = str(int(def.get("quantity", def.get("count", 0))))
	var use_type := _use_type(def)
	_info_vals[2].visible = false
	_status_stamp.visible = true
	_status_stamp.texture = _tex("status_usable" if use_type == "usable" else ("status_battle" if use_type == "battle" else "status_disabled"))
	_status_label.text = "可用" if use_type == "usable" else ("戰鬥限定" if use_type == "battle" else "不可用")
	_effect_text.text = ItemDB.get_effect_display_text(def)
	var cond := String(def.get("use_condition", "")).strip_edges()
	_cond_text.text = cond if cond != "" else "無特殊限制。"
	_desc_text.text = String(def.get("desc", def.get("description", "")))
	var quote := String(def.get("quote", "")).strip_edges()
	_quote_box.visible = quote != ""
	_quote_label.text = quote
	_detail_scroll.scroll_vertical = 0
	_update_buttons(def)

func _can_discard(def: Dictionary) -> bool:
	if def.is_empty():
		return false
	# 可出售的才能丟（can_sell 沒寫 = 可出售）；任務道具、書籍等 can_sell=false 的一律不能丟；裝備中的要先卸下
	if def.has("can_sell") and not bool(def.get("can_sell")):
		return false
	return _equipped_by(String(def.get("id", selected_id))) == ""

func _update_buttons(def: Dictionary) -> void:
	if def.is_empty():
		_btn_use.disabled = true
		_btn_use.text = "不可使用"
		_btn_drop.disabled = true
		_btn_sort.disabled = false
		return
	var action := String(def.get("use_action", "none"))
	var scope := String(def.get("use_scope", "none"))
	_btn_use.disabled = false
	if action == "consume" and (scope == "any" or scope == "world"):
		_btn_use.text = "使用"
	elif action == "consume" and scope == "battle":
		_btn_use.disabled = true
		_btn_use.text = "戰鬥限定"
	elif action == "equip" and (scope == "any" or scope == "world"):
		_btn_use.text = "裝備"
	else:
		_btn_use.disabled = true
		_btn_use.text = "不可使用"
	_btn_drop.disabled = not _can_discard(def)
	_btn_sort.disabled = false

# ------------------------------------------------------------------
# 操作
# ------------------------------------------------------------------
func _on_category_pressed(id: String) -> void:
	if id == category:
		_sync_category_buttons()
		return
	category = id
	_list_scroll.scroll_vertical = 0
	_refresh()

func _on_row_pressed(id: String) -> void:
	selected_id = id
	_rebuild_rows()
	_refresh_detail()

func _on_use_pressed() -> void:
	var def := _item_def(selected_id)
	if def.is_empty():
		return
	if menu != null and menu.has_method("use_item_by_id"):
		await menu.use_item_by_id(selected_id)
		_refresh()

func _on_sort_pressed() -> void:
	InventorySync.sort_inventory_by_id()
	show_toast("已整理")

func _on_drop_pressed() -> void:
	var def := _item_def(selected_id)
	if not _can_discard(def):
		show_toast("這個道具不能丟棄")
		return
	var n := int(def.get("quantity", def.get("count", 1)))
	_show_confirm("丟棄道具", "確定要丟棄「%s」嗎？\n丟棄後無法找回。%s" % [String(def.get("name", selected_id)), ("\n（目前持有 %d 個，將丟棄 1 個）" % n) if n > 1 else ""], "確認丟棄", func():
		InventorySync.consume_item(selected_id, 1, false)
		show_toast("已丟棄"))

## 系統選單呼叫：entries = [{id, name}]；選定後呼叫 done.call(actor_id)
func pick_target(entries: Array, done: Callable) -> void:
	_pick_callback = done
	_clear_overlay()
	_overlay.visible = true
	var panel_pos := Vector2(336, 194)
	_panel("pick_panel", 28, 24, panel_pos, Vector2(480, 260), _overlay)
	_label("請選擇對象", panel_pos + Vector2(0, 22), Vector2(480, 30), 20, CREAM, HORIZONTAL_ALIGNMENT_CENTER, _overlay)
	var n := mini(entries.size(), 3)
	var total_w := n * 140 + (n - 1) * 10
	var x0 := panel_pos.x + (480 - total_w) / 2.0
	for i in n:
		var e: Dictionary = entries[i]
		var card := _tex_button(Vector2(140, 160), Vector2(x0 + i * 150, panel_pos.y + 56), "pick_card_normal", "pick_card_hover", "pick_card_selected", "pick_card_disabled", 24, 24, _overlay)
		var id := String(e.get("id", ""))
		var actor = TeamData.get_character_by_id(id) if TeamData and TeamData.has_method("get_character_by_id") else {}
		var portrait_path := String(actor.get("portrait_path", ""))
		if portrait_path != "" and ResourceLoader.exists(portrait_path):
			var pr := _image_from(portrait_path, Vector2(22, 12), Vector2(96, 96), card)
			pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_label(String(e.get("name", id)), Vector2(0, 108), Vector2(140, 20), 15, CREAM, HORIZONTAL_ALIGNMENT_CENTER, card)
		_label("Lv.%d" % int(actor.get("level", 1)), Vector2(0, 126), Vector2(140, 16), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER, card)
		_bar(card, Vector2(16, 143), "hp", float(actor.get("hp", 0)), float(maxi(1, int(actor.get("max_hp", 1)))))
		card.pressed.connect(_on_pick.bind(id))
	var cancel := _tex_button(Vector2(120, 30), Vector2(panel_pos.x + 180, panel_pos.y + 222), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	cancel.text = "取消"
	cancel.add_theme_font_size_override("font_size", 16)
	cancel.pressed.connect(_close_overlay)

func _on_pick(actor_id: String) -> void:
	var cb := _pick_callback
	_close_overlay()
	if cb.is_valid():
		await cb.call(actor_id)
	_refresh()

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

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _overlay.visible:
			_close_overlay()
		else:
			close_requested.emit()

## 道具頁固定用前景方案 1（照老闆的 DEMO：書、劍、茶壺、燈籠）
func _foreground_preset() -> String:
	return "demo"
