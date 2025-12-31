# ✅ 初版 ItemListPopup.gd
# 戰鬥中使用道具的彈窗面板

extends PopupPanel

signal item_selected(item: Dictionary)
signal selection_cancelled()
signal item_used(item: Dictionary)

@onready var item_list = $VBoxContainer/ItemListPopup
@onready var description = $VBoxContainer/Description
@onready var quantity_label = $VBoxContainer/QuantityLabel
@onready var btn_confirm = $VBoxContainer/HBoxContainer/Confirm
@onready var btn_cancel = $VBoxContainer/HBoxContainer/Cancel

var current_items: Array = []
var selected_index = -1
var user_actor: Dictionary = {}

func _ready():
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	item_list.item_selected.connect(_on_item_selected)
	hide()

# ✅ 顯示可用道具（僅限有 effect 欄位的）
func show_items(actor: Dictionary):
	user_actor = actor
	selected_index = -1
	current_items = []
	item_list.clear()
	description.text = "請選擇一個可使用的道具。"
	quantity_label.text = ""

	var inventory = InventorySync.get_items()
	for item in inventory:
		if item.has("effect"):
			current_items.append(item)
			item_list.add_item(item.get("name", "無名道具"))

	popup_centered()

func _on_item_selected(index):
	selected_index = index
	if index >= 0 and index < current_items.size():
		var item = current_items[index]
		description.text = item.get("description", "")
		quantity_label.text = "擁有：%d 個" % item.get("quantity", 0)
	else:
		description.text = "請選擇一個可使用的道具。"
		quantity_label.text = ""

func _on_confirm_pressed():
	if selected_index >= 0 and selected_index < current_items.size():
		emit_signal("item_selected", current_items[selected_index])
		hide()
	else:
		description.text = "請先選擇一個道具。"
		quantity_label.text = ""

func _on_cancel_pressed():
	selection_cancelled.emit()
	hide()
