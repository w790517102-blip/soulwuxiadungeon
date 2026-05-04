extends CanvasLayer
class_name ShopUI

const ShopDatabaseScript = preload("res://scripts/db/ShopDatabase.gd")
const MenuUIFont = preload("res://assets/fonts/DotGothic16-Regular.ttf")

var _shop_db: Node = ShopDatabaseScript.new()
var _shop_id := ""
var _shop_data: Dictionary = {}
var _buyer = null
var _mode: String = "buy"
var _pending_item: Dictionary = {}
var _selected_entry: Dictionary = {}
var _selected_max_qty: int = 1
var _buy_cart: Dictionary = {}
var _buy_entries: Dictionary = {}
var _sell_cart: Dictionary = {}
var _sell_entries: Dictionary = {}

var panel: Panel
var title_label: Label
var gold_label: Label
var item_list: ItemList
var buy_scroll: ScrollContainer
var buy_list_vbox: VBoxContainer
var info_panel: PanelContainer
var info_name_label: Label
var info_price_label: Label
var info_desc_label: RichTextLabel
var info_extra_label: Label
var info_effect_label: Label
var mode_buy_button: Button
var mode_sell_button: Button
var action_button: Button
var close_button: Button
var qty_label: Label
var qty_minus_button: Button
var qty_plus_button: Button
var confirm_dialog: ConfirmationDialog
var notice_dialog: AcceptDialog

static func open_shop(shop_id: String, buyer = null) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var ui := ShopUI.new()
	ui._shop_id = shop_id
	ui._buyer = buyer
	tree.root.add_child(ui)
	await ui.closed

signal closed

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_shop_data = _shop_db.get_shop(_shop_id) if _shop_db and _shop_db.has_method("get_shop") else {}
	if _shop_data.is_empty():
		title_label.text = "商店未開放"
		action_button.disabled = true
		mode_buy_button.disabled = true
		mode_sell_button.disabled = true
		_update_info_panel({})
		return
	title_label.text = String(_shop_data.get("name", _shop_id))
	_set_mode("buy")
	_refresh_gold()

func _build_ui() -> void:
	panel = Panel.new()
	panel.size = Vector2(820, 530)
	panel.position = (get_viewport().get_visible_rect().size - panel.size) * 0.5
	add_child(panel)

	var vb = VBoxContainer.new()
	vb.anchor_right = 1
	vb.anchor_bottom = 1
	vb.offset_left = 12
	vb.offset_top = 12
	vb.offset_right = -12
	vb.offset_bottom = -12
	panel.add_child(vb)

	title_label = Label.new()
	title_label.text = "商店"
	vb.add_child(title_label)

	gold_label = Label.new()
	vb.add_child(gold_label)

	var mode_hb := HBoxContainer.new()
	vb.add_child(mode_hb)
	mode_buy_button = Button.new()
	mode_buy_button.text = "購買"
	mode_hb.add_child(mode_buy_button)
	mode_sell_button = Button.new()
	mode_sell_button.text = "販賣"
	mode_hb.add_child(mode_sell_button)

	var content_hb := HBoxContainer.new()
	content_hb.custom_minimum_size = Vector2(0, 270)
	vb.add_child(content_hb)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(360, 270)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hb.add_child(list_panel)

	var list_stack := VBoxContainer.new()
	list_stack.anchor_right = 1
	list_stack.anchor_bottom = 1
	list_stack.offset_left = 13
	list_stack.offset_top = 13
	list_stack.offset_right = -13
	list_stack.offset_bottom = -13
	list_panel.add_child(list_stack)

	buy_scroll = ScrollContainer.new()
	buy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_stack.add_child(buy_scroll)

	buy_list_vbox = VBoxContainer.new()
	buy_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.add_child(buy_list_vbox)

	item_list = ItemList.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.visible = false
	item_list.add_theme_font_override("font", MenuUIFont)
	item_list.add_theme_font_size_override("font_size", 18)
	item_list.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	item_list.add_theme_constant_override("outline_size", 4)
	list_stack.add_child(item_list)

	info_panel = PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(250, 270)
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hb.add_child(info_panel)

	var info_vb := VBoxContainer.new()
	info_vb.anchor_right = 1
	info_vb.anchor_bottom = 1
	info_vb.offset_left = 10
	info_vb.offset_top = 10
	info_vb.offset_right = -10
	info_vb.offset_bottom = -10
	info_panel.add_child(info_vb)

	info_name_label = Label.new()
	info_name_label.text = "名稱：-"
	info_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vb.add_child(info_name_label)

	info_price_label = Label.new()
	info_price_label.text = "價格：-"
	info_price_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vb.add_child(info_price_label)

	info_extra_label = Label.new()
	info_extra_label.text = "備註：-"
	info_extra_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vb.add_child(info_extra_label)

	var desc_margin := MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 5)
	desc_margin.add_theme_constant_override("margin_top", 5)
	desc_margin.add_theme_constant_override("margin_right", 5)
	desc_margin.add_theme_constant_override("margin_bottom", 5)
	desc_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vb.add_child(desc_margin)

	info_desc_label = RichTextLabel.new()
	info_desc_label.bbcode_enabled = true
	info_desc_label.fit_content = true
	info_desc_label.scroll_active = false
	info_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_desc_label.custom_minimum_size = Vector2(0, 130)
	desc_margin.add_child(info_desc_label)

	info_effect_label = Label.new()
	info_effect_label.text = "效果：-"
	info_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vb.add_child(info_effect_label)

	var action_hb := HBoxContainer.new()
	vb.add_child(action_hb)

	qty_minus_button = Button.new()
	qty_minus_button.text = "-"
	action_hb.add_child(qty_minus_button)

	qty_label = Label.new()
	qty_label.text = "數量: 1"
	qty_label.custom_minimum_size = Vector2(92, 0)
	action_hb.add_child(qty_label)

	qty_plus_button = Button.new()
	qty_plus_button.text = "+"
	action_hb.add_child(qty_plus_button)

	action_button = Button.new()
	action_button.text = "購買"
	action_hb.add_child(action_button)

	close_button = Button.new()
	close_button.text = "離開"
	action_hb.add_child(close_button)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "確認"
	confirm_dialog.add_theme_font_override("font", MenuUIFont)
	confirm_dialog.add_theme_font_size_override("font_size", 18)
	confirm_dialog.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	confirm_dialog.add_theme_constant_override("outline_size", 4)
	confirm_dialog.about_to_popup.connect(_apply_confirm_dialog_style)
	panel.add_child(confirm_dialog)

	notice_dialog = AcceptDialog.new()
	notice_dialog.title = "提示"
	panel.add_child(notice_dialog)

	mode_buy_button.pressed.connect(func(): _set_mode("buy"))
	mode_sell_button.pressed.connect(func(): _set_mode("sell"))
	action_button.pressed.connect(_on_action_pressed)
	close_button.pressed.connect(_close_shop)
	qty_minus_button.pressed.connect(_on_qty_minus_pressed)
	qty_plus_button.pressed.connect(_on_qty_plus_pressed)
	item_list.item_selected.connect(_on_item_selected)
	confirm_dialog.confirmed.connect(_on_confirmed)
	_apply_shop_font_style(panel)
	_apply_confirm_dialog_style()

func _apply_shop_font_style(root: Node) -> void:
	if root is Control:
		var ctrl := root as Control
		ctrl.add_theme_font_override("font", MenuUIFont)
		ctrl.add_theme_font_size_override("font_size", 18)
		ctrl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		ctrl.add_theme_constant_override("outline_size", 4)
		if ctrl is RichTextLabel:
			ctrl.add_theme_font_override("normal_font", MenuUIFont)
			ctrl.add_theme_font_size_override("normal_font_size", 18)
	for child in root.get_children():
		_apply_shop_font_style(child)

func _apply_confirm_dialog_style() -> void:
	if confirm_dialog == null:
		return
	confirm_dialog.add_theme_font_override("font", MenuUIFont)
	confirm_dialog.add_theme_font_size_override("font_size", 18)
	confirm_dialog.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	confirm_dialog.add_theme_constant_override("outline_size", 4)
	var text_label := confirm_dialog.get_label()
	if text_label:
		text_label.add_theme_font_override("font", MenuUIFont)
		text_label.add_theme_font_size_override("font_size", 18)
		text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		text_label.add_theme_constant_override("outline_size", 4)
	var ok_btn := confirm_dialog.get_ok_button()
	if ok_btn:
		ok_btn.add_theme_font_override("font", MenuUIFont)
		ok_btn.add_theme_font_size_override("font_size", 18)
		ok_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		ok_btn.add_theme_constant_override("outline_size", 4)
	if confirm_dialog.has_method("get_cancel_button"):
		var cancel_btn = confirm_dialog.get_cancel_button()
		if cancel_btn:
			cancel_btn.add_theme_font_override("font", MenuUIFont)
			cancel_btn.add_theme_font_size_override("font_size", 18)
			cancel_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			cancel_btn.add_theme_constant_override("outline_size", 4)

func _set_mode(mode: String) -> void:
	_mode = mode if ["buy", "sell"].has(mode) else "buy"
	action_button.text = "結帳" if _mode == "buy" else "販賣"
	mode_buy_button.disabled = _mode == "buy"
	mode_sell_button.disabled = _mode == "sell"
	if buy_scroll:
		buy_scroll.visible = true
	if item_list:
		item_list.visible = false
	if qty_minus_button:
		qty_minus_button.visible = false
	if qty_plus_button:
		qty_plus_button.visible = false
	if qty_label:
		qty_label.visible = false
	_selected_entry.clear()
	_selected_max_qty = 1
	_pending_item.clear()
	_buy_cart.clear()
	_buy_entries.clear()
	_sell_cart.clear()
	_sell_entries.clear()
	_refresh_items()
	_update_qty_label()
	_update_info_panel(_selected_entry)

func _refresh_gold() -> void:
	var g := InventorySync.get_gold() if InventorySync else 0
	gold_label.text = "盤纏：%d文" % g

func _item_name(item_id: String) -> String:
	var d := ItemDB.get_def(item_id)
	if d.is_empty():
		return item_id
	return String(d.get("name", item_id))

func _runtime_stock_key(item_id: String) -> String:
	return "%s::%s" % [_shop_id, item_id]

func _template_stock(entry: Dictionary) -> int:
	return int(entry.get("stock", -1))

func _get_runtime_stock(item_id: String, entry: Dictionary) -> int:
	var template_stock := _template_stock(entry)
	if template_stock < 0:
		return -1
	# finite stock items in current towns are designed as non-restocking
	if GlobalState == null:
		return template_stock
	var key := _runtime_stock_key(item_id)
	if not GlobalState.shop_runtime_stock.has(key):
		GlobalState.shop_runtime_stock[key] = template_stock
	return int(GlobalState.shop_runtime_stock.get(key, template_stock))

func _set_runtime_stock(item_id: String, new_stock: int) -> void:
	if GlobalState == null:
		return
	var key := _runtime_stock_key(item_id)
	GlobalState.shop_runtime_stock[key] = max(new_stock, 0)

func _refresh_items() -> void:
	if _mode == "buy":
		_refresh_buy_items()
		var has_cart_items := _buy_cart.values().any(func(v): return int(v) > 0)
		action_button.disabled = not has_cart_items
	else:
		_refresh_sell_items()
		var has_sell_items := _sell_cart.values().any(func(v): return int(v) > 0)
		action_button.disabled = not has_sell_items
	qty_minus_button.disabled = true
	qty_plus_button.disabled = true
	if _selected_entry.is_empty():
		_update_info_panel({})
	else:
		_update_info_panel(_selected_entry)
	_update_qty_label()

func _refresh_buy_items() -> void:
	for child in buy_list_vbox.get_children():
		child.queue_free()
	var entries: Array = _shop_data.get("items", [])
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id := String((entry as Dictionary).get("item_id", ""))
		if item_id == "":
			continue
		var price := int((entry as Dictionary).get("price", 0))
		var runtime_stock := _get_runtime_stock(item_id, entry)
		var metadata := (entry as Dictionary).duplicate(true)
		metadata["runtime_stock"] = runtime_stock
		_buy_entries[item_id] = metadata
		if not _buy_cart.has(item_id):
			_buy_cart[item_id] = 0
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_list_vbox.add_child(row)
		var name_btn := Button.new()
		name_btn.flat = true
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_cart_list_text_style(name_btn)
		var stock_text := "∞" if runtime_stock < 0 else str(runtime_stock)
		name_btn.text = "%s｜%d文｜庫存:%s" % [_item_name(item_id), price, stock_text]
		name_btn.pressed.connect(func():
			_selected_entry = metadata.duplicate(true)
			_update_info_panel(_selected_entry)
		)
		row.add_child(name_btn)
		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(28, 0)
		_apply_cart_list_text_style(minus_btn)
		row.add_child(minus_btn)
		var qty_label_row := Label.new()
		qty_label_row.custom_minimum_size = Vector2(34, 0)
		qty_label_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label_row.text = str(int(_buy_cart.get(item_id, 0)))
		_apply_cart_list_text_style(qty_label_row)
		row.add_child(qty_label_row)
		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(28, 0)
		_apply_cart_list_text_style(plus_btn)
		row.add_child(plus_btn)
		minus_btn.pressed.connect(func():
			var qty: int = max(int(_buy_cart.get(item_id, 0)) - 1, 0)
			_buy_cart[item_id] = qty
			qty_label_row.text = str(qty)
			action_button.disabled = not _buy_cart.values().any(func(v): return int(v) > 0)
		)
		plus_btn.pressed.connect(func():
			var qty: int = int(_buy_cart.get(item_id, 0))
			if runtime_stock >= 0 and qty >= runtime_stock:
				return
			_buy_cart[item_id] = qty + 1
			qty_label_row.text = str(qty + 1)
			action_button.disabled = false
		)

func _refresh_sell_items() -> void:
	for child in buy_list_vbox.get_children():
		child.queue_free()
	if InventorySync == null:
		return
	var first_entry := {}
	for item in InventorySync.get_items():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String((item as Dictionary).get("id", ""))
		if item_id == "":
			continue
		var item_def := ItemDB.get_def(item_id)
		if item_def.is_empty():
			continue
		if not bool(item_def.get("can_sell", true)):
			continue
		var quantity := int((item as Dictionary).get("quantity", (item as Dictionary).get("count", 0)))
		if quantity <= 0:
			continue
		var base_price := int(item_def.get("base_price", item_def.get("price", 0)))
		if base_price <= 0:
			continue
		var sell_price := int(floor(float(base_price) * 0.4))
		if sell_price <= 0:
			continue
		var equipped_blocked := InventorySync.has_method("is_item_equipped_anywhere") and InventorySync.is_item_equipped_anywhere(item_id)
		var metadata := {
			"item_id": item_id,
			"base_price": base_price,
			"sell_price": sell_price,
			"quantity": quantity,
			"equipped_blocked": equipped_blocked,
		}
		_sell_entries[item_id] = metadata
		if not _sell_cart.has(item_id):
			_sell_cart[item_id] = 0
		if first_entry.is_empty():
			first_entry = metadata.duplicate(true)
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_list_vbox.add_child(row)
		var name_btn := Button.new()
		name_btn.flat = true
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_cart_list_text_style(name_btn)
		var equipped_text := "（已裝備）" if equipped_blocked else ""
		name_btn.text = "%s｜持有:%d｜回收:%d文%s" % [_item_name(item_id), quantity, sell_price, equipped_text]
		name_btn.pressed.connect(func():
			_selected_entry = metadata.duplicate(true)
			_update_info_panel(_selected_entry)
		)
		row.add_child(name_btn)
		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(28, 0)
		_apply_cart_list_text_style(minus_btn)
		row.add_child(minus_btn)
		var qty_label_row := Label.new()
		qty_label_row.custom_minimum_size = Vector2(34, 0)
		qty_label_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label_row.text = str(int(_sell_cart.get(item_id, 0)))
		_apply_cart_list_text_style(qty_label_row)
		row.add_child(qty_label_row)
		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(28, 0)
		plus_btn.disabled = equipped_blocked
		_apply_cart_list_text_style(plus_btn)
		row.add_child(plus_btn)
		minus_btn.pressed.connect(func():
			var qty: int = max(int(_sell_cart.get(item_id, 0)) - 1, 0)
			_sell_cart[item_id] = qty
			qty_label_row.text = str(qty)
			action_button.disabled = not _sell_cart.values().any(func(v): return int(v) > 0)
		)
		plus_btn.pressed.connect(func():
			if equipped_blocked:
				return
			var qty: int = int(_sell_cart.get(item_id, 0))
			if qty >= quantity:
				return
			_sell_cart[item_id] = qty + 1
			qty_label_row.text = str(qty + 1)
			action_button.disabled = false
		)
	if not first_entry.is_empty():
		_selected_entry = (first_entry as Dictionary).duplicate(true)
		_update_info_panel(_selected_entry)

func _on_item_selected(index: int) -> void:
	var entry = item_list.get_item_metadata(index)
	if typeof(entry) != TYPE_DICTIONARY:
		_selected_entry.clear()
		_selected_max_qty = 1
		_update_qty_label()
		_update_info_panel({})
		return
	_selected_entry = (entry as Dictionary).duplicate(true)
	var selected_qty := int(_selected_entry.get("selected_qty", 1))
	var max_qty := _compute_max_qty(_selected_entry)
	_selected_max_qty = max_qty
	if _selected_max_qty <= 0:
		_selected_entry["selected_qty"] = 1
	else:
		_selected_entry["selected_qty"] = clamp(selected_qty, 1, _selected_max_qty)
	action_button.disabled = _selected_max_qty <= 0
	_update_qty_label()
	_update_info_panel(_selected_entry)

func _update_info_panel(entry: Dictionary) -> void:
	if info_name_label == null or info_price_label == null or info_desc_label == null or info_extra_label == null or info_effect_label == null:
		return
	if entry.is_empty():
		info_name_label.text = "名稱：-"
		info_price_label.text = "價格：-"
		info_extra_label.text = "備註：請先選擇商品"
		info_desc_label.text = "描述：-"
		info_effect_label.text = "效果：-"
		return
	var item_id := String(entry.get("item_id", ""))
	var item_def := ItemDB.get_def(item_id) if item_id != "" else {}
	var item_name := String(item_def.get("name", item_id))
	var item_desc := String(item_def.get("desc", ""))
	var item_effect := ItemDB.get_effect_display_text(item_def)
	if item_desc == "":
		item_desc = "（尚無描述）"
	info_name_label.text = "名稱：%s" % item_name
	var type_text := _item_type_display_name(String(item_def.get("type", "-")))
	if _mode == "buy":
		info_price_label.text = "價格：%d 文" % int(entry.get("price", 0))
		var runtime_stock := int(entry.get("runtime_stock", int(entry.get("stock", -1))))
		var stock_text := "∞" if runtime_stock < 0 else str(runtime_stock)
		info_extra_label.text = "備註：庫存 %s｜類型：%s" % [stock_text, type_text]
	else:
		info_price_label.text = "回收：%d 文" % int(entry.get("sell_price", 0))
		var equipped_text := "（已裝備，暫不可賣）" if bool(entry.get("equipped_blocked", false)) else ""
		var sell_note := "持有 %d" % int(entry.get("quantity", 0))
		if equipped_text != "":
			sell_note += " " + equipped_text
		info_extra_label.text = "備註：%s｜類型：%s" % [sell_note, type_text]
	info_desc_label.text = "描述：%s" % item_desc
	info_effect_label.text = "效果：%s" % item_effect

func _item_type_display_name(item_type: String) -> String:
	match item_type:
		"equipment":
			return "裝備"
		"consumable":
			return "消耗"
		"material":
			return "材料"
		"tool":
			return "器具"
		"food":
			return "食物"
		"misc":
			return "雜項"
		"quest":
			return "任務"
		_:
			return item_type

func _apply_cart_list_text_style(ctrl: Control) -> void:
	if ctrl == null:
		return
	ctrl.add_theme_font_override("font", MenuUIFont)
	ctrl.add_theme_font_size_override("font_size", 18)
	ctrl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	ctrl.add_theme_constant_override("outline_size", 4)

func _compute_max_qty(entry: Dictionary) -> int:
	if _mode == "buy":
		var price := int(entry.get("price", 0))
		if price <= 0 or InventorySync == null:
			return 0
		var by_gold := int(floor(float(InventorySync.get_gold()) / float(price)))
		var runtime_stock := int(entry.get("runtime_stock", int(entry.get("stock", -1))))
		if runtime_stock < 0:
			return by_gold
		return min(runtime_stock, by_gold)
	var quantity := int(entry.get("quantity", 0))
	return max(quantity, 1)

func _update_qty_label() -> void:
	var qty := 1
	if not _selected_entry.is_empty():
		qty = int(_selected_entry.get("selected_qty", 1))
	qty_label.text = "數量: %d" % qty
	if _selected_entry.is_empty() or _selected_max_qty <= 1:
		qty_minus_button.disabled = true
		qty_plus_button.disabled = true
		return
	qty_minus_button.disabled = qty <= 1
	qty_plus_button.disabled = qty >= _selected_max_qty

func _on_qty_minus_pressed() -> void:
	if _selected_entry.is_empty():
		return
	var qty := int(_selected_entry.get("selected_qty", 1))
	qty = max(qty - 1, 1)
	_selected_entry["selected_qty"] = qty
	_update_qty_label()

func _on_qty_plus_pressed() -> void:
	if _selected_entry.is_empty():
		return
	var qty := int(_selected_entry.get("selected_qty", 1))
	qty = min(qty + 1, _selected_max_qty)
	_selected_entry["selected_qty"] = qty
	_update_qty_label()

func _show_notice(text: String) -> void:
	notice_dialog.dialog_text = text
	notice_dialog.popup_centered()

func _on_action_pressed() -> void:
	if _mode == "buy":
		_pending_item.clear()
		var lines: Array[String] = []
		var total_cost := 0
		for item_id in _buy_cart.keys():
			var qty := int(_buy_cart.get(item_id, 0))
			if qty <= 0:
				continue
			var entry: Dictionary = (_buy_entries.get(item_id, {}) as Dictionary).duplicate(true)
			if entry.is_empty():
				continue
			entry["selected_qty"] = qty
			_pending_item[item_id] = entry
			var price := int(entry.get("price", 0))
			total_cost += price * qty
			lines.append("• %s × %d（%d文）" % [_item_name(item_id), qty, price * qty])
		if _pending_item.is_empty():
			_show_notice("請先選擇要購買的商品。")
			return
		confirm_dialog.dialog_text = "是否購買以下商品？\n\n%s\n\n總計：%d 文" % ["\n".join(lines), total_cost]
		confirm_dialog.popup_centered()
		return
	_pending_item.clear()
	var sell_lines: Array[String] = []
	var total_gain := 0
	for item_id in _sell_cart.keys():
		var qty := int(_sell_cart.get(item_id, 0))
		if qty <= 0:
			continue
		var sell_entry: Dictionary = (_sell_entries.get(item_id, {}) as Dictionary).duplicate(true)
		if sell_entry.is_empty():
			continue
		if bool(sell_entry.get("equipped_blocked", false)):
			continue
		var owned := int(sell_entry.get("quantity", 0))
		qty = min(qty, owned)
		if qty <= 0:
			continue
		sell_entry["selected_qty"] = qty
		_pending_item[item_id] = sell_entry
		var sell_price := int(sell_entry.get("sell_price", 0))
		total_gain += sell_price * qty
		sell_lines.append("• %s × %d（%d文）" % [_item_name(item_id), qty, sell_price * qty])
	if _pending_item.is_empty():
		_show_notice("請先選擇要販賣的商品。")
		return
	confirm_dialog.dialog_text = "是否販賣以下商品？\n\n%s\n\n總計：%d 文" % ["\n".join(sell_lines), total_gain]
	confirm_dialog.popup_centered()

func _on_confirmed() -> void:
	if _mode == "buy":
		if _pending_item.is_empty():
			return
		_execute_buy_cart(_pending_item)
	else:
		if _pending_item.is_empty():
			return
		_execute_sell_cart(_pending_item)
	_pending_item.clear()

func _execute_buy_cart(cart_entries: Dictionary) -> void:
	if InventorySync == null:
		return
	var total_cost := 0
	for item_id in cart_entries.keys():
		var entry_any: Variant = cart_entries.get(item_id, {})
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry_any as Dictionary
		var qty: int = max(int(d.get("selected_qty", 0)), 0)
		var runtime_stock: int = int(d.get("runtime_stock", int(d.get("stock", -1))))
		if runtime_stock >= 0:
			qty = min(qty, runtime_stock)
		if qty <= 0:
			continue
		total_cost += int(d.get("price", 0)) * qty
	if total_cost <= 0:
		_show_notice("沒有可購買的品項。")
		return
	if InventorySync.get_gold() < total_cost:
		_show_notice("盤纏不足。")
		return
	if not InventorySync.spend_gold(total_cost, false):
		_show_notice("盤纏不足。")
		return
	for item_id in cart_entries.keys():
		var entry_any: Variant = cart_entries.get(item_id, {})
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry_any as Dictionary
		var qty: int = max(int(d.get("selected_qty", 0)), 0)
		var runtime_stock: int = int(d.get("runtime_stock", int(d.get("stock", -1))))
		if runtime_stock >= 0:
			qty = min(qty, runtime_stock)
		if qty <= 0:
			continue
		InventorySync.add_item_stack(item_id, qty, false)
		if runtime_stock > 0:
			_set_runtime_stock(item_id, runtime_stock - qty)
		_buy_cart[item_id] = 0
	_refresh_gold()
	_refresh_items()

func _execute_buy(entry: Dictionary) -> void:
	var item_id := String(entry.get("item_id", ""))
	var price := int(entry.get("price", 0))
	var qty = max(int(entry.get("selected_qty", 1)), 1)
	if item_id == "" or InventorySync == null or price <= 0:
		return
	var runtime_stock := int(entry.get("runtime_stock", int(entry.get("stock", -1))))
	if runtime_stock == 0:
		_show_notice("此商品已售完。")
		return
	if runtime_stock > 0:
		qty = min(qty, runtime_stock)
	var affordable := int(floor(float(InventorySync.get_gold()) / float(price)))
	qty = min(qty, affordable)
	if qty <= 0:
		_show_notice("盤纏不足。")
		return
	if not InventorySync.spend_gold(price * qty, false):
		_show_notice("盤纏不足。")
		return

	InventorySync.add_item_stack(item_id, qty, false)
	if runtime_stock > 0:
		_set_runtime_stock(item_id, runtime_stock - qty)

	_refresh_gold()
	_refresh_items()

func _execute_sell(entry: Dictionary) -> void:
	if InventorySync == null:
		return
	var item_id := String(entry.get("item_id", ""))
	var sell_price := int(entry.get("sell_price", 0))
	var qty = max(int(entry.get("selected_qty", 1)), 1)
	if item_id == "" or sell_price <= 0:
		return
	if bool(entry.get("equipped_blocked", false)):
		_show_notice("請先解除裝備後再販賣。")
		return
	var owned := InventorySync.get_item_by_id(item_id)
	var count := int(owned.get("count", owned.get("quantity", 0)))
	if count <= 0:
		_show_notice("物品不足。")
		return
	qty = min(qty, count)
	InventorySync.consume_item(item_id, qty, false)
	InventorySync.add_gold(sell_price * qty, false)
	_refresh_gold()
	_refresh_items()

func _execute_sell_cart(cart_entries: Dictionary) -> void:
	if InventorySync == null:
		return
	var total_gain := 0
	for item_id in cart_entries.keys():
		var entry_any: Variant = cart_entries.get(item_id, {})
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry_any as Dictionary
		if bool(d.get("equipped_blocked", false)):
			continue
		var qty: int = max(int(d.get("selected_qty", 0)), 0)
		var owned := int(d.get("quantity", 0))
		qty = min(qty, owned)
		if qty <= 0:
			continue
		total_gain += int(d.get("sell_price", 0)) * qty
	if total_gain <= 0:
		_show_notice("沒有可販賣的品項。")
		return
	for item_id in cart_entries.keys():
		var entry_any: Variant = cart_entries.get(item_id, {})
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry_any as Dictionary
		if bool(d.get("equipped_blocked", false)):
			continue
		var qty: int = max(int(d.get("selected_qty", 0)), 0)
		var owned := int(d.get("quantity", 0))
		qty = min(qty, owned)
		if qty <= 0:
			continue
		InventorySync.consume_item(item_id, qty, false)
		InventorySync.add_gold(int(d.get("sell_price", 0)) * qty, false)
		_sell_cart[item_id] = 0
	_refresh_gold()
	_refresh_items()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_shop()

func _close_shop() -> void:
	emit_signal("closed")
	queue_free()
