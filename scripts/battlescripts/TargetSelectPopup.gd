extends PopupPanel
class_name TargetSelectPopup

signal target_selected(target: Dictionary)
signal selection_cancelled()
signal target_focus_changed(target: Dictionary)  # ⭐ 新增：目前鎖定的目標

@onready var target_list: ItemList      = $VBoxContainer/TargetList
@onready var description: RichTextLabel = $VBoxContainer/Description
@onready var btn_confirm: Button        = $VBoxContainer/HBoxContainer/Confirm
@onready var btn_cancel: Button         = $VBoxContainer/HBoxContainer/Cancel

var _targets: Array[Dictionary] = []
var _selected_index: int = -1

func _ready() -> void:
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	target_list.item_selected.connect(_on_target_list_item_selected)
	target_list.item_activated.connect(_on_target_list_item_activated)
	_clear_state()


func _clear_state() -> void:
	_targets.clear()
	target_list.clear()
	description.text = ""
	_selected_index = -1
	btn_confirm.disabled = true
	# 🔄 清掉焦點（如果外面有接收這個 signal，可以順便 reset）
	emit_signal("target_focus_changed", {})


func show_targets(target_array: Array) -> void:
	_clear_state()

	_targets = []
	for i: int in range(target_array.size()):
		var t: Dictionary = target_array[i]
		_targets.append(t)
		var name: String = t.get("name", "？？")
		target_list.add_item(name)

	if _targets.is_empty():
		description.text = "目前沒有可選擇的目標。"
		btn_confirm.disabled = true
	else:
		# 有目標的話預設選第一個
		_selected_index = 0
		target_list.select(0)

		var first: Dictionary = _targets[0]
		var first_name: String = first.get("name", "？？")
		description.text = "目前選擇目標：%s" % first_name
		btn_confirm.disabled = false

		# ⭐ 通知外面「現在預設鎖定第 1 個」
		emit_signal("target_focus_changed", first)

	popup_centered()


func _on_target_list_item_selected(index: int) -> void:
	_selected_index = index

	if index >= 0 and index < _targets.size():
		var t: Dictionary = _targets[index]
		var name: String = t.get("name", "？？")
		description.text = "目前選擇目標：%s" % name
		btn_confirm.disabled = false

		# ⭐ 這裡發出「鎖定目標」事件 → BattleUI 來做閃爍 / 抖動
		emit_signal("target_focus_changed", t)
	else:
		description.text = "請選擇目標。"
		btn_confirm.disabled = true
		emit_signal("target_focus_changed", {})  # 沒有有效目標，就清空聚焦


func _on_target_list_item_activated(index: int) -> void:
	_selected_index = index
	_on_confirm_pressed()


func _on_confirm_pressed() -> void:
	if _selected_index >= 0 and _selected_index < _targets.size():
		var target: Dictionary = _targets[_selected_index]
		emit_signal("target_selected", target)
	else:
		emit_signal("selection_cancelled")
	hide()


func _on_cancel_pressed() -> void:
	emit_signal("selection_cancelled")
	hide()
