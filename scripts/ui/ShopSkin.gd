extends "res://scripts/inventory/StudyPageBase.gd"
# 商店的畫面：書房桌面＋大卷軸（與道具頁同一套素材與寫法）。只負責「畫」；商店的資料與買賣規則仍在 ShopUI.gd，
# 這裡把畫好的控制項交給 ShopUI（同名欄位），所以 ShopUI 的邏輯幾乎不用改。
# 版面（邏輯 px，1152×648）：左＝商品清單（購買／販賣切換在上方），右＝商品詳情，下＝結帳（販賣）與離開。

const LIST_POS := Vector2(200, 190)
const LIST_SIZE := Vector2(420, 372)
const ROW_H := 54
const DETAIL_X := 676.0

var shop: Node
var _paper_ok: Callable

func _ready() -> void:
	name = "ShopSkin"
	set_meta("skip_menu_skin", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

## 商店用「備案 1」前景（書、劍、茶壺、燈籠，與道具頁相同）
func _foreground_preset() -> String:
	return "demo"

## 建好畫面，並把 ShopUI 要用的控制項填進去
func build(owner_shop: Node) -> void:
	shop = owner_shop
	_build_background(true)
	# 標題牌與盤纏
	_panel("gold_plate", 28, 12, Vector2(676, 100), Vector2(300, 32))
	_image("icon_gold", Vector2(684, 102), Vector2(28, 28))
	shop.gold_label = _label("", Vector2(718, 100), Vector2(250, 30), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	shop.title_label = _label("商店", Vector2(200, 96), Vector2(400, 40), 30, INK, HORIZONTAL_ALIGNMENT_LEFT)
	# 購買／販賣切換：被選中的那顆是 disabled（用朱紅底素材當「選中」外觀）
	shop.mode_buy_button = _mode_button("購買", Vector2(200, 142))
	shop.mode_sell_button = _mode_button("販賣", Vector2(312, 142))
	# 清單
	_panel("list_header", 16, 4, Vector2(200, 180), Vector2(LIST_SIZE.x, 26))
	_label("商品", Vector2(260, 180), Vector2(70, 26), 15, INK_DIM)
	_label("數量", Vector2(520, 180), Vector2(80, 26), 15, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	shop.buy_scroll = ScrollContainer.new()
	shop.buy_scroll.position = LIST_POS + Vector2(0, 20)
	shop.buy_scroll.size = LIST_SIZE - Vector2(0, 20)
	shop.buy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(shop.buy_scroll)
	shop.buy_list_vbox = VBoxContainer.new()
	shop.buy_list_vbox.add_theme_constant_override("separation", 0)
	shop.buy_list_vbox.custom_minimum_size = Vector2(LIST_SIZE.x - 10, 0)
	shop.buy_scroll.add_child(shop.buy_list_vbox)
	_style_scrollbar(shop.buy_scroll)
	_panel("divider_v", 2, 4, Vector2(640, 180), Vector2(4, 384))
	# 詳情
	shop.info_name_label = _label("", Vector2(DETAIL_X, 150), Vector2(400, 40), 28, INK, HORIZONTAL_ALIGNMENT_LEFT)
	shop.info_price_label = _label("", Vector2(DETAIL_X, 196), Vector2(250, 26), 17, Color("#7A1C1C"), HORIZONTAL_ALIGNMENT_LEFT)
	shop.info_extra_label = _label("", Vector2(DETAIL_X, 226), Vector2(250, 26), 15, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_image("divider_h", Vector2(DETAIL_X, 258), Vector2(250, 4))
	_art_bg = _image("detail_art_bg_empty", Vector2(944, 190), Vector2(172, 240))
	_art = _image_from("", Vector2(952, 198), Vector2(156, 224), self)
	InkGlowScript.attach(_art)
	shop.info_desc_label = RichTextLabel.new()
	shop.info_desc_label.position = Vector2(DETAIL_X, 268)
	shop.info_desc_label.size = Vector2(250, 76)
	shop.info_desc_label.bbcode_enabled = true
	shop.info_desc_label.scroll_active = true
	shop.info_desc_label.add_theme_font_override("normal_font", FONT)
	shop.info_desc_label.add_theme_font_size_override("normal_font_size", 16)
	shop.info_desc_label.add_theme_color_override("default_color", INK)
	add_child(shop.info_desc_label)
	shop.info_effect_label = _label("", Vector2(DETAIL_X, 350), Vector2(250, 90), 16, Color("#2F5A2A"), HORIZONTAL_ALIGNMENT_LEFT)
	shop.info_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop.info_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# 底部按鈕
	shop.action_button = _tex_button(Vector2(165, 38), Vector2(440, 586), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16)
	shop.action_button.text = "結帳"
	shop.close_button = _tex_button(Vector2(165, 38), Vector2(620, 586), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	shop.close_button.text = "離開"
	# 舊版的單件數量控制（現在的買賣是逐列加減），保留欄位但不顯示
	shop.qty_minus_button = Button.new()
	shop.qty_plus_button = Button.new()
	shop.qty_label = Label.new()
	shop.item_list = ItemList.new()
	for c in [shop.qty_minus_button, shop.qty_plus_button, shop.qty_label, shop.item_list]:
		c.visible = false
		add_child(c)
	_build_toast()
	_build_overlay()
	shop.panel = self

func _mode_button(text: String, pos: Vector2) -> Button:
	var b := _tex_button(Vector2(104, 34), pos, "btn_normal", "btn_hover", "btn_pressed", "btn_primary_normal", 48, 16)
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	return b

func _style_scrollbar(sc: ScrollContainer) -> void:
	var bar := sc.get_v_scroll_bar()
	bar.custom_minimum_size.x = 8
	var track := _box("scroll_track", 2, 4)
	bar.add_theme_stylebox_override("scroll", track if track != null else StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("scroll_focus", track if track != null else StyleBoxEmpty.new())
	for pair in [["grabber", "scroll_thumb_normal"], ["grabber_highlight", "scroll_thumb_hover"], ["grabber_pressed", "scroll_thumb_drag"]]:
		var gb := _box(pair[1], 2, 4)
		bar.add_theme_stylebox_override(pair[0], gb if gb != null else StyleBoxEmpty.new())

## 一列商品：{row, name_btn（點了選中）, sub（價格／庫存小字）, minus, qty, plus}。購買與販賣共用
func make_row(item_id: String, item_name: String) -> Dictionary:
	var row := Control.new()
	row.custom_minimum_size = Vector2(LIST_SIZE.x - 10, ROW_H)
	var bg := Panel.new()
	bg.size = row.custom_minimum_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var normal := _box("row_normal", 16, 4)
	bg.add_theme_stylebox_override("panel", normal if normal != null else StyleBoxEmpty.new())
	row.add_child(bg)
	var name_btn := Button.new()
	name_btn.position = Vector2.ZERO
	name_btn.size = Vector2(row.custom_minimum_size.x - 130, ROW_H)
	name_btn.flat = true
	name_btn.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		name_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	row.add_child(name_btn)
	var sel := ColorRect.new()
	sel.name = "Sel"
	sel.color = Color(0.95, 0.72, 0.20, 0.0)
	sel.size = row.custom_minimum_size
	sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sel)
	row.set_meta("item_id", item_id)
	var glow := ColorRect.new()
	glow.color = Color(0.95, 0.78, 0.30, 0.0)
	glow.size = Vector2(row.custom_minimum_size.x - 130, ROW_H)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glow)
	name_btn.mouse_entered.connect(func(): glow.color.a = 0.18)
	name_btn.mouse_exited.connect(func(): glow.color.a = 0.0)
	var def := ItemDB.get_def(item_id)
	var icon := _image_from(ItemIconMap.icon_path(item_id, def), Vector2(8, 6), Vector2(42, 42), row)
	InkGlowScript.attach(icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := _label(item_name, Vector2(58, 3), Vector2(220, 28), 18, INK, HORIZONTAL_ALIGNMENT_LEFT, row)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub := _label("", Vector2(58, 29), Vector2(260, 20), 13, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, row)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var minus := _round_button("－", Vector2(row.custom_minimum_size.x - 118, 11), row)
	var qty := _label("0", Vector2(row.custom_minimum_size.x - 86, 11), Vector2(40, 30), 18, INK, HORIZONTAL_ALIGNMENT_CENTER, row)
	var plus := _round_button("＋", Vector2(row.custom_minimum_size.x - 44, 11), row)
	return {"row": row, "name_btn": name_btn, "sub": sub, "minus": minus, "qty": qty, "plus": plus}

func _round_button(text: String, pos: Vector2, parent: Node) -> Button:
	var b := _tex_button(Vector2(32, 32), pos, "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 12, 8, parent)
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	return b

# ------------------------------------------------------------------
# 確認與提示：宣紙卷軸視窗（與武術頁的視窗同一張卷軸）
# ------------------------------------------------------------------
func ask(text: String, on_ok: Callable) -> void:
	_paper_ok = on_ok
	_clear_overlay()
	_overlay.visible = true
	var pos := Vector2(216, 124)
	var size := Vector2(720, 400)
	var scroll := _image("scroll_body", pos, size, _overlay)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_label("請確認", pos + Vector2(140, 52), Vector2(300, 34), 24, Color("#5A3208"), HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	var body := _label(text, pos + Vector2(140, 96), Vector2(400, 190), 17, INK, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var ok := _tex_button(Vector2(160, 40), pos + Vector2(140, size.y - 80), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, _overlay)
	ok.text = "確定"
	var cancel := _tex_button(Vector2(160, 40), pos + Vector2(320, size.y - 80), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	cancel.text = "取消"
	ok.pressed.connect(func():
		var cb := _paper_ok
		_close_overlay()
		if cb.is_valid():
			cb.call())
	cancel.pressed.connect(_close_overlay)

func notice(text: String) -> void:
	show_toast(text)

var _art_bg: TextureRect
var _art: TextureRect

## 右側的商品大圖
func set_art(item_id: String) -> void:
	if _art == null:
		return
	_art_bg.visible = item_id != ""
	if item_id == "":
		_art.texture = null
		return
	var def := ItemDB.get_def(item_id)
	var p := ItemIconMap.art_path(item_id, def)
	_art.texture = load(p) as Texture2D if ResourceLoader.exists(p) else null

## 選中的那一列加金色底
func highlight_row(item_id: String) -> void:
	if shop == null or shop.buy_list_vbox == null:
		return
	for r in shop.buy_list_vbox.get_children():
		var sel := r.get_node_or_null("Sel") as ColorRect
		if sel != null:
			sel.color.a = 0.28 if String(r.get_meta("item_id", "")) == item_id else 0.0
