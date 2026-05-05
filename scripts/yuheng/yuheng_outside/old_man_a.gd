# 客棧用路人 NPC 通用腳本模板 (支援 Gossip Flag)
extends CharacterBody2D
const EnemyDB = preload("res://scripts/db/EnemyDB.gd")

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var gossip_flag := "heard_oldman_zuoyin" # 例："heard_oldman_leftyin"
@export var trigger_topic := "zuoyin" # 例："leftyin"
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var _interaction_flow_active := false
var _unlock_on_next_reset := false

const QUEST_ID := "yh_side_oldfighter_01"
const QUEST_TITLE := "拳骨未老"
const FLAG_WEAPON_WIN := "yh_side_oldfighter_weapon_win"
const FLAG_UNARMED_WIN := "yh_side_oldfighter_unarmed_win"

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC 通用模板] DialogManager 沒抓到！")

	if dialog_manager:
		dialog_manager.connect("dialog_sequence_finished", Callable(self, "_on_dialogue_finished"))

	if dialog_lines.is_empty():
		dialog_lines = [
			{ "text": "「這平臺啊... 曾經也是第一武堂賽的場地呢...」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「現在少年們不喜歡武學，都去搞那什麼文墨了...」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「嗯？你說左飲啊？我年輕時候和他們也總是在這練演武呢。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「唉，希望可以再看到一次他的燕行破風斬...」", "speaker": 1, "portrait": portrait_path },
		]
	call_deferred("_try_resolve_oldfighter_battle_return")

func _process(_delta):
	z_index = int(global_position.y + z_index_offset)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	var anim_name = _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _get_anim_by_vector(dir: Vector2, prefix: String) -> String:
	var angle = dir.angle()
	if angle >= -PI * 7/8 and angle < -PI * 5/8:
		return "%s_left_up" % prefix
	elif angle >= -PI * 5/8 and angle < -PI * 3/8:
		return "%s_up" % prefix
	elif angle >= -PI * 3/8 and angle < -PI * 1/8:
		return "%s_right_up" % prefix
	elif angle >= -PI * 1/8 and angle < PI * 1/8:
		return "%s_right" % prefix
	elif angle >= PI * 1/8 and angle < PI * 3/8:
		return "%s_right_down" % prefix
	elif angle >= PI * 3/8 and angle < PI * 5/8:
		return "%s_down" % prefix
	elif angle >= PI * 5/8 and angle < PI * 7/8:
		return "%s_left_down" % prefix
	else:
		return "%s_left" % prefix

func _unhandled_input(event):
	if not can_interact:
		return
	if dialog_manager.dialog_active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_begin_interaction_flow()
		var player_pos = get_node("/root/GameRoot/LiuYu").global_position
		face_towards(player_pos)
		_run_oldfighter_interaction()

func _on_dialogue_finished(npc_node):
	if npc_node != self:
		return

	# 🎯 這裡就是對話完全播完後的安全時機！
	_check_gossip_topic()


func _check_gossip_topic():
	if trigger_topic == "":
		return

	var flags := [
		"heard_wanderoldman_%s" % trigger_topic,
		"heard_waterwoman_%s" % trigger_topic,
		"heard_oldman_%s" % trigger_topic
	]

	var all_flags_ok := true
	for flag in flags:
		if not GlobalState.get_flag(flag):
			all_flags_ok = false
			break

	if all_flags_ok and not GlobalState.get_flag("triggered_%s_gossip_summary" % trigger_topic):
		GlobalState.set_flag("triggered_%s_gossip_summary" % trigger_topic, true)

		# 🎯 關鍵：等對話完後再播獨白！
		await get_tree().process_frame
		dialog_manager.show_dialog_sequence([
			{ "text": "（看來在鎮民的眼裡，左飲本來是位古道熱腸的俠義之士...）", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "（只是最近出於某些原因鮮少露面了）", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "嗯...", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "再繼續跟更多人打聽些左飲的消息好了。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		], self)


func reset_dialog_state():
	if _interaction_flow_active and not _unlock_on_next_reset:
		return
	_end_interaction_flow()

func _run_oldfighter_interaction() -> void:
	await _handle_oldfighter_interact()
	if _interaction_flow_active:
		_end_interaction_flow()

func _handle_oldfighter_interact() -> void:
	var quest := SideQuestManager.get_quest(QUEST_ID)
	if quest.has("quest_id") and bool(quest.get("is_finished", false)):
		_unlock_on_next_reset = false
		await _play_sequence_and_wait([
			{ "text": "「左飲那小子啊，當年出刀快得像燕子掠水。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「可他真正厲害的，不是刀快，是收刀也快。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「一個人能傷人不稀奇，能在該停的地方停下來，才叫本事。」", "speaker": 1, "portrait": portrait_path },
		])
		return
	if not quest.has("quest_id"):
		await _start_oldfighter_intro_and_offer()
		return
	await _offer_spar_choice()

func _start_oldfighter_intro_and_offer() -> void:
	_unlock_on_next_reset = false
	await _play_sequence_and_wait([
		{ "text": "「唉……這演武台啊，從前可熱鬧得很。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「那時候的年輕人，誰不想在這裡露兩手？刀劍拳腳，打得木樁都快開花。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "劉語塵：「如今倒是冷清。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「我年輕時，曾在這台上與左飲比劃過。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「那小子身法快，出刀更快。一式『燕行破風斬』，我至今都忘不了。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「少俠，既然你也帶著一身江湖氣，不如上來與老夫比劃比劃？」", "speaker": 1, "portrait": portrait_path },
	])
	GlobalState.set_flag(gossip_flag, true)
	if not SideQuestManager.get_quest(QUEST_ID).has("quest_id"):
		SideQuestManager.register_quest(QUEST_ID, {"quest_id": QUEST_ID, "title": QUEST_TITLE})
	var quest := SideQuestManager.get_quest(QUEST_ID)
	quest["title"] = QUEST_TITLE
	quest["description"] = "演武台旁的老翁懷念昔日武風，也提起曾與左飲在此比劃。他似乎很想再與人活動筋骨。"
	quest["objective"] = "與演武台旁的老翁比試。"
	quest["current_objective"] = quest["objective"]
	quest["stage"] = 1
	quest["is_finished"] = false
	SideQuestManager.side_quests[QUEST_ID] = quest
	await _offer_spar_choice()

func _offer_spar_choice() -> void:
	dialog_manager.show_choice([
		{ "text": "與老翁比試", "callback": Callable(self, "_choose_spar") },
		{ "text": "暫時婉拒", "callback": Callable(self, "_choose_decline") },
	])

func _choose_decline() -> void:
	dialog_manager.choice_box.hide_choices()
	_unlock_on_next_reset = false
	dialog_manager.show_dialog_sequence([
		{ "text": "劉語塵：「晚輩還有事在身，改日再向前輩請教。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「改日？江湖人最愛說改日。罷了罷了，年輕人怕輸也正常。」", "speaker": 1, "portrait": portrait_path },
	], self)

func _choose_spar() -> void:
	dialog_manager.choice_box.hide_choices()
	await _start_oldfighter_sparring_battle()

func _resolve_spar_result(has_weapon: bool, has_armor_or_acc: bool) -> void:
	_unlock_on_next_reset = false
	if not has_weapon and not has_armor_or_acc:
		await _play_sequence_and_wait([
			{ "text": "「咦？你……你連兵器甲飾都未帶，便敢上演武台？」", "speaker": 1, "portrait": portrait_path },
			{ "text": "劉語塵：「前輩不是說比劃筋骨嗎？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		])
		await _complete_oldfighter_quest()
		return
	if has_weapon:
		GlobalState.set_flag(FLAG_WEAPON_WIN, true)
		await _play_sequence_and_wait([
			{ "text": "「停停停！不打了不打了！你提著兵器跟我較勁，這不算見拳！」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「若真有本事，就卸了兵器，空手與我再比一回！」", "speaker": 1, "portrait": portrait_path },
		])
		var quest := SideQuestManager.get_quest(QUEST_ID)
		quest["stage"] = 2
		quest["objective"] = "卸下武器，再與老翁比試一次。"
		quest["current_objective"] = quest["objective"]
		SideQuestManager.side_quests[QUEST_ID] = quest
		return
	GlobalState.set_flag(FLAG_UNARMED_WIN, true)
	await _play_sequence_and_wait([
		{ "text": "「沒用兵器是不假，可你身上行頭那麼多！還不算純粹！」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「無兵、無甲、無飾，再與我比一回，老夫才認你真本事！」", "speaker": 1, "portrait": portrait_path },
	])
	var quest2 := SideQuestManager.get_quest(QUEST_ID)
	quest2["stage"] = 3
	quest2["objective"] = "卸下武器、防具與飾品，再與老翁比試。"
	quest2["current_objective"] = quest2["objective"]
	SideQuestManager.side_quests[QUEST_ID] = quest2

func _start_oldfighter_sparring_battle() -> void:
	var equip := InventorySync.get_equipped("liuyu")
	var has_weapon := String(equip.get("weapon_1", "")) != "" or String(equip.get("weapon_2", "")) != ""
	var has_armor_or_acc := false
	for slot in ["armor_head", "armor_body", "armor_hands", "armor_feet", "accessory_1", "accessory_2"]:
		if String(equip.get(slot, "")) != "":
			has_armor_or_acc = true
			break
	if not has_weapon and not has_armor_or_acc:
		await _play_sequence_and_wait([
			{ "text": "「咦？你……你連兵器甲飾都未帶，便敢上演武台？」", "speaker": 1, "portrait": portrait_path },
			{ "text": "劉語塵：「前輩不是說比劃筋骨嗎？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "「好，好一個比劃筋骨！」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「年輕人，你倒是比那些滿身行頭的江湖客乾脆多了。」", "speaker": 1, "portrait": portrait_path },
		])
	GlobalState.set_meta("oldfighter_spar_pending", true)
	GlobalState.set_meta("oldfighter_spar_has_weapon", has_weapon)
	GlobalState.set_meta("oldfighter_spar_has_armor_or_acc", has_armor_or_acc)
	var game_root = get_node_or_null("/root/GameRoot")
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if game_root == null or liuyu == null:
		return
	GlobalState.set_meta("return_player_pos", liuyu.global_position)
	var enemy := EnemyDB.make_enemy("yuheng_old_fighter")
	enemy["ui_index"] = 0
	var context = {
		"player_party": TeamData.get_active_party(),
		"enemy_party": [enemy],
		"ruleset": {"id": "sparring"},
		"battle_tag": "yuheng_old_fighter_spar",
		"zone_id": "yuheng_old_fighter_spar",
	}
	GlobalState.set_meta("pending_battle_context", context)
	liuyu.can_move = false
	game_root.change_map_to("res://scenes/battle_scene.tscn")

func _try_resolve_oldfighter_battle_return() -> void:
	if not GlobalState.get_meta("oldfighter_spar_pending", false):
		return
	var result_meta = GlobalState.get_meta("pending_battle_result", {})
	if typeof(result_meta) != TYPE_DICTIONARY:
		return
	GlobalState.remove_meta("oldfighter_spar_pending")
	var result := String((result_meta as Dictionary).get("result", ""))
	var has_weapon := bool(GlobalState.get_meta("oldfighter_spar_has_weapon", true))
	var has_armor_or_acc := bool(GlobalState.get_meta("oldfighter_spar_has_armor_or_acc", true))
	GlobalState.remove_meta("oldfighter_spar_has_weapon")
	GlobalState.remove_meta("oldfighter_spar_has_armor_or_acc")
	if result != "victory":
		_begin_interaction_flow()
		await _play_sequence_and_wait([
			{ "text": "「哼哼，年輕人，江湖飯可不是靠臉吃的。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「回去調調氣，想清楚身上哪些東西是本事，哪些東西只是重量，再來找老夫。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "你在比試中落敗。這場比試不會造成死亡，稍作整備後可再次挑戰。", "speaker": 1, "portrait": portrait_path },
		])
		_end_interaction_flow()
		return
	_begin_interaction_flow()
	await _resolve_spar_result(has_weapon, has_armor_or_acc)
	_end_interaction_flow()

func _complete_oldfighter_quest() -> void:
	await _play_sequence_and_wait([
		{ "text": "「好！好啊！你捨去外物，仍能守住拳意，這才是真本事。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「這兩本祕笈，你拿去。」", "speaker": 1, "portrait": portrait_path },
	])
	if TeamData and TeamData.has_method("learn_inner_force"):
		TeamData.learn_inner_force("liuyu", "shipo_xinfa")
	if TeamData and TeamData.has_method("learn_skill"):
		TeamData.learn_skill("liuyu", "skill_tianjingquan")
	var quest := SideQuestManager.get_quest(QUEST_ID)
	quest["description"] = "已完成：拳骨未老"
	quest["objective"] = "習得石破心法與天驚拳。"
	quest["current_objective"] = quest["objective"]
	SideQuestManager.side_quests[QUEST_ID] = quest
	SideQuestManager.complete_quest(QUEST_ID)

func _play_sequence_and_wait(lines: Array) -> void:
	dialog_manager.show_dialog_sequence(lines, self)
	await dialog_manager.dialog_sequence_finished

func _begin_interaction_flow() -> void:
	_interaction_flow_active = true
	_unlock_on_next_reset = false
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = false

func _end_interaction_flow() -> void:
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = true
	_interaction_flow_active = false
	_unlock_on_next_reset = false
