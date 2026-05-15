extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/inn_boss.png"
@export var speaker_id := 1
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines := []
var stage := 0
var is_talking: bool = false
var has_recently_talked: bool = false
var just_advanced := false
var _mark_lore_flag_after_close := false
const INN_BOSS_QUEST_ID := "talk_to_yuheng_inn_boss"
const INN_BOSS_QUEST_TITLE := "向旅館老闆打聽左飲消息"
const INN_BOSS_STAGE0_DESCRIPTION := "向旅館老闆打聽左飲消息"
const INN_BOSS_STAGE0_OBJECTIVE := "向旅館老闆打聽左飲消息"
const INN_BOSS_STAGE1_DESCRIPTION := "代替老闆向左飲問好"
const INN_BOSS_STAGE1_OBJECTIVE := "與左飲見面，並向他提及旅館老闆的事情"
const INN_BOSS_STAGE1_NOTE := "問問看左飲是否還記得『江湖冷，給人一口熱湯，勝過一劍天下。』這句話。"
const INN_BOSS_QUEST_GET_FLAG := "got_talk_to_yuheng_inn_boss_quest"
# TODO: 與左飲對話「關於旅店老闆的事」完成後，
# 將此支線標記完成並追加收束筆記：
# 「原來左飲曾歷經讓內心如此拉扯的過往……」

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[警告] DialogManager 沒抓到！請確認路徑")

	var quest_already_registered := SideQuestManager.get_quest(INN_BOSS_QUEST_ID).has("quest_id")
	var quest_already_got := GlobalState != null and GlobalState.has_method("get_flag") and bool(GlobalState.get_flag(INN_BOSS_QUEST_GET_FLAG))
	if quest_already_registered or quest_already_got:
		_ensure_inn_boss_side_quest()
	var inn_quest = SideQuestManager.get_quest(INN_BOSS_QUEST_ID)
	if int(inn_quest.get("stage", 0)) > 0:
		_mark_inn_boss_lore_flags()

func _process(_delta):
	z_index = int(global_position.y + z_index_offset)

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	var anim_name = _get_anim_by_vector(direction, "idle")
	if $AnimatedSprite2D.sprite_frames.has_animation(anim_name):
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

func show_dialog_sequence(lines: Array) -> void:
	if dialog_manager:
		dialog_manager.show_dialog_sequence(lines, self)
	else:
		push_warning("[警告] DialogManager 為 null，無法顯示對話。")

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true
		print("流語客進入互動區域")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false
		print("流語客離開互動區域")

func _unhandled_input(event):
	if not can_interact or just_advanced:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_node("/root/GameRoot/LiuYu").can_move = false
		var player_pos = get_node("/root/GameRoot/LiuYu").global_position
		face_towards(player_pos)
		_on_interact()

func reset_dialog_state():
	if _mark_lore_flag_after_close:
		_mark_inn_boss_lore_flags()
		_mark_lore_flag_after_close = false
	is_talking = false
	has_recently_talked = false
	just_advanced = false
	get_node("/root/GameRoot/LiuYu").can_move = true
func _on_interact():
	var quest = SideQuestManager.get_quest(INN_BOSS_QUEST_ID)
	if not quest.has("quest_id"):
		_start_inn_boss_quest_intro()
		return
	var stage = int(quest.get("stage", 0))
	if stage == 0:
		dialog_manager.show_choice([
			{ "text": "打聽左飲消息", "callback": Callable(self, "_talk_about_zuoyin") },
			{ "text": "沒事了", "callback": Callable(self, "_end_conversation") },
		])
	elif stage >= 1:
		_mark_lore_flag_after_close = true
		show_dialog_sequence([
			{ "text": "（微笑）要是真的能見到左飲，也替我問他一句：\n　『還記得當年醉月樓的桂花酒不？』", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "——就說是我，還在這間店守著他說過的那句話：\n　『江湖冷，給人一口熱湯，勝過一劍天下。』", "speaker": speaker_id, "portrait": portrait_path },
		])

func _talk_about_zuoyin():
	dialog_manager.choice_box.hide_choices()
	_mark_lore_flag_after_close = true
	show_dialog_sequence([
		{ "text": "劉語塵：「老闆，我是從外鄉來的，聽說這玉衡鎮有位左飲大哥，\n曾經行走江湖、見多識廣……敝人有些事情想請教他。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「但我一介凡夫, 不知是否能入足飲月山莊… 」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "（語氣一轉，放低聲音）唉呀……你要找左飲啊。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "（頓了一下，擦擦手上的布巾）他啊，這幾年是住在鎮外的飲月山莊。\n白日裡門關得緊，一般人上山可見不著他」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "不過你要是想上山，我勸你……先問問自己是抱著什麼心情去的。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "劉語塵：「我只是想請教他一點事，並無惡意。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「（語氣轉溫，但仍保留一點距離）年輕人，你看著是正派人。\n左飲大哥心腸不壞，就是這些年……看得多、想得多，\n說得少了。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "「有人說他怪，有人說他清高，其實啊——」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "（老闆望向窗外，語調一緩）「他只是不想再看著誰，把江湖\n當成救命的繩子，卻反被那繩子勒死了。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "劉語塵：「(…的確有許多人只是為了逃避社會才投身江湖,而非為了\n心中的情與義…)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「(然而苟且偷生的下場…卻反而落得自己死無葬身之地…)。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「(看來左飲十分在乎他人的『義』是否夠真)。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「我明白了，謝謝老闆指點。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "（微笑）要是真的能見到左飲，也替我問他一句：『還記得當年\n醉月樓的桂花酒不？』」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "—— 就說是我，還在這間店守著他說過的那句話：\n『江湖冷，給人一口熱湯，勝過一劍天下。』」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "劉語塵：「(看樣子左飲目前算是半隱退江湖的狀態,原因在於過去\n太多人以江湖情義之名和他來往,最後卻辜負了他)。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「(除非讓他信得過我的為人，否則在他眼中我應該也跟\n其他人一樣…)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「(只是以『義氣』之名來跟他稱兄道弟，實際上只是想\n利用他的人脈資源佔他便宜的吧)。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
	])
	_apply_inn_boss_quest_stage_1()
	just_advanced = true

func _start_inn_boss_quest_intro() -> void:
	_mark_lore_flag_after_close = true
	show_dialog_sequence([
		{ "text": "這位客倌,住得還滿意嗎? 如果還有甚麼需要的儘管吩咐啊", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "(嗯…或許可以問問這位客棧老闆關於左飲的消息?)", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
	])
	if dialog_manager:
		await dialog_manager.dialog_sequence_finished
	else:
		push_warning("[旅館老闆] DialogManager 缺失，直接接取支線以避免卡住流程。")
	_accept_inn_boss_side_quest()

func _accept_inn_boss_side_quest() -> void:
	if not SideQuestManager.get_quest(INN_BOSS_QUEST_ID).has("quest_id"):
		SideQuestManager.register_quest(INN_BOSS_QUEST_ID, {
			"quest_id": INN_BOSS_QUEST_ID,
			"title": INN_BOSS_QUEST_TITLE
		})
	_ensure_inn_boss_side_quest()
	if GlobalState and GlobalState.has_method("set_flag"):
		GlobalState.set_flag(INN_BOSS_QUEST_GET_FLAG, true)

func _ensure_inn_boss_side_quest() -> void:
	if not SideQuestManager.get_quest(INN_BOSS_QUEST_ID).has("quest_id"):
		SideQuestManager.register_quest(INN_BOSS_QUEST_ID, {
			"quest_id": INN_BOSS_QUEST_ID,
			"title": INN_BOSS_QUEST_TITLE
		})
	var quest := SideQuestManager.get_quest(INN_BOSS_QUEST_ID)
	var stage := int(quest.get("stage", 0))
	quest["quest_id"] = INN_BOSS_QUEST_ID
	quest["title"] = INN_BOSS_QUEST_TITLE
	quest["description"] = INN_BOSS_STAGE1_DESCRIPTION if stage >= 1 else INN_BOSS_STAGE0_DESCRIPTION
	quest["objective"] = INN_BOSS_STAGE1_OBJECTIVE if stage >= 1 else INN_BOSS_STAGE0_OBJECTIVE
	quest["current_objective"] = quest["objective"]
	quest["notes"] = [INN_BOSS_STAGE1_NOTE] if stage >= 1 else []
	quest["note"] = INN_BOSS_STAGE1_NOTE if stage >= 1 else ""
	# stage>=2 目前預留給未來「與左飲對話完成」收尾實作。
	SideQuestManager.side_quests[INN_BOSS_QUEST_ID] = quest

func _apply_inn_boss_quest_stage_1() -> void:
	SideQuestManager.advance_quest(INN_BOSS_QUEST_ID, 1)
	var quest := SideQuestManager.get_quest(INN_BOSS_QUEST_ID)
	quest["title"] = INN_BOSS_QUEST_TITLE
	quest["description"] = INN_BOSS_STAGE1_DESCRIPTION
	quest["objective"] = INN_BOSS_STAGE1_OBJECTIVE
	quest["current_objective"] = INN_BOSS_STAGE1_OBJECTIVE
	quest["notes"] = [INN_BOSS_STAGE1_NOTE]
	quest["note"] = INN_BOSS_STAGE1_NOTE
	SideQuestManager.side_quests[INN_BOSS_QUEST_ID] = quest

func _mark_inn_boss_lore_flags() -> void:
	if GlobalState == null or not GlobalState.has_method("set_flag"):
		return
	GlobalState.set_flag("met_yuheng_inn_boss", true)
	GlobalState.set_flag("met_yuheng_teahouse_boss", true)

func _end_conversation():
	dialog_manager.choice_box.hide_choices()
	print("[NPC] 玩家選擇略過詢問左飲的支線。")
	get_node("/root/GameRoot/LiuYu").can_move = true
