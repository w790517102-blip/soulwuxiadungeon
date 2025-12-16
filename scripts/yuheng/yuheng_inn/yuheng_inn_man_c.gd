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
		{ "text": "「我說啊，這客棧老闆——以前可不是簡單人。」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_3.png" },
		{ "text": "「傳言他以前也是混江湖的，特別跟飲月山莊的左飲十分要好\n 他們年輕時可是常一起喝酒的夥伴。」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_3.png" },
		{ "text": "「只是…如果向他打聽有關左飲的消息，他常常一副欲言又止的樣子…」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_3.png" },
		{ "text": "「所以你最好要推敲一下，他的話語中背後到底透露出甚麼資訊來著」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_3.png" }
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_node("/root/GameRoot/LiuYu").can_move = false
		var player_pos = get_node("/root/GameRoot/LiuYu").global_position
		face_towards(player_pos)
		if dialog_lines.size() > 0:
			dialog_manager.show_dialog_sequence(dialog_lines, self)

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
