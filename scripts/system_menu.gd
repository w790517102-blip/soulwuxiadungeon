# 掛在 system_menu.tscn 的 Panel 根節點上的腳本
extends Panel

@onready var tabs: TabContainer = $VBoxContainer
@onready var item_list: ItemList = $VBoxContainer/道具/ItemList
@onready var item_desc: RichTextLabel = $VBoxContainer/道具/RichTextLabel
@onready var gold_label: Label = $VBoxContainer/道具/GoldLabel
@onready var status_gold_label: Label = get_node_or_null("VBoxContainer/狀態/GoldLabel")
@onready var use_button: Button = get_node_or_null("VBoxContainer/道具/UseButton")
var _item_entries: Array = []

func _ready():
	# ✅ Godot 4 正確用法，Control 沒有 pause_mode，這裡不能設！
	# 所以這行我們移除：pause_mode = Node.PAUSE_MODE_PROCESS ❌

	# ✅ 抓焦點與接收輸入
	focus_mode = Control.FOCUS_ALL
	grab_focus()

	# ✅ 這邊開啟輸入處理
	set_process_unhandled_input(true)

	if item_list:
		item_list.item_selected.connect(_on_item_selected)
	if use_button:
		use_button.pressed.connect(_on_use_pressed)
	if tabs:
		tabs.tab_changed.connect(_on_tab_changed)
	if InventorySync:
		InventorySync.inventory_changed.connect(_on_inventory_changed)
		InventorySync.gold_changed.connect(_on_gold_changed)
	_refresh_item_tab()
	_refresh_gold()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		# 直接呼叫 Autoload：SystemMenu
		SystemMenu._close_system_menu()
		get_viewport().set_input_as_handled()

func _on_tab_changed(tab_index: int) -> void:
	if tabs == null:
		return
	var item_tab_index = $VBoxContainer/道具.get_index()
	if tab_index == item_tab_index:
		_refresh_item_tab()

func _refresh_item_tab() -> void:
	if item_list == null or item_desc == null:
		return
	var selected_index = item_list.get_selected_items()
	var selected_id := ""
	if selected_index.size() > 0:
		selected_id = str(item_list.get_item_metadata(selected_index[0]))
	item_list.clear()
	_item_entries = InventorySync.get_items()
	for item in _item_entries:
		var count = int(item.get("quantity", item.get("count", 0)))
		var label = "%s x%d" % [item.get("name", item.get("id", "???")), count]
		item_list.add_item(label)
		var item_index = item_list.item_count - 1
		var item_id = item.get("id", "")
		item_list.set_item_metadata(item_index, item_id)
		if selected_id != "" and item_id == selected_id:
			item_list.select(item_index)
	if _item_entries.is_empty():
		item_desc.text = "背包裡空空如也。"
	elif selected_id != "":
		var selected_items = item_list.get_selected_items()
		if selected_items.size() > 0:
			_on_item_selected(selected_items[0])
		elif item_list.item_count > 0:
			item_list.select(0)
			_on_item_selected(0)
		else:
			item_desc.text = "背包裡空空如也。"
	else:
		item_list.select(0)
		_on_item_selected(0)

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= item_list.item_count:
		return
	var item_id = str(item_list.get_item_metadata(index))
	if item_id == "":
		return
	var item: Dictionary = InventorySync.get_item_by_id(item_id)
	if item.is_empty():
		return
	var name = item.get("name", item.get("id", "???"))
	var desc = item.get("desc", item.get("description", ""))
	var count = int(item.get("quantity", item.get("count", 0)))
	item_desc.text = "[b]%s[/b]\n數量：%d\n\n%s" % [name, count, desc]

func _on_inventory_changed() -> void:
	if tabs == null:
		return
	var item_tab_index = $VBoxContainer/道具.get_index()
	if tabs.current_tab == item_tab_index:
		_refresh_item_tab()

func _on_gold_changed(_new_gold: int) -> void:
	_refresh_gold()

func _refresh_gold() -> void:
	var gold := InventorySync.get_gold()
	if gold_label:
		gold_label.text = "💰 盤纏：%d文" % gold
	if status_gold_label:
		status_gold_label.text = "💰 盤纏：%d文" % gold

func _on_use_pressed() -> void:
	if item_list == null:
		return
	var selected_items = item_list.get_selected_items()
	if selected_items.is_empty():
		return
	var item_id = str(item_list.get_item_metadata(selected_items[0]))
	if item_id == "":
		return
	InventorySync.consume_item(item_id, 1)
	print("[ItemUse] used:", item_id)
