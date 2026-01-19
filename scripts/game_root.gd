extends Node2D

# 遊戲初始是否要直接導向 intro_room（僅限新遊戲）
var go_to_intro_on_start := true
var spawn_point_name := "default" # 每次切換地圖時記住要傳送到哪個點

# 🎵 音樂播放邏輯（動態抓取 BGM 檔案）
var current_music_tag := ""
var music_folder := "res://assets/BGM/"

@onready var music_player := $MusicPlayer  # 音樂播放器節點

func change_map_to(path: String):
	if $CurrentScene.get_child_count() > 0:
		$CurrentScene.get_child(0).queue_free()
	var new_scene = load(path).instantiate()
	$CurrentScene.add_child(new_scene)

	# ✅ 移動流語客到指定出生點（如果有）
	await get_tree().process_frame
	var spawn_point = new_scene.get_node_or_null("SpawnPoints/%s" % spawn_point_name)
	if spawn_point:
		$LiuYu.global_position = spawn_point.global_position
	else:
		push_warning("Spawn point '%s' not found in %s" % [spawn_point_name, path])

	if $LiuYu.has_method("reset_encounter_state"):
		$LiuYu.reset_encounter_state()

	# 清除為下一次準備
	spawn_point_name = "default"

	# 🎵 自動偵測 music_tag
	var tag := ""
	var props = new_scene.get_property_list()
	for p in props:
		if p.name == "music_tag":
			tag = new_scene.get("music_tag")
			print("[音樂] 偵測到 music_tag = ", tag)
			break

	if tag != "":
		if tag != current_music_tag:
			play_music_by_tag(tag)
	elif current_music_tag == "":
		music_player.stop()
		print("[音樂] 無 music_tag 並無當前播放音樂，停止播放")

	# 📹 新增：重置 Camera 限制
	var cam_bounds = new_scene.get_node_or_null("CameraBounds")
	if cam_bounds:
		$MainCamera.set_bounds_from_area(cam_bounds)
	else:
		print("[Camera] 未找到 CameraBounds")

func play_music_by_tag(tag: String, fade_time := 1.5):
	if tag == current_music_tag:
		print("[音樂] music_tag 無變化（仍為：", tag, "）")
		return
	var track_path = music_folder + tag + ".ogg"
	print("[音樂] 嘗試載入：", track_path)
	var track = load(track_path)
	if track is AudioStream:
		current_music_tag = tag
		fade_out_and_in(track, fade_time)
		print("[音樂] 成功播放：", tag)
	else:
		push_warning("[音樂] 未找到對應曲盤: %s" % track_path)
		print("[音樂] ❌ 載入失敗：", track_path)

func fade_out_and_in(new_track: AudioStream, fade_time: float):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -50, 1.5)
	tween.tween_callback(func ():
		music_player.stream = new_track
		music_player.stream.loop = true
		music_player.play()
		music_player.volume_db = -5
		var fade_in = create_tween()
		fade_in.tween_property(music_player, "volume_db", 1, 0.5)
	)

func _ready():
	if go_to_intro_on_start:
		change_map_to("res://scenes/intro_room.tscn")
