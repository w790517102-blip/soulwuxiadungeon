extends Panel

@onready var save_button = $SaveButton
@onready var load_button = $LoadButton
@onready var slots = [
	$VBoxContainer/SaveSlot1,
	$VBoxContainer/SaveSlot2,
	$VBoxContainer/SaveSlot3
]

var selected_slot_index: int = -1
var quest_party_serializer = null

func _ready() -> void:
	quest_party_serializer = get_node_or_null("/root/QuestPartySerializer")

	for i in range(slots.size()):
		var slot = slots[i]
		slot.set_slot_index(i + 1)

		var cb := Callable(self, "_on_slot_selected")
		if not slot.is_connected("slot_selected", cb):
			slot.connect("slot_selected", cb)

	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	load_button.disabled = true


func _on_slot_selected(index: int) -> void:
	selected_slot_index = index
	print("Selected slot:", index)

	var slot = slots[selected_slot_index - 1]
	load_button.disabled = slot.is_empty()


func _on_save_button_pressed() -> void:
	if selected_slot_index == -1:
		push_warning("尚未選擇存檔槽！")
		return

	SaveManager.save_to_slot(selected_slot_index)

	for slot in slots:
		slot._refresh_label()

	var active_slot = slots[selected_slot_index - 1]
	load_button.disabled = active_slot.is_empty()


func _on_load_button_pressed() -> void:
	if selected_slot_index == -1:
		push_warning("尚未選擇讀取槽！")
		return

	var active_slot = slots[selected_slot_index - 1]
	if active_slot.is_empty():
		push_warning("該存檔槽沒有可讀取資料。")
		return

	SaveManager.load_from_slot(selected_slot_index)
