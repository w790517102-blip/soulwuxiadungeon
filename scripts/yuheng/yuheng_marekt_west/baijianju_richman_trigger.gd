extends Node2D

const EMPTY_PORTRAIT := "res://assets/sprites/empty.png"
const LIUYU_PORTRAIT := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const RICHMAN_PORTRAIT := EMPTY_PORTRAIT
const NARRATION_SPEAKER := 0
const LIUYU_SPEAKER := 2
const NPC_SPEAKER := 1
const F_MANOR_CLOSED := "main_yh_manor_closed"
const F_EVENT_DONE := "event_baijianju_richman_done"
const F_BAIJIANJU_OPEN := "main_yh_baijianju_open"
const MAIN_QUEST_ID := "main_001"
const EVENT_STAGE := 4
const EVENT_OBJECTIVE := "進入白箋居，確認書眠是否無恙。"
const BAIJIANJU_EVENT_SCENE := "res://scenes/yuheng/yuheng_market_west/Bai_Jian_Jue/bai_jian_jue_scene1.tscn"

@onready var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
@onready var player := get_node_or_null("/root/GameRoot/LiuYu") as CharacterBody2D
@onready var area := get_node_or_null("Area2D") as Area2D
@onready var player_path := get_node_or_null("to_bai_jian_ju_front") as Path2D
@onready var scene_root := get_parent()
@onready var overlay := scene_root.get_node_or_null("BlackOverlay") as ColorRect
@onready var richman_root := scene_root.get_node_or_null("NPC/yuheng_Parvenu") as Node2D
@onready var richman_actor := scene_root.get_node_or_null("NPC/yuheng_Parvenu/Bookstore_guestC") as CharacterBody2D
@onready var richman_out_path := scene_root.get_node_or_null("NPC/yuheng_Parvenu/Path_OutFromBookstore") as Path2D
@onready var richman_leave_path := scene_root.get_node_or_null("NPC/yuheng_Parvenu/Path_LeaveTown") as Path2D

var triggered := false
var cutscene_busy := false
var _menu_was_locked := false
var _forbidden_busy := false
var _forbidden_requires_exit: Dictionary = {}
var _transition_busy := false


func _ready() -> void:
	_connect_scene_areas()
	if GlobalState.get_flag(F_EVENT_DONE):
		_apply_post_event_scene_state.call_deferred()
		return

	if not GlobalState.get_flag(F_MANOR_CLOSED):
		_hide_richman_until_entrance()
		return

	# 進入事件副本後立即持有控制鎖，避免出生點與 Trigger 重疊檢查前可移動或開選單。
	cutscene_busy = true
	_menu_was_locked = bool(GlobalState.get_meta("menu_locked", false))
	_lock_cutscene_controls()
	_hide_richman_until_entrance()
	if area and not area.body_entered.is_connected(_on_player_entered):
		area.body_entered.connect(_on_player_entered)
	_check_spawn_overlap.call_deferred()


func _check_spawn_overlap() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if triggered or area == null or player == null:
		return
	if area.get_overlapping_bodies().has(player):
		_on_player_entered(player)
		return
	# SpawnPoint 與 Area2D 理應重疊；若物理查詢未及更新，位置在碰撞框附近時仍安全啟動。
	var shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and player.global_position.distance_to(shape.global_position) <= 140.0:
		push_warning("[暴發戶事件] 出生重疊查詢未回報 LiuYu，改以 SpawnPoint 距離啟動。")
		_on_player_entered(player)


func _on_player_entered(body: Node2D) -> void:
	if triggered or body == null or body.name != "LiuYu":
		return
	if not GlobalState.get_flag(F_MANOR_CLOSED) or GlobalState.get_flag(F_EVENT_DONE):
		return
	triggered = true
	_run_richman_cutscene()


func _run_richman_cutscene() -> void:
	_lock_cutscene_controls()
	await _fade_event_scene_in()
	await _run_player_approach()
	await _play_hidden_richman_intro()
	await _run_richman_entrance()
	await _play_dialog(_build_recognition_lines())
	await _play_dialog(_build_confrontation_lines())
	await _run_richman_exit()
	await _finalize_richman_event_under_black()
	await _fade_overlay_to(0.0)
	await get_tree().create_timer(0.3).timeout
	await _play_after_event_line()
	_finish_cutscene_safely()


func _run_player_approach() -> void:
	await _move_node_along_path(player, player_path, 1.55, "劉語塵進場")
	_play_idle(player, Vector2(1, -1))
	await get_tree().create_timer(0.4).timeout


func _play_hidden_richman_intro() -> void:
	await _play_dialog([
		_unknown("哼！跩什麼跩？！"),
		_l("……！", LIUYU_SPEAKER, LIUYU_PORTRAIT),
	])


func _run_richman_entrance() -> void:
	if richman_actor:
		richman_actor.visible = true
	await _move_node_along_path(richman_actor, richman_out_path, 1.45, "暴發戶出場")
	if richman_actor and player:
		_play_idle(richman_actor, (player.global_position - richman_actor.global_position).normalized())


func _run_richman_exit() -> void:
	_lock_cutscene_controls()
	# 老闆指定：暴發戶開始離場時便同步淡黑，而非等他走完全程才淡黑。
	var fade_tween: Tween = null
	if overlay:
		overlay.visible = true
		fade_tween = overlay.create_tween()
		fade_tween.tween_property(overlay, "modulate:a", 1.0, 1.8)
	else:
		push_warning("[暴發戶事件] 暴發戶離場時找不到 BlackOverlay，略過同步淡黑。")
	await _move_node_along_path(richman_actor, richman_leave_path, 1.8, "暴發戶離場")
	if fade_tween and fade_tween.is_running():
		await fade_tween.finished
	if richman_actor:
		_play_idle(richman_actor, Vector2(1, 1))


func _fade_event_scene_in() -> void:
	if overlay == null:
		push_warning("[暴發戶事件] 進場找不到 BlackOverlay，略過全黑淡出並繼續。")
		return
	overlay.visible = true
	overlay.modulate.a = 1.0
	await get_tree().process_frame
	await get_tree().physics_frame
	await _fade_overlay_to(0.0)


func _finalize_richman_event_under_black() -> void:
	if richman_root and is_instance_valid(richman_root):
		_disable_node_tree(richman_root)
		richman_root.queue_free()
		richman_root = null
		richman_actor = null
		await get_tree().process_frame
	else:
		push_warning("[暴發戶事件] 全黑結算時找不到 yuheng_Parvenu；仍繼續落旗以避免流程卡死。")

	GlobalState.set_flag(F_EVENT_DONE, true)
	GlobalState.set_flag(F_BAIJIANJU_OPEN, true)
	_advance_main_quest_to_event_stage()
	_disable_main_trigger()


func _play_after_event_line() -> void:
	await _play_dialog([
		_l("（心想）方才鬧出這麼大動靜……", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("（心想）得先去看看書眠是否無恙。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
	])


func _finish_cutscene_safely() -> void:
	if overlay:
		overlay.modulate.a = 0.0
		overlay.visible = false
	if player:
		_clear_player_motion()
		if player.has_method("_restore_idle_animation"):
			player.call("_restore_idle_animation")
		player.set("can_move", true)
	GlobalState.set_meta("menu_locked", _menu_was_locked)
	cutscene_busy = false


func _apply_post_event_scene_state() -> void:
	triggered = true
	cutscene_busy = false
	# 舊存檔若只留下事件完成旗標，也要重建白箋居已開放的世界狀態。
	GlobalState.set_flag(F_BAIJIANJU_OPEN, true)
	_disable_main_trigger()
	if richman_root and is_instance_valid(richman_root):
		_disable_node_tree(richman_root)
		richman_root.queue_free()
		richman_root = null
		richman_actor = null
	if overlay:
		overlay.modulate.a = 0.0
		overlay.visible = false
	if player:
		_clear_player_motion()
		player.set("can_move", true)


func _hide_richman_until_entrance() -> void:
	if richman_actor:
		richman_actor.visible = false


func _disable_main_trigger() -> void:
	if area:
		area.monitoring = false
		area.monitorable = false
		var collision := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision:
			collision.set_deferred("disabled", true)


func _lock_cutscene_controls() -> void:
	cutscene_busy = true
	var system_menu := get_node_or_null("/root/SystemMenu")
	if system_menu and system_menu.has_method("close_menu_if_open"):
		system_menu.call("close_menu_if_open")
	GlobalState.set_meta("menu_locked", true)
	if player:
		player.set("can_move", false)
		player.set("override_idle_animation", true)
		_clear_player_motion()


func _clear_player_motion() -> void:
	if player == null:
		return
	player.velocity = Vector2.ZERO
	player.set("direction", Vector2.ZERO)


func _move_node_along_path(node: Node2D, path: Path2D, duration: float, label: String) -> void:
	if node == null:
		push_warning("[暴發戶事件] %s找不到移動角色，略過走位並繼續。" % label)
		return
	if path == null:
		push_warning("[暴發戶事件] %s找不到 Path2D，保留角色現位並繼續。" % label)
		return
	var follow := path.get_node_or_null("PathFollow2D") as PathFollow2D
	if follow == null:
		push_warning("[暴發戶事件] %s的 Path2D 缺少 PathFollow2D，改將角色放到 Curve 終點並繼續。" % label)
		_place_node_at_curve_end(node, path)
		return
	if path.curve == null or path.curve.get_baked_length() <= 0.0:
		push_warning("[暴發戶事件] %s的 Curve2D 無有效長度，保留角色現位並繼續。" % label)
		return

	follow.progress_ratio = 0.0
	node.global_position = follow.global_position
	var elapsed := 0.0
	var previous_position := node.global_position
	while elapsed < duration and is_instance_valid(node):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		follow.progress_ratio = clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		node.global_position = follow.global_position
		var move_direction := node.global_position - previous_position
		if move_direction.length_squared() > 0.01:
			_play_walk(node, move_direction.normalized())
		previous_position = node.global_position
	if is_instance_valid(node):
		follow.progress_ratio = 1.0
		node.global_position = follow.global_position
		if node is CharacterBody2D:
			(node as CharacterBody2D).velocity = Vector2.ZERO


func _place_node_at_curve_end(node: Node2D, path: Path2D) -> void:
	if node == null or path == null or path.curve == null:
		return
	var curve_length := path.curve.get_baked_length()
	if curve_length <= 0.0:
		return
	node.global_position = path.to_global(path.curve.sample_baked(curve_length))
	if node is CharacterBody2D:
		(node as CharacterBody2D).velocity = Vector2.ZERO


func _play_walk(node: Node2D, direction: Vector2) -> void:
	var sprite := node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var walk_name := _anim_name_for_direction(direction, "walk")
	if sprite.sprite_frames.has_animation(walk_name):
		sprite.play(walk_name)
		return
	var idle_name := _anim_name_for_direction(direction, "idle")
	if sprite.sprite_frames.has_animation(idle_name):
		sprite.play(idle_name)


func _play_idle(node: Node2D, direction: Vector2) -> void:
	if node == null:
		return
	var sprite := node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim_name := _anim_name_for_direction(direction, "idle")
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


func _anim_name_for_direction(direction: Vector2, prefix: String) -> String:
	var angle := direction.angle()
	if angle >= -PI * 7.0 / 8.0 and angle < -PI * 5.0 / 8.0:
		return "%s_left_up" % prefix
	if angle < -PI * 3.0 / 8.0:
		return "%s_up" % prefix
	if angle < -PI * 1.0 / 8.0:
		return "%s_right_up" % prefix
	if angle < PI * 1.0 / 8.0:
		return "%s_right" % prefix
	if angle < PI * 3.0 / 8.0:
		return "%s_right_down" % prefix
	if angle < PI * 5.0 / 8.0:
		return "%s_down" % prefix
	if angle < PI * 7.0 / 8.0:
		return "%s_left_down" % prefix
	return "%s_left" % prefix


func _play_dialog(lines: Array, preserve_cutscene_lock := true) -> void:
	if dialog_manager == null:
		push_warning("[暴發戶事件] 找不到 DialogManager，略過本段對話並繼續安全收束。")
		return
	if preserve_cutscene_lock:
		_lock_cutscene_controls()
	await dialog_manager.call("show_dialog_sequence", lines, self)
	if preserve_cutscene_lock:
		_lock_cutscene_controls()


func _fade_overlay_to(target_alpha: float) -> void:
	if overlay == null:
		push_warning("[暴發戶事件] 找不到 BlackOverlay，略過淡入淡出並繼續。")
		return
	overlay.visible = true
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", target_alpha, 0.5)
	await tween.finished
	if is_equal_approx(target_alpha, 0.0):
		overlay.visible = false


func _advance_main_quest_to_event_stage() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager == null or not quest_manager.has_method("get_main_quest_state"):
		push_warning("[暴發戶事件] 找不到 QuestManager，旗標已落但無法推進 stage 4。")
		return
	var main_quest := quest_manager.call("get_main_quest_state") as Dictionary
	if String(main_quest.get("id", "")) != MAIN_QUEST_ID:
		return
	var current_stage := int(main_quest.get("stage", 1))
	if current_stage == 3 and quest_manager.has_method("advance_main_quest"):
		quest_manager.call("advance_main_quest", EVENT_STAGE, EVENT_OBJECTIVE)
	elif current_stage >= EVENT_STAGE and quest_manager.has_method("set_main_objective"):
		quest_manager.call("set_main_objective", EVENT_OBJECTIVE)
	else:
		push_warning("[暴發戶事件] 預期 main_001 stage 3，實際為 stage %d；不跨階強推。" % current_stage)


func _connect_scene_areas() -> void:
	_connect_forbidden_area("yuheng_market_east_forbidden", "SpawnPoints/from_yuheng_market_east")
	_connect_forbidden_area("yuheng_weapon_shop_forbidden", "SpawnPoints/from_yuheng_weapon_shop")
	_connect_forbidden_area("pharmacy_forbidden", "SpawnPoints/from_yuheng_pharmacy")
	_connect_forbidden_area("Bamboo_Grove_Suburb_forbidden", "SpawnPoints/from_Bamboo_Grove_Suburb")
	var baijianju_area := scene_root.get_node_or_null("to_Bai_Jian_Jue") as Area2D
	if baijianju_area and not baijianju_area.body_entered.is_connected(_on_baijianju_entered):
		baijianju_area.body_entered.connect(_on_baijianju_entered)


func _connect_forbidden_area(area_path: String, marker_path: String) -> void:
	var forbidden_area := scene_root.get_node_or_null(area_path) as Area2D
	var return_marker := scene_root.get_node_or_null(marker_path) as Marker2D
	if forbidden_area == null:
		push_warning("[暴發戶事件] 找不到 Forbidden Zone：%s" % area_path)
		return
	forbidden_area.body_entered.connect(_on_forbidden_body_entered.bind(forbidden_area, return_marker))
	forbidden_area.body_exited.connect(_on_forbidden_body_exited.bind(forbidden_area))


func _on_forbidden_body_entered(body: Node2D, forbidden_area: Area2D, return_marker: Marker2D) -> void:
	if body == null or body.name != "LiuYu" or cutscene_busy or _forbidden_busy:
		return
	if bool(_forbidden_requires_exit.get(forbidden_area.get_instance_id(), false)):
		return
	await _play_forbidden_flow(body as CharacterBody2D, forbidden_area, return_marker)


func _on_forbidden_body_exited(body: Node2D, forbidden_area: Area2D) -> void:
	if body and body.name == "LiuYu" and not _forbidden_busy:
		_forbidden_requires_exit[forbidden_area.get_instance_id()] = false


func _play_forbidden_flow(body: CharacterBody2D, forbidden_area: Area2D, return_marker: Marker2D) -> void:
	if body == null:
		return
	_forbidden_busy = true
	_forbidden_requires_exit[forbidden_area.get_instance_id()] = true
	var menu_was_locked := bool(GlobalState.get_meta("menu_locked", false))
	GlobalState.set_meta("menu_locked", true)
	body.set("can_move", false)
	body.velocity = Vector2.ZERO
	await _play_dialog([
		_l("（心想）現在不是往這裡去的時候。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("（心想）方才白箋居鬧出那麼大動靜，得先看看書眠是否無恙。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
	], false)
	body.set("can_move", false)
	await _fade_overlay_to(1.0)
	if return_marker:
		body.global_position = return_marker.global_position
		body.velocity = Vector2.ZERO
		await get_tree().physics_frame
	else:
		push_warning("[暴發戶事件] Forbidden Zone %s 找不到退回 Marker。" % forbidden_area.name)
	await _fade_overlay_to(0.0)
	body.velocity = Vector2.ZERO
	body.set("can_move", true)
	GlobalState.set_meta("menu_locked", menu_was_locked)
	_forbidden_busy = false


func _on_baijianju_entered(body: Node2D) -> void:
	if body == null or body.name != "LiuYu" or cutscene_busy or _transition_busy:
		return
	if not GlobalState.get_flag(F_EVENT_DONE) or not GlobalState.get_flag(F_BAIJIANJU_OPEN):
		return
	var baijianju_area := scene_root.get_node_or_null("to_Bai_Jian_Jue") as Area2D
	if not MapTransitionGuard.can_transition(body, baijianju_area):
		return
	_transition_busy = true
	body.set("can_move", false)
	if body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO
	await _fade_overlay_to(1.0)
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root and game_root.has_method("change_map_to"):
		game_root.set("spawn_point_name", "from_yuheng_market_west_scene1")
		game_root.call("change_map_to", BAIJIANJU_EVENT_SCENE)
	else:
		push_warning("[暴發戶事件] 找不到 GameRoot.change_map_to，恢復玩家控制。")
		await _fade_overlay_to(0.0)
		body.set("can_move", true)
		_transition_busy = false


func _disable_node_tree(root: Node) -> void:
	root.process_mode = Node.PROCESS_MODE_DISABLED
	for child in root.find_children("*", "CollisionShape2D", true, false):
		(child as CollisionShape2D).set_deferred("disabled", true)
	for child in root.find_children("*", "Area2D", true, false):
		(child as Area2D).set_deferred("monitoring", false)
		(child as Area2D).set_deferred("monitorable", false)


func _build_recognition_lines() -> Array:
	return [_l("那個人……是方才白箋居裡的那位暴發戶！", LIUYU_SPEAKER, LIUYU_PORTRAIT)]


func _build_confrontation_lines() -> Array:
	return [
		_r("喂！你不是方才也在白箋居裡的那位少俠嗎？"),
		_r("來得正好。你替我進去跟那女人說一聲——她那些親筆詩稿，我出雙倍價錢！"),
		_r("不，三倍也成！"),
		_l("書眠姑娘既已說不賣，閣下再加多少銀兩，又有何用？", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_r("哪有做買賣嫌銀子多的？"),
		_r("她不過是故作清高，想抬高價錢罷了。"),
		_r("你替我把話帶到。事成之後，自然少不了你的好處。"),
		_l("閣下誤會了。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("她不賣，不是因為價錢不夠。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_r("那是為什麼？"),
		_n("你忽然想起方才讀過的《臨風寄影》。"),
		_n("那些原本連千言萬語也難以說清的感受，曾在短短幾行詩裡，被你真真切切地接住。"),
		_n("而那份才剛泛起的酸楚與悸動，又曾被街上那道琴聲一點一點按回沉寂。"),
		_l("因為她寫下的，從來不只是幾張紙、幾行字。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("若只是把它買回去，當成尋常筆墨收藏，或拿來襯托自己有幾分雅致——", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("那你買到的，也只是紙上的字。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("真正留在詩裡的東西，是要有人願意讀、願意感受，才接得住的。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("至少我讀過之後，是這麼想的。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_n("你始終壓著語氣，不疾不徐地向眼前的暴發戶說明。"),
		_n("你原只是希望他多少能聽懂一些——白書眠的拒絕從來不是價碼的多寡，更不是故作清高。"),
		_y("她已在這座鎮子裡承受了太多無聲的委屈。至少這一次，不該連自己珍而重之的文字，都被旁人曲解成待價而沽的玩物。"),
		_n("你原以為，話說到這裡，他多少會聽進去一些。"),
		_n("誰知那暴發戶聽罷，只是不屑地撇了撇嘴，目光又在你身上來回打量一番，彷彿方才那番話根本不值得放在心上。"),
		_r("哼！我肯花銀子買她的字，是看得起她！"),
		_n("你怔了一下。"),
		_n("原本放鬆的指尖，不知何時已微微發僵；一股細麻沿著脊背竄上後頸，連頭皮都隱隱發緊。"),
		_n("那不是畏懼。"),
		_n("你很清楚——那是怒意。"),
		_y("《臨風寄影》的字句重新浮上心頭；書眠安靜的神情、那些被琴聲壓回胸口的感動，以及書客談起往事時逐漸麻木的臉，也一一掠過眼前。"),
		_n("你本就不是容易動怒的人。"),
		_y("可眼前之人明明能恣意宣洩自己的不滿，卻偏偏將另一個人的真心踩在腳下，還把那叫作『抬舉』。"),
		_n("你緩緩吐出一口氣。"),
		_n("再開口時，聲音依舊平穩，只是那雙眼裡，已再沒有半分退讓。"),
		_l("你那不是誠意。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("只是毫無品味可言的銀子。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_r("你——！"),
		_l("你要的也不是字。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("是旁人看你時，多敬你半寸的眼神。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_r("我買她的詩稿，拿回去好生供著，有什麼不對？"),
		_l("供的是詩，還是閣下自己的門面？", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_l("這一點，閣下心裡應該明白。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_r("說到底，不過是幾張紙、幾行字！"),
		_r("這世上還有銀子買不到的東西？"),
		_l("有。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_r("什麼？"),
		_l("你買不到別人願意。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		{"wait": 0.35},
		_r("今日她不賣，來日自有人求著我買！"),
		_l("我也覺得你等得到。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_r("算你識相。"),
		_l("等到書都成精了懂得嫌你這個人。", LIUYU_SPEAKER, LIUYU_PORTRAIT),
		_r("你——！"),
		_r("哼！山水有相逢，咱們走著瞧！"),
	]


func _l(text: String, speaker: int, portrait: String) -> Dictionary:
	return {"text": "劉語塵：「%s」" % text, "speaker": speaker, "portrait": portrait}


func _r(text: String) -> Dictionary:
	return {"text": "暴發戶：「%s」" % text, "speaker": NPC_SPEAKER, "portrait": RICHMAN_PORTRAIT}


func _n(text: String) -> Dictionary:
	return {"text": text, "speaker": NARRATION_SPEAKER, "portrait": EMPTY_PORTRAIT}


func _unknown(text: String) -> Dictionary:
	return {"text": "？？？：「%s」" % text, "speaker": NPC_SPEAKER, "portrait": EMPTY_PORTRAIT}


func reset_dialog_state() -> void:
	# DialogManager 每段結束都會呼叫；整場控制權只由 _finish_cutscene_safely 統一釋放。
	pass


## 第二人稱／劉語塵內心的旁白：用下方、劉語塵同側的對話框，不帶頭像。
func _y(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": LIUYU_SPEAKER,
		"portrait": EMPTY_PORTRAIT,
	}
