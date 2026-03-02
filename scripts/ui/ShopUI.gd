extends CanvasLayer
class_name ShopUI

const ShopDatabaseScript = preload("res://scripts/db/ShopDatabase.gd")

var _shop_db: Node = ShopDatabaseScript.new()
var _shop_id := ""
var _shop_data: Dictionary = {}
var _buyer = null
var _mode: String = "buy"
var _pending_item: Dictionary = {}

var panel: Panel
var title_label: Label
var gold_label: Label
var item_list: ItemList
var mode_buy_button: Button
var mode_sell_button: Button
var action_button: Button
var close_button: Button
var confirm_dialog: ConfirmationDialog

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
		return
	title_label.text = String(_shop_data.get("name", _shop_id))
	_set_mode("buy")
	_refresh_gold()

func _build_ui() -> void:
	panel = Panel.new()
	panel.size = Vector2(560, 400)
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

	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(0, 260)
	vb.add_child(item_list)

	var hb = HBoxContainer.new()
	vb.add_child(hb)

	action_button = Button.new()
	action_button.text = "購買"
	hb.add_child(action_button)

	close_button = Button.new()
	close_button.text = "離開"
	hb.add_child(close_button)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "確認"
	panel.add_child(confirm_dialog)

	mode_buy_button.pressed.connect(func(): _set_mode("buy"))
	mode_sell_button.pressed.connect(func(): _set_mode("sell"))
	action_button.pressed.connect(_on_action_pressed)
	close_button.pressed.connect(_close_shop)
	confirm_dialog.confirmed.connect(_on_confirmed)

func _set_mode(mode: String) -> void:
	_mode = mode if ["buy", "sell"].has(mode) else "buy"
	action_button.text = "購買" if _mode == "buy" else "販賣"
	mode_buy_button.disabled = _mode == "buy"
	mode_sell_button.disabled = _mode == "sell"
	_refresh_items()

func _refresh_gold() -> void:
	var g := InventorySync.get_gold() if InventorySync else 0
	gold_label.text = "盤纏：%d文" % g

func _item_name(item_id: String) -> String:
	var d := ItemDB.get_def(item_id)
	if d.is_empty():
		return item_id
	return String(d.get("name", item_id))

func _refresh_items() -> void:
	item_list.clear()
	if _mode == "buy":
		_refresh_buy_items()
	else:
		_refresh_sell_items()
	action_button.disabled = item_list.item_count <= 0

func _refresh_buy_items() -> void:
	var entries: Array = _shop_data.get("items", [])
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id := String((entry as Dictionary).get("item_id", ""))
		if item_id == "":
			continue
		var price := int((entry as Dictionary).get("price", 0))
		var stock := int((entry as Dictionary).get("stock", -1))
		var stock_text := "" if stock < 0 else "｜庫存:%d" % stock
		item_list.add_item("%s｜%d文%s" % [_item_name(item_id), price, stock_text])
		item_list.set_item_metadata(item_list.item_count - 1, entry)

func _refresh_sell_items() -> void:
	if InventorySync == null:
		return
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
		var base_price := int(item_def.get("base_price", item_def.get("price", 0)))
		if base_price <= 0:
			continue
		var quantity := int((item as Dictionary).get("quantity", (item as Dictionary).get("count", 0)))
		if quantity <= 0:
			continue
		var sell_price := int(floor(float(base_price) * 0.4))
		if sell_price <= 0:
			continue
		var metadata := {
			"item_id": item_id,
			"base_price": base_price,
			"sell_price": sell_price,
			"quantity": quantity,
		}
		item_list.add_item("%s ×%d｜回收:%d文" % [_item_name(item_id), quantity, sell_price])
		item_list.set_item_metadata(item_list.item_count - 1, metadata)

func _on_action_pressed() -> void:
	var selected = item_list.get_selected_items()
	if selected.is_empty():
		return
	var idx := int(selected[0])
	var entry = item_list.get_item_metadata(idx)
	if typeof(entry) != TYPE_DICTIONARY:
		return
	_pending_item = (entry as Dictionary).duplicate(true)
	if _mode == "buy":
		var item_id := String(_pending_item.get("item_id", ""))
		var price := int(_pending_item.get("price", 0))
		confirm_dialog.dialog_text = "購買 1 個 %s，花費 %d 文？" % [_item_name(item_id), price]
	else:
		var sell_item_id := String(_pending_item.get("item_id", ""))
		var sell_price := int(_pending_item.get("sell_price", 0))
		confirm_dialog.dialog_text = "販賣 1 個 %s，獲得 %d 文？" % [_item_name(sell_item_id), sell_price]
	confirm_dialog.popup_centered()

func _on_confirmed() -> void:
	if _pending_item.is_empty():
		return
	if _mode == "buy":
		_execute_buy(_pending_item)
	else:
		_execute_sell(_pending_item)
	_pending_item.clear()

func _execute_buy(entry: Dictionary) -> void:
	var item_id := String(entry.get("item_id", ""))
	var price := int(entry.get("price", 0))
	var stock := int(entry.get("stock", -1))
	if item_id == "" or InventorySync == null:
		return
	if InventorySync.get_gold() < price:
		print("[Shop] 盤纏不足")
		return
	if stock == 0:
		print("[Shop] 已售完")
		return
	if not InventorySync.spend_gold(price):
		return
	InventorySync.add_item_stack(item_id, 1)
	if stock > 0:
		entry["stock"] = stock - 1
		var entries: Array = _shop_data.get("items", [])
		for i in range(entries.size()):
			var src := entries[i]
			if typeof(src) != TYPE_DICTIONARY:
				continue
			if String((src as Dictionary).get("item_id", "")) == item_id:
				entries[i] = entry
				break
		_shop_data["items"] = entries
	_refresh_gold()
	_refresh_items()

func _execute_sell(entry: Dictionary) -> void:
	if InventorySync == null:
		return
	var item_id := String(entry.get("item_id", ""))
	var sell_price := int(entry.get("sell_price", 0))
	if item_id == "" or sell_price <= 0:
		return
	var owned := InventorySync.get_item_by_id(item_id)
	var count := int(owned.get("count", owned.get("quantity", 0)))
	if count <= 0:
		print("[Shop] 物品不足")
		return
	InventorySync.consume_item(item_id, 1)
	InventorySync.add_gold(sell_price)
	_refresh_gold()
	_refresh_items()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_shop()

func _close_shop() -> void:
	emit_signal("closed")
	queue_free()
