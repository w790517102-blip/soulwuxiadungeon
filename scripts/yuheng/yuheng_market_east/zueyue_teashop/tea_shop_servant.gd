# res://npc/tea_house_servant.gd
extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/Teahouse_Servant_headshot.png"
@export var speaker_id := 1
@export var wander_range := 180
@export var wander_interval := 1.2
@export var wander_speed := 45.0
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
		push_warning("[TeaServant] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[TeaServant] PathFollow2D 沒有設定或找不到：" + str(path_node))
	previous_position = global_position

	dialog_lines = _build_lines_for_stage(_get_main_stage_safely())

func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag("met_yuheng_teahouse_servant")
	var observed := GlobalState.get_flag("event_market_choice_observe")
	var heard_qin := GlobalState.get_flag("event_yuheng_market_melody")

	# 首見：表／裏語氣分支
	if not met:
		if observed and heard_qin:
			return [
				{ "text": "「客倌裡請!…（他剛開口正準備大聲吆喝，忽地止住）」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "「…咳，客倌失禮了，我嗓子這幾日總是卡著似的。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "「熱茶馬上來，您先坐。今日上的是『醉月青魁』，回甘不苦澀，提神不擾眠。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "「那邊彈琴的姑娘？是新請來的，聽說是左飲爺引薦的高人。」", "speaker": speaker_id },
				{ "text": "（忽然間，整間茶坊寂靜了下來，只餘琴聲緩緩）", "speaker」": speaker_id },
				{ "text": "「您聽，那琴一響，滿坊都靜了三分。", "speaker": speaker_id },
				{ "text": "「咱這坊裡近來靜得很，如果有誰話講重了，都像是被那琴音轉了調，\n給轉平了。」", "speaker": speaker_id },
				{ "text": "「就像我方才本想大聲招待您，突然滿腦都是這動人的琴聲，」", "speaker": speaker_id },
				{ "text": "「也不知道是不是分了神，竟給口水嗆著了。」", "speaker": speaker_id },
				{ "text": "「小的只求月底結帳時能講清楚話，別被當啞巴扣了工錢。」", "speaker": speaker_id }
			]
		else:
			return [
				{ "text": "「熱茶馬上來，您先坐。今日上的是『醉月青魁』，回甘不苦澀，提神不擾眠。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "「那邊彈琴的姑娘？是新請來的，聽說是左飲爺引薦的高人。」", "speaker": speaker_id },
				{ "text": "「您聽，那琴一響，滿坊都靜了三分。」", "speaker": speaker_id }
			]

	# 循環精簡語（主線未完）
	if main_stage <= 2:
		if observed and heard_qin:
			return [
				{ "text": "「現在我整日跑堂，卻一句話都不能講大聲……」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "「嗓子緊得很，連睡覺作夢都怕吵到誰似的。」", "speaker": speaker_id }
			]
		else:
			return [
				{ "text": "「客官來得正巧，茶湯正暖，琴聲正亮。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "「要不要來壺回甘不擾夢的『醉月青魁』?」", "speaker": speaker_id, "portrait": portrait_path }
			]

	# ❸ 主線後段（取得白鳶橫天琴譜）
	elif main_stage <= 6:
		return [
			{ "text": "「(聲音宏亮)客倌!裡面坐喲~想喝甚麼儘管說嘿!」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「女伶換了首曲，聽著聽著嗓子也不啞了呢!」", "speaker": 1, "portrait": portrait_path },
		]
	else:
		return [
			{ "text": "「客倌!想喝甚麼儘管說，店內茶品五花八門,不怕你叫!」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「前陣子流行『醉月青魁』,現在無論甚麼濃淡溫涼大家甚麼茶都喝!」", "speaker": 1, "portrait": portrait_path },
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
		# ✅ 在 reset_dialog_state 裡落旗與重建台詞
		_mark_flag_after_close = not GlobalState.set_flag("met_yuheng_teahouse_servant", true)

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	is_talking = false
	if _mark_flag_after_close:
		GlobalState.set_flag("met_yuheng_teahouse_servant", true)
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
