extends HBoxContainer

signal slot_selected(index: int)

@onready var label: Label = $Label
@onready var select_button: Button = $SelectButton

@export var slot_index: int = 1

var is_empty_slot: bool = true
var selected: bool = false

func _ready() -> void:
	select_button.text = "選取"
	if not select_button.pressed.is_connected(_on_select_button_pressed):
		select_button.pressed.connect(_on_select_button_pressed)

func set_slot_index(index: int) -> void:
	slot_index = index
	_refresh_label()

func _on_select_button_pressed() -> void:
	emit_signal("slot_selected", slot_index)

func _refresh_label() -> void:
	var summary: Dictionary = SaveManager.get_slot_summary(slot_index)
	var status: String = String(summary.get("_status", "empty"))

	if status == "empty":
		is_empty_slot = true
		label.text = "存檔 %d｜尚無資料" % slot_index
		return

	if status == "invalid":
		is_empty_slot = true
		label.text = "存檔 %d｜異常格式" % slot_index
		return

	# ok
	is_empty_slot = false

	var timestamp: int = int(summary.get("timestamp", 0))
	var timestamp_text := "未知時間"
	if timestamp > 0:
		timestamp_text = Time.get_datetime_string_from_unix_time(timestamp, true)

	var map_path: String = String(summary.get("current_map_path", ""))
	var scene_path: String = String(summary.get("current_scene_path", ""))
	var path_for_name: String = map_path if map_path != "" else scene_path
	var scene_name: String = path_for_name.get_file().get_basename() if path_for_name != "" else "未知場景"

	label.text = "存檔 %d｜%s｜%s" % [slot_index, timestamp_text, scene_name]

func is_empty() -> bool:
	return is_empty_slot

func mark_selected() -> void:
	selected = true
	select_button.text = "✔ 選取中"

func unmark_selected() -> void:
	selected = false
	select_button.text = "選取"
