extends "res://scripts/presentation/StageCommandTray.gd"
## Card Stage keeps this tray ONLY for its expanded option list (skill / inner
## force / item pages). The four main commands are no longer shown at the bottom:
## they pop up from the active character card instead.


func _ready() -> void:
	super._ready()
	_bring_options_forward()
	for node_name: String in ["CommandConsole", "CommandPlaque"]:
		var node: Node3D = get_node_or_null(node_name)
		if node:
			node.hide()
	for button: Node3D in _buttons:
		button.hide()


## The hidden main buttons must never be hit-tested.
func pick(_camera: Camera3D, _screen_position: Vector2) -> int:
	return -1


## The option pages (and the 確認 / 取消 buttons) must stand in FRONT of the player's cards, or a card hides them. They are
## brought toward the camera by scaling the whole option root about the camera's own point: on screen they look exactly
## as before (same size, same place), only their depth is now in front of the cards. Picking uses the global transform,
## so it follows.
const OPTION_WORLD_Z := 10.4
const CAMERA_Z := 18.0
const OPTION_LOCAL_Z := 3.15


func _enter_tree() -> void:
	if _options_root != null:
		_bring_options_forward()


func _bring_options_forward() -> void:
	var factor: float = (CAMERA_Z - OPTION_WORLD_Z) / (CAMERA_Z - OPTION_LOCAL_Z)
	_options_root.scale = Vector3(factor, factor, factor)
	_options_root.position = Vector3(0.0, 0.0, CAMERA_Z * (1.0 - factor))
