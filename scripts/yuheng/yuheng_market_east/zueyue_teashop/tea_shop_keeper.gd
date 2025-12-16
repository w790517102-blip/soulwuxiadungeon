# res://npc/tea_house_boss.gd
extends CharacterBody2D

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
	var met := GlobalState.get_flag("met_yuheng_teahouse_boss")
	var observed := GlobalState.get_flag("event_market_choice_observe")
	var heard_qin := GlobalState.get_flag("event_yuheng_market_melody")

	# ❶ 首見｜有觀察琴音者進入「裏」語氣
	if not met:
		if observed and heard_qin:
			return [
				{ "text": "「客官裡頭請，小店雅座仍有空位。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "「近日店內流行淡茶，配這琴的調剛剛好。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "（茶香混著絃音在空氣裡緩緩擴散）", "speaker": 1 },
				{ "text": "劉語塵：「老闆，這茶坊內的悠悠琴聲有如天籟、餘音繞樑，\n是誰有這般雅致呢?」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "「啊~你也是被這琴音吸引過來的啊，這琴聲乃出自於店內駐彈的\n那位紅衣女伶之手。」", "speaker": speaker_id },
				{ "text": "(老闆手指了指右方一位穿紅衣的彈琴女伶，琴聲未停)", "speaker": speaker_id },
				{ "text": "劉語塵：「好琴!」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「但這琴音…雖說讓內心平靜，但聽著聽著…總覺得讓有些\n本來想說出口的話…欲言卻又止。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「像是被琴音掐住了喉，說不出口」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「敢問這位紅衣女伶的來歷??」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "「女伶之事…（語音出口的一瞬，被絃音壓住）…掌櫃的我，\n也只知她是左飲爺引進來的。至於緣由，從未細問。」", "speaker": speaker_id },
				{ "text": "「至於你說的琴音壓情，自有其妙，大家都有感覺到。不過內心平靜\n未嘗壞事，再加上女伶是左飲引薦的，大家也不深究了。」", "speaker": speaker_id },
				{ "text": "「只是壓久了，心頭像壓著絨被，雖說暖是暖的，但也悶。」", "speaker": speaker_id },
				{ "text": "「這世道，有時知太多，不如只知七分。」", "speaker": speaker_id },
				{ "text": "「客官若有困惑，不妨往市集西街走走。那裡……風聲比琴聲大些。」", "speaker": speaker_id }
			]
		else:
			return [
				{ "text": "「官裡頭請，小店雅座仍有空位。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "「本坊請了一位女伶駐彈，是左飲爺親自提的。客人們都說，琴音沉靜養心。」", "speaker": speaker_id },
				{ "text": "「琴音聽著心就靜，靜心飲茶見真味。」", "speaker": speaker_id }
			]

	# ❷ 已對話｜循環（簡化）版本
	if main_stage <= 2:
		if observed and heard_qin:
			return [
				{ "text": "「這世道，有時知太多，不如只知七分。」", "speaker": speaker_id },
				{ "text": "「客官若有困惑，不妨往市集西街走走。那裡……風聲比琴聲大些。」", "speaker": speaker_id }
			]
		else:
			return [
				{ "text": "「來杯茶罷，客官。淡茶最適這兩日天氣。」", "speaker": speaker_id, "portrait": portrait_path }
			]

	# ❸ 主線後段（取得白鳶橫天琴譜）
	elif main_stage <= 6:
		return [
			{ "text": "「近日女伶彈奏的曲調似乎有些不同。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「聽得比先前更加通暢、如沐春風。」", "speaker": 1, "portrait": portrait_path },
		]
	else:
		return [
			{ "text": "「女伶近日奏了別的曲，客人也不像從前那樣好同一品淡茶。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「現在所有人都願意嘗試不同茶品了!」", "speaker": 1, "portrait": portrait_path },
		]

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
		dialog_lines = _build_lines_for_stage(main_stage)

		dialog_manager.show_dialog_sequence(dialog_lines, self)
		# ✅ 在 reset_dialog_state 裡落旗與重建台詞
		_mark_flag_after_close = not GlobalState.set_flag("met_yuheng_teahouse_boss", true)

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	is_talking = false
	if _mark_flag_after_close:
		GlobalState.set_flag("met_yuheng_teahouse_boss", true)
		_mark_flag_after_close = false
		# 旗標落地後，重建成「精簡循環版」
		dialog_lines = _build_lines_for_stage(_get_main_stage_safely())
		animated_sprite.play("idle")
			

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
