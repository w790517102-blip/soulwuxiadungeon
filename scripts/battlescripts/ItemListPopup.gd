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


func _is_item_usable_in_battle(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if str(item.get("use_action", "none")) != "consume":
		return false
	var scope = str(item.get("use_scope", "none"))
	if not ["battle", "any"].has(scope):
		return false
	return item.has("effect")

func _ready():
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	item_list.item_selected.connect(_on_item_selected)
	hide()

# ✅ 顯示可用道具（僅限有 effect 欄位的）
func show_items(actor: Dictionary):
	user_actor = actor
	selected_index = -1
	btn_confirm.disabled = true
	current_items = []
	item_list.clear()
	description.text = "請選擇一個可使用的道具。"
	quantity_label.text = ""

	var inventory = InventorySync.get_items()
	for item in inventory:
		if _is_item_usable_in_battle(item):
			current_items.append(item)
			item_list.add_item("%s ×%d" % [item.get("name", "無名道具"), int(item.get("quantity", 0))])

	if current_items.is_empty():
		description.text = "戰鬥中沒有可使用的道具。"
	popup_centered()

func _on_item_selected(index):
	selected_index = index
	if index >= 0 and index < current_items.size():
		var item = current_items[index]
		btn_confirm.disabled = false
		var scopes := {"ally_single": "我方單人", "enemy_single": "敵方單人", "all_single": "任一角色", "ally_all": "我方全體", "enemy_all": "敵方全體", "self": "自身"}
		var scope := String(item.get("target_scope", "ally_single"))
		var kind := "消耗品" if String(item.get("type", "")) == "consumable" else String(item.get("type", ""))
		description.text = "%s\n類型：%s\n適用目標：%s\n\n%s" % [item.get("name", ""), kind, scopes.get(scope, scope), item.get("description", item.get("desc", ""))]
		var effect := String(item.get("effect", ""))
		var effects := {"heal": "回復氣血", "mp_heal": "回復內力", "cure_status": "解除狀態", "damage": "造成傷害", "revive": "復甦", "revive_hp": "復甦"}
		description.text += "\n\n效果：%s" % effects.get(effect, effect)
		if item.has("amount"): description.text += " %s" % item.amount
		if item.has("status_id"): description.text += "（%s）" % item.status_id
		quantity_label.text = "擁有：%d 個" % item.get("quantity", 0)
	else:
		btn_confirm.disabled = true
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
