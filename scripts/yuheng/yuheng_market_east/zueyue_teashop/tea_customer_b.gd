# ==============================
# 客人丙｜妙齡女客
# res://npc/tea_house_guest_lady.gd
# ==============================
extends CharacterBody2D

const F_GO_TO_ZUIYUE_HUIYIN := "main_yh_go_to_zuiyue_huiyin"
const F_HUIYIN_FIRST_TALK_DONE := "event_huiyin_first_talk_done"
const F_CUSTOMER_B_WAITING_LINE_HEARD := "event_zuiyue_customer_b_waiting_line_heard"
const NIGHT_TEASHOP_SCENE_PATH := "res://scenes/yuheng/zueyue_teashop/zueyue_teashop_night.tscn"
const MAIN_QUEST_ID := "main_001"

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/Teahouse_Boss_headshot.png"
@export var speaker_id := 1
@export var wander_range := 160
@export var wander_interval := 2.0
@export var wander_speed := 30.0
@export var use_path_patrol := false
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
var path_ref: PathFollow2D = null
var previous_position: Vector2 = Vector2.ZERO
var _mark_flag_after_close := false
var _mark_waiting_line_heard_after_close := false

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[TeaBoss] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[TeaBoss] PathFollow2D 沒有設定或找不到：" + str(path_node))
	previous_position = global_position

	dialog_lines = _build_lines_for_stage(_get_main_stage_safely())

func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag("met_yuheng_teahouse_lady")
	var observed := GlobalState.get_flag("event_market_choice_observe")
	var heard_qin := GlobalState.get_flag("event_yuheng_market_melody")

	if _is_huiyin_night_story_window():
		if not GlobalState.get_flag(F_HUIYIN_FIRST_TALK_DONE):
			return [
				{
					"text": "女茶客：「你也聽出來了？曲子明明不急，我卻總覺得有一句話，非得在今晚說出口不可。」",
					"speaker": speaker_id,
					"portrait": portrait_path,
				},
			]
		if GlobalState.get_flag(F_CUSTOMER_B_WAITING_LINE_HEARD):
			return [
				{
					"text": "女茶客：「先前那句非得說出口的話，似乎已經傳到了。如今聽來，倒像終於有人願意替她把那份盼望帶走。」",
					"speaker": speaker_id,
					"portrait": portrait_path,
				},
			]
		return [
			{
				"text": "女茶客：「這曲子聽來不像尋常演奏，倒像有人剛把心裡的話送了出去，也把剩下的盼望交給了願意承接的人。」",
				"speaker": speaker_id,
				"portrait": portrait_path,
			},
		]

	if not met:
		if observed and heard_qin:
			return [
				{ "text": "一名女茶客輕放茶盞。", "speaker": 0 },
				{ "text": "女茶客：「這茶溫恰好，琴也彈得好。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "她的聲音不大，卻像是讓茶館更靜了幾分。", "speaker": 0 },
				{ "text": "劉語塵：「冒昧叨擾您一問，希望沒有驚動到您用茶。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "女茶客：「無妨，少俠看上去為人正派，有甚麼事想問小女子的呢？」", "speaker": speaker_id },
				{ "text": "劉語塵：「那位彈琴女伶似乎已在此店駐彈已久，您可曾與她交談過？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "女茶客：「我喜靜，本就不喜主動與人對談，所以這坊子合我心。不過……我也並非無話可說。」", "speaker": speaker_id },
				{ "text": "女茶客：「那彈琴的姑娘眉目不俗。只是這琴一響，我心裡要說的話像被輕輕縫起，針腳細密，找不到翻口。」", "speaker": speaker_id },
				{ "text": "女伶的指腹在琴絃上使出一記滑音，女客乍然靜聲，猶如聲音被推回喉間。", "speaker": 0 },
				{ "text": "女茶客：「咳咳…抱歉少俠…嗓子不知怎地突然有點乾…」", "speaker": speaker_id },
				{ "text": "她抿了一口茶。", "speaker": 0 },
				{ "text": "女茶客：「總之，人不爭是好，但倘若不敢愛、不敢氣，未必是好。」", "speaker": speaker_id }
			]
		else:
			return [
				{ "text": "一名女茶客輕放茶盞。", "speaker": 0 },
				{ "text": "女茶客：「這茶溫恰好，琴也彈得好。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "她指尖碰杯，像怕驚動誰。", "speaker": 0 },
				{ "text": "女茶客：「我喜靜，這坊子合我心。」", "speaker": speaker_id }
			]

	if main_stage <= 2:
		if observed and heard_qin:
			return [
				{ "text": "女茶客：「人不爭是好，但倘若不敢愛、不敢氣，未必是好。」", "speaker": speaker_id }
			]
		else:
			return [ { "text": "女茶客：「茶好。安靜便好。」", "speaker": speaker_id, "portrait": portrait_path } ]

	return [ { "text": "女茶客：「改日再談。」", "speaker": speaker_id, "portrait": portrait_path } ]


func _is_huiyin_night_story_window() -> bool:
	var scene_root := get_parent()
	if scene_root == null or scene_root.scene_file_path != NIGHT_TEASHOP_SCENE_PATH:
		return false
	var main_state := _get_main_quest_state_safely()
	return (
		String(main_state.get("id", "")) == MAIN_QUEST_ID
		and GlobalState.get_flag(F_GO_TO_ZUIYUE_HUIYIN)
	)


func _process(delta):
	z_index = int(global_position.y + z_index_offset)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false

func _unhandled_input(event):
	if not can_interact:
		animated_sprite.play("idle")
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
		_mark_waiting_line_heard_after_close = (
			_is_huiyin_night_story_window()
			and not GlobalState.get_flag(F_HUIYIN_FIRST_TALK_DONE)
			and not GlobalState.get_flag(F_CUSTOMER_B_WAITING_LINE_HEARD)
		)
		dialog_lines = _build_lines_for_stage(main_stage)

		dialog_manager.show_dialog_sequence(dialog_lines, self)
		# ✅ 在 reset_dialog_state 裡落旗與重建台詞
		_mark_flag_after_close = not GlobalState.set_flag("met_yuheng_teahouse_lady", true)

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	is_talking = false
	if _mark_waiting_line_heard_after_close:
		_mark_waiting_line_heard_after_close = false
		_commit_waiting_line_heard.call_deferred()
	if _mark_flag_after_close:
		GlobalState.set_flag("met_yuheng_teahouse_lady", true)
		_mark_flag_after_close = false
		# 旗標落地後，重建成「精簡循環版」
		dialog_lines = _build_lines_for_stage(_get_main_stage_safely())
		animated_sprite.play("idle")
			

func _commit_waiting_line_heard() -> void:
	GlobalState.set_flag(F_CUSTOMER_B_WAITING_LINE_HEARD, true)


func _get_main_stage_safely() -> int:
	var state := _get_main_quest_state_safely()
	return int(state.get("stage", 1))


func _get_main_quest_state_safely() -> Dictionary:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		return qm.get_main_quest_state()
	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		return qm.get_main_quest_state()
	return {}

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	last_direction = direction
	last_idle_direction = direction
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
