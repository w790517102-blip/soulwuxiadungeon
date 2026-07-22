extends Node2D

# 純場景音樂宣告；實際播放仍由 GameRoot 的單一 MusicPlayer 管理。
@export var music_tag := ""
@export var fade_duration := 0.2


func _ready() -> void:
	if music_tag == "":
		return
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root and game_root.has_method("transition_music_by_tag"):
		await game_root.call("transition_music_by_tag", music_tag, fade_duration, fade_duration)
	else:
		push_warning("[場景音樂] 找不到 GameRoot.transition_music_by_tag，無法播放 %s。" % music_tag)
