extends "res://scripts/inventory/StudyPageBase.gd"
class_name ChronicleScreen
# 《江湖行跡錄》：存檔／讀檔共用介面（99 格、每頁 10 格、共 10 頁）。書房卷軸版（與道具、裝備、武術、見聞頁同一套底圖與寫法）。
# 三種入口共用同一份畫面與同一個 SaveManager：
#   Mode.SAVE        遊戲內 → 系統 → 儲存進度（只能存）
#   Mode.LOAD        遊戲內 → 系統 → 讀取進度（只能讀，確認時提醒未存進度會遺失）
#   Mode.TITLE_LOAD  主選單 → 讀取進度（只能讀，沒有警告，返回回主選單）
# 存讀檔的規則與資料流程完全沿用舊版（只換畫面）。標題橫幅、縮圖框、預覽框、隊伍小人沿用舊皮膚（ChronicleSkin）與 chronicle_party。
# 座標為邏輯 px（1152×648）。

signal closed

enum Mode { SAVE, LOAD, TITLE_LOAD }

# ---------------- LAYOUT ----------------
const GRID_POS := Vector2(196, 126)
const GRID_H_SEP := 6
const GRID_V_SEP := 4
const BUTTON_Y := 586
const PAGER_BTN := Vector2(120, 38)
const RIGHT_X := 780.0
const RIGHT_W := 320.0
const PREVIEW_RECT := Rect2(780, 126, 320, 180)
const INFO_Y := 316.0
const ACTION_BTN_SIZE := Vector2(165, 38)
const PARTY_ROW_H := 118.0
const PARTY_LIUYU_MENU_H := 72.0
const PARTY_LIUYU_WORLD_H := 108.9
const PARTY_BASELINE := 76.0   # 腳底基準線（相對陣容列上緣）
const PARTY_CHIBI_H := PARTY_BASELINE
const PARTY_MAX := 3   # 遊戲中隊伍最多三人
const PARTY_DIR := "res://assets/UI/chronicle_party/"
const PIXEL_FONT := preload("res://assets/fonts/DotGothic16-Regular.ttf")
const CONFIRM_RECT := Rect2(216, 124, 720, 400)

var mode: int = Mode.SAVE
var page := 0
var selected_slot := 1
var _busy := false

var _items: Array[ChronicleSlotItem] = []
var _thumb_cache: Dictionary = {}   # slot -> Texture2D（null = 沒有縮圖）

var _grid: GridContainer
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
var _note: Label
var _pending_action: Callable

static func open(parent: Node, open_mode: int, start_slot: int = 1) -> ChronicleScreen:
	var screen := ChronicleScreen.new()
	screen.mode = open_mode
	screen.selected_slot = clampi(start_slot, 1, SaveManager.slot_count())
	screen.page = (screen.selected_slot - 1) / SaveManager.SLOTS_PER_PAGE
	parent.add_child(screen)
	return screen

func _ready() -> void:
	name = "ChronicleScreen"
	set_meta("skip_menu_skin", true)
	soft_halo = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 2000   # 系統選單根節點 z_index 是 1024，要壓在它上面
	_build_ui()
	_refresh_all()

## 沿用道具頁的前景（書、劍、茶壺、燈籠）
func _foreground_preset() -> String:
	return "demo"

# ------------------------------------------------------------------
# 建立節點
# ------------------------------------------------------------------
func _build_ui() -> void:
	_build_background(true)
	# 標題橫幅（含書法字，沿用舊皮膚的圖）
	if ChronicleSkin.has("chronicle_title"):
		var banner := ChronicleSkin.make_image("chronicle_title", ChronicleSkin.texture("chronicle_title").get_size() / ChronicleSkin.ART_SCALE * 0.9)
		banner.position = Vector2((1152.0 - banner.size.x) * 0.5, 66.0 - banner.size.y * 0.5)
		banner.z_index = 2
		add_child(banner)
	else:
		_label("江湖行跡錄", Vector2(0, 50), Vector2(1152, 40), 30, INK, HORIZONTAL_ALIGNMENT_CENTER)

	# 左：存檔目錄 2 欄 × 5 列（10 個欄位，翻頁重複使用）
	_grid = GridContainer.new()
	_grid.name = "SlotGrid"
	_grid.columns = 2
	_grid.position = GRID_POS
	_grid.add_theme_constant_override("h_separation", GRID_H_SEP)
	_grid.add_theme_constant_override("v_separation", GRID_V_SEP)
	add_child(_grid)
	for i in SaveManager.SLOTS_PER_PAGE:
		var item := ChronicleSlotItem.new()
		item.name = "Slot%d" % i
		item.pressed.connect(_on_item_pressed.bind(item))
		_grid.add_child(item)
		_items.append(item)

	# 下排（桌面上，與其他頁的返回鈕同一高度）：翻頁、頁碼、儲存／讀取、返回
	_prev_btn = _tex_button(PAGER_BTN, Vector2(190, BUTTON_Y), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	_prev_btn.text = "上一頁"
	_next_btn = _tex_button(PAGER_BTN, Vector2(480, BUTTON_Y), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	_next_btn.text = "下一頁"
	_page_label = _label("", Vector2(314, BUTTON_Y), Vector2(164, 38), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_page_label.z_index = BUTTON_Z
	_outlined(_page_label)
	_prev_btn.pressed.connect(_change_page.bind(-1))
	_next_btn.pressed.connect(_change_page.bind(1))
	_action_btn = _tex_button(ACTION_BTN_SIZE, Vector2(660, BUTTON_Y), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16)
	_action_btn.text = "儲存進度" if mode == Mode.SAVE else "讀取進度"
	_back_btn = _tex_button(ACTION_BTN_SIZE, Vector2(840, BUTTON_Y), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	_back_btn.text = "返回"
	_action_btn.pressed.connect(_on_action_pressed)
	_back_btn.pressed.connect(close)

	# 右：預覽（舊皮膚的預覽框與縮圖暫代圖）
	var pv := Control.new()
	pv.name = "PreviewFrame"
	pv.position = PREVIEW_RECT.position
	pv.size = PREVIEW_RECT.size
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pv)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.position = Vector2(6, 6)
	back.size = PREVIEW_RECT.size - Vector2(12, 12)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(back)
	_preview_tex = TextureRect.new()
	_preview_tex.name = "PreviewTexture"
	_preview_tex.position = Vector2(6, 6)
	_preview_tex.size = PREVIEW_RECT.size - Vector2(12, 12)
	_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(_preview_tex)
	_preview_ph = ChronicleSkin.make_image("thumb_placeholder", PREVIEW_RECT.size - Vector2(12, 12))
	if _preview_ph != null:
		_preview_ph.position = Vector2(6, 6)
		_preview_ph.visible = false
		pv.add_child(_preview_ph)
	_preview_empty_label = _label("", Vector2(0, 70), Vector2(PREVIEW_RECT.size.x, 36), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, pv)
	_outlined(_preview_empty_label)
	var pv_skin := ChronicleSkin.make_nine("preview_frame", PREVIEW_RECT.size)
	if pv_skin != null:
		pv.add_child(pv_skin)

	_no_label = _label("", Vector2(RIGHT_X, INFO_Y), Vector2(RIGHT_W, 34), 26, Color("#5A3208"))
	_date_label = _label("", Vector2(RIGHT_X, INFO_Y + 34), Vector2(RIGHT_W, 24), 16, INK)
	_map_label = _label("", Vector2(RIGHT_X, INFO_Y + 58), Vector2(RIGHT_W, 24), 16, INK)
	_chapter_label = _label("", Vector2(RIGHT_X, INFO_Y + 82), Vector2(RIGHT_W, 24), 16, INK)
	_level_label = _label("", Vector2(RIGHT_X, INFO_Y + 118), Vector2(RIGHT_W, 24), 16, INK)
	for l in [_no_label, _date_label, _map_label, _chapter_label, _level_label]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 隊伍陣容：一排小人（chibi 左下 idle），底下名字與等級；最多 PARTY_MAX 位
	var sj := PARTY_DIR + "scales.json"
	if FileAccess.file_exists(sj):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(sj))
		if typeof(parsed) == TYPE_DICTIONARY:
			_party_scales = parsed
	_party_row = Control.new()
	_party_row.name = "PartyRow"
	_party_row.position = Vector2(RIGHT_X - 8.0, INFO_Y + 106)
	_party_row.size = Vector2(RIGHT_W, PARTY_ROW_H)
	_party_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party_row)
	_status_label = _label("", Vector2(RIGHT_X, INFO_Y + 130), Vector2(RIGHT_W, 60), 15, INK_DIM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outlined(_status_label)      # 壓在山水上：白字黑框
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# 提示（儲存成功／失敗等）：疊在預覽圖下緣
	_note = _label("", Vector2(RIGHT_X, PREVIEW_RECT.position.y + PREVIEW_RECT.size.y - 38), Vector2(RIGHT_W, 32), 18, Color("#FFF0C0"), HORIZONTAL_ALIGNMENT_CENTER)
	_note.z_index = 6
	_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_note.add_theme_constant_override("outline_size", 6)
	_note.modulate.a = 0.0

	_build_overlay()      # 確認視窗用（卷軸攤開當視窗）

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
	var cell_w := 88.0   # 三人一排，每格固定寬度，靠左擠
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
		# 隊伍名字與等級壓在右下的山水上：白字黑框才看得清楚
		var name_l := _label(SaveManager.actor_display_name(String(m.get("id", ""))), Vector2(0, PARTY_CHIBI_H + 2), Vector2(cell_w, 20), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, cell)
		name_l.add_theme_font_override("font", PIXEL_FONT)      # 角色名稱用點陣字體
		_outlined(name_l)
		var lv := int(m.get("level", 0))
		var lv_l := _label("Lv.%d" % lv if lv > 0 else "Lv.?", Vector2(0, PARTY_CHIBI_H + 20), Vector2(cell_w, 20), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, cell)
		lv_l.add_theme_font_override("font", PIXEL_FONT)
		_outlined(lv_l)

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
	if _busy or _overlay.visible:
		return
	selected_slot = item.slot_index
	for it in _items:
		it.set_selected(it.slot_index == selected_slot)
	_refresh_detail()

func _change_page(delta: int) -> void:
	if _busy or _overlay.visible:
		return
	page = clampi(page + delta, 0, SaveManager.page_count() - 1)
	# 翻頁後選取該頁第一格，避免畫面上選的和右側資訊不是同一格
	selected_slot = _slot_of_item(0)
	_refresh_all()

func _on_action_pressed() -> void:
	if _busy or _overlay.visible:
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

## 確認視窗：卷軸攤開當視窗（與武術頁、商店同一張卷軸）。字用墨色，避開卷軸的竹子與山水
func _show_confirm(title_text: String, body_text: String, ok_text: String, action: Callable) -> void:
	_pending_action = action
	_clear_overlay()
	_overlay.visible = true
	var pos := CONFIRM_RECT.position
	var size_ := CONFIRM_RECT.size
	var scroll := _image("scroll_body", pos, size_, _overlay)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_label(title_text, pos + Vector2(130, 50), Vector2(size_.x - 260, 36), 24, Color("#5A3208"), HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	var b := _label(body_text, pos + Vector2(130, 100), Vector2(size_.x - 300, 170), 18, INK, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var ok := _tex_button(Vector2(160, 40), pos + Vector2(130, size_.y - 78), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, _overlay)
	ok.text = ok_text
	var cancel := _tex_button(Vector2(160, 40), pos + Vector2(310, size_.y - 78), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	cancel.text = "取消"
	ok.pressed.connect(_on_confirm_ok)
	cancel.pressed.connect(_hide_confirm)

func _hide_confirm() -> void:
	_close_overlay()
	_pending_action = Callable()

func _on_confirm_ok() -> void:
	var action := _pending_action
	_hide_confirm()
	if action.is_valid():
		action.call()

func _show_toast(text_value: String, hold_sec: float = 1.6) -> void:
	_note.text = text_value
	_note.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(hold_sec)
	tw.tween_property(_note, "modulate:a", 0.0, 0.5)

func close() -> void:
	if _busy:
		return
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _overlay.visible:
			_hide_confirm()
		else:
			close()
