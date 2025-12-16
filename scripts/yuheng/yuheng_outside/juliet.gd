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
		push_warning("[廣場情侶女] DialogManager 沒抓到！")
		
	dialog_lines = [
		
		{ "text": "女子：「你看那舞台……你說要是能站在上面彈一曲，\n會是什麼樣的感覺呢？」", "speaker": 2, "portrait": portrait_path },
		{ "text": "男子：「如果妳站上去，我就站在最前面聽。\n其他人怎麼看我不管，我只聽妳彈。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "（靦腆一笑）：「你這樣說……那我可就真考慮了。」", "speaker": 2, "portrait": portrait_path },
		{ "text": "(男子看向正在「模擬比劍」的小男孩與舉符的女孩)", "speaker": 1, "portrait": portrait_path },
		{ "text": "「你看那兩個小娃兒，一個想當劍客、一個要當符仔仙……」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「是『符咒師』啦！現在女孩子也很厲害的好嗎～」", "speaker": 2, "portrait": portrait_path },
		{ "text": "「好好好～是我失言，符咒師最厲害～」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「……你說他們長大以後還會記得彼此嗎？」", "speaker": 2, "portrait": portrait_path },
		{ "text": "「若是有心，自然記得。」", "speaker": 1, "portrait": portrait_path },
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
