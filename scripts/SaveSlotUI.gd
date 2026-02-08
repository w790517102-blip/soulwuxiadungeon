extends HBoxContainer
class_name SaveSlotUI

@onready var label = $Label
@onready var select_button = $SelectButton # <- 修正這裡！SaveButton 實際上是 SelectButton

@export var slot_index = 1

var selected = false

func _on_select_button_pressed() -> void:

func _ready():
	select_button.text = "選取"
	select_button.pressed.connect(_on_select_pressed)

func set_slot_index(index: int) -> void:
	slot_index = index
	_refresh_label()

func _on_select_pressed():
	emit_signal("slot_selected", slot_index)

func _refresh_label():
	var summary = SaveManager.get_slot_summary(slot_index)
	var status = String(summary.get("_status", "empty"))
	if status == "empty":
		is_empty_slot = true
		label.text = "存檔 %d｜空" % slot_index
		return
	if status == "invalid":
		is_empty_slot = true
		label.text = "存檔 %d｜異常格式" % slot_index
		return

	is_empty_slot = false
	var timestamp = int(summary.get("timestamp", 0))
	var timestamp_text = ""
	if timestamp > 0:
		timestamp_text = Time.get_datetime_string_from_unix_time(timestamp, true)
	else:
		timestamp_text = "未知時間"

	var scene_path = String(summary.get("current_scene_path", ""))
	var scene_name = scene_path.get_file().get_basename() if scene_path != "" else "未知場景"

	label.text = "存檔 %d｜%s｜%s" % [slot_index, timestamp_text, scene_name]

func is_empty() -> bool:
	return is_empty_slot

func mark_selected():
	selected = true
	select_button.text = "✔ 選取中"

func unmark_selected():
	selected = false
	select_button.text = "選取"
