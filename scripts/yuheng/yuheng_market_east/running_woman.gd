extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var wander_range := 240
@export var wander_interval := 1.5
@export var wander_speed := 60.0
@export var use_path_patrol := true
@export var path_node: NodePath

@onready var animated_sprite := $AnimatedSprite2D
var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var wander_target := Vector2.ZERO
var wander_timer := 0.0
var last_direction := Vector2.DOWN
var last_idle_direction := Vector2.DOWN
var is_talking: bool = false
var has_recently_talked: bool = false
var patrol_progress := 0.0
var path_ref: PathFollow2D = null
var previous_position: Vector2 = Vector2.ZERO
var _interaction_flow_active := false
var _unlock_on_next_reset := false

const QUEST_ID := "yuheng_green_beans"
const QUEST_TITLE := "一把四季豆"
const QUEST_STAGE_1_DESC := "前往市集菜鋪，替秋嬸買回炸過的熟豆。"
const QUEST_STAGE_2_DESC := "將四季豆帶回給秋嬸。"
const QUEST_GET_FLAG := "got_yuheng_green_beans_quest"
const BEAN_RAW_ITEM_ID := "quest_green_beans_raw"
const BEAN_FRIED_ITEM_ID := "quest_green_beans_fried"

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[NPC] PathFollow2D 沒有設定或找不到：" + str(path_node))

	previous_position = global_position

	dialog_lines = [
		{ "text": "「趁今天天氣好，趕快把衣服洗乾淨曬起來。」", "speaker": speaker_id, "portrait": portrait_path },
	]

func _process(delta):
	z_index = int(global_position.y + z_index_offset)

	if is_talking or has_recently_talked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if use_path_patrol and path_ref:
		patrol_progress += wander_speed * delta
		path_ref.progress = patrol_progress
		var new_position = path_ref.global_position
		var movement_dir = (new_position - previous_position).normalized()
		global_position = new_position
		_play_directional_anim(movement_dir)
		previous_position = new_position
		return

	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = wander_interval
		wander_target = global_position + Vector2(
			randi_range(-wander_range, wander_range),
			randi_range(-wander_range, wander_range)
		)

	var dir = (wander_target - global_position).normalized()
	velocity = dir * wander_speed

	if velocity.length() > 1:
		_play_directional_anim(dir)
	else:
		velocity = Vector2.ZERO
		if last_direction.distance_to(last_idle_direction) > 0.1:
			last_idle_direction = last_direction
		var idle_anim = _get_anim_by_vector(last_idle_direction, "idle")
		if animated_sprite.sprite_frames.has_animation(idle_anim):
			animated_sprite.play(idle_anim)

	move_and_slide()

func _play_directional_anim(dir: Vector2):
	if dir.length() < 0.1:
		return
	last_direction = dir
	var anim_name = _get_anim_by_vector(dir, "walk")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		animated_sprite.play("idle_down")

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

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	last_direction = direction
	last_idle_direction = direction
	var anim_name = _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false

func _unhandled_input(event):
	if not can_interact:
		return
	if dialog_manager.dialog_active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_begin_interaction_flow()
		var player_pos = get_node("/root/GameRoot/LiuYu").global_position
		face_towards(player_pos)
		_run_qiushen_interaction()

func reset_dialog_state():
	if _interaction_flow_active and not _unlock_on_next_reset:
		is_talking = true
		return
	_end_interaction_flow()

func _run_qiushen_interaction() -> void:
	await _handle_qiushen_interact()
	if _interaction_flow_active:
		_end_interaction_flow()

func _handle_qiushen_interact() -> void:
	var quest := SideQuestManager.get_quest(QUEST_ID)
	if not quest.has("quest_id"):
		await _start_green_beans_quest_intro()
		return
	if bool(quest.get("is_finished", false)):
		await _show_post_quest_loop_dialog(quest)
		return
	var stage := int(quest.get("stage", 0))
	if stage <= 1:
		_unlock_on_next_reset = true
		await _play_sequence_and_wait([
			{ "text": "「少俠，記得啊，是炸過一遍的熟豆。生的可不能直接拿回來下肚。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "「唉，明明這句話我在這裡說得清清楚楚，怎麼一到菜鋪前，就像有人把它揉進琴聲裡了呢……」", "speaker": speaker_id, "portrait": portrait_path },
		])
		return
	await _report_green_beans_result(quest)

func _start_green_beans_quest_intro() -> void:
	_unlock_on_next_reset = true
	await _play_sequence_and_wait([
		{ "text": "「四季豆……四季豆……炸過的……還是沒炸的……哎唷，不對不對，我到底要買哪一種來著？」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "劉語塵：「這位大嬸，你已經在這廣場來回走了好幾趟。可是迷了路？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「迷路？那倒不至於。咱在玉衡鎮住了大半輩子，閉著眼都能摸回灶房。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "「怪就怪在……我一走到市集菜鋪前，耳邊那琴聲一繞，腦子就像被人輕輕拍了一下，什麼都散了。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "劉語塵：「你的眼睛還好嗎？要不要去藥鋪請大夫看看？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「哎呀，不是眼睛的事。咱眼睛好著呢，連隔壁老王偷夾我醃蘿蔔都看得一清二楚。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "「可到了菜鋪前就不行。心裡倒是平靜得很，偏偏注意力不在眼前。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "「別說分得清生的熟的，咱光是記得自己是來買四季豆，就已經很了不起了。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "劉語塵：「生熟不分可不是小事。四季豆若未熟透，吃下去輕則腹痛嘔吐，重則中毒。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「是啊，所以咱才在這裡繞圈嘛。站在廣場還記得，走到菜鋪又忘了。回到廣場又想起來，走到菜鋪又忘了……」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "「再繞下去，晚飯沒做成，咱倒先把自己繞熟了。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "劉語塵：「既然如此，我替你走一趟吧。你要買的是炸過的熟豆，對嗎？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「對對對！就是炸過一遍的熟豆，回去拌點蒜鹽就能上桌。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "「少俠，你可真是好心。菜鋪就在市集那頭，阿茂家的攤，四季豆堆得跟小山似的，很好認。」", "speaker": speaker_id, "portrait": portrait_path },
	])
	_register_green_beans_quest()

func _register_green_beans_quest() -> void:
	if not SideQuestManager.get_quest(QUEST_ID).has("quest_id"):
		SideQuestManager.register_quest(QUEST_ID, {"quest_id": QUEST_ID, "title": QUEST_TITLE})
	var quest := SideQuestManager.get_quest(QUEST_ID)
	quest["title"] = QUEST_TITLE
	quest["description"] = QUEST_STAGE_1_DESC
	quest["objective"] = QUEST_STAGE_1_DESC
	quest["current_objective"] = QUEST_STAGE_1_DESC
	quest["notes"] = ["秋嬸受琴聲影響，總在菜鋪前分不清生熟。"]
	quest["note"] = "秋嬸受琴聲影響，總在菜鋪前分不清生熟。"
	quest["stage"] = 1
	quest["is_finished"] = false
	SideQuestManager.side_quests[QUEST_ID] = quest
	if GlobalState and GlobalState.has_method("set_flag"):
		GlobalState.set_flag(QUEST_GET_FLAG, true)

func _report_green_beans_result(quest: Dictionary) -> void:
	var bean_type := String(quest.get("bean_type", "raw"))
	if bean_type == "fried":
		_unlock_on_next_reset = false
		await _play_sequence_and_wait([
			{ "text": "「少俠，你回來啦！讓我看看……」", "speaker": speaker_id, "portrait": portrait_path },
		])
		if InventorySync:
			InventorySync.consume_item(BEAN_FRIED_ITEM_ID, 1, true)
		_unlock_on_next_reset = true
		await _play_sequence_and_wait([
			{ "text": "「哎呀，就是這個！炸過一遍的熟豆，香氣不會騙人。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "「年輕人就是有定力。那市集琴聲裊裊的，連我這種老玉衡人都被牽著走，你倒還分得清。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "劉語塵：「不是我定力好。只是這琴聲的影響，比我想得更深。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "「深是深，可日子不能不過啊。飯要煮，菜要買，人再怎麼分神，也得想辦法把晚飯端上桌。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "「來，這些小意思給你買茶解渴。還有這包草藥，是我在自家後院摘的。」", "speaker": speaker_id, "portrait": portrait_path },
		])
		if InventorySync:
			InventorySync.add_gold(30)
			InventorySync.add_item_stack("med_trauma_herb", 1)
		quest["ending"] = "right"
		quest["notes"] = ["豆子買對了，秋嬸總算能安心做晚飯。"]
		quest["note"] = "豆子買對了，秋嬸總算能安心做晚飯。"
	else:
		_unlock_on_next_reset = false
		await _play_sequence_and_wait([
			{ "text": "「少俠，你回來啦！讓我看看……」", "speaker": speaker_id, "portrait": portrait_path },
		])
		if InventorySync:
			InventorySync.consume_item(BEAN_RAW_ITEM_ID, 1, true)
		_unlock_on_next_reset = true
		await _play_sequence_and_wait([
			{ "text": "「哎呀，這是生的四季豆。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "劉語塵：「……生的？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "「嗯，還沒炸過。看來那市集前的琴聲，連你這樣的年輕人也能分神。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "劉語塵：「抱歉，是我疏忽了。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "「別這麼說。至少我站在這廣場，還分得出它是生是熟。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "「來，這些小錢給你買點涼的喝。路上辛苦啦。」", "speaker": speaker_id, "portrait": portrait_path },
		])
		if InventorySync:
			InventorySync.add_gold(20)
		quest["ending"] = "wrong"
		quest["notes"] = ["豆子買成生的了，但秋嬸仍笑著收下這份好意。"]
		quest["note"] = "豆子買成生的了，但秋嬸仍笑著收下這份好意。"

	SideQuestManager.complete_quest(QUEST_ID)
	quest["description"] = "已完成：一把四季豆"
	quest["objective"] = "把日常過下去，本身就是一種定力。"
	quest["current_objective"] = quest["objective"]
	SideQuestManager.side_quests[QUEST_ID] = quest

func _play_sequence_and_wait(lines: Array) -> void:
	if dialog_manager == null:
		return
	dialog_manager.show_dialog_sequence(lines, self)
	await dialog_manager.dialog_sequence_finished

func _show_post_quest_loop_dialog(quest: Dictionary) -> void:
	if String(quest.get("ending", "")) == "right":
		_unlock_on_next_reset = true
		await _play_sequence_and_wait([
			{ "text": "「那晚的四季豆拌蒜鹽，可香啦。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "「多虧少俠幫忙，不然咱家晚飯怕是要從四季豆變成白粥配懊悔了。」", "speaker": speaker_id, "portrait": portrait_path },
		])
	else:
		_unlock_on_next_reset = true
		await _play_sequence_and_wait([
			{ "text": "「後來我把那把四季豆煮得透透的，沒事，放心。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "「不過少俠啊，你也別太自責。這鎮上的琴聲，連鍋鏟聽久了都會發呆。」", "speaker": speaker_id, "portrait": portrait_path },
		])

func _begin_interaction_flow() -> void:
	_interaction_flow_active = true
	_unlock_on_next_reset = false
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = false
	is_talking = true

func _end_interaction_flow() -> void:
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = true
	is_talking = false
	_interaction_flow_active = false
	_unlock_on_next_reset = false
