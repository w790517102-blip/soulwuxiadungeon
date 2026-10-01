extends "res://scripts/presentation/StageCommandTray.gd"
## Card Stage keeps this tray ONLY for its expanded option list (skill / inner
## force / item pages). The four main commands are no longer shown at the bottom:
## they pop up from the active character card instead.


func _ready() -> void:
	super._ready()
	for node_name: String in ["CommandConsole", "CommandPlaque"]:
		var node: Node3D = get_node_or_null(node_name)
		if node:
			node.hide()
	for button: Node3D in _buttons:
		button.hide()


## The hidden main buttons must never be hit-tested.
func pick(_camera: Camera3D, _screen_position: Vector2) -> int:
	return -1
