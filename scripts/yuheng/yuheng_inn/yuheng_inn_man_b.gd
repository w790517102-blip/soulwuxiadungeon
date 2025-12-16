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
		{ "text": "「這玉衡鎮啊……真是個妙地方。」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_2.png" },
		{ "text": "「西邊是藥谷，南邊通山路，鎮裡還保有老式的鑄劍鋪和書墨坊。」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_2.png" },
		{ "text": "「經過北方的市集時，看見有老匠在賣手刻的符令，每張圖騰都不太一樣。」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_2.png" },
		{ "text": "「說到書墨坊，這裡的四大名產:茶、酒、琴、書每個都十分有特色。」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_2.png" },
		{ "text": "「路過市集的時候，還能聽見悠悠的琴音和淡淡的茶香。」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_2.png" },
		{ "text": "「這地方不大，卻藏著一種很乾淨的味道…」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_2.png" },
		{ "text": "「當外頭早已被語魅和邪典惹得烏煙瘴氣時」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_2.png" },
		{ "text": "「玉衡鎮這裡卻絲毫不受影響，讓人能夠放寬心生活」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_2.png" },
		{ "text": "「只不過，本地人情緒平得很，尤其是市集那裡，反而不像廣場那麼熱鬧…」", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/outsider_2.png" }
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
