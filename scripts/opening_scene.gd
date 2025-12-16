extends Control

var has_switched := false

func _ready():
	$AudioStreamPlayer2D.play()
	$VideoStreamPlayer.play()
	$VideoStreamPlayer.connect("finished", Callable(self, "_on_video_finished"))

func _on_video_finished():
	if not has_switched:
		has_switched = true
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _input(event):
	if not has_switched and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		has_switched = true
		$AudioStreamPlayer2D.stop()
		$VideoStreamPlayer.stop()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
