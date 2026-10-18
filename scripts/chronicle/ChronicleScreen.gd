extends Control
class_name ChronicleScreen
# 《江湖行跡錄》：存檔／讀檔共用介面（99 格、每頁 10 格、共 10 頁）。
# 三種入口共用同一份畫面與同一個 SaveManager：
#   Mode.SAVE        遊戲內 → 系統 → 儲存進度（只能存）
#   Mode.LOAD        遊戲內 → 系統 → 讀取進度（只能讀，確認時提醒未存進度會遺失）
#   Mode.TITLE_LOAD  主選單 → 讀取進度（只能讀，沒有警告，返回回主選單）
# 版面常數都在下面的 LAYOUT 區，美術規格書以這些數字為準。

signal closed

enum Mode { SAVE, LOAD, TITLE_LOAD }

const FONT := preload("res://assets/fonts/DotGothic16-Regular.ttf")

# ---------------- LAYOUT（參考解析度 1152×648） ----------------
const FRAME_RECT := Rect2(32, 24, 1088, 600)
## 貼圖外框比內容區再往外多出這些（邏輯 px），讓外框的木邊／裝飾落在內容區外面；加上後外框貼圖剛好鋪滿 1152×648
const FRAME_OUTSET := Vector2(28, 24)
const TITLE_POS := Vector2(0, 34)            # 標題列（寬度 = FRAME 寬，置中）
const GRID_POS := Vector2(56, 88)
const GRID_H_SEP := -3
const GRID_V_SEP := -3
const PAGER_Y := 568.0
const PAGER_BTN_SIZE := Vector2(120, 32)
const RIGHT_X := 716.0
const RIGHT_W := 384.0
const PREVIEW_RECT := Rect2(716, 88, 384, 216)
const INFO_Y := 318.0
const ACTION_BTN_SIZE := Vector2(184, 36)
## 確認視窗：邏輯 600×344，置中。外框木邊與雲紋約佔四周 45px，內容一律放在距邊 56px 以內（文字與按鈕都不碰到邊飾）。
## 隊伍陣容列
const PARTY_ROW_H := 118.0
## 小人縮放：以「遊戲畫面上的實際大小」等比縮放到選單（劉語塵 122.7px 高 → 72px，其他角色用同一個比例），腳底對齊同一條基準線。
const PARTY_LIUYU_MENU_H := 72.0
const PARTY_LIUYU_WORLD_H := 108.9
const PARTY_BASELINE := 76.0   # 腳底基準線（相對陣容列上緣）
const PARTY_CHIBI_H := PARTY_BASELINE
const PARTY_MAX := 3   # 遊戲中隊伍最多三人
const PARTY_DIR := "res://assets/UI/chronicle_party/"

const CONFIRM_RECT := Rect2(276, 148, 600, 344)
const CONFIRM_SAFE := 56.0

const COL_BG := Color(0.075, 0.06, 0.05, 0.98)
const COL_RED := Color(0.56, 0.11, 0.11, 1.0)
# 文字顏色走 ChronicleSkin.color()（skin.json 可覆蓋）

var mode: int = Mode.SAVE
var page := 0
var selected_slot := 1
var _busy := false

var _items: Array[ChronicleSlotItem] = []
var _thumb_cache: Dictionary = {}   # slot -> Texture2D（null = 沒有縮圖）

var _frame: Panel
var _grid: GridContainer
var _title_label: Label
var _mode_label: Label
var _prev_btn: Button
var _next_btn: Button
var _page_label: Label
var _preview_tex: TextureRect
var _preview_empty_label: Label
var _preview_ph: TextureRect = null
var _level_label: Label
var _party_row: Control
var _party_scales: Dictionary = {}
var _no_label: Label
var _date_label: Label
var _map_label: Label
var _chapter_label: Label
var _status_label: Label
var _action_btn: Button
var _back_btn: Button
var _toast: Label
var _confirm_layer: Control
var _confirm_title: Label
var _confirm_body: Label
var _confirm_ok: Button
var _confirm_cancel: Button
var _pending_action: Callable

## 建立並加到 parent 底下。parent 為 Control 或 CanvasLayer 都可以。
static func open(parent: Node, open_mode: int, start_slot: int = 1) -> ChronicleScreen:
	var screen := ChronicleScreen.new()
	screen.mode = open_mode
	screen.selected_slot = clampi(start_slot, 1, SaveManager.slot_count())
	screen.page = (screen.selected_slot - 1) / SaveManager.SLOTS_PER_PAGE
	parent.add_child(screen)
	return screen

func _ready() -> void:
	name = "ChronicleScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 2000   # 系統選單根節點 z_index 是 1024，要壓在它上面
	_build_ui()
	_refresh_all()

# ------------------------------------------------------------------
# 建立節點
# ------------------------------------------------------------------
func _style(bg: Color, border: Color, border_w: int, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s

func _label(label_name: String, parent: Node, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.name = label_name
	l.position = pos
	l.size = label_size
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _button(button_name: String, parent: Node, pos: Vector2, btn_size: Vector2, text_value: String, red := false) -> Button:
	var b := Button.new()
	b.name = button_name
	b.position = pos
	b.size = btn_size
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", ChronicleSkin.color("button_text"))
	b.add_theme_color_override("font_hover_color", ChronicleSkin.color("button_text_hover"))
	b.add_theme_color_override("font_pressed_color", ChronicleSkin.color("button_text_hover"))
	b.add_theme_color_override("font_disabled_color", ChronicleSkin.color("button_text_disabled"))
	var base := COL_RED if red else Color(0.11, 0.09, 0.07, 1.0)
	b.add_theme_stylebox_override("normal", _style(base, Color(0.5, 0.4, 0.2), 2))
	b.add_theme_stylebox_override("hover", _style(base.lightened(0.15), ChronicleSkin.color("gold"), 2))
	b.add_theme_stylebox_override("pressed", _style(base.darkened(0.2), ChronicleSkin.color("gold"), 3))
	b.add_theme_stylebox_override("disabled", _style(Color(0.08, 0.07, 0.06, 0.9), Color(0.25, 0.22, 0.17), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	ChronicleSkin.skin_button(b, "btn_primary" if red else "btn")
	parent.add_child(b)
	return b

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.68)
	add_child(dim)

	_frame = Panel.new()
	_frame.name = "Frame"
	_frame.position = FRAME_RECT.position
	_frame.size = FRAME_RECT.size
	_frame.add_theme_stylebox_override("panel", _style(COL_BG, ChronicleSkin.color("gold"), 3, 4))
	add_child(_frame)
	var frame_skin := ChronicleSkin.make_nine("chronicle_frame", FRAME_RECT.size + FRAME_OUTSET * 2.0)
	if frame_skin != null:
		frame_skin.position = -FRAME_OUTSET
		_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_frame.add_child(frame_skin)

	# 標題列（座標相對 Frame）
	_title_label = _label("TitleLabel", _frame, Vector2(0, 14), Vector2(FRAME_RECT.size.x, 40), 30, ChronicleSkin.color("gold"), HORIZONTAL_ALIGNMENT_CENTER)
	_title_label.text = "江湖行跡錄"
	_mode_label = _label("ModeLabel", _frame, Vector2(FRAME_RECT.size.x - 224, 22), Vector2(200, 28), 18, ChronicleSkin.color("dim"), HORIZONTAL_ALIGNMENT_RIGHT)
	var banner := ChronicleSkin.make_image("chronicle_title", ChronicleSkin.texture("chronicle_title").get_size() / ChronicleSkin.ART_SCALE if ChronicleSkin.has("chronicle_title") else Vector2.ZERO)
	if banner != null:
		# 標題橫幅（含書法字）：置中，上緣超出外框 16px；有橫幅時不再顯示文字標題
		banner.position = Vector2((FRAME_RECT.size.x - banner.size.x) * 0.5, -16)
		_frame.add_child(banner)
		_title_label.visible = false
		_mode_label.visible = false   # 按鈕文字已經標明目前是儲存或讀取，不再另放小字
	var rule := ColorRect.new()
	rule.name = "TitleRule"
	rule.position = Vector2(24, 60)
	rule.size = Vector2(FRAME_RECT.size.x - 48, 2)
	rule.color = Color(0.42, 0.34, 0.17, 1)
	_frame.add_child(rule)

	# 左：存檔目錄 2 欄 × 5 列（10 個欄位，翻頁重複使用）
	_grid = GridContainer.new()
	_grid.name = "SlotGrid"
	_grid.columns = 2
	_grid.position = GRID_POS - FRAME_RECT.position
	_grid.add_theme_constant_override("h_separation", GRID_H_SEP)
	_grid.add_theme_constant_override("v_separation", GRID_V_SEP)
	_frame.add_child(_grid)
	for i in SaveManager.SLOTS_PER_PAGE:
		var item := ChronicleSlotItem.new()
		item.name = "Slot%d" % i
		item.pressed.connect(_on_item_pressed.bind(item))
		_grid.add_child(item)
		_items.append(item)

	# 左下：翻頁
	var pager_y := PAGER_Y - FRAME_RECT.position.y
	var grid_x := GRID_POS.x - FRAME_RECT.position.x
	var grid_w := 2.0 * ChronicleSlotItem.ITEM_SIZE.x + float(GRID_H_SEP)
	_prev_btn = _button("PrevPageButton", _frame, Vector2(grid_x, pager_y), PAGER_BTN_SIZE, "上一頁")
	_next_btn = _button("NextPageButton", _frame, Vector2(grid_x + grid_w - PAGER_BTN_SIZE.x, pager_y), PAGER_BTN_SIZE, "下一頁")
	var plate_size := Vector2(150, 30)
	var plate_center := Vector2(grid_x + grid_w * 0.5, pager_y + 17)
	var plate: Control = ChronicleSkin.make_nine("btn_normal", plate_size)
	if plate == null:
		var flat := Panel.new()
		flat.size = plate_size
		flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flat.add_theme_stylebox_override("panel", _style(Color(0.08, 0.065, 0.05, 0.95), Color(0.5, 0.4, 0.2), 2))
		plate = flat
	plate.name = "PagePlate"
	plate.position = plate_center - plate_size * 0.5
	_frame.add_child(plate)
	_page_label = _label("PageLabel", _frame, Vector2(grid_x + PAGER_BTN_SIZE.x, pager_y + 4), Vector2(grid_w - PAGER_BTN_SIZE.x * 2.0, 26), 16, ChronicleSkin.color("page"), HORIZONTAL_ALIGNMENT_CENTER)
	_prev_btn.pressed.connect(_change_page.bind(-1))
	_next_btn.pressed.connect(_change_page.bind(1))

	# 右：預覽
	var pv := Panel.new()
	pv.name = "PreviewFrame"
	pv.position = PREVIEW_RECT.position - FRAME_RECT.position
	pv.size = PREVIEW_RECT.size
	pv.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.85), Color(0.5, 0.4, 0.2), 2))
	_frame.add_child(pv)
	_preview_tex = TextureRect.new()
	_preview_tex.name = "PreviewTexture"
	_preview_tex.position = Vector2(4, 4)
	_preview_tex.size = PREVIEW_RECT.size - Vector2(8, 8)
	_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(_preview_tex)
	_preview_ph = ChronicleSkin.make_image("thumb_placeholder", PREVIEW_RECT.size - Vector2(8, 8))
	if _preview_ph != null:
		_preview_ph.position = Vector2(4, 4)
		_preview_ph.visible = false
		pv.add_child(_preview_ph)
	_preview_empty_label = _label("PreviewEmptyLabel", pv, Vector2(0, 88), Vector2(PREVIEW_RECT.size.x, 36), 22, ChronicleSkin.color("dim"), HORIZONTAL_ALIGNMENT_CENTER)
	var pv_skin := ChronicleSkin.make_nine("preview_frame", PREVIEW_RECT.size)
	if pv_skin != null:
		pv.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		pv.add_child(pv_skin)

	var info_x := RIGHT_X - FRAME_RECT.position.x
	var info_y := INFO_Y - FRAME_RECT.position.y
	_no_label = _label("SlotNumberLabel", _frame, Vector2(info_x, info_y), Vector2(RIGHT_W, 34), 26, ChronicleSkin.color("gold"))
	_date_label = _label("DateLabel", _frame, Vector2(info_x, info_y + 36), Vector2(RIGHT_W, 24), 17, ChronicleSkin.color("text"))
	_map_label = _label("MapLabel", _frame, Vector2(info_x, info_y + 64), Vector2(RIGHT_W, 24), 17, ChronicleSkin.color("text"))
	_chapter_label = _label("ChapterLabel", _frame, Vector2(info_x, info_y + 92), Vector2(RIGHT_W, 24), 17, ChronicleSkin.color("text"))
	_level_label = _label("LevelLabel", _frame, Vector2(info_x, info_y + 138), Vector2(RIGHT_W, 24), 17, ChronicleSkin.color("text"))
	_level_label.text = ""
	# 隊伍陣容：一排小人（chibi 左下 idle），底下名字與等級；最多 PARTY_MAX 位，多了就縮小間距
	var sj := PARTY_DIR + "scales.json"
	if FileAccess.file_exists(sj):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(sj))
		if typeof(parsed) == TYPE_DICTIONARY:
			_party_scales = parsed
	_party_row = Control.new()
	_party_row.name = "PartyRow"
	_party_row.position = Vector2(info_x - 8.0, info_y + 124)
	_party_row.size = Vector2(RIGHT_W, PARTY_ROW_H)
	_party_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_party_row)
	_status_label = _label("StatusLabel", _frame, Vector2(info_x, info_y + 178), Vector2(RIGHT_W, 48), 15, ChronicleSkin.color("dim"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 右下：操作按鈕
	_action_btn = _button("ActionButton", _frame, Vector2(info_x, pager_y), ACTION_BTN_SIZE, "儲存進度" if mode == Mode.SAVE else "讀取進度", true)
	_back_btn = _button("BackButton", _frame, Vector2(info_x + RIGHT_W - ACTION_BTN_SIZE.x, pager_y), ACTION_BTN_SIZE, "返回")
	_action_btn.pressed.connect(_on_action_pressed)
	_back_btn.pressed.connect(close)
	_mode_label.text = "儲存進度" if mode == Mode.SAVE else "讀取進度"

	# 提示（儲存成功／失敗等）：疊在預覽圖下緣
	_toast = _label("Toast", _frame, Vector2(info_x, PREVIEW_RECT.position.y - FRAME_RECT.position.y + PREVIEW_RECT.size.y - 36), Vector2(RIGHT_W, 32), 18, ChronicleSkin.color("toast"), HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.modulate.a = 0.0

	_build_confirm()

func _build_confirm() -> void:
	_confirm_layer = Control.new()
	_confirm_layer.name = "ConfirmLayer"
	_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_layer.visible = false
	_confirm_layer.z_index = 10   # 選中的欄位 z_index 是 1，確認視窗要蓋在它上面
	add_child(_confirm_layer)
	var cdim := ColorRect.new()
	cdim.name = "ConfirmDim"
	cdim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cdim.color = Color(0, 0, 0, 0.6)
	_confirm_layer.add_child(cdim)
	var panel := Panel.new()
	panel.name = "ConfirmPanel"
	panel.position = CONFIRM_RECT.position
	panel.size = CONFIRM_RECT.size
	panel.add_theme_stylebox_override("panel", _style(Color(0.09, 0.07, 0.055, 1.0), ChronicleSkin.color("gold"), 3, 4))
	_confirm_layer.add_child(panel)
	var cp_skin := ChronicleSkin.make_nine("confirm_panel", CONFIRM_RECT.size)
	if cp_skin != null:
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		panel.add_child(cp_skin)
		panel.move_child(cp_skin, 0)
	_confirm_title = _label("ConfirmTitle", panel, Vector2(CONFIRM_SAFE, 54), Vector2(CONFIRM_RECT.size.x - CONFIRM_SAFE * 2.0, 34), 24, ChronicleSkin.color("gold"), HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_body = _label("ConfirmBody", panel, Vector2(CONFIRM_SAFE, 100), Vector2(CONFIRM_RECT.size.x - CONFIRM_SAFE * 2.0, 130), 18, ChronicleSkin.color("text"), HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn_size := Vector2(190, 40)
	var by := CONFIRM_RECT.size.y - CONFIRM_SAFE - btn_size.y
	_confirm_ok = _button("ConfirmOkButton", panel, Vector2(CONFIRM_SAFE + 16.0, by), btn_size, "確認", true)
	_confirm_cancel = _button("ConfirmCancelButton", panel, Vector2(CONFIRM_RECT.size.x - CONFIRM_SAFE - 16.0 - btn_size.x, by), btn_size, "取消")
	_confirm_ok.pressed.connect(_on_confirm_ok)
	_confirm_cancel.pressed.connect(_hide_confirm)

# ------------------------------------------------------------------
# 資料與重新整理
# ------------------------------------------------------------------
func _slot_of_item(i: int) -> int:
	return page * SaveManager.SLOTS_PER_PAGE + i + 1

func _texture_for_slot(slot: int) -> Texture2D:
	if _thumb_cache.has(slot):
		return _thumb_cache[slot]
	var tex: Texture2D = null
	var p: String = SaveManager.thumb_path_for_slot(slot)
	if FileAccess.file_exists(p):
		var img := Image.new()
		if img.load(p) == OK:
			tex = ImageTexture.create_from_image(img)
	_thumb_cache[slot] = tex
	return tex

func _kind_of(summary: Dictionary) -> int:
	match String(summary.get("_status", "empty")):
		"ok": return ChronicleSlotItem.Kind.FILLED
		"invalid": return ChronicleSlotItem.Kind.CORRUPT
	return ChronicleSlotItem.Kind.EMPTY

func _date_text(summary: Dictionary) -> String:
	var ts := int(summary.get("timestamp", 0))
	if ts <= 0:
		return "未知時間"
	return Time.get_datetime_string_from_unix_time(ts, true)

func _map_text(summary: Dictionary) -> String:
	var n := String(summary.get("map_display_name", "")).strip_edges()
	return n if n != "" else "未知場景"

func _refresh_all() -> void:
	_refresh_page()
	_refresh_detail()

func _refresh_page() -> void:
	for i in _items.size():
		var slot := _slot_of_item(i)
		var item := _items[i]
		if slot > SaveManager.slot_count():
			item.visible = false
			continue
		item.visible = true
		var summary: Dictionary = SaveManager.get_slot_summary_cached(slot)
		var k := _kind_of(summary)
		item.show_slot(slot, k, _texture_for_slot(slot) if k == ChronicleSlotItem.Kind.FILLED else null, _map_text(summary), _date_text(summary))
		item.set_selected(slot == selected_slot)
	_page_label.text = "第 %d / %d 頁" % [page + 1, SaveManager.page_count()]
	_prev_btn.disabled = page <= 0
	_next_btn.disabled = page >= SaveManager.page_count() - 1

func _refresh_detail() -> void:
	var slot := selected_slot
	var summary: Dictionary = SaveManager.get_slot_summary_cached(slot)
	var status := String(summary.get("_status", "empty"))
	_no_label.text = "存檔 %02d" % slot
	_status_label.text = ""
	_preview_empty_label.text = ""
	_preview_tex.texture = null
	_level_label.text = ""
	_clear_party()
	if _preview_ph != null:
		_preview_ph.visible = false
	match status:
		"ok":
			_preview_tex.texture = _texture_for_slot(slot)
			if _preview_tex.texture == null:
				_preview_empty_label.text = "（沒有縮圖）"
			_date_label.text = "時間：%s" % _date_text(summary)
			_map_label.text = "所在場景：%s" % _map_text(summary)
			_chapter_label.text = "主線進度：%s" % String(summary.get("chapter_text", "章節未記錄"))
			_show_party(summary.get("party", []), int(summary.get("leader_level", 0)))
		"invalid":
			_preview_empty_label.text = "存檔異常"
			_date_label.text = ""
			_map_label.text = ""
			_chapter_label.text = ""
			_status_label.text = "這份紀錄無法讀取，也不會被覆蓋。請保留原檔，或聯絡開發者協助。"
		_:
			_preview_empty_label.text = "空白紀錄"
			_date_label.text = ""
			_map_label.text = ""
			_chapter_label.text = ""
			_status_label.text = "尚無存檔。" if mode != Mode.SAVE else "尚無存檔，可在此建立新的紀錄。"
	if _preview_ph != null:
		_preview_ph.visible = _preview_tex.texture == null
	_update_action_button(status)

func _clear_party() -> void:
	for c in _party_row.get_children():
		c.queue_free()
		_party_row.remove_child(c)

## 隊伍陣容：[{id, level}]。舊存檔沒有隊伍資料時退回只顯示主角等級一行。
func _show_party(party: Array, leader_level: int) -> void:
	_clear_party()
	if party.is_empty():
		_level_label.text = "角色等級：Lv.%d" % leader_level if leader_level > 0 else "角色等級：未記錄"
		return
	_level_label.text = ""   # 不另放「隊伍」標題，陣容直接接在主線進度下面
	var members: Array = party.slice(0, PARTY_MAX)
	var cell_w := 88.0   # 三人一排，每格固定寬度，靠左擠（右邊留給背景的竹葉）
	for i in members.size():
		var m: Dictionary = members[i]
		var cell := Control.new()
		cell.position = Vector2(i * cell_w, 0)
		cell.size = Vector2(cell_w, PARTY_ROW_H)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_party_row.add_child(cell)
		var tex_path := "%s%s.png" % [PARTY_DIR, String(m.get("id", ""))]
		if ResourceLoader.exists(tex_path):
			var tr := TextureRect.new()
			var tex := load(tex_path) as Texture2D
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			# 實際縮放 = 該角色在遊戲裡的縮放（scales.json）× 統一的選單比例；沒有記錄的角色用劉語塵的縮放
			var world_scale := float(_party_scales.get(String(m.get("id", "")), _party_scales.get("liuyu", 0.3)))
			var k := PARTY_LIUYU_MENU_H / PARTY_LIUYU_WORLD_H
			var sz := tex.get_size() * world_scale * k
			tr.size = sz
			tr.position = Vector2((cell_w - sz.x) * 0.5, PARTY_BASELINE - sz.y)   # 腳底（圖片底邊）對齊基準線
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(tr)
		var name_l := _label("Name", cell, Vector2(0, PARTY_CHIBI_H + 2), Vector2(cell_w, 20), 14, ChronicleSkin.color("text"), HORIZONTAL_ALIGNMENT_CENTER)
		name_l.text = SaveManager.actor_display_name(String(m.get("id", "")))
		var lv_l := _label("Level", cell, Vector2(0, PARTY_CHIBI_H + 20), Vector2(cell_w, 20), 14, ChronicleSkin.color("gold"), HORIZONTAL_ALIGNMENT_CENTER)
		var lv := int(m.get("level", 0))
		lv_l.text = "Lv.%d" % lv if lv > 0 else "Lv.?"

func _update_action_button(status: String) -> void:
	if mode == Mode.SAVE:
		# 異常存檔不可覆蓋（避免玩家把還有救的資料蓋掉）
		_action_btn.disabled = status == "invalid" or _busy
	else:
		_action_btn.disabled = status != "ok" or _busy
	_back_btn.disabled = _busy

# ------------------------------------------------------------------
# 操作
# ------------------------------------------------------------------
func _on_item_pressed(item: ChronicleSlotItem) -> void:
	if _busy or _confirm_layer.visible:
		return
	selected_slot = item.slot_index
	for it in _items:
		it.set_selected(it.slot_index == selected_slot)
	_refresh_detail()

func _change_page(delta: int) -> void:
	if _busy or _confirm_layer.visible:
		return
	page = clampi(page + delta, 0, SaveManager.page_count() - 1)
	# 翻頁後選取該頁第一格，避免畫面上選的和右側資訊不是同一格
	selected_slot = _slot_of_item(0)
	_refresh_all()

func _on_action_pressed() -> void:
	if _busy or _confirm_layer.visible:
		return
	var slot := selected_slot
	var summary: Dictionary = SaveManager.get_slot_summary_cached(slot)
	var status := String(summary.get("_status", "empty"))
	if mode == Mode.SAVE:
		if status == "invalid":
			_show_toast("存檔異常，不能覆蓋")
		elif status == "ok":
			_show_confirm(
				"是否覆蓋存檔 %02d？" % slot,
				"原本的紀錄：\n%s\n%s" % [_map_text(summary), _date_text(summary)],
				"確認覆蓋",
				_do_save.bind(slot))
		else:
			_do_save(slot)
	else:
		var check: Dictionary = SaveManager.check_slot_loadable(slot)
		if not bool(check.get("ok", false)):
			_show_toast(String(check.get("reason", "無法讀取")))
			return
		var body := "存檔 %02d｜%s\n%s" % [slot, _map_text(summary), _date_text(summary)]
		if mode == Mode.LOAD:
			body += "\n\n目前尚未儲存的遊戲進度將會遺失。"
		_show_confirm("確定要讀取這份進度嗎？", body, "確認讀取", _do_load.bind(slot))

func _do_save(slot: int) -> void:
	var ok: bool = SaveManager.save_to_slot(slot)
	_thumb_cache.erase(slot)
	SaveManager.invalidate_summary_cache(slot)
	_refresh_all()
	_show_toast("儲存成功" if ok else "儲存失敗")

func _do_load(slot: int) -> void:
	_busy = true
	_update_action_button("ok")
	_show_toast("讀取中……", 30.0)
	var ok: bool
	if mode == Mode.TITLE_LOAD:
		ok = await SaveManager.load_from_title(slot)
	else:
		ok = await SaveManager.load_from_slot(slot)
	if not is_instance_valid(self):
		return
	if ok:
		# 遊戲內讀檔時系統選單已被 SaveManager 關閉；這個畫面跟著收掉
		queue_free()
		return
	_busy = false
	_refresh_detail()
	_show_toast("讀取失敗")

func _show_confirm(title_text: String, body_text: String, ok_text: String, action: Callable) -> void:
	_confirm_title.text = title_text
	_confirm_body.text = body_text
	_confirm_ok.text = ok_text
	_pending_action = action
	_confirm_layer.visible = true

func _hide_confirm() -> void:
	_confirm_layer.visible = false
	_pending_action = Callable()

func _on_confirm_ok() -> void:
	var action := _pending_action
	_hide_confirm()
	if action.is_valid():
		action.call()

func _show_toast(text_value: String, hold_sec: float = 1.6) -> void:
	_toast.text = text_value
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(hold_sec)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)

func close() -> void:
	if _busy:
		return
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirm_layer.visible:
			_hide_confirm()
		else:
			close()
