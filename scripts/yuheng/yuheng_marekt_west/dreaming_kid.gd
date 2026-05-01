
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

const QUEST_ID := "yh_side_dabao_01"
const QUEST_TITLE := "大寶的不能說"
const QUEST_STAGE_1_DESC := "找來一條細繩，交給大寶。"
const QUEST_STAGE_2_DESC := "前往井旁，調查大寶所指的石塊。"
const ITEM_FINE_THREAD := "misc_hemp_twine"
const FLAG_COIN_HINT := "yh_side_dabao_01_coin_hint"
const FLAG_COIN_TAKEN := "yh_side_dabao_01_coin_taken"

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

func _build_lines_for_stage(_main_stage: int) -> Array:
	return [
		{ "text": "「哥哥，等你到井邊的時候，記得看看石頭底下。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「有些話說不出口，只能讓繩子和石頭幫我說。」", "speaker": 1, "portrait": portrait_path },
	]

func _process(delta):
	z_index = int(global_position.y + z_index_offset)

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
		if is_talking:
			return
		_begin_interaction_flow()
		var liuyu := get_node("/root/GameRoot/LiuYu")
		face_towards(liuyu.global_position)
		_run_dabao_interaction()
func reset_dialog_state():
	if _interaction_flow_active and not _unlock_on_next_reset:
		is_talking = true
		return
	_end_interaction_flow()

func _run_dabao_interaction() -> void:
	await _handle_dabao_interact()
	if _interaction_flow_active:
		_end_interaction_flow()

func _handle_dabao_interact() -> void:
	var quest := SideQuestManager.get_quest(QUEST_ID)
	if not quest.has("quest_id"):
		await _start_dabao_quest_intro()
		return
	if bool(quest.get("is_finished", false)):
		_unlock_on_next_reset = false
		await _play_sequence_and_wait(_build_lines_for_stage(_get_main_stage_safely()))
		return
	var stage := int(quest.get("stage", 0))
	if stage <= 1:
		await _handle_need_thread()
		return
	_unlock_on_next_reset = false
	await _play_sequence_and_wait([
		{ "text": "「哥哥，井邊石頭那裡……你到了就會懂。」", "speaker": 1, "portrait": portrait_path },
	])

func _start_dabao_quest_intro() -> void:
	_unlock_on_next_reset = false
	var lines: Array = [
		{ "text": "劉語塵心想：「這孩子……似乎和其他孩子不同。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵心想：「一個人站在市集邊上若有所思，未免安靜過了頭。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "大寶：「大哥哥，你是不是在擔心我？」", "speaker": 1, "portrait": portrait_path },
		{ "text": "大寶：「我叫大寶。我沒事，只是最近朋友們都說不出話。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "大寶：「井裡的鯉魚先生最著急……可是我一說井在哪，嘴巴就像被琴聲打結。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "劉語塵：「那你用別的方式告訴我。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "大寶：「我可以用繩子！你幫我找一條細繩，我就能把夢裡的路排給你看。」", "speaker": 1, "portrait": portrait_path },
	]
	if GlobalState.get_flag("event_market_choice_observe"):
		lines.insert(2, { "text": "劉語塵心想：「連孩子的不安都像被琴聲壓住了……」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" })
	await _play_sequence_and_wait(lines)
	_register_dabao_quest()

func _handle_need_thread() -> void:
	if InventorySync and InventorySync.has_item(ITEM_FINE_THREAD, 1):
		if InventorySync:
			InventorySync.consume_item(ITEM_FINE_THREAD, 1, true)
		_unlock_on_next_reset = false
		await _play_sequence_and_wait([
			{ "text": "大寶接過細繩，蹲在地上繞出彎曲的路。", "speaker": 1, "portrait": portrait_path },
			{ "text": "大寶：「這裡是市集……這裡是水聲……這裡是井。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "大寶：「井旁邊有塊石頭，下面壓著亮亮的東西。那會幫上你的忙。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "大寶把細繩還給你。", "speaker": 1, "portrait": portrait_path },
		])
		if InventorySync:
			InventorySync.add_item_stack(ITEM_FINE_THREAD, 1)
		_update_dabao_quest_to_hint_stage()
		return
	_unlock_on_next_reset = false
	await _play_sequence_and_wait([
		{ "text": "大寶：「哥哥，還差一條細繩。沒有繩子，我就排不出夢裡的路。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「雜貨舖常有賣，帶一條來就好。」", "speaker": 1, "portrait": portrait_path },
	])

func _register_dabao_quest() -> void:
	if not SideQuestManager.get_quest(QUEST_ID).has("quest_id"):
		SideQuestManager.register_quest(QUEST_ID, {"quest_id": QUEST_ID, "title": QUEST_TITLE})
	var quest := SideQuestManager.get_quest(QUEST_ID)
	quest["title"] = QUEST_TITLE
	quest["description"] = QUEST_STAGE_1_DESC
	quest["objective"] = QUEST_STAGE_1_DESC
	quest["current_objective"] = QUEST_STAGE_1_DESC
	quest["stage"] = 1
	quest["is_finished"] = false
	quest["notes"] = ["大寶說不出口井的位置，請你帶一條細繩給他排出方向。"]
	quest["note"] = "大寶說不出口井的位置，請你帶一條細繩給他排出方向。"
	SideQuestManager.side_quests[QUEST_ID] = quest

func _update_dabao_quest_to_hint_stage() -> void:
	if GlobalState and GlobalState.has_method("set_flag"):
		GlobalState.set_flag(FLAG_COIN_HINT, true)
	var quest := SideQuestManager.get_quest(QUEST_ID)
	quest["title"] = QUEST_TITLE
	quest["description"] = QUEST_STAGE_2_DESC
	quest["objective"] = QUEST_STAGE_2_DESC
	quest["current_objective"] = QUEST_STAGE_2_DESC
	quest["stage"] = 2
	quest["notes"] = ["大寶用繩索指向井旁石塊，去那裡調查看看。"]
	quest["note"] = "大寶用繩索指向井旁石塊，去那裡調查看看。"
	SideQuestManager.side_quests[QUEST_ID] = quest

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
