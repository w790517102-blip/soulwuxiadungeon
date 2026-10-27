extends "res://scripts/inventory/StudyPageBase.gd"
class_name QuestPage
# 任務頁：書房桌面＋卷軸（與道具頁同一個外殼）。左＝分類（主線／支線／已完成）、中＝任務清單、右＝任務詳情
# （標題、類型章、狀態章、任務描述、當前目標、劉語塵筆記）。
# 資料沿用系統選單的 _build_quest_entries()（主線來自 QuestManager、支線來自 SideQuestManager），這裡只負責畫面。
# 座標一律是邏輯 px（1152×648）。素材全部沿用已驗收的書房套件；專屬的狀態印章、分類圖示等等共邊國交件後再換。

const StudyForegrounds = preload("res://scripts/inventory/StudyForegrounds.gd")
const CATEGORIES := [
	{"id": "主線", "icon": "quest", "empty": "目前沒有進行中的主線任務。"},
	{"id": "支線", "icon": "book", "empty": "目前沒有進行中的支線任務。"},
	{"id": "已完成", "icon": "all", "empty": "還沒有完成或錯過的任務。"},
]
const STATUS_ART := {"進行中": "status_usable", "已完成": "badge_equipped", "已錯過": "status_disabled"}
const STATUS_TEXT_COLOR := {"進行中": Color("#F6EEDC"), "已完成": Color.WHITE, "已錯過": Color("#D8CDB4")}

const MarqueeScript = preload("res://scripts/ui/MarqueeLabel.gd")
const ROW_H := 56
const LIST_POS := Vector2(200, 176)
const LIST_SIZE := Vector2(393, 384)
const BUTTON_Y := 586
const DETAIL_X := 632.0
const SEAL_POS := Vector2(1032, 146)       # 右上角的紅色類型章（主線／支線），字上下排
const SEAL_SIZE := Vector2(40, 74)
const SEAL_FONT := 22

var category := "主線"
var selected_id := ""
var _entries: Array = []                 # 全部任務（未分類）
var _shown: Array = []                   # 目前分類下的任務
var _cat_buttons: Dictionary = {}
var _cat_counts: Dictionary = {}
var _list_box: VBoxContainer
var _list_scroll: ScrollContainer
var _row_buttons: Dictionary = {}
var _title_label: Label
var _seal_label: Label
var _status_stamp: TextureRect
var _status_label: Label
var _detail_scroll: ScrollContainer
var _detail_box: VBoxContainer
var _desc_text: RichTextLabel
var _goal_text: RichTextLabel
var _note_text: RichTextLabel
var _empty_label: Label
var _detail_root: Control
var _btn_back: Button

## 前景用武術頁的（見 _ready），不用共用前景
func _foreground_preset() -> String:
	return "none"

func _ready() -> void:
	name = "QuestPage"
	set_meta("skip_menu_skin", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100      # 舊任務分頁節點的 z_index 比其他分頁高，新頁要蓋在上面
	_build_background()
	StudyForegrounds.add_martial(self)      # 前景沿用武術頁的（念珠、墨壺、燭燈柱）
	_build_nav("TabQuest")
	_build_categories()
	_build_list()
	_build_detail()
	_btn_back = _tex_button(Vector2(165, 38), Vector2(494, BUTTON_Y), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	_btn_back.text = "返回"
	_btn_back.pressed.connect(func(): close_requested.emit())
	_build_toast()
	_build_overlay()
	_refresh()

# ------------------------------------------------------------------
# 建立畫面
# ------------------------------------------------------------------
func _build_categories() -> void:
	_panel("cat_panel", 20, 28, Vector2(24, 76), Vector2(131, 440))
	var y := 82.0
	for c in CATEGORIES:
		var id: String = c["id"]
		var b := _tex_button(Vector2(131, 58), Vector2(24, y), "cat_item_normal", "cat_item_hover", "cat_item_selected", "cat_item_normal", 20, 14)
		b.name = "Cat_" + id
		b.toggle_mode = true
		var glow := _image("cat_item_selected", Vector2.ZERO, Vector2(131, 58), b)
		glow.name = "SelectedGlow"
		glow.visible = false
		var icon := _image("cat_icon_" + String(c["icon"]), Vector2(14, 11), Vector2(36, 36), b)
		icon.name = "Icon"
		var lab := _label(id, Vector2(56, 6), Vector2(70, 28), 21, CREAM, HORIZONTAL_ALIGNMENT_LEFT, b)
		lab.name = "Label"
		var cnt := _label("", Vector2(56, 30), Vector2(70, 20), 13, CREAM, HORIZONTAL_ALIGNMENT_LEFT, b)
		cnt.name = "Count"
		_cat_counts[id] = cnt
		b.pressed.connect(_on_category_pressed.bind(id))
		_cat_buttons[id] = b
		y += 58.0

func _build_list() -> void:
	_panel("list_header", 16, 4, Vector2(200, 148), Vector2(393, 28))
	_label("任務", Vector2(214, 148), Vector2(120, 28), 15, INK_DIM)
	_label("狀態", Vector2(520, 148), Vector2(60, 28), 15, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_list_scroll = ScrollContainer.new()
	_list_scroll.position = LIST_POS
	_list_scroll.size = LIST_SIZE
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 0)
	_list_box.custom_minimum_size = Vector2(LIST_SIZE.x - 10, 0)
	_list_scroll.add_child(_list_box)
	_skin_scrollbar(_list_scroll)
	_panel("divider_v", 2, 4, Vector2(599, 148), Vector2(4, 424))

func _skin_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 8
	var track := _box("scroll_track", 2, 4)
	bar.add_theme_stylebox_override("scroll", track if track != null else StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("scroll_focus", track if track != null else StyleBoxEmpty.new())
	for pair in [["grabber", "scroll_thumb_normal"], ["grabber_highlight", "scroll_thumb_hover"], ["grabber_pressed", "scroll_thumb_drag"]]:
		var gb := _box(pair[1], 2, 4)
		bar.add_theme_stylebox_override(pair[0], gb if gb != null else StyleBoxEmpty.new())

func _build_detail() -> void:
	_detail_root = Control.new()
	_detail_root.name = "Detail"
	_detail_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_root)
	_title_label = _label("", Vector2(DETAIL_X, 154), Vector2(400, 44), 28, INK, HORIZONTAL_ALIGNMENT_LEFT, _detail_root)
	_image("seal_type", SEAL_POS, SEAL_SIZE, _detail_root)
	_seal_label = _label("", SEAL_POS, SEAL_SIZE, SEAL_FONT, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, _detail_root)
	_seal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seal_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_seal_label.add_theme_constant_override("line_spacing", -2)
	_image("label_ink_s", Vector2(DETAIL_X, 206), Vector2(80, 26), _detail_root)
	_label("狀態", Vector2(DETAIL_X + 5, 206), Vector2(66, 26), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, _detail_root)
	_status_stamp = _image("status_usable", Vector2(DETAIL_X + 92, 208), Vector2(64, 24), _detail_root)
	_status_label = _label("", Vector2(DETAIL_X + 92, 208), Vector2(64, 24), 13, Color("#F6EEDC"), HORIZONTAL_ALIGNMENT_CENTER, _detail_root)
	_image("divider_h", Vector2(DETAIL_X, 240), Vector2(490, 6), _detail_root)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.position = Vector2(DETAIL_X, 252)
	_detail_scroll.size = Vector2(496, 316)
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_root.add_child(_detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 4)
	_detail_box.custom_minimum_size = Vector2(482, 0)
	_detail_scroll.add_child(_detail_box)
	_skin_scrollbar(_detail_scroll)
	_desc_text = _section("任務描述")
	_goal_text = _section("當前目標")
	_note_text = _section("劉語塵筆記")
	_empty_label = _label("", Vector2(DETAIL_X, 300), Vector2(490, 60), 18, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_empty_label.visible = false

func _section(title: String) -> RichTextLabel:
	var head := Control.new()
	head.custom_minimum_size = Vector2(110, 26)
	_detail_box.add_child(head)
	_image("label_ink_m", Vector2.ZERO, Vector2(110, 26), head)
	_label(title, Vector2(7, 0), Vector2(90, 26), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, head)
	var t := RichTextLabel.new()
	t.fit_content = true
	t.bbcode_enabled = true
	t.scroll_active = false
	t.custom_minimum_size = Vector2(478, 0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_override("normal_font", FONT)
	t.add_theme_font_size_override("normal_font_size", 16)
	_white_outline_rich(t)
	_detail_box.add_child(t)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(1, 8)
	_detail_box.add_child(gap)
	return t

# ------------------------------------------------------------------
# 資料
# ------------------------------------------------------------------
func _refresh() -> void:
	_entries = menu._build_quest_entries() if menu != null and menu.has_method("_build_quest_entries") else []
	for c in CATEGORIES:
		var id: String = c["id"]
		(_cat_counts[id] as Label).text = "%d 項" % _in_category(id).size()
	_apply_category()

## 分類規則與舊任務頁相同：主線＝進行中的主線；支線＝進行中的支線；已完成＝完成或已錯過
func _in_category(cat: String) -> Array:
	var out: Array = []
	for e in _entries:
		var status := String(e.get("status", "進行中"))
		var qtype := String(e.get("type", "支線"))
		match cat:
			"主線":
				if qtype == "主線" and status != "已完成":
					out.append(e)
			"支線":
				if qtype == "支線" and status != "已完成" and status != "已錯過":
					out.append(e)
			"已完成":
				if status == "已完成" or status == "已錯過":
					out.append(e)
	return out

func _apply_category() -> void:
	for id in _cat_buttons.keys():
		var b: Button = _cat_buttons[id]
		var on: bool = id == category
		b.set_pressed_no_signal(on)
		b.get_node("SelectedGlow").visible = on
		var icon_name := ""
		for c in CATEGORIES:
			if c["id"] == id:
				icon_name = String(c["icon"])
		(b.get_node("Icon") as TextureRect).texture = _tex("cat_icon_%s%s" % [icon_name, "_on" if on else ""])
		var tint := Color("#FFF3D0") if on else CREAM
		(b.get_node("Label") as Label).add_theme_color_override("font_color", tint)
		(b.get_node("Count") as Label).add_theme_color_override("font_color", tint)
	_shown = _in_category(category)
	var found := false
	for e in _shown:
		if String(e.get("id", "")) == selected_id:
			found = true
	if not found:
		selected_id = String(_shown[0].get("id", "")) if not _shown.is_empty() else ""
	_rebuild_rows()
	_refresh_detail()

func _rebuild_rows() -> void:
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	_row_buttons.clear()
	if _shown.is_empty():
		var empty := Label.new()
		empty.text = _category_empty_text()
		empty.custom_minimum_size = Vector2(LIST_SIZE.x - 10, 80)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_override("font", FONT)
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", INK_DIM)
		_list_box.add_child(empty)
		return
	for e in _shown:
		var id := String(e.get("id", ""))
		var on := id == selected_id
		var b := Button.new()
		b.custom_minimum_size = Vector2(LIST_SIZE.x - 10, ROW_H)
		b.focus_mode = Control.FOCUS_NONE
		var normal := _box("row_normal", 16, 4)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, normal)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var glow := _image("row_selected" if on else "row_hover", Vector2.ZERO, Vector2(LIST_SIZE.x - 10, ROW_H), b)
		glow.modulate.a = 1.0 if on else 0.0
		if not on:
			b.mouse_entered.connect(func(): glow.modulate.a = 0.6)
			b.mouse_exited.connect(func(): glow.modulate.a = 0.0)
		# 欄位只有一行：放不下時平常顯示「…」，滑鼠移到這一列就用跑馬燈把剩下的字跑出來
		var title_m := _marquee(String(e.get("title", id)), Vector2(14, 4), Vector2(300, 28), 18, INK, b)
		var step := int(e.get("stage", 0))
		var sub := String(e.get("objective", ""))
		if step > 0:
			sub = "第 %d 步　%s" % [step, sub]
		var sub_m := _marquee(sub, Vector2(14, 31), Vector2(310, 20), 13, INK_DIM, b)
		b.mouse_entered.connect(func():
			title_m.start()
			sub_m.start())
		b.mouse_exited.connect(func():
			title_m.stop()
			sub_m.stop())
		_status_chip(String(e.get("status", "進行中")), Vector2(LIST_SIZE.x - 10 - 72, 16), Vector2(60, 24), b)
		b.pressed.connect(_on_row_pressed.bind(id))
		_list_box.add_child(b)
		_row_buttons[id] = b

func _marquee(text: String, pos: Vector2, area: Vector2, font_size: int, color: Color, parent: Node) -> Control:
	var m: Control = MarqueeScript.new()
	m.position = pos
	m.setup(text, area, FONT, font_size, color)
	parent.add_child(m)
	return m

func _status_chip(status: String, pos: Vector2, size: Vector2, parent: Node) -> void:
	_image(String(STATUS_ART.get(status, "status_usable")), pos, size, parent)
	_label(status, pos, size, 13, STATUS_TEXT_COLOR.get(status, Color.WHITE), HORIZONTAL_ALIGNMENT_CENTER, parent)

func _category_empty_text() -> String:
	for c in CATEGORIES:
		if c["id"] == category:
			return String(c["empty"])
	return "目前沒有任務。"

func _current() -> Dictionary:
	for e in _shown:
		if String(e.get("id", "")) == selected_id:
			return e
	return {}

func _refresh_detail() -> void:
	var e := _current()
	var has := not e.is_empty()
	for n in _detail_root.get_children():
		if n != _empty_label:
			(n as CanvasItem).visible = has
	_empty_label.visible = not has
	if not has:
		_empty_label.text = _category_empty_text()
		return
	_title_label.text = String(e.get("title", "未命名任務"))
	_seal_label.text = "\n".join(Array(String(e.get("type", "支線")).split("")))      # 章是直的：一個字一行，上下排
	var status := String(e.get("status", "進行中"))
	_status_stamp.texture = _tex(String(STATUS_ART.get(status, "status_usable")))
	_status_label.text = status
	_status_label.add_theme_color_override("font_color", STATUS_TEXT_COLOR.get(status, Color.WHITE))
	_desc_text.text = String(e.get("description", "尚無任務描述。"))
	_goal_text.text = String(e.get("objective", "尚無明確目標。"))
	var note := String(e.get("note", "")).strip_edges()
	_note_text.text = note if note != "" else "（尚無）"
	_detail_scroll.scroll_vertical = 0

# ------------------------------------------------------------------
# 操作
# ------------------------------------------------------------------
func _on_category_pressed(id: String) -> void:
	category = id
	_apply_category()

func _on_row_pressed(id: String) -> void:
	selected_id = id
	_apply_category()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
