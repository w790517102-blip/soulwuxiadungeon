# res://npc/apothecary_vendor.gd
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

const QUEST_ID := "yuheng_valley_herb"
const QUEST_TITLE := "谷影入藥"
const ITEM_VALLEY_GRASS := "quest_valley_shadow_grass"
const ITEM_AWAKEN_TONIC := "med_awaken_tonic"

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[NPC] PathFollow2D 沒有設定或找不到：" + str(path_node))

	previous_position = global_position

	var main_stage := _get_main_stage_safely()
	dialog_lines = _build_lines_for_stage(main_stage)

func _process(delta):
	z_index = int(global_position.y + z_index_offset)

	if is_talking or has_recently_talked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if use_path_patrol and path_ref:
		# 路徑巡邏
		patrol_progress += wander_speed * delta
		path_ref.progress = patrol_progress
		var new_position = path_ref.global_position
		var movement_dir = (new_position - previous_position).normalized()
		global_position = new_position
		_play_directional_anim(movement_dir)
		previous_position = new_position
		return
	else:
		# 隨機游走
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = wander_interval
			wander_target = global_position + Vector2(
				randi_range(-wander_range, wander_range),
				randi_range(-wander_range, wander_range))

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
		if is_talking:
			return
		_begin_interaction_flow()
		var liuyu := get_node("/root/GameRoot/LiuYu")
		face_towards(liuyu.global_position)
		_run_herb_seller_interaction()

func reset_dialog_state():
	if _interaction_flow_active and not _unlock_on_next_reset:
		is_talking = true
		return
	_end_interaction_flow()

func _run_herb_seller_interaction() -> void:
	await _handle_herb_seller_interact()
	if _interaction_flow_active:
		_end_interaction_flow()

func _handle_herb_seller_interact() -> void:
	var quest := SideQuestManager.get_quest(QUEST_ID)
	if not quest.has("quest_id"):
		await _start_valley_herb_quest_intro()
		return
	if bool(quest.get("is_finished", false)):
		_unlock_on_next_reset = false
		await _play_sequence_and_wait([
			{ "text": "「谷影草性子清冷，能把神思從昏沉裡拉回來。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「少俠若再遇頭昏眼花、神思不清之症，記得備上一帖醒神湯。」", "speaker": 1, "portrait": portrait_path },
		])
		return
	var stage := int(quest.get("stage", 0))
	if stage <= 1:
		_unlock_on_next_reset = false
		await _play_sequence_and_wait([
			{ "text": "「谷影草要三朵才夠用。廣場邊緣陰影重的地方，最容易找到。」", "speaker": 1, "portrait": portrait_path },
		])
		return
	await _turn_in_valley_herb_quest()

func _start_valley_herb_quest_intro() -> void:
	_unlock_on_next_reset = false
	await _play_sequence_and_wait([
		{ "text": "「少俠來得正好。我想調一帖安神不滯的藥，偏偏還缺三朵谷影草。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「若你願意幫忙，就去玉衡鎮廣場邊緣看看，陰影處常有它。」", "speaker": 1, "portrait": portrait_path },
	])
	if not SideQuestManager.get_quest(QUEST_ID).has("quest_id"):
		SideQuestManager.register_quest(QUEST_ID, {"quest_id": QUEST_ID, "title": QUEST_TITLE})
	var quest := SideQuestManager.get_quest(QUEST_ID)
	quest["title"] = QUEST_TITLE
	quest["description"] = "賣藥翁想調一帖安神不滯的藥，還缺三朵谷影草。"
	quest["objective"] = "在玉衡鎮廣場邊緣採集三朵谷影草。"
	quest["current_objective"] = quest["objective"]
	quest["stage"] = 1
	quest["is_finished"] = false
	quest["notes"] = ["去玉衡鎮廣場邊緣採集三朵谷影草。"]
	quest["note"] = "去玉衡鎮廣場邊緣採集三朵谷影草。"
	SideQuestManager.side_quests[QUEST_ID] = quest
	GlobalState.set_flag("met_apothecary_intro", true)

func _turn_in_valley_herb_quest() -> void:
	if not InventorySync or not InventorySync.has_item(ITEM_VALLEY_GRASS, 3):
		_unlock_on_next_reset = false
		await _play_sequence_and_wait([
			{ "text": "「還差些谷影草。要三朵，藥性才穩。」", "speaker": 1, "portrait": portrait_path },
		])
		return
	InventorySync.consume_item(ITEM_VALLEY_GRASS, 3, true)
	InventorySync.add_item_stack(ITEM_AWAKEN_TONIC, 1, true)
	_unlock_on_next_reset = false
	await _play_sequence_and_wait([
		{ "text": "「好，三朵齊了。這帖醒神湯你收著，遇暈眩正好能用。」", "speaker": 1, "portrait": portrait_path },
	])
	var quest := SideQuestManager.get_quest(QUEST_ID)
	quest["description"] = "已完成：谷影入藥"
	quest["objective"] = "賣藥翁以三朵谷影草調成醒神湯。"
	quest["current_objective"] = quest["objective"]
	quest["notes"] = ["賣藥翁以三朵谷影草調成醒神湯，日後可備不時之需。"]
	quest["note"] = "賣藥翁以三朵谷影草調成醒神湯，日後可備不時之需。"
	SideQuestManager.side_quests[QUEST_ID] = quest
	SideQuestManager.complete_quest(QUEST_ID)

# ---------------- 台詞組裝（沿用苦行僧模板的分段） ----------------
func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag("met_apothecary_intro")
	var event_market_choice_observe := GlobalState.get_flag("event_market_choice_observe")
	var event_yuheng_market_melody := GlobalState.get_flag("event_yuheng_market_melody")
	# ❶ 尚未遇過 → 完整雙向版（你要求的來回交流）
	if event_market_choice_observe and event_yuheng_market_melody:
		if not met:
			return [
				{ "text": "「(關於琴聲，也許他知道些甚麼...)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "「我是從外地來這裡行腳賣藥的，背上一籃，都是山裡風月熬出來的藥。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「不瞞你說，這鎮子氣味兒怪得很——風不動、心不動，大家像是被什麼\n罩住了，臉上都沒個起伏。」", "speaker": 1, "portrait": portrait_path },

				{ "text": "劉語塵:「(!!!)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵:「老丈也察覺了？我一路行來，只覺眾人情緒像火\n被捂著，不滅也不燃——悶得很。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },

				{ "text": "「(賣藥翁瞄了眼四周，食指輕抬至唇前) 嘘，聲音小點。你我都是\n外人，才看得清些，但說話得留點分寸。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「我瞧見的，是一種說不出口的病。不是傷風也不是寒熱，是……\n話卡在心裡，情悶在肚子裡。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「這地方啊，用的是猛藥。只要人一想說心裡話，琴聲就壓下來\n讓你說不出口，火也冒不起來。」", "speaker": 1, "portrait": portrait_path },

				{ "text": "劉語塵:「(低頭思索)果然如此……但老丈，這樣壓著真的好嗎？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵:「心火壓太久，會悶出病來吧？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },

				{ "text": "「說得對。藥要慢熬，氣要順著走。光靠壓，壓久了，一爆\n就收不回來。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「河流本該流海去，你硬是築堤堵它，哪天潰堤了，後果難料。」", "speaker": 1, "portrait": portrait_path },

				{ "text": "劉語塵:「看來，這份太平……其實很不自然。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵:「這琴，是為了壓邪？還是壓人？這道理，恐怕還藏著\n彎彎繞繞。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },

				{ "text": "「少俠是個明白人，能聽懂我這些話，我原想送你一帖『安神不滯散』，\n喝了能讓心頭順點，嘴巴也不那麼悶。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「可惜還缺一味藥——叫『谷影草』，得湊齊了，這帖藥才能發得了力。」", "speaker": 1, "portrait": portrait_path },

				{ "text": "劉語塵:「(如今局勢詭譎，身邊若有良方，總不是壞事。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵:「(若能替他覓來谷影草，也許能換些線索。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" }
			]
	# ❷ 已遇過 → 依主線進度給短句循環（和苦行僧模板一致）
	if main_stage <= 2:
		if event_market_choice_observe and event_yuheng_market_melody and met:
			return [
				{ "text": "「藥要慢熬，氣要順著走。光靠壓，壓久了，一爆就收不回來。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「河流本該流海去，你硬是築堤堵它，哪天潰堤了，後果難料。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "劉語塵:「……我會留心。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" }
			]
		else:
			return [
				{ "text": "「藥要慢熬，氣要順著走。光靠壓，壓久了，一爆就收不回來。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「河流本該流海去，你硬是築堤堵它，哪天潰堤了，後果難料。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "劉語塵:「這位賣藥翁似乎話中有話…」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" }
			]
	elif main_stage <= 6:
		return [
			{ "text": "「琴音按人心火，按得住，卻按不久。藥講調和，不講死壓。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「若有別法能護心而不悶心，那才是長久之計。」", "speaker": 1, "portrait": portrait_path },
		]
	else:
		# ≥7（你設定拿到〈白鳶橫天〉之後的口徑）
		return [
			{ "text": "「白鳶一過，像在谷口開了道風眼——能透氣，便不致鬱。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「願君持衡：弦不傷人，心不傷己。」", "speaker": 1, "portrait": portrait_path },
		]

# ---------------- 小工具（沿用模板） ----------------
func _play_directional_anim(dir: Vector2):
	if dir.length() < 0.1:
		return
	last_direction = dir
	var anim_name = _get_anim_by_vector(dir, "walk")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		animated_sprite.play("idle_down")

func _get_main_stage_safely() -> int:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s: Dictionary = qm.get_main_quest_state()
		return int(s.get("stage", 1))
	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s2: Dictionary = qm.get_main_quest_state()
		return int(s2.get("stage", 1))
	return 1

func _get_anim_by_vector(dir: Vector2, prefix: String) -> String:
	var angle = dir.angle()
	if angle >= -PI * 7/8 and angle < -PI * 5/8: return "%s_left_up" % prefix
	elif angle >= -PI * 5/8 and angle < -PI * 3/8: return "%s_up" % prefix
	elif angle >= -PI * 3/8 and angle < -PI * 1/8: return "%s_right_up" % prefix
	elif angle >= -PI * 1/8 and angle < PI * 1/8: return "%s_right" % prefix
	elif angle >= PI * 1/8 and angle < PI * 3/8: return "%s_right_down" % prefix
	elif angle >= PI * 3/8 and angle < PI * 5/8: return "%s_down" % prefix
	elif angle >= PI * 5/8 and angle < PI * 7/8: return "%s_left_down" % prefix
	else: return "%s_left" % prefix

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	last_direction = direction
	last_idle_direction = direction
	var anim_name = _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _play_sequence_and_wait(lines: Array) -> void:
	if dialog_manager == null:
		return
	dialog_manager.show_dialog_sequence(lines, self)
	await dialog_manager.dialog_sequence_finished

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
