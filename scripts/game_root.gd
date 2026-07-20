extends Node2D

# 遊戲初始是否要直接導向 intro_room（僅限新遊戲）
var go_to_intro_on_start = true
var spawn_point_name = "default" # 每次切換地圖時記住要傳送到哪個點
var current_map_path = ""

# 🎵 音樂播放邏輯（動態抓取 BGM 檔案）
var current_music_tag = ""
var music_folder = "res://assets/BGM/"
var _world_bgm_paused_for_battle := false
var _world_bgm_resume_volume_db := -5.0
var map_transition_locked := false
const MAP_EXIT_REQUIRES_EXIT_META := "map_transition_requires_exit"

@onready var music_player = $MusicPlayer  # 音樂播放器節點

func lock_map_transitions(reason := "") -> void:
	map_transition_locked = true
	if GlobalState:
		GlobalState.set_meta("map_transition_locked", true)
	if reason != "":
		print("[MapTransitionGuard] locked: ", reason)

func unlock_map_transitions(reason := "") -> void:
	map_transition_locked = false
	if GlobalState and GlobalState.has_meta("map_transition_locked"):
		GlobalState.remove_meta("map_transition_locked")
	if reason != "":
		print("[MapTransitionGuard] unlocked: ", reason)

func is_map_transition_locked() -> bool:
	if map_transition_locked:
		return true
	if GlobalState:
		if bool(GlobalState.get("is_loading")):
			return true
		return bool(GlobalState.get_meta("map_transition_locked", false))
	return false

func can_use_map_transition(body: Node, area: Area2D = null) -> bool:
	if body == null or body.name != "LiuYu":
		return false
	if is_map_transition_locked():
		print("[MapTransitionGuard] blocked while locked. area=", area.name if area else "<unknown>", " pos=", (body as Node2D).global_position if body is Node2D else Vector2.ZERO)
		return false
	if area != null and area.has_meta(MAP_EXIT_REQUIRES_EXIT_META):
		print("[MapTransitionGuard] blocked until player exits area=", area.name)
		return false
	return true

func disarm_overlapping_map_exits(player: Node2D) -> void:
	if player == null:
		return
	var scene_root: Node = null
	var current_scene = get_node_or_null("CurrentScene")
	if current_scene and current_scene.get_child_count() > 0:
		scene_root = current_scene.get_child(0)
	if scene_root == null:
		return
	var areas: Array[Area2D] = []
	_collect_map_exit_areas(scene_root, areas)
	for area in areas:
		var bodies := area.get_overlapping_bodies()
		if bodies.has(player):
			area.set_meta(MAP_EXIT_REQUIRES_EXIT_META, true)
			var exited_callable := Callable(self, "_on_guarded_map_exit_body_exited").bind(area)
			if not area.body_exited.is_connected(exited_callable):
				area.body_exited.connect(exited_callable)
			print("[MapTransitionGuard] disarmed overlapping exit=", area.name, " player_pos=", player.global_position)

func _collect_map_exit_areas(node: Node, out: Array[Area2D]) -> void:
	if node is Area2D and String(node.name).begins_with("to_"):
		out.append(node)
	for child in node.get_children():
		_collect_map_exit_areas(child, out)

func _on_guarded_map_exit_body_exited(body: Node, area: Area2D) -> void:
	if body == null or body.name != "LiuYu" or area == null:
		return
	if area.has_meta(MAP_EXIT_REQUIRES_EXIT_META):
		area.remove_meta(MAP_EXIT_REQUIRES_EXIT_META)
		print("[MapTransitionGuard] rearmed exit after leave=", area.name)

func change_map_to(path: String):
	current_map_path = path
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

	var is_battle_return = GlobalState.get_meta("pending_battle_return", false) == true
	if not is_battle_return and $LiuYu.has_method("reset_encounter_state"):
		$LiuYu.reset_encounter_state()

	# 清除為下一次準備
	spawn_point_name = "default"

	# 🎵 自動偵測 music_tag
	var tag = ""
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

	# ✅ 戰鬥回歸：在新地圖 ready 後 restore LiuYu
	if GlobalState.get_meta("pending_battle_return", false) == true:
		GlobalState.remove_meta("pending_battle_return")

		var return_pos: Vector2 = GlobalState.get_meta("return_player_pos", $LiuYu.global_position)
		var cooldown_distance = float(GlobalState.get_meta("return_encounter_cooldown", 0.0))

		if GlobalState.has_meta("return_player_pos"):
			GlobalState.remove_meta("return_player_pos")
		if GlobalState.has_meta("return_encounter_cooldown"):
			GlobalState.remove_meta("return_encounter_cooldown")
		if GlobalState.has_meta("return_map_path"):
			GlobalState.remove_meta("return_map_path")
		# 保留 pending_battle_result 給地圖腳本（例如切磋 NPC）自行消化

		await get_tree().process_frame
		await get_tree().process_frame

		$LiuYu.global_position = return_pos
		if $LiuYu.has_method("battle_restore"):
			$LiuYu.battle_restore()
		if GlobalState.get_meta("oldfighter_sparring_flow_lock_active", false) == true:
			$LiuYu.can_move = false
			GlobalState.set_meta("menu_locked", true)
		if $LiuYu.has_method("set_encounter_cooldown"):
			$LiuYu.set_encounter_cooldown(cooldown_distance)
		if $LiuYu.has_method("refresh_danger_zone_from_position"):
			await $LiuYu.refresh_danger_zone_from_position(0.0)
		resume_world_bgm_after_battle(0.5)

		print("[GameRoot Return] liuyu visible=", $LiuYu.visible, " can_move=", $LiuYu.get("can_move"))

func play_music_by_tag(tag: String, fade_time = 1.5):
	if tag == current_music_tag:
		print("[音樂] music_tag 無變化（仍為：", tag, "）")
		return
	var track_path = music_folder + tag + ".ogg"
	print("[音樂] 嘗試載入：", track_path)
	var track = load(track_path)
	if track is AudioStream:
		_world_bgm_paused_for_battle = false
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

func pause_world_bgm_for_battle() -> void:
	if music_player == null:
		return
	if not music_player.playing:
		return
	_world_bgm_resume_volume_db = music_player.volume_db
	music_player.stream_paused = true
	_world_bgm_paused_for_battle = true

func resume_world_bgm_after_battle(fade_time: float = 0.5) -> void:
	if music_player == null or not _world_bgm_paused_for_battle:
		return
	_world_bgm_paused_for_battle = false
	var target_volume = _world_bgm_resume_volume_db
	music_player.volume_db = -40.0
	music_player.stream_paused = false
	if not music_player.playing:
		music_player.play()
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", target_volume, max(fade_time, 0.01))

func _ready():
	if go_to_intro_on_start:
		change_map_to("res://scenes/intro_room.tscn")
