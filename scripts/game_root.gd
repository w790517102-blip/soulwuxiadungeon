extends Node2D

# 開場 intro_room 只在新遊戲時由 Game.gd 設為 true；預設 false（讀檔、中途測試都不進開場）
var go_to_intro_on_start = false
var spawn_point_name = "default" # 每次切換地圖時記住要傳送到哪個點
var current_map_path = ""

# 🎵 音樂播放邏輯（動態抓取 BGM 檔案）
var current_music_tag = ""
var music_folder = "res://assets/BGM/"
var _world_bgm_paused_for_battle := false
const WORLD_BGM_VOLUME_DB := -5.0
var _world_bgm_resume_volume_db := WORLD_BGM_VOLUME_DB
var _music_transition_serial := 0
var _music_transition_pending_track: AudioStream = null
var _music_tween: Tween = null
var map_transition_locked := false
const MAP_EXIT_REQUIRES_EXIT_META := "map_transition_requires_exit"
## 到達新場景後，出口鎖住這麼多秒（防呆：剛進來就被按住的滑鼠、或出生點附近的出口帶走）。
const ARRIVAL_EXIT_GRACE_SEC := 1.5
var _arrival_grace_until_msec := 0

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

func is_arrival_grace() -> bool:
	return Time.get_ticks_msec() < _arrival_grace_until_msec

func can_use_map_transition(body: Node, area: Area2D = null) -> bool:
	if body == null or body.name != "LiuYu":
		return false
	if is_arrival_grace():
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
			_guard_map_exit_until_player_leaves(area, player)

func _guard_map_exit_until_player_leaves(area: Area2D, player: Node2D) -> void:
	if area == null or player == null:
		return
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
	# 正常換圖與讀檔都必須遵守同一個進場不變條件：出生點定位及物理
	# overlap 更新完成前，目的地出口不可再次觸發。既有的外層鎖（讀檔／
	# 劇情）不由此函式解除，避免搶走真正需要延續的控制權。
	var inherited_transition_lock := is_map_transition_locked()
	if not inherited_transition_lock:
		lock_map_transitions("scene_change")
	current_map_path = path
	var resolver := get_node_or_null("/root/InteractionResolver")
	if resolver != null and resolver.has_method("cancel_mouse_intent_for_scene_change"):
		resolver.call("cancel_mouse_intent_for_scene_change")
	if $CurrentScene.get_child_count() > 0:
		$CurrentScene.get_child(0).queue_free()
	# 進戰鬥場景一律藏起大地圖的劉語塵（隨機遭遇與下水道各自會藏；劇情戰鬥如老翁比武、茶樓護衛沒藏，會在戰鬥畫面中央留下 chibi）。回場時 battle_restore 會讓他重新顯示
	if path.ends_with("battle_scene.tscn"):
		$LiuYu.visible = false
	# 換場景一律先把操作還給玩家：上一張地圖在出口先鎖了操作時，沒有進場劇情的目的地不會有人替他打開（會動不了）。
	# 有進場劇情的地圖，自己的 _ready 之後會再鎖一次（新場景建立在這行之後）。
	# 戰鬥回場、劇情持有 menu_locked 時不動，由原本的流程交還控制。
	if GlobalState.get_meta("pending_battle_return", false) != true and GlobalState.get_meta("menu_locked", false) != true:
		$LiuYu.can_move = true
	var new_scene = load(path).instantiate()
	$CurrentScene.add_child(new_scene)

	# ✅ 移動流語客到指定出生點（如果有）
	await get_tree().process_frame
	# 舊式 NPC（空白鍵＋Area2D）套用預設的三層互動；場景或腳本自己放了 InteractionTarget 的不動（見 NpcInteractionAdapter）
	NpcInteractionAdapter.adopt_scene(new_scene)
	# 舊式物件（調香室、琴室、符咒室）：Area2D 當蛋黃區、往外擴張當蛋白區、游標是饅頭手（見 ObjectInteractionAdapter）
	ObjectInteractionAdapter.adopt_scene(new_scene)
	var spawn_point = new_scene.get_node_or_null("SpawnPoints/%s" % spawn_point_name)
	if spawn_point:
		$LiuYu.global_position = spawn_point.global_position
	else:
		push_warning("Spawn point '%s' not found in %s" % [spawn_point_name, path])

	# Area2D 的 overlap 清單在 physics frame 後才可靠。先保持轉場鎖，
	# 再把出生點仍重疊的出口標成「必須先離開」，最後才交還換圖權。
	await get_tree().physics_frame
	disarm_overlapping_map_exits($LiuYu)
	if not inherited_transition_lock:
		unlock_map_transitions("scene_change")
	_arrival_grace_until_msec = Time.get_ticks_msec() + int(ARRIVAL_EXIT_GRACE_SEC * 1000.0)

	var is_battle_return = GlobalState.get_meta("pending_battle_return", false) == true
	var loading_save := GlobalState != null and bool(GlobalState.get("is_loading"))
	var destination_has_encounters := _scene_contains_random_encounter_zone(new_scene)
	if not is_battle_return:
		if loading_save or not destination_has_encounters:
			if $LiuYu.has_method("reset_encounter_state"):
				$LiuYu.reset_encounter_state()
		elif $LiuYu.has_method("suspend_encounter_for_scene_change"):
			# 同一危險 region 的新 DangerZone 會重新註冊設定；只暫停目前
			# Scene 的 Area，不清除累積 pressure。
			$LiuYu.suspend_encounter_for_scene_change()

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
		# battle_restore 會先恢復一般 idle；需要延續戰鬥姿勢的地圖可在同一幀覆寫，
		# 避免 BlackOverlay 退去後才看見角色由 idle 跳回劇情姿勢。
		if new_scene.has_method("prepare_battle_return_actor"):
			new_scene.call("prepare_battle_return_actor", $LiuYu)
		# 地圖劇情若仍持有 menu lock，戰鬥回場只恢復角色可見與輸入處理，
		# 不得搶先開放移動；由該劇情在收尾完成後自行交還控制。
		if GlobalState.get_meta("menu_locked", false) == true:
			$LiuYu.can_move = false
			if $LiuYu.has_method("set_encounter_paused"):
				$LiuYu.set_encounter_paused(true)
		if GlobalState.get_meta("oldfighter_sparring_flow_lock_active", false) == true:
			$LiuYu.can_move = false
			GlobalState.set_meta("menu_locked", true)
		if $LiuYu.has_method("set_encounter_cooldown"):
			$LiuYu.set_encounter_cooldown(cooldown_distance)
		if $LiuYu.has_method("refresh_danger_zone_from_position"):
			await $LiuYu.refresh_danger_zone_from_position(0.0)
		resume_world_bgm_after_battle(0.5)

		print("[GameRoot Return] liuyu visible=", $LiuYu.visible, " can_move=", $LiuYu.get("can_move"))

func _scene_contains_random_encounter_zone(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("random_encounter_zone"):
		return true
	for child in node.get_children():
		if _scene_contains_random_encounter_zone(child):
			return true
	return false

func play_music_by_tag(tag: String, fade_time = 1.5):
	if tag == current_music_tag and music_player.playing:
		print("[音樂] music_tag 無變化（仍為：", tag, "）")
		return
	transition_music_by_tag(tag, fade_time, 0.5)


# 供劇情場景在 BlackOverlay 淡出前等待音樂確實完成交接。
# 全專案仍只使用 GameRoot/MusicPlayer；serial 會讓較新的切歌取消較舊的延遲 callback，
# 避免快速換場時上一首在稍後又被設回來。
func transition_music_by_tag(tag: String, fade_out_time := 0.2, fade_in_time := 0.2) -> bool:
	if tag == current_music_tag and music_player.playing:
		return true
	var track_path = music_folder + tag + ".ogg"
	print("[音樂] 嘗試載入：", track_path)
	var track = load(track_path)
	if not track is AudioStream:
		push_warning("[音樂] 未找到對應曲盤: %s" % track_path)
		print("[音樂] ❌ 載入失敗：", track_path)
		return false

	_music_transition_serial += 1
	var serial := _music_transition_serial
	_world_bgm_paused_for_battle = false
	current_music_tag = tag
	_music_transition_pending_track = track
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	if music_player.playing and fade_out_time > 0.0:
		_music_tween = create_tween()
		_music_tween.tween_property(music_player, "volume_db", -50.0, fade_out_time)
		await _music_tween.finished
		if serial != _music_transition_serial:
			return false

	_music_transition_pending_track = null
	music_player.stop()
	music_player.stream = track
	music_player.stream.loop = true
	music_player.stream_paused = false
	music_player.volume_db = -50.0 if fade_in_time > 0.0 else WORLD_BGM_VOLUME_DB
	music_player.play()
	if fade_in_time > 0.0:
		_music_tween = create_tween()
		_music_tween.tween_property(music_player, "volume_db", WORLD_BGM_VOLUME_DB, fade_in_time)
		await _music_tween.finished
		if serial != _music_transition_serial:
			return false
	print("[音樂] 成功播放：", tag)
	return true

func fade_out_and_in(new_track: AudioStream, fade_time: float):
	# 舊呼叫點相容入口；新程式應以 tag 呼叫 transition_music_by_tag()。
	_music_transition_serial += 1
	var serial := _music_transition_serial
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(music_player, "volume_db", -50.0, maxf(fade_time, 0.0))
	_music_tween.tween_callback(func ():
		if serial != _music_transition_serial:
			return
		music_player.stop()
		music_player.stream = new_track
		music_player.stream.loop = true
		music_player.volume_db = -5.0
		music_player.play()
	)

func pause_world_bgm_for_battle() -> void:
	if music_player == null:
		return
	# 地圖 BGM 可能正處於換歌淡入淡出途中（剛進場、BlackOverlay 還沒退完就觸發戰鬥）。
	# 若只是暫停：換歌 coroutine 稍後會把新曲子重新 play() 出來（戰鬥中兩首 BGM 重疊），
	# 而且記到的「還原音量」會是淡到一半的低音量（戰後 BGM 變小聲）。
	# 所以先取消進行中的換歌，並把待換的曲子直接定位好，再暫停。
	var pending_track := _music_transition_pending_track
	var transition_in_flight := pending_track != null or (_music_tween != null and _music_tween.is_valid())
	if not music_player.playing and not transition_in_flight:
		return
	_music_transition_serial += 1
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if pending_track != null:
		_music_transition_pending_track = null
		music_player.stop()
		music_player.stream = pending_track
		music_player.stream.loop = true
	_world_bgm_resume_volume_db = WORLD_BGM_VOLUME_DB
	music_player.volume_db = WORLD_BGM_VOLUME_DB
	music_player.stream_paused = true
	_world_bgm_paused_for_battle = true


func stop_world_bgm(fade_time: float = 0.2) -> void:
	# Story videos own their soundtrack, so unlike a battle pause this stop is
	# intentional and must not be resumed by the battle-return path.
	_world_bgm_paused_for_battle = false
	_music_transition_serial += 1
	_music_transition_pending_track = null
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if music_player == null:
		return
	if music_player.playing and fade_time > 0.0:
		_music_tween = create_tween()
		_music_tween.tween_property(music_player, "volume_db", -50.0, fade_time)
		await _music_tween.finished
	music_player.stop()
	music_player.stream_paused = false
	current_music_tag = ""

func resume_world_bgm_after_battle(fade_time: float = 0.5) -> void:
	if music_player == null or not _world_bgm_paused_for_battle:
		return
	_world_bgm_paused_for_battle = false
	var target_volume = _world_bgm_resume_volume_db
	music_player.volume_db = -40.0
	music_player.stream_paused = false
	if not music_player.playing:
		music_player.play()
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(music_player, "volume_db", target_volume, max(fade_time, 0.01))

func _ready():
	if go_to_intro_on_start:
		change_map_to("res://scenes/intro_room.tscn")
