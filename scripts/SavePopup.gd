extends Panel

@onready var save_button := $SaveButton
@onready var load_button := $LoadButton
@onready var slots := [
	$VBoxContainer/SaveSlot1,
	$VBoxContainer/SaveSlot2,
	$VBoxContainer/SaveSlot3
]

var selected_slot_index := -1
var quest_party_serializer: QuestPartySerializerInstance = null

func _ready():
	quest_party_serializer = get_node("/root/QuestPartySerializer")

	for i in range(slots.size()):
		var slot = slots[i]
		slot.set_slot_index(i + 1)
		slot.connect("slot_selected", Callable(self, "_on_slot_selected"))

	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	load_button.disabled = true

func _on_slot_selected(index: int):
	selected_slot_index = index
	print("Selected slot:", index)
	var slot := slots[selected_slot_index - 1]
	load_button.disabled = slot.is_empty()

func _on_save_button_pressed():
	if selected_slot_index == -1:
		push_warning("尚未選擇存檔槽！")
		return

	# 改為直接讓 SaveManager 自行取得當前序列化資料
	SaveManager.save_to_slot(selected_slot_index)

	slots[selected_slot_index - 1]._refresh_label()

func _on_load_button_pressed():
	if selected_slot_index == -1:
		push_warning("尚未選擇讀取槽！")
		return

	SaveManager.load_from_slot(selected_slot_index)
