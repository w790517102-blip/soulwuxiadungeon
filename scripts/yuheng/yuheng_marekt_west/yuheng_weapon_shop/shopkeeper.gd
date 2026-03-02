# 武器店老闆腳本
extends CharacterBody2D

const ShopUI = preload("res://scripts/ui/ShopUI.gd")

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var shop_id: String = "yuheng_weapon_shop"
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var has_recently_talked := false
var is_talking := false
var _after_dialog_action := ""

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC] DialogManager 沒抓到！")

func _process(_delta):
	z_index = int(global_position.y + z_index_offset)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false
		has_recently_talked = false

func _unhandled_input(event):
	if not can_interact or is_talking:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		is_talking = true
		var player = get_node("/root/GameRoot/LiuYu")
		player.can_move = false
		face_towards(player.global_position)
		show_intro_dialog()

func show_intro_dialog():
	dialog_lines = [
		{ "text": "「兵器齊全，價錢公道，歡迎隨意看看——不強買、不強賣，只賣對得起\n這份工的東西。」", "speaker": speaker_id, "portrait": portrait_path }
	]
	dialog_manager.dialog_sequence_finished.connect(_on_intro_finished)
	dialog_manager.show_dialog_sequence(dialog_lines, self)

func _on_intro_finished(npc_node):
	if npc_node != self:
		return
	dialog_manager.dialog_sequence_finished.disconnect(_on_intro_finished)
	is_talking = false
	dialog_manager.show_choice([
		{ "text": "交易", "callback": Callable(self, "_dealing") },
		{ "text": "閒聊", "callback": Callable(self, "_chat") }
	])

func _dealing():
	dialog_manager.choice_box.hide_choices()
	is_talking = true
	var player = get_node("/root/GameRoot/LiuYu")
	player.can_move = false
	await ShopUI.open_shop(shop_id, player)
	is_talking = false
	player.can_move = true

func _chat():
	dialog_manager.choice_box.hide_choices()
	is_talking = true
	dialog_lines = [
		{ "text": "「左飲？他啊…比起人，更像是劍。你若真想見他，得先讓自己別像塊鐵。」", "speaker": speaker_id, "portrait": portrait_path }
	]
	dialog_manager.dialog_sequence_finished.connect(_on_done_reset)
	dialog_manager.show_dialog_sequence(dialog_lines, self)

func _on_done_reset(npc_node):
	if npc_node != self:
		return
	dialog_manager.dialog_sequence_finished.disconnect(_on_done_reset)
	is_talking = false
	has_recently_talked = true
	get_node("/root/GameRoot/LiuYu").can_move = true

func face_towards(target_position: Vector2):
	var direction = (target_position - global_position).normalized()
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
