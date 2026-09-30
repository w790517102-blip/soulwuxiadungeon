extends Node
## Added last under the battle UI so typewriter completion consumes the input
## before target/command handlers. Popup Windows forward to the same authority.
var ui: Control

func _input(event: InputEvent) -> void:
	var consumed: bool = ui.handle_battle_message_input(event)
	if consumed:
		get_viewport().set_input_as_handled()
