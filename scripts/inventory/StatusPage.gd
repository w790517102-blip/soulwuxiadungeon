extends "res://scripts/inventory/StudyPageBase.gd"
# 狀態頁：共邊國版（書房桌面＋大卷軸）。版面照概念圖：左＝同行俠客（切換角色，與裝備頁共用）、
# 中＝人物（紙娃娃）與直排姓名、右＝等級經驗、戰鬥、素質、裝備摘要（八格，沿用裝備頁的格子與圖示）。
# 氣血、內力只在左邊角色卡上，右邊不重複。數值用 system_menu.compute_overview_stats（與裝備頁、舊狀態頁同一套公式）。
# 座標一律是邏輯 px（1152×648）。大卷軸先沿用裝備頁那張（之後共邊國交狀態頁專用的再換）。

const EquipmentInfoScript = preload("res://scripts/inventory/EquipmentInfo.gd")

const BUTTON_Y := 586
const FIGURE_CLIP := Rect2(318, 92, 447, 486)       # 中頁人物的顯示範圍（超出裁掉）
const PORTRAIT_SIZE := Vector2(330, 632)            # 半身立繪（母圖 508×972 約放大 1.3 倍）
const PORTRAIT_DIR := "res://assets/UI/equipment/doll/"
const NAME_POS := Vector2(684, 108)         # 直排姓名（中頁右側）
const NAME_BOX := Vector2(60, 330)
const X0 := 790.0                           # 右頁內容左緣（右頁 770 起，往右縮進）
const COL_W := 148.0
const ROW_H := 25.0
const SUMMARY_TILE := Vector2(66, 63)
const SUMMARY_ORDER := ["weapon_1", "weapon_2", "armor_head", "armor_body", "armor_hands", "armor_feet", "accessory_1", "mechanism"]
const COMBAT_ROWS := [["atk", "攻擊"], ["def", "防禦"], ["speed", "身法"], ["hit", "命中"], ["crit", "暴擊"], ["evade", "閃避"]]
const TRAIT_ROWS := [["str", "力量"], ["agi", "敏捷"], ["int", "智力"], ["con", "體能"], ["luck", "幸運"]]

var _fig_clip: Control
var _portrait: TextureRect
var _name_box: Control
var _level_label: Label
var _exp_fill: TextureRect
var _exp_label: Label
var _stat_labels: Dictionary = {}           # key → 數值 Label
var _tiles: Dictionary = {}                 # slot_id → 格子
var _btn_back: Button

func _ready() -> void:
	name = "StatusPage"
	set_meta("skip_menu_skin", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100      # 舊狀態分頁的節點 z_index 是 1024（比其他分頁高），新頁要蓋在它上面
	_build_background(false)
	_image(E + "equip_scroll_complete", Vector2(0, 0), Vector2(1152, 648.5))
	_build_nav("TabStatus")
	build_roster_panel(false)
	_build_figure()
	_build_right_page()
	_btn_back = _tex_button(Vector2(165, 38), Vector2(494, BUTTON_Y), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	_btn_back.text = "返回"
	_btn_back.pressed.connect(func(): close_requested.emit())
	_build_toast()
	_build_overlay()
	if InventorySync:
		InventorySync.inventory_changed.connect(_refresh)
		InventorySync.equipment_changed.connect(_refresh)
	_refresh()

## 狀態頁用的前景方案：沿用裝備頁（備案 2）
func _foreground_preset() -> String:
	return "cloth_big"

# ------------------------------------------------------------------
# 建立畫面
# ------------------------------------------------------------------
func _build_figure() -> void:
	# 狀態頁用半身立繪（靜態圖，不是紙娃娃）：放大、頂端對齊，下緣被中頁裁掉，比全身更有張力。紙娃娃留給裝備頁與武術頁
	_fig_clip = Control.new()
	_fig_clip.name = "FigureClip"
	_fig_clip.position = FIGURE_CLIP.position
	_fig_clip.size = FIGURE_CLIP.size
	_fig_clip.clip_contents = true
	_fig_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fig_clip)
	_portrait = TextureRect.new()
	_portrait.name = "HalfBodyPortrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size = PORTRAIT_SIZE
	_portrait.position = Vector2((FIGURE_CLIP.size.x - PORTRAIT_SIZE.x) * 0.5 - 22.0, 0)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_fig_clip.add_child(_portrait)
	_name_box = Control.new()
	_name_box.name = "VerticalName"
	_name_box.position = NAME_POS
	_name_box.size = NAME_BOX
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_box)

func _section_title(title: String, pos: Vector2) -> void:
	_image("label_ink_m", pos, Vector2(100, 26))
	_label(title, pos + Vector2(7, 0), Vector2(80, 26), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

## 一列：小圖示位置（目前是菱形占位，美術的數值圖示交來後換成圖）＋名稱＋數值
func _stat_row(key: String, label: String, pos: Vector2) -> void:
	var icon_path := STATUS_DIR + "icon_%s.png" % key
	if ResourceLoader.exists(icon_path):
		_image_from(icon_path, pos + Vector2(0, 2), Vector2(20, 20), self)
	else:
		_outlined(_label("◆", pos, Vector2(18, ROW_H), 12, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_outlined(_label(label, pos + Vector2(22, 0), Vector2(56, ROW_H), 15, INK, HORIZONTAL_ALIGNMENT_LEFT))
	_stat_labels[key] = _outlined(_label("", pos + Vector2(78, 0), Vector2(64, ROW_H), 16, INK, HORIZONTAL_ALIGNMENT_LEFT))

func _build_right_page() -> void:
	# 基礎：等級、經驗（氣血與內力在左邊角色卡上，這裡不重複）
	_section_title("基礎", Vector2(X0, 96))
	_stat_row("level", "等級", Vector2(X0, 126))
	_level_label = _stat_labels["level"]
	_stat_row("exp", "經驗", Vector2(X0, 152))
	_stat_labels["exp"].visible = false
	_image("bar_mp_frame", Vector2(X0 + 78, 159), Vector2(120, 12))
	_exp_fill = _image("bar_mp_fill", Vector2(X0 + 78, 159), Vector2(120, 12))
	_exp_fill.modulate = Color(1.25, 1.0, 0.45)          # 經驗條用金黃（沿用內力條的條，染色）
	_exp_fill.clip_contents = true
	_exp_label = _outlined(_label("", Vector2(X0 + 204, 152), Vector2(70, ROW_H), 13, INK, HORIZONTAL_ALIGNMENT_LEFT))
	# 戰鬥（左欄）與素質（右欄）
	_section_title("戰鬥", Vector2(X0, 190))
	_section_title("素質", Vector2(X0 + COL_W, 190))
	for i in COMBAT_ROWS.size():
		_stat_row(COMBAT_ROWS[i][0], COMBAT_ROWS[i][1], Vector2(X0, 222 + i * ROW_H))
	for i in TRAIT_ROWS.size():
		_stat_row(TRAIT_ROWS[i][0], TRAIT_ROWS[i][1], Vector2(X0 + COL_W, 222 + i * ROW_H))
	# 裝備摘要：八格（沿用裝備頁的格子與圖示；這裡只顯示，不能點）
	_section_title("裝備摘要", Vector2(X0, 384))
	for i in SUMMARY_ORDER.size():
		var slot_id: String = SUMMARY_ORDER[i]
		var tile := make_slot_tile(slot_id, SUMMARY_TILE, self)
		tile.position = Vector2(X0 + (i % 4) * (SUMMARY_TILE.x + 6), 414 + (i / 4) * (SUMMARY_TILE.y + 8))
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tiles[slot_id] = tile

# ------------------------------------------------------------------
# 資料
# ------------------------------------------------------------------
func _actor_ids() -> Array:
	return menu._get_all_character_ids() if menu != null else ["liuyu"]

func _refresh() -> void:
	var ids := _actor_ids()
	if ids.is_empty():
		return
	if actor_id == "" or not ids.has(actor_id):
		var remembered: String = menu._get_tab_actor("equipment") if menu != null else ""
		actor_id = remembered if ids.has(remembered) else String(ids[0])
	rebuild_roster(ids, actor_id, _on_actor_pressed)
	_refresh_figure()
	_refresh_name()
	_refresh_stats()

func _on_actor_pressed(id: String) -> void:
	if id == actor_id:
		return
	actor_id = id
	if menu != null:
		menu._remember_tab_actor("equipment", id)
	_refresh()

func _refresh_figure() -> void:
	var art := PORTRAIT_DIR + "doll_%s_master.png" % actor_id
	if ResourceLoader.exists(art):
		_portrait.texture = load(art) as Texture2D
	else:
		var path := String(_actor(actor_id).get("portrait_path", ""))
		_portrait.texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null

func _refresh_name() -> void:
	fill_vertical_name(_name_box, actor_id)

func _refresh_stats() -> void:
	var a := _actor(actor_id)
	var level := int(a.get("level", 1))
	var exp_now := int(a.get("exp", 0))
	var exp_need := int(TeamData.exp_required(level)) if TeamData and TeamData.has_method("exp_required") else 50
	_level_label.text = str(level)
	_exp_label.text = "%d / %d" % [exp_now, exp_need]
	_exp_fill.size.x = 120.0 * clampf(float(exp_now) / float(maxi(1, exp_need)), 0.0, 1.0)
	_exp_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var stats: Dictionary = menu.compute_overview_stats(a, InventorySync.get_equipment_stat_bonus(actor_id)) if menu != null else {}
	for entry: Array in COMBAT_ROWS + TRAIT_ROWS:
		var key: String = entry[0]
		var value = stats.get(key, 0)
		(_stat_labels[key] as Label).text = ("%.1f%%" % float(value)) if key == "crit" else str(int(value))
	var equipped: Dictionary = InventorySync.get_equipped(actor_id)
	for slot_id in SUMMARY_ORDER:
		var locked: bool = menu != null and menu.is_slot_locked_for(actor_id, slot_id)
		fill_slot_tile(_tiles[slot_id], String(equipped.get(slot_id, "")), locked, false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
