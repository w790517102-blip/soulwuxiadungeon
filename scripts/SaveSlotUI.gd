extends HBoxContainer
class_name SaveSlotUI

@onready var label := $Label
@onready var select_button := $SelectButton # <- 修正這裡！SaveButton 實際上是 SelectButton

@export var slot_index := 1

var selected := false

signal slot_selected(index: int)

func _ready():
	select_button.text = "選取"
	select_button.pressed.connect(_on_select_pressed)
	_refresh_label()

func _on_select_pressed():
	emit_signal("slot_selected", slot_index)

func _refresh_label():
	var path = "user://save/slot_%02d.save" % slot_index
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()

			if data.has("summary"):
				label.text = "存檔 %d｜%s" % [slot_index, data["summary"]]
			else:
				label.text = "存檔 %d｜（無摘要）" % slot_index
		else:
			label.text = "存檔 %d｜讀取失敗" % slot_index
	else:
		label.text = "存檔 %d｜尚無資料" % slot_index

func mark_selected():
	selected = true
	select_button.text = "✔ 選取中"

func unmark_selected():
	selected = false
	select_button.text = "選取"
