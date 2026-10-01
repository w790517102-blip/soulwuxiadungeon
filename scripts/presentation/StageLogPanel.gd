extends "res://scripts/battlescripts/LogPanel.gd"

var stage_active: bool = true
var drawer_open: bool = false

func _input(event: InputEvent) -> void:
	# Reading/scrolling the archive must not silently confirm a combat checkpoint.
	if stage_active and (drawer_open or event is InputEventMouseButton):
		return
	super._input(event)

func accept_checkpoint() -> void:
	handle_message_input()

func _scroll_to_bottom() -> void:
	# Reopening / explicit latest is allowed; incoming log lines cannot move a
	# reader who is browsing the archive, even before the first manual scroll.
	if drawer_open: return
	super._scroll_to_bottom()

func scroll_archive_to_latest() -> void:
	super._scroll_to_bottom()
