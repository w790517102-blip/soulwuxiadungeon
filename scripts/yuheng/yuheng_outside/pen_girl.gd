# 客棧用路人 NPC 通用腳本模板
extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[拿筆與符的女孩] DialogManager 沒抓到！")
		
	dialog_lines = [
		
		{ "text": "「哈！看我的——『燕行破風斬』！！」", "speaker": 1, "portrait": portrait_path },
		{ "text": "（男童手中木劍揮來揮去，氣勢十足）", "speaker": 1, "portrait": portrait_path },
		{ "text": "「我要像左飲大人一樣，成為最帥氣的劍客！」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「聽說他以前一劍斬落山頂大石，連語魅都不敢靠近他！」", "speaker": 1, "portrait": portrait_path },
		{ "text": "（小女孩手中拿著塗鴉紙符和小毛筆，板著臉）", "speaker": 2, "portrait": portrait_path },
		{ "text": "「劍術太粗魯了啦，來看我的——定身符咒！」", "speaker": 2, "portrait": portrait_path },
		{ "text": "（她大聲唸了一句咒語，把紙符往男孩額頭一拍）", "speaker": 2, "portrait": portrait_path },
		{ "text": "「我的符咒不只語魅，連邪典都能封印呢！」", "speaker": 2, "portrait": portrait_path },
		{ "text": "「你現在被我的符咒定住了身!!動了的話就算犯規！」", "speaker": 2, "portrait": portrait_path },
		{ "text": "「欸欸欸！？哪有這樣的啦！你作弊——」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「這就是書眠姐姐筆武流的厲害喔～不只是寫詩畫畫，\n還能打敗壞人呢！」", "speaker": 2, "portrait": portrait_path },
		{ "text": "「哼，下次我也要學會劍氣破符！你等著瞧！」", "speaker": 1, "portrait": portrait_path },
		
	]

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

func _unhandled_input(event):
	if not can_interact:
		return
	if dialog_manager.dialog_active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_node("/root/GameRoot/LiuYu").can_move = false
		var player_pos = get_node("/root/GameRoot/LiuYu").global_position
		face_towards(player_pos)
		if dialog_lines.size() > 0:
			dialog_manager.show_dialog_sequence(dialog_lines, self)

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
