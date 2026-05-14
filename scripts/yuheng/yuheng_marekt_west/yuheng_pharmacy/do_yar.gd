# res://npc/apothecary_vendor.gd
extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var wander_range := 240
@export var wander_interval := 1.5
@export var wander_speed := 45.0
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
var _mark_flag_after_close := false # ✅ 首輪對話結束時才落旗並切換成循環台詞
var _interaction_flow_active := false
var _unlock_on_next_reset := false

const QUEST_ID := "yh_side_charcoal_01"
const QUEST_TITLE := "炭火裡的紙灰"
const ITEM_CLEAN_CHARCOAL := "item_clean_charcoal"
const ITEM_REWARD_ANTIDOTE := "item_antidote_herb"
const QUEST_DESC := "藥鋪的豆芽察覺近日煮藥用的炭火帶有紙灰味，懷疑沾染邪典灰燼，請劉語塵前往雜貨舖購買乾淨木炭。"
const QUEST_OBJECTIVE := "前往雜貨舖，替豆芽買回乾淨木炭。"

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

### 問題診斷小結：
# 因為在對話過程中「空白鍵」會再次觸發 _unhandled_input，
# 若剛好另一個 NPC 的 can_interact 為 true，會立刻觸發對方的對話邏輯，
# 但由於 DialogManager 正忙，對話無法重疊，所以被忽略，
# 然後該 NPC 的 is_talking 變成 true，但 reset_dialog_state 並未被呼叫，導致他鎖死。

### 解法提案：
# ✅ 在每個 NPC 的 _unhandled_input 前面多一個防呆條件：
#    若 DialogManager 正在執行其他對話（dialog_active == true），就不觸發。
# ✅ 或從 DialogManager 端在對話結束後「明確釋放所有 nearby 的 NPC 對話權」。

# 👇 建議更新每個 NPC 的 _unhandled_input 為：
func _unhandled_input(event):
	if not can_interact:
		return
	# ✅ 防止其他 NPC 對話尚未結束時誤觸
	if dialog_manager.dialog_active:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_talking:
			return
		is_talking = true

		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)

		_begin_interaction_flow()
		await _run_charcoal_interaction()
		if _interaction_flow_active:
			_end_interaction_flow()

# ✅ 並確保 reset_dialog_state 一定會把 is_talking 設為 false
func reset_dialog_state():
	is_talking = false
	has_recently_talked = false

	var liuyu := get_node("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = true

	if _mark_flag_after_close:
		GlobalState.set_flag("met_Do_yar", true)
		_mark_flag_after_close = false
		dialog_lines = _build_lines_for_stage(_get_main_stage_safely())


	# ✅ 首輪剛結束 → 落旗＆重建循環台詞（無須出場再進場）
	if _mark_flag_after_close:
		GlobalState.set_flag("met_Do_yar", true)
		_mark_flag_after_close = false
		var main_stage := _get_main_stage_safely()
		dialog_lines = _build_lines_for_stage(main_stage)

# ---------------- 台詞組裝（沿用苦行僧模板的分段） ----------------
func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag("met_Do_yar")
	var event_market_choice_observe := GlobalState.get_flag("event_market_choice_observe")
	var event_yuheng_market_melody := GlobalState.get_flag("event_yuheng_market_melody")
	# ❶ 尚未遇過 → 完整雙向版（你要求的來回交流）
	if not met:
		return [
				{ "text": "（小女孩歪著頭打量你）「欸？你是外地來的吧？看起來不像這裡的人呢～」", "speaker": 1, "portrait": portrait_path },
				{ "text": "劉語塵：「唔……算是吧。你怎麼看出來的？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "小女孩：「因為你的眼神充滿熱忱，一種在尋找某種『秘寶』的熱忱。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "劉語塵：「（一愣）……你倒是觀察得仔細。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "豆芽：「哼哼～我可是藥鋪的豆芽，將來要當會看氣色的大夫的！」", "speaker": 1, "portrait": portrait_path },
				{ "text": "豆芽：「只是最近都沒人來抓藥……師父說，是因為大家的『心病』都被壓著，\n連咳嗽都不好意思咳了。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "劉語塵：「(她指的是琴音壓心的事吧…連『擔憂』身體狀況的\n心情都被壓制啊…)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「這件事情很多大人也都不多談，你不怕講話那麼直，\n說錯話惹你師父生氣？。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "豆芽：「我怕呀……可我更怕大家都不敢講話，那樣比病還可怕對吧？」", "speaker": 1, "portrait": portrait_path },
				{ "text": "劉語塵：「(微微點頭，不多做表情)…嗯。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			]
	# ❷ 已遇過 → 依主線進度給短句循環（和苦行僧模板一致）
	if main_stage <= 2:
			return [
				{ "text": "豆芽：「大哥哥，無論面臨甚麼狀況，都要勇敢說出心裡話喔", "speaker": 1, "portrait": portrait_path },
				{ "text": "劉語塵：「你放心，我就是為了這個來到玉衡鎮的。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" }
			]
	elif main_stage <= 6:
		return [
			{ "text": "大哥哥，最近看你好像跑來跑去,很忙的樣子。", "speaker": 1, "portrait": portrait_path },
			{ "text": "我相信你是為了讓大家可自由說話才這麼努力的", "speaker": 1, "portrait": portrait_path },
			{ "text": "加油喔~", "speaker": 1, "portrait": portrait_path },
		]
	else:
		# ≥7（你設定拿到〈白鳶橫天〉之後的口徑）
		return [
			{ "text": "最近鎮上的琴聲的曲調聽起來沒有像以前那麼悶了。", "speaker": 1, "portrait": portrait_path },
			{ "text": "大家身體有哪邊不舒服，也更願意說出來了。", "speaker": 1, "portrait": portrait_path },
			{ "text": "大哥哥，我知道這都是因為你在默默的努力著，對吧?", "speaker": 1, "portrait": portrait_path },
		]

# ---------------- 小工具（沿用模板） ----------------
func _play_directional_anim(dir: Vector2):
	if dir.length() < 0.1:
		return
	last_direction = dir
	var anim_name = _get_anim_by_vector(dir, "walk")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


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


func _begin_interaction_flow() -> void:
	_interaction_flow_active = true
	_unlock_on_next_reset = false
	is_talking = true
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = false

func _end_interaction_flow() -> void:
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = true
	is_talking = false
	_interaction_flow_active = false
	_unlock_on_next_reset = false

func _run_charcoal_interaction() -> void:
	var quest := SideQuestManager.get_quest(QUEST_ID)
	if not quest.has("quest_id"):
		if GlobalState.get_flag("met_Do_yar"):
			await _start_charcoal_quest()
			return
		var main_stage := _get_main_stage_safely()
		dialog_lines = _build_lines_for_stage(main_stage)
		dialog_manager.show_dialog_sequence(dialog_lines, self)
		await dialog_manager.dialog_sequence_finished
		GlobalState.set_flag("met_Do_yar", true)
		return
	if bool(quest.get("is_finished", false)):
		await _play_lines([{"text":"豆芽：「那天你帶回來的木炭很乾淨，爺爺說火氣也穩。藥要入口，髒不得。人心也是一樣，髒東西進去了，就很難熬出清味了。」","speaker":1,"portrait":portrait_path}])
		return
	if InventorySync and InventorySync.has_item(ITEM_CLEAN_CHARCOAL, 1):
		await _play_lines([
			{"text":"豆芽：「大哥哥，你回來啦！讓我聞聞看……」","speaker":1,"portrait":portrait_path},
			{"text":"豆芽接過木炭，小心湊近聞了聞。","speaker":1,"portrait":portrait_path},
			{"text":"豆芽：「嗯！這塊可以，沒有那股嗆嗆的紙灰味。」","speaker":1,"portrait":portrait_path},
			{"text":"豆芽：「這是我剛剛整理藥材時分出來的，對蛇毒、瘴氣都有點用喔。」","speaker":1,"portrait":portrait_path},
		])
		# 將結算訊息延後到回報對話完全結束後再觸發，避免先於文本暴雷。
		InventorySync.consume_item(ITEM_CLEAN_CHARCOAL, 1, true)
		InventorySync.add_item_stack(ITEM_REWARD_ANTIDOTE, 1, true)
		var q := SideQuestManager.get_quest(QUEST_ID)
		q["description"] = "已完成：%s" % QUEST_TITLE
		q["objective"] = "已交付乾淨木炭，獲得解毒草。"
		q["current_objective"] = q["objective"]
		SideQuestManager.side_quests[QUEST_ID] = q
		SideQuestManager.complete_quest(QUEST_ID)
		GlobalState.set_flag("yh_side_charcoal_completed", true)
		return
	await _play_lines([
		{"text":"豆芽：「大哥哥，記得是乾淨木炭喔。如果聞起來有紙灰味，就不能拿來煮藥。」","speaker":1,"portrait":portrait_path}
	])

func _start_charcoal_quest() -> void:
	await _play_lines([
		{"text":"豆芽：「大哥哥，我有件事想拜託你……我們藥鋪最近用來煮藥的炭火，聞起來有一點紙灰味。」","speaker":1,"portrait":portrait_path},
		{"text":"劉語塵：「紙灰味？炭火本來不就有灰味嗎？」","speaker":2,"portrait":"res://assets/sprites/Liu_Yu/LiuYu_headshot.png"},
		{"text":"豆芽：「不是那種灰啦。鎮上處理邪典，都是先燒掉，再把灰埋起來。」","speaker":1,"portrait":portrait_path},
		{"text":"劉語塵：「好，我替你走一趟。」","speaker":2,"portrait":"res://assets/sprites/Liu_Yu/LiuYu_headshot.png"},
	])
	if not SideQuestManager.get_quest(QUEST_ID).has("quest_id"):
		SideQuestManager.register_quest(QUEST_ID, {"quest_id": QUEST_ID, "title": QUEST_TITLE})
	var quest := SideQuestManager.get_quest(QUEST_ID)
	quest["title"] = QUEST_TITLE
	quest["description"] = QUEST_DESC
	quest["objective"] = QUEST_OBJECTIVE
	quest["current_objective"] = QUEST_OBJECTIVE
	quest["stage"] = 1
	quest["is_finished"] = false
	SideQuestManager.side_quests[QUEST_ID] = quest
	GlobalState.set_flag("yh_side_charcoal_started", true)

func _play_lines(lines: Array) -> void:
	dialog_manager.show_dialog_sequence(lines, self)
	await dialog_manager.dialog_sequence_finished
