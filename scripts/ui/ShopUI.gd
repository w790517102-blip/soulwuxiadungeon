extends CanvasLayer
class_name ShopUI

const ShopDatabaseScript = preload("res://scripts/db/ShopDatabase.gd")

var _shop_db: Node = ShopDatabaseScript.new()
var _shop_id := ""
var _shop_data: Dictionary = {}
var _buyer = null
var _done := false

var panel: Panel
var title_label: Label
var gold_label: Label
var item_list: ItemList
var buy_button: Button
var close_button: Button

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
		buy_button.disabled = true
		return
	title_label.text = String(_shop_data.get("name", _shop_id))
	_refresh_gold()
	_refresh_items()

func _build_ui() -> void:
	panel = Panel.new()
	panel.size = Vector2(520, 360)
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

	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(0, 240)
	vb.add_child(item_list)

	var hb = HBoxContainer.new()
	vb.add_child(hb)

	buy_button = Button.new()
	buy_button.text = "購買"
	hb.add_child(buy_button)

	close_button = Button.new()
	close_button.text = "離開"
	hb.add_child(close_button)

	buy_button.pressed.connect(_on_buy_pressed)
	close_button.pressed.connect(_close_shop)

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

func _on_buy_pressed() -> void:
	var selected = item_list.get_selected_items()
	if selected.is_empty():
		return
	var idx := int(selected[0])
	var entry = item_list.get_item_metadata(idx)
	if typeof(entry) != TYPE_DICTIONARY:
		return
	var item_id := String((entry as Dictionary).get("item_id", ""))
	var price := int((entry as Dictionary).get("price", 0))
	var stock := int((entry as Dictionary).get("stock", -1))
	if item_id == "":
		return
	if InventorySync == null:
		return
	if InventorySync.get_gold() < price:
		print("[Shop] 盤纏不足")
		return
	if stock == 0:
		print("[Shop] 已售完")
		return
	InventorySync.spend_gold(price)
	InventorySync.add_item_stack(item_id, 1)
	if stock > 0:
		(entry as Dictionary)["stock"] = stock - 1
		var items: Array = _shop_data.get("items", [])
		if idx >= 0 and idx < items.size():
			items[idx] = entry
			_shop_data["items"] = items
	_refresh_gold()
	_refresh_items()

func _close_shop() -> void:
	emit_signal("closed")
	queue_free()
