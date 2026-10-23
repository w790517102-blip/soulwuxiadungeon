extends "res://scripts/inventory/StudyPageBase.gd"
# 裝備頁：共邊國美術版（書房桌面＋卷軸）。三區：左＝同行俠客（切換角色）、中＝人物與八個裝備欄、右＝選中裝備的詳情與數值。
# 資料與動作沿用現有系統：裝備資料 InventorySync、武器限制與鎖定欄由系統選單（menu）提供，數值用 EquipmentInfo
# （與狀態頁同一套公式）。座標一律是邏輯 px（1152×648）。版面說明：docs/system_menu/裝備頁_盤點與規格草案.md。

const EquipmentInfoScript = preload("res://scripts/inventory/EquipmentInfo.gd")

# ---- 版面（邏輯 px；共邊國骨架包的位置：assets/UI/equipment/ 的 asset_manifest）----
const BUTTON_Y := 586
const SLOT_SIZE := Vector2(100, 96)
const SLOT_X := [331.0, 654.0]          # 左欄、右欄
const SLOT_Y0 := 132.0
const SLOT_GAP := 10.0
const FIGURE_RECT := Rect2(421, 92, 254, 486)
const DETAIL_X := 790.0                  # 右頁（770 起）內容的左緣：往右縮進，內容在頁面上更置中
const DETAIL_W := 296.0
const STAT_Y := 332.0
const STAT_ROW_H := 28.0

const GOOD := Color("#2F6B3A")
const BAD := Color("#9A2A2A")

var slot := "weapon_1"

var _slot_buttons: Dictionary = {}
var _figure: TextureRect
var _doll: Control
var doll_info: Dictionary = {}
var _art_bg: TextureRect
var _art: TextureRect
var _name_label: Label
var _rarity_holder: Control
var _info_vals: Array[Label] = []
var _stat_cells: Array = []              # 每格：{holder, label, before, arrow, after, delta}
var _stat_holder: Control
var _scroll: ScrollContainer
var _scroll_box: VBoxContainer
var _desc_title: Control
var _desc_text: RichTextLabel
var _effect_text: RichTextLabel
var _btn_change: Button
var _btn_unequip: Button
var _btn_back: Button
var _pick_candidates: Array = []
var _pick_selected := ""
var _pick_rows: Control
var _pick_compare: Control

# ------------------------------------------------------------------
# 建立畫面
# ------------------------------------------------------------------
func _ready() -> void:
	name = "EquipmentPage"
	set_meta("skip_menu_skin", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 5
	_build_background(false)
	_build_pages()
	_build_nav("TabEquip")
	_build_roster()
	_build_slots()
	_build_figure()
	_build_detail()
	_build_buttons()
	_build_toast()
	_build_overlay()
	if InventorySync:
		InventorySync.inventory_changed.connect(_refresh)
		InventorySync.equipment_changed.connect(_refresh)
	_refresh()

## 共邊國 V2：一整張攤開的大卷軸（左：深色底，中、右：兩頁宣紙，兩端軸頭），整頁只畫這一張，三個區塊都放在它上面
func _build_pages() -> void:
	_image(E + "equip_scroll_complete", Vector2(0, 0), Vector2(1152, 648.5))

func _build_roster() -> void:
	build_roster_panel(true)

func _build_slots() -> void:
	var all_slots: Array = []
	for i in 4:
		all_slots.append([EquipmentInfoScript.LEFT_SLOTS[i], SLOT_X[0], SLOT_Y0 + i * (SLOT_SIZE.y + SLOT_GAP)])
		all_slots.append([EquipmentInfoScript.RIGHT_SLOTS[i], SLOT_X[1], SLOT_Y0 + i * (SLOT_SIZE.y + SLOT_GAP)])
	for entry: Array in all_slots:
		var slot_id: String = entry[0]
		var b := make_slot_tile(slot_id, SLOT_SIZE, self)
		b.position = Vector2(entry[1], entry[2])
		b.pressed.connect(_on_slot_pressed.bind(slot_id))      # 單擊：只選中，右頁顯示這件裝備的詳情
		b.gui_input.connect(_on_slot_gui_input.bind(slot_id))
		_slot_buttons[slot_id] = b

func _build_figure() -> void:
	# 人物（紙娃娃）：EquipmentDoll 把母圖與各部位圖層疊在同一張畫布上；沒有母圖的角色退回頭像
	_doll = EquipmentDollScript.new()
	_doll.name = "PaperDoll"
	_doll.position = FIGURE_RECT.position
	_doll.size = FIGURE_RECT.size
	add_child(_doll)
	_figure = TextureRect.new()
	_figure.name = "PortraitFallback"
	_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_figure.position = FIGURE_RECT.position + Vector2(0, 60)
	_figure.size = Vector2(FIGURE_RECT.size.x, 250)
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_figure)

func _build_detail() -> void:
	# 版面：右頁左右平分——左半是大圖（概念圖的裝備圖案很大），右半是名稱與資訊
	_art_bg = _image("detail_art_bg", Vector2(DETAIL_X, 96), Vector2(140, 196))
	_art = _image_from("", Vector2(DETAIL_X + 6, 102), Vector2(128, 184), self)
	InkGlowScript.attach(_art)
	_name_label = _label("", Vector2(DETAIL_X + 150, 96), Vector2(146, 40), 22, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_outlined(_name_label)
	_rarity_holder = Control.new()
	_rarity_holder.position = Vector2(DETAIL_X + 150, 138)
	_rarity_holder.size = Vector2(60, 18)
	_rarity_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rarity_holder)
	var titles := ["品類", "欄位", "裝備者"]
	for i in 3:
		var y := 170.0 + 28.0 * i
		_image("label_ink_s", Vector2(DETAIL_X + 150, y), Vector2(66, 24))
		_label(titles[i], Vector2(DETAIL_X + 155, y), Vector2(52, 24), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_info_vals.append(_outlined(_label("", Vector2(DETAIL_X + 222, y), Vector2(74, 24), 14, INK)))
	# 裝備效果：這件裝備自己的加成，一行 2 格
	_image("label_ink_m", Vector2(DETAIL_X, 298), Vector2(100, 26))
	_label("裝備效果", Vector2(DETAIL_X + 7, 298), Vector2(80, 26), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_stat_holder = Control.new()
	_stat_holder.position = Vector2(DETAIL_X, STAT_Y)
	_stat_holder.size = Vector2(DETAIL_W, STAT_ROW_H * 4)
	_stat_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stat_holder)
	# 說明與特殊效果：可捲動；內容超過高度時才出現細捲軸（貼圖版），也可用滑鼠滾輪
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(DETAIL_X, STAT_Y + STAT_ROW_H + 8.0)
	_scroll.size = Vector2(DETAIL_W, 200)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)
	_scroll_box = VBoxContainer.new()
	_scroll_box.add_theme_constant_override("separation", 4)
	_scroll_box.custom_minimum_size = Vector2(DETAIL_W - 12, 0)
	_scroll.add_child(_scroll_box)
	var bar := _scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 8
	var track := _box("scroll_track", 2, 4)
	bar.add_theme_stylebox_override("scroll", track if track != null else StyleBoxEmpty.new())
	for pair in [["grabber", "scroll_thumb_normal"], ["grabber_highlight", "scroll_thumb_hover"], ["grabber_pressed", "scroll_thumb_drag"]]:
		var gb := _box(pair[1], 2, 4)
		bar.add_theme_stylebox_override(pair[0], gb if gb != null else StyleBoxEmpty.new())
	_desc_text = _section("說明")
	_effect_text = _section("特殊效果")

func _section(title: String) -> RichTextLabel:
	var head := Control.new()
	head.custom_minimum_size = Vector2(100, 26)
	_scroll_box.add_child(head)
	_image("label_ink_m", Vector2.ZERO, Vector2(100, 26), head)
	_label(title, Vector2(7, 0), Vector2(80, 26), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, head)
	var t := RichTextLabel.new()
	t.fit_content = true
	t.bbcode_enabled = true
	t.scroll_active = false
	t.custom_minimum_size = Vector2(DETAIL_W - 24, 0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_override("normal_font", FONT)
	t.add_theme_font_size_override("normal_font_size", 15)
	t.add_theme_color_override("default_color", Color.WHITE)
	t.add_theme_color_override("font_outline_color", Color.BLACK)
	t.add_theme_constant_override("outline_size", 4)
	_scroll_box.add_child(t)
	return t

func _build_buttons() -> void:
	var xs := [308, 494, 680]
	var labels := ["更換裝備", "卸下", "返回"]
	var made: Array[Button] = []
	for i in 3:
		var primary := i == 0
		var b := _tex_button(Vector2(165, 38), Vector2(xs[i], BUTTON_Y),
			"btn_primary_normal" if primary else "btn_normal", "btn_primary_hover" if primary else "btn_hover",
			"btn_primary_pressed" if primary else "btn_pressed", "btn_primary_disabled" if primary else "btn_disabled", 48, 16)
		b.text = labels[i]
		made.append(b)
	_btn_change = made[0]; _btn_unequip = made[1]; _btn_back = made[2]
	_btn_change.pressed.connect(_on_change_pressed)
	_btn_unequip.pressed.connect(_on_unequip_pressed)
	_btn_back.pressed.connect(func(): close_requested.emit())

# ------------------------------------------------------------------
# 資料
# ------------------------------------------------------------------
func _actor_ids() -> Array:
	return menu._get_all_character_ids() if menu != null else ["liuyu"]

func _equipped_item_id() -> String:
	return String(InventorySync.get_equipped(actor_id).get(slot, ""))

func _is_locked(slot_id: String) -> bool:
	return menu != null and menu.is_slot_locked_for(actor_id, slot_id)

func _refresh() -> void:
	var ids := _actor_ids()
	if ids.is_empty():
		return
	if actor_id == "" or not ids.has(actor_id):
		var remembered: String = menu._get_tab_actor("equipment") if menu != null else ""
		actor_id = remembered if ids.has(remembered) else String(ids[0])
	rebuild_roster(ids, actor_id, _on_actor_pressed)
	_refresh_slots()
	_refresh_figure()
	_refresh_detail()
	_refresh_buttons()

func _refresh_slots() -> void:
	var equipped: Dictionary = InventorySync.get_equipped(actor_id)
	for slot_id in _slot_buttons.keys():
		fill_slot_tile(_slot_buttons[slot_id], String(equipped.get(slot_id, "")), _is_locked(slot_id), slot_id == slot)

func _refresh_figure() -> void:
	var info: Dictionary = _doll.show_actor(actor_id)
	var has_master: bool = _doll.has_figure()
	_figure.visible = not has_master
	if not has_master:
		var path := String(_actor(actor_id).get("portrait_path", ""))
		_figure.texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	doll_info = info

func _refresh_detail() -> void:
	var a := _actor(actor_id)
	var item_id := _equipped_item_id()
	var def: Dictionary = ItemDB.get_def(item_id) if item_id != "" else {}
	var has_item := not def.is_empty()
	# 名稱、稀有度、品類、欄位、裝備者
	_name_label.text = String(def.get("name", item_id)) if has_item else "（未裝備）"
	for c in _rarity_holder.get_children():
		_rarity_holder.remove_child(c)
		c.queue_free()
	if has_item:
		_rarity_chip(ItemRarity.rarity_of(def), Vector2.ZERO, Vector2(56, 20), _rarity_holder)
		_rarity_holder.position = Vector2(DETAIL_X + 150, 138)
	var art_path := ItemIconMap.art_path(item_id, def) if has_item else ""
	_art.texture = load(art_path) as Texture2D if art_path != "" and ResourceLoader.exists(art_path) else null
	_info_vals[0].text = EquipmentInfoScript.category_label(def) if has_item else "—"
	_info_vals[1].text = EquipmentInfoScript.slot_label(slot)
	_info_vals[2].text = String(a.get("name", actor_id)) if has_item else "—"
	# 數值：只顯示這件裝備自己的加成（換裝後的變化量只在「更換裝備」的視窗裡出現）
	_fill_item_stats(def if has_item else {})
	# 說明與特殊效果
	_desc_text.text = String(def.get("desc", def.get("description", ""))) if has_item else ("這個欄位目前被固定，不能更換。" if _is_locked(slot) else "這個欄位目前沒有裝備。按「更換裝備」挑選。")
	_effect_text.text = EquipmentInfoScript.special_effect_text(def) if has_item else "—"
	_scroll.scroll_vertical = 0

## 這件裝備自己的數值加成：只列有的，一行 3 格；說明區依數值佔的高度往下讓出空間
func _fill_item_stats(def: Dictionary) -> void:
	for c in _stat_holder.get_children():
		_stat_holder.remove_child(c)
		c.queue_free()
	var rows: Array = EquipmentInfoScript.item_stat_rows(def)
	var lines := 1
	if rows.is_empty():
		_outlined(_label("無數值加成", Vector2(4, 0), Vector2(200, STAT_ROW_H), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, _stat_holder))
	else:
		lines = (rows.size() + 1) / 2
		for i in rows.size():
			var row: Dictionary = rows[i]
			var x := (i % 2) * 148.0
			var y := (i / 2) * STAT_ROW_H
			_outlined(_label(String(row["label"]), Vector2(x + 2, y), Vector2(66, STAT_ROW_H), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, _stat_holder))
			var tint := Color("#A8F0A8") if int(row["sign"]) > 0 else Color("#FFA0A0")
			_outlined(_label(String(row["text"]), Vector2(x + 68, y), Vector2(76, STAT_ROW_H), 16, tint, HORIZONTAL_ALIGNMENT_LEFT, _stat_holder))
	var top := STAT_Y + lines * STAT_ROW_H + 8.0
	_scroll.position.y = top
	_scroll.size.y = 562.0 - top

func _refresh_buttons() -> void:
	var item_id := _equipped_item_id()
	var locked := _is_locked(slot)
	_btn_change.disabled = locked
	_btn_unequip.disabled = locked or item_id == ""

# ------------------------------------------------------------------
# 操作
# ------------------------------------------------------------------
func _on_actor_pressed(id: String) -> void:
	if id == actor_id:
		_refresh()
		return
	actor_id = id
	if menu != null:
		menu._remember_tab_actor("equipment", id)
	if _is_locked(slot):
		slot = "weapon_1"
	_refresh()

func _on_slot_pressed(slot_id: String) -> void:
	if slot_id != slot:
		slot = slot_id
	_refresh()

## 雙擊（連續兩下左鍵）：選中這一格並開「更換裝備」視窗（固定欄位只選中不開）；單擊只選中
func _on_slot_double_clicked(slot_id: String) -> void:
	_on_slot_pressed(slot_id)
	if not _is_locked(slot_id):
		_on_change_pressed()

## 右鍵點在「有裝備」的格子上＝詢問卸下，不當成「離開頁面」。空格子、格子以外的地方，右鍵照常關閉選單
## （有彈窗時右鍵照常取消彈窗）
func _right_click_free(pos: Vector2) -> bool:
	if _overlay != null and _overlay.visible:
		return true
	var equipped: Dictionary = InventorySync.get_equipped(actor_id)
	for slot_id: String in _slot_buttons.keys():
		var b: Control = _slot_buttons[slot_id]
		if b.get_global_rect().has_point(pos) and String(equipped.get(slot_id, "")) != "":
			return false
	return true

## 格子的滑鼠輸入：左鍵雙擊＝更換、右鍵單擊＝卸下（先問一次，防誤觸）
func _on_slot_gui_input(event: InputEvent, slot_id: String) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		_on_slot_double_clicked(slot_id)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_on_slot_pressed(slot_id)
		_ask_unequip()

## 「卸下」按鈕與右鍵共用：有裝備、沒鎖定才問；確認後才卸下
func _ask_unequip() -> void:
	var item_id := _equipped_item_id()
	if item_id == "" or _is_locked(slot):
		return
	var item_name := String(ItemDB.get_def(item_id).get("name", item_id))
	_show_confirm("卸下裝備", "確定要卸下「%s」嗎？
卸下後會放回背包。" % item_name, "確認卸下", func(): _apply_equip(""))

func _on_unequip_pressed() -> void:
	_ask_unequip()

## 換上 new_item_id（空字串＝卸下），並記下「前 → 後」讓詳情顯示變化量
func _apply_equip(new_item_id: String) -> void:
	var old_name := ""
	if _equipped_item_id() != "":
		old_name = String(ItemDB.get_def(_equipped_item_id()).get("name", ""))
	if new_item_id == "":
		InventorySync.unequip(slot, actor_id)
		show_toast("已卸下「%s」" % old_name)
	else:
		InventorySync.equip_item_to_slot(new_item_id, slot, actor_id)
		show_toast("已裝上「%s」" % String(ItemDB.get_def(new_item_id).get("name", new_item_id)))
	_refresh()

## 這個欄位可以換上的道具（背包裡的，符合欄位與角色的武器限制）
func _candidates() -> Array:
	var out: Array = []
	for item in InventorySync.get_items():
		var item_id := String(item.get("id", ""))
		var def := ItemDB.get_def(item_id)
		if def.is_empty() or String(def.get("use_action", "none")) != "equip":
			continue
		var item_slot := String(def.get("equip_slot", ""))
		if slot.begins_with("weapon"):
			if not item_slot.begins_with("weapon"):
				continue
		elif item_slot != slot:
			continue
		if menu != null and not menu._is_weapon_type_allowed_for_actor(def, slot, actor_id):
			continue
		out.append(item_id)
	return out

func _on_change_pressed() -> void:
	if _is_locked(slot):
		return
	_pick_candidates = _candidates()
	_pick_selected = String(_pick_candidates[0]) if not _pick_candidates.is_empty() else ""
	_show_pick()

func _show_pick() -> void:
	_clear_overlay()
	_overlay.visible = true
	var pos := Vector2(176, 112)
	var size := Vector2(800, 420)
	_panel("confirm_panel", 28, 24, pos, size, _overlay)
	_label("更換%s" % EquipmentInfoScript.slot_label(slot), pos + Vector2(40, 22), Vector2(300, 30), 22, GOLD, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	# 目前裝備（玩家左鍵點格子就直接進這個視窗，所以目前穿的東西要在這裡看得到）
	var cur_id := _equipped_item_id()
	var cur_text := "目前裝備：（無）"
	if cur_id != "":
		var cur_def := ItemDB.get_def(cur_id)
		var parts: Array[String] = []
		for row: Dictionary in EquipmentInfoScript.item_stat_rows(cur_def):
			parts.append("%s %s" % [row["label"], row["text"]])
		cur_text = "目前裝備：%s　%s" % [String(cur_def.get("name", cur_id)), "　".join(parts) if not parts.is_empty() else "無數值加成"]
	_outlined(_label(cur_text, pos + Vector2(40, 58), Vector2(720, 26), 15, CREAM, HORIZONTAL_ALIGNMENT_LEFT, _overlay))
	if _pick_candidates.is_empty():
		var none := _label("背包裡沒有可以裝在這個欄位的道具。", pos + Vector2(40, 140), size - Vector2(80, 60), 18, CREAM, HORIZONTAL_ALIGNMENT_CENTER, _overlay)
		none.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		_build_pick_list(pos + Vector2(40, 92))
		_pick_compare = Control.new()
		_pick_compare.position = pos + Vector2(380, 92)
		_pick_compare.size = Vector2(380, 252)
		_pick_compare.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(_pick_compare)
		_refresh_pick_compare()
	var ok := _tex_button(Vector2(170, 40), pos + Vector2(size.x - 40 - 170 - 190, size.y - 66), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, _overlay)
	ok.text = "裝上"
	ok.disabled = _pick_candidates.is_empty()
	var cancel := _tex_button(Vector2(170, 40), pos + Vector2(size.x - 40 - 170, size.y - 66), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	cancel.text = "取消"
	ok.pressed.connect(func():
		var chosen := _pick_selected
		_close_overlay()
		if chosen != "":
			_apply_equip(chosen))
	cancel.pressed.connect(_close_overlay)

func _build_pick_list(pos: Vector2) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = pos
	scroll.size = Vector2(320, 252)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(scroll)
	_pick_rows = VBoxContainer.new()
	_pick_rows.custom_minimum_size = Vector2(310, 0)
	scroll.add_child(_pick_rows)
	for item_id in _pick_candidates:
		var def := ItemDB.get_def(String(item_id))
		var sel: bool = String(item_id) == _pick_selected
		var b := Button.new()
		b.custom_minimum_size = Vector2(310, 48)
		b.focus_mode = Control.FOCUS_NONE
		var normal := _box("row_normal", 16, 4)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, normal)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if sel:
			var glow := _image("row_selected", Vector2.ZERO, Vector2(310, 48), b)
			glow.name = "SelectedGlow"
		var icon_path := ItemIconMap.icon_path(String(item_id), def)
		_image_from(icon_path, Vector2(8, 4), Vector2(40, 40), b)
		_label(String(def.get("name", item_id)), Vector2(56, 0), Vector2(170, 48), 17, INK, HORIZONTAL_ALIGNMENT_LEFT, b)
		var rar := ItemRarity.rarity_of(def)
		if rar >= 2:
			_rarity_chip(rar, Vector2(232, 14), Vector2(56, 20), b)
		b.pressed.connect(func():
			_pick_selected = String(item_id)
			_show_pick())
		_pick_rows.add_child(b)

func _refresh_pick_compare() -> void:
	for c in _pick_compare.get_children():
		_pick_compare.remove_child(c)
		c.queue_free()
	var def := ItemDB.get_def(_pick_selected)
	_label(String(def.get("name", _pick_selected)), Vector2(0, 0), Vector2(250, 32), 22, CREAM, HORIZONTAL_ALIGNMENT_LEFT, _pick_compare)
	_label(EquipmentInfoScript.category_label(def), Vector2(0, 32), Vector2(250, 22), 14, Color("#BFAF8A"), HORIZONTAL_ALIGNMENT_LEFT, _pick_compare)
	var rows: Array = EquipmentInfoScript.compare(menu, _actor(actor_id), actor_id, slot, _pick_selected)
	var y := 66.0
	for row: Dictionary in rows:
		var key: String = row["key"]
		var delta: float = row["delta"]
		var color := Color("#8FD39A") if delta > 0.0001 else (Color("#E88A8A") if delta < -0.0001 else Color("#9C9078"))
		_label(String(row["label"]), Vector2(0, y), Vector2(80, 28), 16, Color("#BFAF8A"), HORIZONTAL_ALIGNMENT_LEFT, _pick_compare)
		_label(EquipmentInfoScript.format_value(key, row["before"]), Vector2(84, y), Vector2(64, 28), 17, CREAM, HORIZONTAL_ALIGNMENT_RIGHT, _pick_compare)
		_label("→", Vector2(150, y), Vector2(24, 28), 15, Color("#9C9078"), HORIZONTAL_ALIGNMENT_CENTER, _pick_compare)
		_label(EquipmentInfoScript.format_value(key, row["after"]), Vector2(176, y), Vector2(64, 28), 17, color if absf(delta) > 0.0001 else CREAM, HORIZONTAL_ALIGNMENT_RIGHT, _pick_compare)
		_label(EquipmentInfoScript.format_delta(key, delta), Vector2(246, y), Vector2(70, 28), 16, color, HORIZONTAL_ALIGNMENT_LEFT, _pick_compare)
		y += 28.0

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _overlay.visible:
			_close_overlay()
		else:
			close_requested.emit()

## 裝備頁固定用前景方案 2（青布與劍放大、右下角是藥罐與藥丸）
func _foreground_preset() -> String:
	return "cloth_big"
