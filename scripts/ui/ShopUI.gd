extends CanvasLayer
class_name ShopUI

const ShopDatabaseScript = preload("res://scripts/db/ShopDatabase.gd")
const MenuUIFont = preload("res://assets/fonts/UIFontKaiti.tres")
const ShopSkinScript = preload("res://scripts/ui/ShopSkin.gd")

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

var panel: Control
var _skin: Control
var title_label: Label
var gold_label: Label
var item_list: ItemList
var buy_scroll: ScrollContainer
var buy_list_vbox: VBoxContainer
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
	_skin = ShopSkinScript.new()
	add_child(_skin)
	_skin.build(self)
	mode_buy_button.pressed.connect(func(): _set_mode("buy"))
	mode_sell_button.pressed.connect(func(): _set_mode("sell"))
	action_button.pressed.connect(_on_action_pressed)
	close_button.pressed.connect(_close_shop)
	qty_minus_button.pressed.connect(_on_qty_minus_pressed)
	qty_plus_button.pressed.connect(_on_qty_plus_pressed)
	item_list.item_selected.connect(_on_item_selected)

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
		var parts: Dictionary = _skin.make_row(item_id, _item_name(item_id))
		var row: Control = parts["row"]
		buy_list_vbox.add_child(row)
		var name_btn: Button = parts["name_btn"]
		var stock_text := "∞" if runtime_stock < 0 else str(runtime_stock)
		(parts["sub"] as Label).text = "%d文｜庫存:%s" % [price, stock_text]
		name_btn.pressed.connect(func():
			_selected_entry = metadata.duplicate(true)
			_update_info_panel(_selected_entry)
		)
		var minus_btn: Button = parts["minus"]
		var qty_label_row: Label = parts["qty"]
		qty_label_row.text = str(int(_buy_cart.get(item_id, 0)))
		var plus_btn: Button = parts["plus"]
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
		var parts: Dictionary = _skin.make_row(item_id, _item_name(item_id))
		var row: Control = parts["row"]
		buy_list_vbox.add_child(row)
		var name_btn: Button = parts["name_btn"]
		var equipped_text := "（已裝備）" if equipped_blocked else ""
		(parts["sub"] as Label).text = "持有:%d｜回收:%d文%s" % [quantity, sell_price, equipped_text]
		name_btn.pressed.connect(func():
			_selected_entry = metadata.duplicate(true)
			_update_info_panel(_selected_entry)
		)
		var minus_btn: Button = parts["minus"]
		var qty_label_row: Label = parts["qty"]
		qty_label_row.text = str(int(_sell_cart.get(item_id, 0)))
		var plus_btn: Button = parts["plus"]
		plus_btn.disabled = equipped_blocked
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
	_skin.set_art(String(entry.get("item_id", "")))
	_skin.highlight_row(String(entry.get("item_id", "")))
	if info_name_label == null or info_price_label == null or info_desc_label == null or info_extra_label == null or info_effect_label == null:
		return
	if entry.is_empty():
		info_name_label.text = "請選擇商品"
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
	info_name_label.text = item_name
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
	_skin.notice(text)

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
		_skin.ask("是否購買以下商品？\n\n%s\n\n總計：%d 文" % ["\n".join(lines), total_cost], _on_confirmed)
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
	_skin.ask("是否販賣以下商品？\n\n%s\n\n總計：%d 文" % ["\n".join(sell_lines), total_gain], _on_confirmed)

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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		_close_shop()

func _close_shop() -> void:
	emit_signal("closed")
	queue_free()
