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
		push_warning("[客棧路人] DialogManager 沒抓到！")
		
	dialog_lines = [
		{ "text": "墨箴公:「這符，名喚‘斂氣’，專封心頭雜念，讓兵器不染妄氣……\n你有緣才看得到我刻這一枚。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "墨箴公:「有時兵器的氣，勝過人的氣——若你連自己情緒都鎮不住，\n別妄想握得住那種劍。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "墨箴公:「你問我怎麼能夠在這裡擺攤賣符令?」", "speaker": 1, "portrait": portrait_path },
		{ "text": "墨箴公:「我是這店鋪當家兄弟的舅舅」", "speaker": 1, "portrait": portrait_path },
		{ "text": "墨箴公:「我那外甥嘴硬心軟，我能坐在這角落，是他們說還欠我\n一頓酒，所以租我店面。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "墨箴公:「其實是他們看我年過耳順卻漂泊天涯只靠賣符維生，便想說\n要讓一個符令攤給我租」", "speaker": 1, "portrait": portrait_path },
		{ "text": "墨箴公:「怕我這老頭給後輩照顧很丟面子，所以給個體面的說辭罷了。」", "speaker": 1, "portrait": portrait_path },

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
