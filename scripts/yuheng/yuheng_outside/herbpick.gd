extends Area2D
const FLAG_GOT_VALLEY_HERB := "got_valley_herb"

func _on_body_entered(body):
	if body.name != "LiuYu": return
	var n := int(GlobalState.triggered_flags.get(FLAG_GOT_VALLEY_HERB, 0))
	GlobalState.triggered_flags[FLAG_GOT_VALLEY_HERB] = n + 1
	# 可加個小提示或音效
	queue_free()
