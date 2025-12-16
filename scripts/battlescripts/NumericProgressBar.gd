extends ProgressBar

func _get_progress_text() -> String:
	return "%d / %d" % [int(value), int(max_value)]
