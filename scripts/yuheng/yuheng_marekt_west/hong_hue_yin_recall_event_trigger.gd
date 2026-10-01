# 紅徽音弦外之音事件觸發腳本
# 掛載位置：yuheng_market_west_night / Hong_hue_yin_recall_event_trigger
# 子節點預期：Hong_hue_yin_recall_event (Area2D) / CollisionShape2D
# 功能：銀屏語事件後切到夜晚玉衡鎮西市集，玩家落在 spawn point 附近後，自動播放紅徽音召喚事件。

extends Node2D

@export var area_path: NodePath = "Hong_huei_yin_recall_event"
@export var player_path: NodePath = "/root/GameRoot/LiuYu"
@export var dialog_manager_path: NodePath = "/root/GameRoot/DialogManager"

# 若玩家切場景後不是自動落在 spawn point，可由本腳本在事件前把玩家放到這裡。
@export var spawn_point_path: NodePath = "../SpawnPoints/Hong_huei_yin_recall_event_point"
@export var move_player_to_spawn_on_ready := true
@export var auto_start_if_ready := true
@export var wait_for_scene_entry_fade := true

@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var huiyin_portrait_path := "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png"
@export var empty_portrait_path := "res://assets/sprites/empty.png"

@export var liuyu_speaker_id := 2
@export var huiyin_speaker_id := 1
@export var narration_speaker_id := 0

const F_READY_HUIYIN_VOICE := "main_yh_ready_huiyin_voice"
const F_HUIYIN_VOICE_DONE := "event_huiyin_voice_done"
const F_HEARD_HUIYIN_VOICE := "main_yh_heard_huiyin_voice"
const F_GO_TO_ZUIYUE_HUIYIN := "main_yh_go_to_zuiyue_huiyin"

var triggered := false
var area: Area2D = null
var player: Node = null
var dialog_manager: Node = null
var _entry_fade_completed := false


func _ready() -> void:
	area = get_node_or_null(area_path) as Area2D
	player = get_node_or_null(player_path)
	dialog_manager = get_node_or_null(dialog_manager_path)

	if area == null:
		push_warning("[紅徽音弦外之音] 找不到 Area2D：%s" % str(area_path))
		return
	if dialog_manager == null:
		push_warning("[紅徽音弦外之音] 找不到 DialogManager：%s" % str(dialog_manager_path))
		return

	area.body_entered.connect(_on_body_entered)
	if wait_for_scene_entry_fade:
		return

	# 保險機制：玩家轉場後可能一出生就已經在 Area2D 裡，body_entered 未必會觸發。
	# 因此等一幀/一個 physics frame 後檢查旗標，必要時直接啟動事件。
	await get_tree().process_frame
	await get_tree().physics_frame

	if not _should_start_event():
		return

	if player == null:
		player = get_node_or_null(player_path)

	if move_player_to_spawn_on_ready and player:
		_move_player_to_spawn()
		await get_tree().process_frame
		await get_tree().physics_frame

	if auto_start_if_ready and player:
		_start_event(player)
		return

	# 若不自動啟動，就檢查是否真的踩在 Area2D 裡。
	for body in area.get_overlapping_bodies():
		if body.name == "LiuYu":
			_start_event(body)
			return


func start_after_entry_fade() -> void:
	_entry_fade_completed = true
	if triggered or not _should_start_event():
		_release_entry_lock_if_no_event()
		return
	if player == null:
		player = get_node_or_null(player_path)
	if move_player_to_spawn_on_ready and player:
		_move_player_to_spawn()
		await get_tree().process_frame
		await get_tree().physics_frame
	if player:
		_start_event(player)
	else:
		push_warning("[紅徽音弦外之音] 進場淡出後仍找不到 LiuYu，解除控制鎖以避免卡死。")
		_release_entry_lock_if_no_event()


func _on_body_entered(body: Node) -> void:
	if triggered:
		return
	if wait_for_scene_entry_fade and not _entry_fade_completed:
		return
	if body.name != "LiuYu":
		return
	if not _should_start_event():
		return
	_start_event(body)


func _should_start_event() -> bool:
	return GlobalState.get_flag(F_READY_HUIYIN_VOICE) and not GlobalState.get_flag(F_HUIYIN_VOICE_DONE)


func _move_player_to_spawn() -> void:
	var spawn_point := get_node_or_null(spawn_point_path)
	if spawn_point == null:
		push_warning("[紅徽音弦外之音] 找不到 SpawnPoint：%s" % str(spawn_point_path))
		return
	if player and player is Node2D and spawn_point is Node2D:
		(player as Node2D).global_position = (spawn_point as Node2D).global_position


func _start_event(body: Node) -> void:
	if triggered:
		return
	triggered = true
	player = body

	if player:
		player.set("can_move", false)
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
	GlobalState.set_meta("menu_locked", true)
	GlobalState.set_meta("yinpingyu_cutscene_busy", false)
	GlobalState.set_meta("huiyin_recall_cutscene_busy", true)

	await dialog_manager.call("show_dialog_sequence", _build_huiyin_voice_lines(), self)

	GlobalState.set_flag(F_READY_HUIYIN_VOICE, false)
	GlobalState.set_flag(F_HUIYIN_VOICE_DONE, true)
	GlobalState.set_flag(F_HEARD_HUIYIN_VOICE, true)
	GlobalState.set_flag(F_GO_TO_ZUIYUE_HUIYIN, true)
	_set_main_objective_safely("前往醉月茶坊，尋找紅徽音。")

	if player:
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
		player.set("can_move", true)
	GlobalState.set_meta("menu_locked", false)
	GlobalState.set_meta("yinpingyu_cutscene_busy", false)
	GlobalState.set_meta("huiyin_recall_cutscene_busy", false)

	queue_free()


func reset_dialog_state() -> void:
	# DialogManager 關閉對話時仍由 _start_event 持有控制鎖，完成落旗後才統一釋放。
	pass


func _release_entry_lock_if_no_event() -> void:
	if player:
		player.set("can_move", true)
	GlobalState.set_meta("menu_locked", false)
	GlobalState.set_meta("yinpingyu_cutscene_busy", false)


func _build_huiyin_voice_lines() -> Array:
	return [
		_n("劉語塵走出白箋居。"),
		_n("天色漸暗，市集聲音變得稀薄。遠處琴聲仍在。"),
		_n("白箋居的門在身後合上，聲音很輕，卻像又一扇門關了。"),
		_l("左飲閉了山門。", liuyu_speaker_id, liuyu_portrait_path),
		_l("書眠也關上了筆墨。", liuyu_speaker_id, liuyu_portrait_path),
		_l("茶坊女伶的琴聲……卻偏偏在這時候纏住了我。", liuyu_speaker_id, liuyu_portrait_path),
		_n("他站在階下，一語不發。"),
		_n("左飲的線索中斷，鎮上的琴音難解，現在連書眠也將話收回了空白裡。"),
		_n("香包的氣味仍在衣襟旁，混著白箋居裡帶出的墨香。"),
		_l("我是不是……還是太晚了？", liuyu_speaker_id, liuyu_portrait_path),
		_n("微弱琴音與女性耳語混合浮現。"),
		_l("少俠……", huiyin_speaker_id, huiyin_portrait_path),
		_n("劉語塵驚愕抬頭。"),
		_l("誰？", liuyu_speaker_id, liuyu_portrait_path),
		_l("你終於能聽見我的弦外之音了。", huiyin_speaker_id, huiyin_portrait_path),
		_l("醉月茶坊的彈琴女伶？", liuyu_speaker_id, liuyu_portrait_path),
		_l("是我。", huiyin_speaker_id, huiyin_portrait_path),
		_l("時間不多了。", huiyin_speaker_id, huiyin_portrait_path),
		_l("若你願意知道玉衡鎮真正發生了什麼，請來醉月茶坊。", huiyin_speaker_id, huiyin_portrait_path),
		_l("你不能直接說？", liuyu_speaker_id, liuyu_portrait_path),
		_l("我能說的話，都壓在弦裡。", huiyin_speaker_id, huiyin_portrait_path),
		_l("你既已聽見，就請過來。", huiyin_speaker_id, huiyin_portrait_path),
		_n("琴聲微微一顫，像弦上有血，卻仍被彈得平穩。"),
		_l("……好。", liuyu_speaker_id, liuyu_portrait_path),
		_n("主線更新：前往醉月茶坊，尋找紅徽音。"),
	]


func _set_main_objective_safely(text: String) -> void:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("set_main_objective"):
		qm.set_main_objective(text)
		return

	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("set_main_objective"):
		qm.set_main_objective(text)


func _l(text: String, speaker: int, portrait: String = "") -> Dictionary:
	return {
		"text": text,
		"speaker": speaker,
		"portrait": portrait if portrait != "" else empty_portrait_path,
	}


func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": narration_speaker_id,
		"portrait": empty_portrait_path,
	}
