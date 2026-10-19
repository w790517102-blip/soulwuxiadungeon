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
## 格內版面（邏輯 px）：上＝部位名稱、其餘全是大圖示（裝備名稱不寫在格子上，玩家在右頁就能看到完整資訊）；留白越少越好
const SLOT_ICON_BOX := Rect2(11, 15, 78, 78)         # 圖示盡量填滿整格（部位名稱疊在上面）
## 個別格子的圖示縮放（往下靠齊，避免頂到上面的部位名稱）
const SLOT_ICON_SCALE := {"head": 0.80}
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
var _slot_frame_material: ShaderMaterial
var _trim_cache: Dictionary = {}
const SLOT_LABEL_CHAR_PX := 13.0          # 部位名稱每個字的大小（八格統一）
const SLOT_LABEL_CHARS := {"main_weapon": 3, "off_weapon": 3, "head": 2, "body": 2, "hands": 2, "feet": 2, "accessory": 2, "mechanism": 2}
const FIGURE_RECT := Rect2(421, 92, 254, 486)
## 三個角色卡槽（V2 placement.json 的 runtime 座標 ÷ 2）
const ROSTER_SLOTS := [Rect2(55, 142, 246.5, 123), Rect2(55, 273, 246.5, 123.5), Rect2(55, 402.5, 246.5, 122)]
const DETAIL_X := 790.0                  # 右頁（770 起）內容的左緣：往右縮進，內容在頁面上更置中
const DETAIL_W := 296.0
const STAT_Y := 332.0
const STAT_ROW_H := 28.0
const E := "equipment/"                  # 素材資料夾前綴（assets/UI/equipment/）

const GOOD := Color("#2F6B3A")
const BAD := Color("#9A2A2A")

var menu: Node
var actor_id := ""
var slot := "weapon_1"

var _roster_box: Control
var _roster_buttons: Dictionary = {}
var _slot_buttons: Dictionary = {}
var _figure: TextureRect
var _figure_name: Label
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
	# 大卷軸左側深色底上：標題牌、三個角色卡槽（位置照 V2 的 placement.json，runtime ÷ 2）、底部引言
	# 標題牌：老闆從概念圖截下來的「同行俠客」整條（字在圖上，不是程式輸出；451×79，等比放大到寬 246.5）
	_image(E + "equip_roster_title", Vector2(55, 96), Vector2(246.5, 37))
	_image(E + "equip_roster_title_cut", Vector2(55, 93), Vector2(246.5, 43.2))
	_panel(E + "equip_roster_quote", 22, 22, Vector2(62, 530), Vector2(233, 38))
	_label("江湖如逆旅，幸有同路人。", Vector2(70, 530), Vector2(190, 38), 13, CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	_image(E + "equip_quote_seal", Vector2(261, 535), Vector2(28, 28))
	_roster_box = Control.new()
	_roster_box.position = Vector2.ZERO
	_roster_box.size = Vector2(1152, 648)
	_roster_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster_box.z_index = 1
	add_child(_roster_box)

func _build_slots() -> void:
	var all_slots: Array = []
	for i in 4:
		all_slots.append([EquipmentInfoScript.LEFT_SLOTS[i], SLOT_X[0], SLOT_Y0 + i * (SLOT_SIZE.y + SLOT_GAP)])
		all_slots.append([EquipmentInfoScript.RIGHT_SLOTS[i], SLOT_X[1], SLOT_Y0 + i * (SLOT_SIZE.y + SLOT_GAP)])
	for entry: Array in all_slots:
		var slot_id: String = entry[0]
		var part := _empty_icon_name(slot_id)
		var b := Button.new()
		b.name = "Slot_" + slot_id
		b.position = Vector2(entry[1], entry[2])
		b.size = SLOT_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.z_index = 1
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		add_child(b)
		# 版面原則：留白越少越好，玩家一眼看出這格是什麼。
		# 上：部位名稱（共邊國的字，統一縮放成同樣的字大小）；其餘：大圖示（空格是灰剪影、有裝備是物品圖）。格子上不寫裝備名稱。
		var frame := _image(E + "slots/slot_frame_" + part, Vector2.ZERO, SLOT_SIZE, b)
		frame.name = "Frame"
		frame.material = _frame_material()
		var label_tex := _tex(E + "slots/label_" + part)
		if label_tex != null:
			var per_char := label_tex.get_size().x / float(SLOT_LABEL_CHARS.get(part, 2))
			var disp := label_tex.get_size() * (SLOT_LABEL_CHAR_PX / per_char)
			var pl := _image(E + "slots/label_" + part, Vector2((SLOT_SIZE.x - disp.x) * 0.5, 5.0 + (SLOT_LABEL_CHAR_PX - disp.y) * 0.5), disp, b)
			pl.name = "PartLabel"
		var ghost_tex := _tex(E + "slots/ghost_" + part)
		var icon_rect := _slot_icon_rect(part)
		var empty_icon := _image(E + "slots/ghost_" + part, icon_rect.position, icon_rect.size, b)
		empty_icon.name = "EmptyIcon"
		empty_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ghost_tex != null:
			empty_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon := _image_from("", icon_rect.position, icon_rect.size, b)
		icon.name = "Icon"
		if b.has_node("PartLabel"):
			b.move_child(b.get_node("PartLabel"), b.get_child_count() - 1)       # 部位名稱蓋在圖示上面，不被劍尖之類擋住
		# 金光：加亮加粗。兩層疊加（加色混合）：內層是共邊國的光暈（240×232，疊在格子 (-10,-10)），外層放大一圈做出更粗的光邊；
		# 不能縮進框內也不能裁切。素材是靜態的，呼吸由程式調透明度。
		var glow := Control.new()
		glow.name = "SelectedGlow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.visible = false
		b.add_child(glow)
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		for layer in [[Vector2(-20, -20), Vector2(140, 136), 0.5], [Vector2(-10, -10), Vector2(120, 116), 0.8], [Vector2(-10, -10), Vector2(120, 116), 0.55]]:
			var g := _image(E + "slots/slot_selected_gold_overlay", layer[0], layer[1], glow)
			g.material = additive
			g.modulate = Color(1.0, 0.80, 0.32, layer[2])      # 偏金色，不要加成純白
		var breath := glow.create_tween().set_loops()
		breath.tween_property(glow, "modulate:a", 0.8, 1.1).set_trans(Tween.TRANS_SINE)
		breath.tween_property(glow, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
		# 沒有移入圖，用提亮代替
		b.mouse_entered.connect(func(): if not b.disabled: b.modulate = Color(1.1, 1.08, 1.02))
		b.mouse_exited.connect(func(): b.modulate = Color(0.55, 0.52, 0.48) if b.disabled else Color.WHITE)
		b.pressed.connect(_on_slot_pressed.bind(slot_id))
		_slot_buttons[slot_id] = b

## 空格剪影的檔名（V3：slots/slot_empty_<名稱>.png）
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
func _build_figure() -> void:
	# 人物立繪（紙娃娃預留）：目前只放角色頭像當底圖；之後在這個節點下加各部位圖層（後髮／身體／披風／機關…），不用改版面
	var doll := Control.new()
	doll.name = "PaperDoll"
	doll.position = FIGURE_RECT.position
	doll.size = FIGURE_RECT.size
	doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(doll)
	_figure = TextureRect.new()
	_figure.name = "Base"
	_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_figure.size = Vector2(FIGURE_RECT.size.x, 250)
	_figure.position = Vector2(0, 60)
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	doll.add_child(_figure)
	_figure_name = _label("", Vector2(0, 320), Vector2(FIGURE_RECT.size.x, 30), 20, INK, HORIZONTAL_ALIGNMENT_CENTER, doll)

func _build_detail() -> void:
	# 版面：右頁左右平分——左半是大圖（概念圖的裝備圖案很大），右半是名稱與資訊
	_art_bg = _image("detail_art_bg", Vector2(DETAIL_X, 96), Vector2(140, 196))
	_art = _image_from("", Vector2(DETAIL_X + 6, 102), Vector2(128, 184), self)
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
		_label(titles[i], Vector2(DETAIL_X + 158, y), Vector2(52, 24), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_info_vals.append(_outlined(_label("", Vector2(DETAIL_X + 222, y), Vector2(74, 24), 14, INK)))
	# 裝備效果：這件裝備自己的加成，一行 2 格
	_image("label_ink_m", Vector2(DETAIL_X, 298), Vector2(100, 26))
	_label("裝備效果", Vector2(DETAIL_X + 10, 298), Vector2(80, 26), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
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

## 右側文字：白字加黑色外框，不會被背景的山水畫吃掉
func _outlined(l: Label) -> Label:
	var current := l.get_theme_color("font_color")
	if current == INK or current == INK_DIM:
		l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l

func _section(title: String) -> RichTextLabel:
	var head := Control.new()
	head.custom_minimum_size = Vector2(100, 26)
	_scroll_box.add_child(head)
	_image("label_ink_m", Vector2.ZERO, Vector2(100, 26), head)
	_label(title, Vector2(10, 0), Vector2(80, 26), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, head)
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

func _actor(id: String) -> Dictionary:
	return TeamData.get_character_by_id(id) if TeamData else {}

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
	_rebuild_roster(ids)
	_refresh_slots()
	_refresh_figure()
	_refresh_detail()
	_refresh_buttons()

func _rebuild_roster(ids: Array) -> void:
	for c in _roster_box.get_children():
		_roster_box.remove_child(c)
		c.queue_free()
	_roster_buttons.clear()
	# 永遠三個卡槽；名冊多於三位時，顯示包含目前角色的那三位
	var start := 0
	var selected_index := ids.find(actor_id)
	if ids.size() > ROSTER_SLOTS.size():
		start = clampi(selected_index - 1, 0, ids.size() - ROSTER_SLOTS.size())
	for i in ROSTER_SLOTS.size():
		var rect: Rect2 = ROSTER_SLOTS[i]
		var index := start + i
		var normal_art := E + ("equip_actor_card_normal_02" if i < 2 else "equip_actor_card_normal_03")
		if index >= ids.size():
			# 空位：還沒有同行的人（名冊沒解鎖更多角色），畫暗一點的空白卡槽
			var empty := _panel(normal_art, 22, 22, rect.position, rect.size, _roster_box)
			empty.modulate = Color(0.8, 0.76, 0.7, 0.85)
			_label("尚未同行", rect.position, rect.size, 14, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, _roster_box)
			continue
		var id := String(ids[index])
		var a := _actor(id)
		var on: bool = id == actor_id
		var card := Button.new()
		card.position = rect.position
		card.size = rect.size
		card.focus_mode = Control.FOCUS_NONE
		card.toggle_mode = true
		card.set_pressed_no_signal(on)
		var sb := _box(normal_art, 22, 22)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			card.add_theme_stylebox_override(st, sb if sb != null else StyleBoxEmpty.new())
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		card.mouse_entered.connect(func(): card.modulate = Color(1.08, 1.06, 1.0))
		card.mouse_exited.connect(func(): card.modulate = Color.WHITE)
		_roster_box.add_child(card)
		if on:
			# 選中：共邊國的金光卡（比一般卡高約 6px，金光在牌緣外一圈）
			var glow := _image(E + "equip_actor_card_selected", Vector2(0, -3), Vector2(rect.size.x, rect.size.y + 6), card)
			glow.name = "SelectedArt"
		var portrait_path := String(a.get("portrait_path", ""))
		if portrait_path != "":
			var pr := _image_from(portrait_path, Vector2(8, 10), Vector2(96, rect.size.y - 20), card)
			pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_panel(E + "equip_portrait_frame", 12, 12, Vector2(6, 8), Vector2(100, rect.size.y - 16), card)
		if TeamData and TeamData.current_team_ids.has(id):
			_panel(E + "equip_deployed_tag", 6, 8, Vector2(4, 12), Vector2(22, 40), card)
			_label("上陣", Vector2(4, 12), Vector2(22, 40), 11, Color("#FFF3D0"), HORIZONTAL_ALIGNMENT_CENTER, card).autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_label(String(a.get("name", id)), Vector2(118, 12), Vector2(120, 24), 18, INK, HORIZONTAL_ALIGNMENT_LEFT, card)
		_label("Lv.%d" % int(a.get("level", 1)), Vector2(118, 38), Vector2(120, 20), 14, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, card)
		_bar(card, Vector2(118, 68), "hp", float(a.get("hp", 0)), float(maxi(1, int(a.get("max_hp", 1)))))
		_bar(card, Vector2(118, 88), "mp", float(a.get("mp", 0)), float(maxi(1, int(a.get("max_mp", 1)))))
		card.pressed.connect(_on_actor_pressed.bind(id))
		_roster_buttons[id] = card

func _slot_icon_rect(part: String) -> Rect2:
	var s: float = float(SLOT_ICON_SCALE.get(part, 1.0))
	var size := SLOT_ICON_BOX.size * s
	return Rect2(SLOT_ICON_BOX.position + (SLOT_ICON_BOX.size - size) * Vector2(0.5, 1.0), size)

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

func _refresh_slots() -> void:
	var equipped: Dictionary = InventorySync.get_equipped(actor_id)
	for slot_id in _slot_buttons.keys():
		var b: Button = _slot_buttons[slot_id]
		b.set_pressed_no_signal(slot_id == slot)
		(b.get_node("SelectedGlow") as Control).visible = slot_id == slot and not _is_locked(slot_id)
		b.z_index = 3 if slot_id == slot else 1        # 選中的格子蓋在鄰格上面，金光才不會被切到
		var item_id := String(equipped.get(slot_id, ""))
		var icon := b.get_node("Icon") as TextureRect
		var empty_icon := b.get_node("EmptyIcon") as TextureRect
		var locked := _is_locked(slot_id)
		b.disabled = locked
		b.modulate = Color(0.55, 0.52, 0.48) if locked else Color.WHITE      # 停用（固定欄位）：整格壓暗
		if item_id != "":
			var def := ItemDB.get_def(item_id)
			icon.texture = _slot_icon_texture(item_id, def)
			empty_icon.visible = false
		else:
			icon.texture = null
			empty_icon.visible = true

func _refresh_figure() -> void:
	var a := _actor(actor_id)
	var path := String(a.get("portrait_path", ""))
	_figure.texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	_figure_name.text = String(a.get("name", actor_id))

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

func _on_unequip_pressed() -> void:
	var item_id := _equipped_item_id()
	if item_id == "" or _is_locked(slot):
		return
	_apply_equip("")

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
	if _pick_candidates.is_empty():
		var none := _label("背包裡沒有可以裝在這個欄位的道具。", pos + Vector2(40, 140), size - Vector2(80, 60), 18, CREAM, HORIZONTAL_ALIGNMENT_CENTER, _overlay)
		none.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		_build_pick_list(pos + Vector2(40, 64))
		_pick_compare = Control.new()
		_pick_compare.position = pos + Vector2(380, 64)
		_pick_compare.size = Vector2(380, 280)
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
	scroll.size = Vector2(320, 280)
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
