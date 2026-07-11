extends Node2D
class_name YuhengStalactiteCave

# ------------------------------------------------------------
# 場景路徑 / 基本設定
# ------------------------------------------------------------
@export_file("*.tscn") var yuheng_sewer_final_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_final_room/yuheng_sewer_final_room.tscn"
@export_file("*.tscn") var yin_yue_manor_room_night: String = "res://scenes/yuheng/YinYueManor/yin_yue_manor_room/yin_yue_manor_room(night).tscn"

@export var music_tag := "yuheng"
@export var map_display_name: String = "玉衡鎮地下鐘乳石洞"
@export var manor_spawn_point_name := "from_stalactite_cave"
@export var sewer_final_room_spawn_point_name := "from_yuheng_stalactite_cave"

# 之後 Seedance 影片出來後，可以讓 CutsceneManager 依這個 key 播放。
@export var intro_cutscene_key := "yuheng_stalactite_shumian_fish_intro"
@export var zuoyin_arrival_cutscene_key := "yuheng_stalactite_zuoyin_arrival"

# 戰鬥設定。若你的 BattleTransition / BattleController 有自己的 battle_id，改這裡即可。
@export var fish_boss_battle_id := "boss_yuheng_mutated_carp_spirit"
@export var fish_boss_enemy_id := "mutated_carp_spirit"

# 對話設定
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var shumian_portrait_path := "res://assets/sprites/Shu_mian/ShuMian_headshot.png"
@export var zuoyin_portrait_path := "res://assets/sprites/Zuo_yin/ZuoYin_headshot.png"

@export var narration_speaker_id := 0
@export var liuyu_speaker_id := 2
@export var shumian_speaker_id := 4
@export var zuoyin_speaker_id := 6

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var event_trigger: Area2D = get_node_or_null("Su_mien_event_trigger2/Su_mien_event_trigger")
@onready var shumian_npc: Node2D = get_node_or_null("NPC/Su_mien")
@onready var zuoyin_npc: Node2D = get_node_or_null("NPC/Zuo_yin")

signal dialog_closed

# ------------------------------------------------------------
# 劇情 / 戰鬥 Flags
# ------------------------------------------------------------
const F_STALACTITE_INTRO_DONE := "event_stalactite_shumian_intro_done"
const F_FISH_BOSS_STARTED := "battle_stalactite_fish_boss_started"
const F_FISH_BOSS_PHASE2 := "battle_stalactite_fish_boss_phase2"
const F_ZUOYIN_ASSIST_ACTIVE := "battle_stalactite_zuoyin_assist_active"
const F_FISH_BOSS_WON := "battle_stalactite_fish_boss_won"
const F_MANOR_AFTER_FISH_READY := "main_yh_manor_after_fish_ready"

const F_SHUMIAN_TEMP_JOINED := "party_shumian_temp_joined"
const F_ZUOYIN_GUEST_JOINED := "party_zuoyin_guest_joined"

var story_locked := false
var transition_locked := false
var _waiting_for_dialog := false


func _ready() -> void:
	if zuoyin_npc:
		zuoyin_npc.visible = false

	if event_trigger:
		if not event_trigger.body_entered.is_connected(_on_su_mien_event_trigger_body_entered):
			event_trigger.body_entered.connect(_on_su_mien_event_trigger_body_entered)
	else:
		push_warning("找不到 Su_mien_event_trigger2/Su_mien_event_trigger，鐘乳石洞事件不會自動觸發。")

	await _play_entry_fade()
	await show_map_name()

	# 若此戰已完成，玩家重回此圖時不再觸發。
	if _get_flag(F_FISH_BOSS_WON, false):
		_disable_event_trigger()


func get_map_display_name() -> String:
	return map_display_name


# ------------------------------------------------------------
# 進場淡入 / 地圖名稱
# ------------------------------------------------------------
func _play_entry_fade() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 1.5

	var tween_in := overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished


func show_map_name() -> void:
	var map_popup := get_node_or_null("CanvasLayer/MapNamePopup")
	if map_popup:
		map_popup.text = map_display_name
		map_popup.visible = true
		map_popup.modulate.a = 1.0

		await get_tree().create_timer(2.0).timeout

		var popup_tween := map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished

		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")


# ------------------------------------------------------------
# 事件觸發：書眠過場 → 魚怪 BOSS 戰
# ------------------------------------------------------------
func _on_su_mien_event_trigger_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if story_locked or _get_flag(F_STALACTITE_INTRO_DONE, false) or _get_flag(F_FISH_BOSS_WON, false):
		return

	story_locked = true
	_disable_event_trigger()
	_set_player_movable(false)

	await _start_stalactite_intro_and_battle()


func _start_stalactite_intro_and_battle() -> void:
	# 這裡是進入 Seedance 過場動畫的地方。
	# 若目前還沒接 CutsceneManager，就會改用文字 fallback。
	await _play_intro_cutscene_or_fallback()

	_set_flag(F_STALACTITE_INTRO_DONE, true)
	_set_flag(F_FISH_BOSS_STARTED, true)
	_set_flag(F_SHUMIAN_TEMP_JOINED, true)

	_add_shumian_temp_member()
	_prepare_battle_context()

	_set_player_movable(true)
	_start_fish_boss_battle()


func _play_intro_cutscene_or_fallback() -> void:
	var cutscene_manager := _get_cutscene_manager()
	if cutscene_manager:
		if cutscene_manager.has_method("play_cutscene"):
			await cutscene_manager.play_cutscene(intro_cutscene_key)
			return
		if cutscene_manager.has_method("play"):
			await cutscene_manager.play(intro_cutscene_key)
			return
		if cutscene_manager.has_method("play_by_key"):
			await cutscene_manager.play_by_key(intro_cutscene_key)
			return

	# Seedance 影片尚未接入時，使用這段文字保底，不會卡流程。
	await _show_dialog(_build_intro_fallback_lines())


func _build_intro_fallback_lines() -> Array:
	return [
		_l("劉少俠……？你怎麼會在這裡？", shumian_speaker_id, shumian_portrait_path),
		_l("書眠姑娘。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你離開白箋居後，神色不對。", liuyu_speaker_id, liuyu_portrait_path),
		_l("紅姑娘很擔心你。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……我也是。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你……為了找我，進了舊水道？", shumian_speaker_id, shumian_portrait_path),
		_l("那些機關與封印，不該那麼容易解開才是。", shumian_speaker_id, shumian_portrait_path),
		_l("確實不易。", liuyu_speaker_id, liuyu_portrait_path),
		_l("但我還是來了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……劉少俠。", shumian_speaker_id, shumian_portrait_path),
		_l("你的心意，我明白。", shumian_speaker_id, shumian_portrait_path),
		_l("可是，你不該來的。", shumian_speaker_id, shumian_portrait_path),
		_l("不是因為我不願見你。", shumian_speaker_id, shumian_portrait_path),
		_l("而是這裡的封印，不只是為了攔外人。", shumian_speaker_id, shumian_portrait_path),
		_l("它們也是為了讓這裡的水脈與濁氣維持平衡。", shumian_speaker_id, shumian_portrait_path),
		_l("所以，我解開封印，也驚動了它？", liuyu_speaker_id, liuyu_portrait_path),
		_l("……也許已經不只是驚動。", shumian_speaker_id, shumian_portrait_path),
		_l("你聽。", shumian_speaker_id, shumian_portrait_path),
		_n("洞中水聲忽然沉了下去。"),
		_n("桌上寫到一半的詩詞、石壁上的碑文，竟滲出一縷縷紫黑色穢氣。"),
		_n("那些穢氣滴入水面，像墨落清池，迅速向四周擴散。"),
		_l("這些是……語魅？", liuyu_speaker_id, liuyu_portrait_path),
		_l("看來，還是壓不住了。", shumian_speaker_id, shumian_portrait_path),
		_l("是我破了封印，才讓事情變成這樣？", liuyu_speaker_id, liuyu_portrait_path),
		_l("不是。", shumian_speaker_id, shumian_portrait_path),
		_l("你只是剛好推了最後一把。", shumian_speaker_id, shumian_portrait_path),
		_l("這裡本來就已經快撐不住了。", shumian_speaker_id, shumian_portrait_path),
		_n("水面下方忽然傳來劇烈震動。"),
		_l("小心，水下有東西！", shumian_speaker_id, shumian_portrait_path),
		_n("一尾受濁氣侵染的巨鯉破水而出，鱗甲翻黑，手中竟握著鏽蝕魚叉。"),
		_l("書眠姑娘，當心！", liuyu_speaker_id, liuyu_portrait_path),
		_l("劉少俠，我沒問題。", shumian_speaker_id, shumian_portrait_path),
		_n("她袖中筆鋒一轉，衣袂微揚，竟已擺出迎敵架勢。"),
		_n("劉語塵微微一怔，隨即握劍。"),
		_l("嗯。", liuyu_speaker_id, liuyu_portrait_path),
		_l("一起上。", liuyu_speaker_id, liuyu_portrait_path),
	]


# ------------------------------------------------------------
# BOSS 戰準備與啟動
# ------------------------------------------------------------
func _prepare_battle_context() -> void:
	# 給 BattleController / BattleTransition 讀取的劇情戰鬥條件。
	# 若你的戰鬥系統有自己的資料格式，保留這些 flag 也不衝突。
	_set_flag("current_story_battle_id", fish_boss_battle_id)
	_set_flag("current_story_battle_scene", "yuheng_stalactite_cave")
	_set_flag("battle_enemy_id", fish_boss_enemy_id)

	_set_flag("battle_phase2_hp_ratio", 0.5)
	_set_flag("battle_phase2_survive_turns", 3)
	_set_flag("battle_phase2_flag", F_FISH_BOSS_PHASE2)
	_set_flag("battle_assist_flag", F_ZUOYIN_ASSIST_ACTIVE)

	_set_flag("battle_party_slot_1", "liuyu")
	_set_flag("battle_party_slot_2", "shumian")
	_set_flag("battle_party_slot_3", "")
	_set_flag("battle_guest_slot_3", "zuoyin")
	_set_flag("battle_guest_slot_3_controllable", false)
	_set_flag("battle_guest_slot_3_ai", "zuoyin_debuff_defense_stop_regen")

	_set_flag("battle_on_win_callback", "on_fish_boss_battle_won")
	_set_flag("battle_on_phase2_callback", "on_fish_boss_phase_two_started")
	_set_flag("battle_on_phase2_survived_callback", "on_fish_boss_phase_two_survived_three_turns")


func get_fish_boss_battle_config() -> Dictionary:
	return {
		"battle_id": fish_boss_battle_id,
		"enemy_id": fish_boss_enemy_id,
		"party": ["liuyu", "shumian"],
		"phase_two": {
			"hp_ratio": 0.5,
			"survive_turns_before_assist": 3,
			"flag": F_FISH_BOSS_PHASE2,
		},
		"guest_assist": {
			"slot": 3,
			"member_id": "zuoyin",
			"controllable": false,
			"ai": "zuoyin_debuff_defense_stop_regen",
			"flag": F_ZUOYIN_ASSIST_ACTIVE,
			"effects": [
				"lower_enemy_defense",
				"disable_enemy_regen",
			],
		},
		"callbacks": {
			"phase2": "on_fish_boss_phase_two_started",
			"assist": "on_fish_boss_phase_two_survived_three_turns",
			"win": "on_fish_boss_battle_won",
		}
	}


func _start_fish_boss_battle() -> void:
	var config := get_fish_boss_battle_config()
	var battle_node := _get_battle_node()

	if battle_node == null:
		push_warning("找不到 BattleTransition / BattleController / BattleManager，暫以 print 代替開戰。")
		print("應進入 BOSS 戰：", config)
		return

	_connect_battle_finished_signal_if_possible(battle_node)

	if battle_node.has_method("start_battle_with_config"):
		battle_node.start_battle_with_config(config)
		return

	if battle_node.has_method("start_story_battle"):
		battle_node.start_story_battle(config)
		return

	if battle_node.has_method("start_battle"):
		battle_node.start_battle(fish_boss_battle_id)
		return

	if battle_node.has_method("begin_battle"):
		battle_node.begin_battle(fish_boss_battle_id)
		return

	push_warning("找到戰鬥節點，但沒有 start_battle/start_story_battle/start_battle_with_config 方法。")


func _connect_battle_finished_signal_if_possible(battle_node: Node) -> void:
	var signal_names := [
		"battle_finished",
		"battle_ended",
		"battle_result",
		"battle_won",
		"combat_finished",
	]

	for signal_name in signal_names:
		if battle_node.has_signal(signal_name):
			var callable := Callable(self, "_on_battle_finished")
			if not battle_node.is_connected(signal_name, callable):
				battle_node.connect(signal_name, callable, CONNECT_ONE_SHOT)
			return


func _on_battle_finished(result = null) -> void:
	var won := true

	if result is Dictionary and result.has("won"):
		won = bool(result["won"])
	elif result is bool:
		won = result
	elif result is String:
		won = result == "win" or result == "won" or result == "victory"

	if won:
		await on_fish_boss_battle_won()


# ------------------------------------------------------------
# 給戰鬥系統呼叫的劇情節點
# ------------------------------------------------------------
func on_fish_boss_phase_two_started() -> void:
	# BOSS 血量低於 50% 時呼叫。
	_set_flag(F_FISH_BOSS_PHASE2, true)
	_set_flag("battle_fish_boss_regen_active", true)
	_set_flag("battle_fish_boss_defense_buff_active", true)

	# 若戰鬥系統會顯示訊息，可讀這些 flag 或直接呼叫自己的 UI。
	print("魚怪進入二階：濁流護身 / 回血 / 防禦上升。")


func on_fish_boss_phase_two_survived_three_turns() -> void:
	# 玩家在二階撐過三回合後呼叫。
	if _get_flag(F_ZUOYIN_ASSIST_ACTIVE, false):
		return

	_set_flag(F_ZUOYIN_ASSIST_ACTIVE, true)
	_set_flag(F_ZUOYIN_GUEST_JOINED, true)

	await _play_zuoyin_arrival_cutscene_or_fallback()
	_activate_zuoyin_guest_assist()


func _play_zuoyin_arrival_cutscene_or_fallback() -> void:
	var cutscene_manager := _get_cutscene_manager()
	if cutscene_manager:
		if cutscene_manager.has_method("play_cutscene"):
			await cutscene_manager.play_cutscene(zuoyin_arrival_cutscene_key)
			return
		if cutscene_manager.has_method("play"):
			await cutscene_manager.play(zuoyin_arrival_cutscene_key)
			return
		if cutscene_manager.has_method("play_by_key"):
			await cutscene_manager.play_by_key(zuoyin_arrival_cutscene_key)
			return

	await _show_dialog([
		_n("巨鯉仰首嘶吼，洞中水脈應聲翻黑。"),
		_n("紫黑濁氣如鎖，纏上牠的鱗甲。"),
		_l("不好……它在借水脈反噬封印！", shumian_speaker_id, shumian_portrait_path),
		_l("這樣下去，整座洞都會被拖進去。", liuyu_speaker_id, liuyu_portrait_path),
		_n("就在此時，一道寒光自洞口斜斬而入。"),
		_n("水面翻起的濁潮被硬生生劈成兩半。"),
		_l("退半步。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("左飲？", liuyu_speaker_id, liuyu_portrait_path),
		_l("別分心。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("魚怪交給你們。", zuoyin_speaker_id, zuoyin_portrait_path),
		_l("濁氣的根，我來斬。", zuoyin_speaker_id, zuoyin_portrait_path),
		_n("左飲斬斷濁流，魚怪的「濁流護身」開始崩解。"),
		_n("左飲加入助戰。"),
	])


func _activate_zuoyin_guest_assist() -> void:
	# 給戰鬥系統讀取：左飲作為第三格客座角色，玩家不可控制。
	_set_flag("battle_party_slot_3", "zuoyin")
	_set_flag("battle_party_slot_3_controllable", false)
	_set_flag("battle_zuoyin_assist_ai", "debuff_defense_stop_regen")

	# 左飲效果：削弱魚怪防禦與回血。
	_set_flag("battle_fish_boss_regen_active", false)
	_set_flag("battle_fish_boss_defense_buff_active", false)
	_set_flag("battle_fish_boss_defense_debuff_by_zuoyin", true)
	_set_flag("battle_fish_boss_regen_disabled_by_zuoyin", true)

	var party_manager := _get_party_manager()
	if party_manager:
		if party_manager.has_method("set_guest_member"):
			party_manager.set_guest_member(3, "zuoyin")
		elif party_manager.has_method("add_guest_member"):
			party_manager.add_guest_member("zuoyin")
		elif party_manager.has_method("set_party_member"):
			party_manager.set_party_member(3, "zuoyin")


func on_fish_boss_battle_won() -> void:
	if _get_flag(F_FISH_BOSS_WON, false):
		return

	_set_flag(F_FISH_BOSS_WON, true)
	_set_flag(F_MANOR_AFTER_FISH_READY, true)

	# 戰後先清除客座戰鬥狀態。書眠正式入隊放到飲月山莊會談結尾再處理。
	_set_flag(F_ZUOYIN_ASSIST_ACTIVE, false)
	_set_flag(F_ZUOYIN_GUEST_JOINED, false)
	_set_flag("battle_party_slot_3", "")
	_set_flag("battle_party_slot_3_controllable", false)

	await _transition_to_yin_yue_manor_night()


func on_fish_boss_battle_lost() -> void:
	# 可給戰鬥系統失敗時呼叫。先保留，不自動處理 Game Over。
	_set_flag("battle_stalactite_fish_boss_lost", true)


# ------------------------------------------------------------
# Party helpers
# ------------------------------------------------------------
func _add_shumian_temp_member() -> void:
	var party_manager := _get_party_manager()
	if party_manager:
		if party_manager.has_method("add_temp_member"):
			party_manager.add_temp_member("shumian")
			return
		if party_manager.has_method("set_party_member"):
			party_manager.set_party_member(2, "shumian")
			return
		if party_manager.has_method("add_member"):
			party_manager.add_member("shumian")
			return

	# 找不到 party manager 時，至少用 GlobalState 讓戰鬥系統讀得到。
	_set_flag("battle_party_slot_2", "shumian")


func _get_party_manager() -> Node:
	var paths := [
		"/root/PartyManager",
		"/root/GameRoot/PartyManager",
		"/root/PartyController",
		"/root/GameRoot/PartyController",
	]
	return _get_first_node(paths)


# ------------------------------------------------------------
# 轉場：回終端房 / 回飲月山莊夜晚
# ------------------------------------------------------------
func _on_to_yuheng_sewer_final_room_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if story_locked or transition_locked:
		return

	transition_locked = true
	_set_player_movable(false)

	await _fade_out()

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = sewer_final_room_spawn_point_name
		if game_root.has_method("change_map_to"):
			game_root.change_map_to(yuheng_sewer_final_room)
			return

	get_tree().change_scene_to_file(yuheng_sewer_final_room)


func _transition_to_yin_yue_manor_night() -> void:
	transition_locked = true
	_set_player_movable(false)

	await _fade_out()

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = manor_spawn_point_name
		if game_root.has_method("change_map_to"):
			game_root.change_map_to(yin_yue_manor_room_night)
			return

	get_tree().change_scene_to_file(yin_yue_manor_room_night)


func _fade_out() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 0.0

	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	await tween.finished


# ------------------------------------------------------------
# Node finders
# ------------------------------------------------------------
func _get_cutscene_manager() -> Node:
	var paths := [
		"/root/CutsceneManager",
		"/root/GameRoot/CutsceneManager",
		"/root/CutscenePlayer",
		"/root/GameRoot/CutscenePlayer",
	]
	return _get_first_node(paths)


func _get_battle_node() -> Node:
	var paths := [
		"/root/GameRoot/BattleTransition",
		"/root/BattleTransition",
		"/root/GameRoot/BattleController",
		"/root/BattleController",
		"/root/GameRoot/BattleManager",
		"/root/BattleManager",
	]
	return _get_first_node(paths)


func _get_first_node(paths: Array[String]) -> Node:
	for node_path in paths:
		var node := get_node_or_null(node_path)
		if node:
			return node
	return null


# ------------------------------------------------------------
# 共用工具：玩家 / Trigger
# ------------------------------------------------------------
func _is_player(body: Node) -> bool:
	return body.name == "LiuYu" or body.name == "Player" or body.is_in_group("player")


func _set_player_movable(value: bool) -> void:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player == null:
		player = get_node_or_null("/root/Player")

	if player:
		player.set("can_move", value)


func _disable_event_trigger() -> void:
	if event_trigger == null:
		return

	for child in event_trigger.get_children():
		if child is CollisionShape2D:
			child.disabled = true


# ------------------------------------------------------------
# Dialog helpers
# ------------------------------------------------------------
func _show_dialog(lines: Array) -> void:
	var dialog_manager := _get_dialog_manager()

	if dialog_manager == null:
		for line in lines:
			print(line)
		return

	if dialog_manager.has_method("show_dialog_sequence"):
		_waiting_for_dialog = true
		dialog_manager.show_dialog_sequence(lines, self)
		await _wait_dialog_finished(dialog_manager)
		return

	if dialog_manager.has_method("start_dialog"):
		dialog_manager.start_dialog(_lines_to_text_array(lines))
		await _wait_dialog_finished(dialog_manager)
		return

	for line in lines:
		print(line)


func _get_dialog_manager() -> Node:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager:
		return dialog_manager

	dialog_manager = get_node_or_null("/root/DialogManager")
	if dialog_manager:
		return dialog_manager

	return null


func _wait_dialog_finished(dialog_manager: Node) -> void:
	if dialog_manager.has_signal("dialog_sequence_finished"):
		await dialog_manager.dialog_sequence_finished
	elif _waiting_for_dialog:
		await dialog_closed

	_waiting_for_dialog = false


func reset_dialog_state() -> void:
	if _waiting_for_dialog:
		_waiting_for_dialog = false
		dialog_closed.emit()


func _lines_to_text_array(lines: Array) -> Array[String]:
	var result: Array[String] = []
	for line in lines:
		if line is Dictionary and line.has("text"):
			result.append(str(line["text"]))
		else:
			result.append(str(line))
	return result


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


# ------------------------------------------------------------
# GlobalState helpers
# ------------------------------------------------------------
func _get_flag(flag_name: String, default_value = null):
	var global_state := _get_global_state()
	if global_state == null:
		return default_value

	if global_state.has_method("get_flag"):
		var value = global_state.get_flag(flag_name)
		if value == null:
			return default_value
		return value

	var value = global_state.get(flag_name)
	if value == null:
		return default_value

	return value


func _set_flag(flag_name: String, value) -> void:
	var global_state := _get_global_state()
	if global_state == null:
		push_warning("找不到 GlobalState，無法寫入：" + flag_name)
		return

	if global_state.has_method("set_flag"):
		global_state.set_flag(flag_name, value)
	else:
		global_state.set(flag_name, value)


func _get_global_state() -> Node:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state:
		return global_state

	global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state:
		return global_state

	return null
