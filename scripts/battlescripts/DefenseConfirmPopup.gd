extends PopupPanel

signal defense_confirmed
signal selection_cancelled

@onready var btn_confirm = $VBoxContainer/HBoxContainer/Confirm
@onready var btn_cancel = $VBoxContainer/HBoxContainer/Cancel

func _ready():
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)

func _on_confirm_pressed():
	hide()
	emit_signal("defense_confirmed")

func _on_cancel_pressed():
	hide()
	emit_signal("selection_cancelled")
