
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
var _mark_flag_after_close := false  # 對話結束時才落旗

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

func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag("met_yuheng_blacksmith")
	# ❶ 主線前期：首輪完整版 / 其後走精簡循環

	if not met:
		return [
				
		{ "text": "(鐵匠抬頭打量了你一番，隨即繼續低頭幹活，並開口說道)", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "「別光看刀刃，握柄才是人心。你這手形，功夫不差啊。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "劉語塵:「過獎。為了行走江湖，練了幾招花拳繡腿防身，\n不足掛齒。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵:「對了，左飲的兵器也是在這兒鑄的嗎？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「左飲啊，他那把……可不是凡鐵能鑄的。我見過一眼，不像是人\n手打出來的。」", "speaker": speaker_id },
		{ "text": "劉語塵:「非鑄之劍？此話怎講？」", "speaker": 2 },
		{ "text": "「有回他醉倒在我這門口，盤纏撒了一地。我好心扶他進屋歇息，\n順手幫他收東西。」", "speaker": speaker_id },
		{ "text": "「那時我才發現——他那劍，竟只裹了塊舊布。」", "speaker": speaker_id },
		{ "text": "「我看不下去，想說給他打個鞘，結果……丈量劍身時，嚇了一跳。」", "speaker": speaker_id },
		{ "text": "「那刃上，有星辰逆紋，順看如劍、逆看似圖……活像某種古陣印記。」", "speaker": speaker_id },
		{ "text": "「更怪的是，我這鐵爐連鎮石都能熔，他那劍一靠近，爐溫硬生生\n掉了三成……詭得很。」", "speaker": speaker_id },
		{ "text": "「後來他醒了，只朝我抱拳致謝，轉身就走。我問他那劍哪來的……」", "speaker": speaker_id },
		{ "text": "「他只是笑笑，沒說話。然後往白箋居的方向看了一眼，就走回山莊去了。」", "speaker": speaker_id },
		{ "text": "「說起來——少俠若要挑把趁手兵器，左邊就是咱鋪子，自己進去看看\n不必客氣。」", "speaker": speaker_id }
			]
	else:
		return [
				{ "text": "「少俠若要挑把趁手兵器，左邊就是咱鋪子，自己進去看看不必客氣。」", "speaker": 1, "portrait": portrait_path },
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
		is_talking = true

		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)

		# ✅ 這行是關鍵：在互動瞬間依目前旗標/主線重新組台詞
		var main_stage := _get_main_stage_safely()
		dialog_lines = _build_lines_for_stage(main_stage)

		dialog_manager.show_dialog_sequence(dialog_lines, self)
		_mark_flag_after_close = not GlobalState.get_flag("met_yuheng_blacksmith")
func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	is_talking = false
	if _mark_flag_after_close:
		GlobalState.set_flag("met_yuheng_blacksmith", true)
		_mark_flag_after_close = false
		# 旗標落地後，重建成「精簡循環版」
		dialog_lines = _build_lines_for_stage(_get_main_stage_safely())

	if not GlobalState.get_flag("heard_yuheng_blacksmith_info"):
		GlobalState.set_flag("heard_yuheng_blacksmith_info", true)

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
